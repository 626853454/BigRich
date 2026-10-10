class_name FurPartyModel
extends RefCounted

const Map=preload("res://scripts/party/party_map.gd")
const Economy=preload("res://scripts/party/party_economy.gd")
const Joint=preload("res://scripts/party/party_joint_contract.gd")
const RollOutlook=preload("res://scripts/party/party_roll_outlook.gd")
const MAX_ROUNDS:=Economy.MAX_ROUNDS
const ITEM_LIMIT:=2
const COIN_LIMIT:=999
const ITEM_PRICES:={"boost":5,"shield":4,"swap":7}
const STAR_CHOICES:=Map.STAR_CHOICES
var _state:Dictionary={}
var _rng:=RandomNumberGenerator.new()
var _serial_clock:=0
var _tiles:Array[Dictionary]=Map.nodes()
# Presentation receives a copy. There is deliberately no writable state setter.
var state:Dictionary:
	get:return snapshot()

func snapshot()->Dictionary:return _state.duplicate(true)
func rng_state()->int:return _rng.state
func _int(value:Variant,lo:int,hi:int)->bool:return typeof(value)==TYPE_INT and value>=lo and value<=hi
func _bump()->void:
	_serial_clock+=1;_state.serial=_serial_clock
func _result(ok:bool,reason:String,action:String,actor:int=-1,facts:Dictionary={})->Dictionary:
	return {"ok":ok,"reason":reason,"action":action,"actor":actor,"phase":str(_state.get("phase","unstarted")),"serial":int(_state.get("serial",0)),"facts":facts.duplicate(true)}
func _reject(reason:String,action:String)->Dictionary:return _result(false,reason,action)
func _actor(actor:Variant,phase:Array[String])->bool:
	return not _state.is_empty() and _int(actor,0,1) and actor==_state.active and str(_state.phase) in phase
func start(seed:Variant,ai_enabled:Variant=true)->Dictionary:
	if not _int(seed,1,2147483647) or typeof(ai_enabled)!=TYPE_BOOL:return _reject("invalid_start","start")
	var players:Array[Dictionary]=[]
	for actor in 2:
		players.append({"id":actor,"name":Map.PLAYER_NAMES[actor],"coins":10,"stars":0,"node":0,"items":[],"ai":bool(ai_enabled) and actor==1,"bonus":0,"protected":false,"preparation":-1,"stake":0})
	_rng.seed=seed
	var properties:Array[Dictionary]=[]
	for tile in _tiles:
		if tile.kind=="property":properties.append({"node":int(tile.id),"owner":-1,"level":0,"visits":0})
	_state={"players":players,"active":0,"round":1,"max_rounds":MAX_ROUNDS,"team_goal":Economy.TEAM_GOAL,"phase":"prepare","roll":0,"remaining":0,"star_node":8,"serial":0,"path":[],"landing_resolved":false,"item_used":false,"challenge_token":0,"last_challenge_token":0,"challenge_history":[],"team_successes":0,"team_score":0,"team_won":false,"winners":[],"diagnostic_rolls":0,"seed":seed,"properties":properties,"economy_history":[],"battle_context":{},"market_actor":0,"market_bought":[false,false],"market_receipts":[],"joint_contract":{},"star_discounts":[0,0]}
	_bump();return _result(true,"","start",0,{"seed":seed,"ai_enabled":ai_enabled,"star_node":8})

func _record_economy(action:String,actor:int,facts:Dictionary)->void:
	_state.economy_history.append({"serial":int(_state.serial),"round":int(_state.round),"action":action,"actor":actor,"facts":facts.duplicate(true)})
	if _state.economy_history.size()>64:_state.economy_history.pop_front()

func prepare_options(actor:Variant)->Array[Dictionary]:
	if not _actor(actor,["prepare"]):return []
	return Economy.preparation_options(int(_state.players[actor].coins))

func choose_preparation(actor:Variant,choice:Variant)->Dictionary:
	if not _actor(actor,["prepare"]):return _reject("wrong_actor_or_phase","choose_preparation")
	if not _int(choice,0,1):return _reject("invalid_choice","choose_preparation")
	var player:Dictionary=_state.players[actor]
	if player.preparation!=-1:return _reject("already_prepared","choose_preparation")
	var cost:int=3 if choice==1 else 0
	if player.coins<cost:return _reject("insufficient_coins","choose_preparation")
	player.preparation=choice;player.stake=cost;player.coins-=cost;_state.phase="roll";_bump()
	var facts:Dictionary={"choice":choice,"cost":cost,"coins_after":int(player.coins),"health_bonus":12.0 if choice==0 else 0.0,"damage_bonus":.12 if choice==1 else 0.0}
	_record_economy("prepare",actor,facts);return _result(true,"","choose_preparation",actor,facts)

func choose_ai_preparation(actor:Variant)->int:
	if not _actor(actor,["prepare"]):return -1
	var player:Dictionary=_state.players[actor]
	# Keep a safe/free opening, protect a near star budget, and recover after a loss.
	if player.coins<8 or _state.challenge_history.is_empty() or _ai_last_lost():return 0
	var price:int=star_price(actor)
	if player.coins<price+3 and player.coins>=price-6 and _ai_distance(int(player.node),int(_state.star_node),int(player.coins))<=6:return 0
	var leader:int=(int(_state.round)-1)%2
	if actor==leader and _tiles[player.node].district==1:return 0 # Wind supplies damage already.
	return 1

func _property(node:int)->Dictionary:
	for property in _state.properties:
		if property.node==node:return property
	return {}

func _shop_discount(actor:int)->int:
	var district:int=_tiles[_state.players[actor].node].district;var discount:=0
	for property in _state.properties:
		if property.owner==actor and _tiles[property.node].district==district:discount=maxi(discount,int(property.level))
	return discount

func star_price(actor:Variant)->int:
	if _state.is_empty() or not _int(actor,0,1):return 20
	return 20-int(_state.star_discounts[actor])

func _star_candidates()->Array[int]:
	var candidates:Array[int]=[]
	for node in STAR_CHOICES:
		if node!=_state.star_node:candidates.append(int(node))
	candidates.sort()
	return candidates

func star_migration_options(actor:Variant)->Array[Dictionary]:
	var options:Array[Dictionary]=[]
	if not _actor(actor,["landing"]) or _state.landing_resolved:return options
	var player:Dictionary=_state.players[actor]
	if player.node!=_state.star_node:return options
	var base_price:int=star_price(actor)
	var price:int=base_price+Economy.STAR_MIGRATION_FEE
	var reason:=""
	if _state.round==MAX_ROUNDS:reason="last_round"
	elif player.stars>=99:reason="star_cap"
	elif player.coins<price:reason="insufficient_coins"
	var candidates:Array[int]=_star_candidates()
	for index in candidates.size():
		options.append({"choice":index+2,"migration_node":candidates[index],"fee":Economy.STAR_MIGRATION_FEE,"base_price":base_price,"total_price":price,"enabled":reason.is_empty(),"reason":reason})
	return options

func joint_quote(actor:Variant)->Dictionary:
	var quote:Dictionary={"enabled":false,"reason":"not_event_landing","origin_node":-1,"target_district":-1,"target_name":"","first_round":0,"expires_round":0,"sponsor":-1,"partner":-1,"star_discount":Economy.JOINT_STAR_DISCOUNT,"partner_coins":Economy.JOINT_PARTNER_REWARD}
	if _state.is_empty() or not _int(actor,0,1):return quote
	var player:Dictionary=_state.players[actor];var node:int=player.node;var target:int=(int(_tiles[node].district)+1)%3
	quote.origin_node=node;quote.target_district=target;quote.target_name=Map.districts()[target].name
	quote.first_round=int(_state.round);quote.expires_round=int(_state.round)+Economy.JOINT_WINDOW_ROUNDS-1;quote.sponsor=actor;quote.partner=1-actor
	if not _actor(actor,["landing"]) or _state.landing_resolved or _tiles[node].kind!="event":return quote
	if _state.round>Economy.JOINT_LAST_ACCEPT_ROUND:quote.reason="too_late";return quote
	if _serial_clock>=2147483647:quote.reason="sequence_exhausted";return quote
	if not _state.joint_contract.is_empty():quote.reason="active_contract";return quote
	if _state.star_discounts[actor]!=0:quote.reason="unused_star_discount";return quote
	if player.stars>=99:quote.reason="star_cap";return quote
	quote.enabled=true;quote.reason="";return quote
func roll_dice(actor:Variant,forced:Variant=0)->Dictionary:
	if not _actor(actor,["roll"]):return _reject("wrong_actor_or_phase","roll_dice")
	if _state.players[actor].preparation not in [0,1]:return _reject("preparation_required","roll_dice")
	if not _int(forced,0,6):return _reject("invalid_die","roll_dice")
	var player:Dictionary=_state.players[actor]
	var face:int=_rng.randi_range(1,6) if forced==0 else forced
	var bonus:int=player.bonus;player.bonus=0
	_state.roll=face+bonus;_state.remaining=_state.roll;_state.path=[int(player.node)];_state.landing_resolved=false
	_state.phase="branch" if _tiles[player.node].next.size()>1 else "moving"
	if forced!=0:_state.diagnostic_rolls+=1
	_bump();return _result(true,"","roll_dice",actor,{"face":face,"bonus":bonus,"steps":_state.roll,"forced":forced!=0})
func branch_options(actor:Variant)->Array[int]:
	var options:Array[int]=[]
	if not _actor(actor,["branch"]):return options
	var player:Dictionary=_state.players[actor]
	for node in _tiles[player.node].next:
		if not Map.is_ferry_edge(player.node,int(node)) or player.coins>=2:options.append(int(node))
	return options

func preview_branch(actor:Variant,target:Variant)->Dictionary:
	var empty:Dictionary={"ok":false,"reason":"invalid_branch","path":[],"node":-1,"remaining":0,"landing":false,"stop_reason":"","ferry_cost":0}
	if not _int(target,0,_tiles.size()-1) or target not in branch_options(actor):return empty
	var player:Dictionary=_state.players[actor];var remaining:int=_state.remaining-1;var node:int=target
	var path:Array[int]=[int(player.node),node]
	var cost:int=2 if Map.is_ferry_edge(int(player.node),node) else 0
	while remaining>0 and _tiles[node].next.size()==1:
		node=int(_tiles[node].next[0]);remaining-=1;path.append(node)
	return {"ok":true,"reason":"","path":path,"node":node,"remaining":remaining,"landing":remaining==0,"stop_reason":"landing" if remaining==0 else "next_fork","ferry_cost":cost}
func advance(actor:Variant,choice:Variant=-1)->Dictionary:
	if not _actor(actor,["moving","branch"]):return _reject("wrong_actor_or_phase","advance")
	if not _int(choice,-1,_tiles.size()-1) or not _int(_state.remaining,1,8):return _reject("invalid_move","advance")
	var player:Dictionary=_state.players[actor];var origin:int=player.node;var edges:Array=_tiles[origin].next
	if _state.phase=="branch" and choice not in edges:return _reject("branch_choice_required","advance")
	if choice!=-1 and choice not in edges:return _reject("invalid_edge","advance")
	var destination:int=edges[0] if choice==-1 else choice
	var ferry:bool=Map.is_ferry_edge(origin,destination);var cost:int=2 if ferry else 0
	if player.coins<cost:return _reject("insufficient_ferry_coins","advance")
	player.coins-=cost
	player.node=destination;_state.remaining-=1;_state.path.append(destination)
	_state.phase="landing" if _state.remaining==0 else ("branch" if _tiles[destination].next.size()>1 else "moving")
	_bump()
	var facts:Dictionary={"from":origin,"to":destination,"remaining":_state.remaining,"branch_options":branch_options(actor),"ferry":ferry,"ferry_cost":cost,"coins_after":int(player.coins),"district":int(_tiles[destination].district)}
	if ferry:_record_economy("ferry",actor,facts)
	return _result(true,"","advance",actor,facts)
func landing_options(actor:Variant)->Array[Dictionary]:
	var options:Array[Dictionary]=[]
	if not _actor(actor,["landing"]) or _state.landing_resolved:return options
	var player:Dictionary=_state.players[actor];var kind:String=_tiles[player.node].kind
	if player.node==_state.star_node:
		var price:int=star_price(actor)
		options=[{"choice":0,"label":"%d金币买当前 +1星；下颗随机%s"%[price,"（券减5）" if price<20 else ""],"cost":price,"enabled":player.coins>=price and player.stars<99},{"choice":1,"label":"这次留钱","cost":0,"enabled":true}]
		for migration in star_migration_options(actor):
			var destination:int=migration.migration_node
			var district_name:String=Map.districts()[int(_tiles[destination].district)].name
			var disabled:String="\n末轮无下一次行动" if migration.reason=="last_round" else ("\n金币不足" if migration.reason=="insufficient_coins" else ("\n星铃已满" if migration.reason=="star_cap" else ""))
			options.append({"choice":migration.choice,"label":"当前 +1星；下颗→%s %02d格\n总价 %d金（含航费%d）%s"%[district_name,destination,migration.total_price,migration.fee,disabled],"cost":migration.total_price,"enabled":migration.enabled,"reason":migration.reason})
		return options
	if kind=="event":
		var quote:Dictionary=joint_quote(actor)
		return [{"choice":0,"label":"帮摊主搬货：金币 +4","cost":0,"enabled":true},{"choice":1,"label":"领加骰道具，下回合 +2步","cost":0,"enabled":player.items.size()<ITEM_LIMIT},{"choice":2,"label":"跨岛合伙：去%s · 截至第%d场\n完成地区任务且守住：自己下颗星15金 / 伙伴 +5金"%[quote.target_name,quote.expires_round],"cost":0,"enabled":quote.enabled,"reason":quote.reason,"quote":quote}]
	if kind=="shop":
		var discount:int=_shop_discount(actor)
		for item in ["boost","shield","swap"]:
			var cost:int=Economy.item_cost(item,discount)
			options.append({"choice":options.size(),"label":{"boost":"加骰 +2步","shield":"保钱护符","swap":"交换两人位置"}[item]+"（%d金）"%cost,"item":item,"cost":cost,"discount":discount,"enabled":player.coins>=cost and player.items.size()<ITEM_LIMIT})
		options.append({"choice":3,"label":"留钱离开","cost":0,"enabled":true});return options
	if kind=="property":
		var property:Dictionary=_property(int(player.node))
		if property.owner==-1:return [{"choice":0,"label":"买合作摊位（8金）：本岛生命 +2 / 商店减1","cost":8,"enabled":player.coins>=8},{"choice":1,"label":"帮摆摊：金币 +2","cost":0,"enabled":true}]
		if property.owner==actor:
			return [{"choice":0,"label":"营业：金币 +%d"%(2 if property.level==1 else 3),"cost":0,"enabled":true},{"choice":1,"label":"升级（6金）并营业赚3：净花3金","cost":6,"enabled":property.level==1 and player.coins>=6}]
		return [{"choice":0,"label":"合作营业：两人各 +1金币","cost":0,"enabled":true}]
	return [{"choice":0,"label":"收取落点效果","cost":0,"enabled":true}]
func resolve_landing(actor:Variant,choice:Variant=0)->Dictionary:
	if not _actor(actor,["landing"]) or _state.landing_resolved:return _reject("wrong_actor_or_phase","resolve_landing")
	if not _int(choice,0,3):return _reject("invalid_choice","resolve_landing")
	var allowed:=false
	for option in landing_options(actor):
		if option.choice==choice and option.enabled:allowed=true
	if not allowed:return _reject("unavailable_choice","resolve_landing")
	var player:Dictionary=_state.players[actor];var kind:String="star" if player.node==_state.star_node else _tiles[player.node].kind
	var before:int=player.coins;var stars_before:int=player.stars;var item:="";var protected:=false;var old_star:int=_state.star_node
	var partner:Dictionary=_state.players[1-actor];var partner_before:int=partner.coins;var cost:=0;var discount:=0;var property:Dictionary={};var consumed_discount:=0
	var star_base_price:=0;var migration_fee:=0
	match kind:
		"star":
			if choice in [0,2,3]:
				star_base_price=star_price(actor);migration_fee=Economy.STAR_MIGRATION_FEE if choice>=2 else 0
				cost=star_base_price+migration_fee;consumed_discount=int(_state.star_discounts[actor])
				player.coins-=cost;player.stars+=1;_state.star_discounts[actor]=0
				var candidates:Array[int]=_star_candidates()
				# One original migration draw is consumed for either purchase.
				# Paid control overrides its destination, never adds another draw.
				var sampled:int=candidates[_rng.randi_range(0,candidates.size()-1)]
				_state.star_node=candidates[int(choice)-2] if choice>=2 else sampled
		"blue":player.coins=mini(COIN_LIMIT,player.coins+3)
		"red":
			if player.protected:player.protected=false;protected=true
			else:player.coins=maxi(0,player.coins-3)
		"coin":player.coins=mini(COIN_LIMIT,player.coins+5)
		"event":
			if choice==0:player.coins=mini(COIN_LIMIT,player.coins+4)
			elif choice==1:item="boost";player.items.append(item)
			else:_state.joint_contract=Joint.create(_serial_clock+1,int(_state.round),actor,int(player.node))
		"shop":
			if choice<3:
				item=["boost","shield","swap"][choice];discount=_shop_discount(actor);cost=Economy.item_cost(item,discount);player.coins-=cost;player.items.append(item)
		"property":
			property=_property(int(player.node));property.visits+=1
			if property.owner==-1:
				if choice==0:cost=8;player.coins-=cost;property.owner=actor;property.level=1
				else:player.coins=mini(COIN_LIMIT,player.coins+2)
			elif property.owner==actor:
				if choice==1:cost=6;player.coins-=cost;property.level=2
				player.coins=mini(COIN_LIMIT,player.coins+(2 if property.level==1 else 3))
			else:
				player.coins=mini(COIN_LIMIT,player.coins+1);partner.coins=mini(COIN_LIMIT,partner.coins+1)
	_state.landing_resolved=true;_bump()
	var facts:Dictionary={"node":player.node,"kind":kind,"choice":choice,"coin_delta":player.coins-before,"star_delta":player.stars-stars_before,"item":item,"protected":protected,"old_star_node":old_star,"star_node":_state.star_node,"property":property.duplicate(true),"partner_coin_delta":partner.coins-partner_before,"discount":discount,"cost":cost,"star_discount_consumed":consumed_discount,"joint_contract":_state.joint_contract.duplicate(true) if kind=="event" and choice==2 else {}}
	if kind=="star" and choice!=1:
		facts["star_base_price"]=star_base_price;facts["migration_fee"]=migration_fee;facts["migration_node"]=int(_state.star_node)
	_record_economy("landing",actor,facts);return _result(true,"","resolve_landing",actor,facts)
func use_item(actor:Variant,kind:Variant,target:Variant=-1)->Dictionary:
	if not _actor(actor,["roll"]):return _reject("wrong_actor_or_phase","use_item")
	if typeof(kind)!=TYPE_STRING or not ITEM_PRICES.has(kind) or not _int(target,-1,1):return _reject("invalid_item","use_item")
	var player:Dictionary=_state.players[actor]
	if _state.item_used or kind not in player.items:return _reject("item_unavailable","use_item")
	if kind=="swap":
		if target!=1-actor or player.node==_state.players[target].node:return _reject("invalid_target","use_item")
	else:
		if target not in [-1,actor]:return _reject("invalid_target","use_item")
		if (kind=="boost" and player.bonus!=0) or (kind=="shield" and player.protected):return _reject("already_active","use_item")
	var origin:int=player.node;var other_origin:=-1
	match kind:
		"boost":player.bonus=2
		"shield":player.protected=true
		"swap":
			other_origin=_state.players[target].node;player.node=other_origin;_state.players[target].node=origin
	player.items.erase(kind);_state.item_used=true;_bump()
	return _result(true,"","use_item",actor,{"item":kind,"target":target,"from":origin,"to":player.node,"other_from":other_origin,"other_to":origin if kind=="swap" else -1})
func finish_turn(actor:Variant)->Dictionary:
	if not _actor(actor,["landing"]) or not _state.landing_resolved:return _reject("unresolved_or_wrong_actor","finish_turn")
	_state.roll=0;_state.remaining=0;_state.path=[];_state.landing_resolved=false;_state.item_used=false
	if actor==0:_state.active=1;_state.phase="prepare"
	else:_state.active=0;_state.phase="challenge"
	_bump()
	if _state.phase=="challenge":
		_state.challenge_token=_state.serial;_state.battle_context=_make_battle_context()
	return _result(true,"","finish_turn",actor,{"next_actor":_state.active,"round":_state.round,"challenge_token":_state.challenge_token})

func _make_battle_context()->Dictionary:
	var leader:int=(int(_state.round)-1)%2;var district:int=_tiles[_state.players[leader].node].district
	var regional:Dictionary=Economy.region_bonus(district);var bonuses:Array[Dictionary]=[];var preparations:Array[int]=[];var strengths:Array[int]=[]
	for actor in 2:
		var player:Dictionary=_state.players[actor];var strength:=0
		for property in _state.properties:
			if property.owner==actor and _tiles[property.node].district==district:strength+=int(property.level)
		strength=mini(4,strength);strengths.append(strength);preparations.append(int(player.preparation))
		bonuses.append({"health_bonus":float(regional.health)+(12.0 if player.preparation==0 else 0.0)+2.0*strength,"damage_bonus":float(regional.damage)+(.12 if player.preparation==1 else 0.0)})
	return {"ok":true,"reason":"","token":int(_state.challenge_token),"round":int(_state.round),"district":district,"district_name":str(Map.districts()[district].name),"leader":leader,"route":district,"bonuses":bonuses,"reward_bonus":int(regional.reward),"preparations":preparations,"property_strength":strengths,"joint_contract":_state.joint_contract.duplicate(true)}

func battle_context()->Dictionary:
	if _state.is_empty() or _state.phase!="challenge":return {"ok":false,"reason":"not_challenge"}
	return _state.battle_context.duplicate(true)
func settle_challenge(results:Variant,token:Variant,proof:Variant={})->Dictionary:
	if _state.is_empty() or _state.phase!="challenge" or not _int(token,1,2147483647) or token!=_state.challenge_token or token==_state.last_challenge_token:return _reject("stale_challenge","settle_challenge")
	if not results is Array or results.size()!=2 or not _int(results[0],0,10000) or not _int(results[1],0,10000):return _reject("invalid_results","settle_challenge")
	var context:Dictionary=_state.battle_context
	var won:bool=results[0]+results[1]>=100;var reward:int=(5+int(context.reward_bonus)) if won else 2
	var proof_status:Dictionary=Joint.validate_proof(proof,token,int(_state.round),int(context.route),won)
	if not proof_status.ok:return _reject("invalid_joint_proof","settle_challenge")
	var joint_result:Dictionary=Joint.result(_state.joint_contract,int(_state.round),int(context.route),won,proof_status)
	var contract_returns:Array[int]=[];var coin_rewards:Array[int]=[]
	for player in _state.players:
		var returned:int=(7 if won else 1) if player.stake==3 else 0
		var before:int=player.coins;player.coins=mini(COIN_LIMIT,player.coins+reward+returned)
		contract_returns.append(returned);coin_rewards.append(int(player.coins)-before)
		player.preparation=-1;player.stake=0
	if joint_result.status=="completed":
		var sponsor:int=joint_result.sponsor;var partner:int=joint_result.partner
		_state.star_discounts[sponsor]=Economy.JOINT_STAR_DISCOUNT;joint_result.star_discount=Economy.JOINT_STAR_DISCOUNT
		var before_joint:int=_state.players[partner].coins
		_state.players[partner].coins=mini(COIN_LIMIT,before_joint+Economy.JOINT_PARTNER_REWARD)
		joint_result.partner_coin_delta=int(_state.players[partner].coins)-before_joint
		coin_rewards[partner]+=int(joint_result.partner_coin_delta)
		_state.joint_contract={}
	elif joint_result.status=="expired":_state.joint_contract={}
	_state.last_challenge_token=token;_state.challenge_token=0;_state.team_score+=int(results[0])+int(results[1])
	if won:_state.team_successes+=1
	var receipt:Dictionary={"round":_state.round,"token":token,"scores":[int(results[0]),int(results[1])],"team_won":won,"coin_reward_each":reward,"district":int(context.district),"leader":int(context.leader),"reward_bonus":int(context.reward_bonus) if won else 0,"preparations":context.preparations.duplicate(),"contract_returns":contract_returns,"coin_rewards":coin_rewards,"joint_result":joint_result}
	_state.challenge_history.append(receipt)
	if _state.round==MAX_ROUNDS:
		_state.phase="finished";_state.team_won=_state.team_successes>=Economy.TEAM_GOAL
		var a:Dictionary=_state.players[0];var b:Dictionary=_state.players[1]
		var a_score:int=a.stars*1000+a.coins;var b_score:int=b.stars*1000+b.coins
		_state.winners=[0,1] if a_score==b_score else [0 if a_score>b_score else 1]
	else:_state.round+=1;_state.phase="market";_state.active=0;_state.market_actor=0;_state.market_bought=[false,false]
	_state.battle_context={};_bump();_record_economy("battle",-1,receipt)
	return _result(true,"","settle_challenge",-1,{"receipt":receipt,"team_successes":_state.team_successes,"finished":_state.phase=="finished","winners":_state.winners})

func buy_workshop(actor:Variant,upgrade_id:Variant)->Dictionary:
	if not _actor(actor,["market"]) or actor!=_state.market_actor:return _reject("wrong_actor_or_phase","buy_workshop")
	if not Economy.valid_workshop(upgrade_id):return _reject("invalid_upgrade","buy_workshop")
	var player:Dictionary=_state.players[actor]
	if _state.market_bought[actor]:return _reject("already_bought","buy_workshop")
	if player.coins<Economy.WORKSHOP_PRICE:return _reject("insufficient_coins","buy_workshop")
	player.coins-=Economy.WORKSHOP_PRICE;_state.market_bought[actor]=true;_bump()
	var receipt:Dictionary={"serial":int(_state.serial),"round":int(_state.round),"actor":int(actor),"upgrade_id":upgrade_id,"cost":Economy.WORKSHOP_PRICE}
	_state.market_receipts.append(receipt);_record_economy("workshop",actor,receipt)
	return _result(true,"","buy_workshop",actor,{"upgrade_id":upgrade_id,"cost":Economy.WORKSHOP_PRICE,"market_receipt":receipt,"coins_after":int(player.coins)})

func finish_market(actor:Variant)->Dictionary:
	if not _actor(actor,["market"]) or actor!=_state.market_actor:return _reject("wrong_actor_or_phase","finish_market")
	if actor==0:_state.market_actor=1;_state.active=1
	else:_state.market_actor=0;_state.active=0;_state.phase="prepare"
	_bump();return _result(true,"","finish_market",actor,{"next_actor":int(_state.active),"round":int(_state.round)})

func choose_ai_workshop(actor:Variant)->String:
	if not _actor(actor,["market"]) or actor!=_state.market_actor or _state.market_bought[actor]:return ""
	var player:Dictionary=_state.players[actor]
	if player.coins<12:return ""
	if player.coins<star_price(actor)+6 and _ai_distance(int(player.node),int(_state.star_node),int(player.coins))<=8:return ""
	if _ai_last_lost():return "heal"
	# Rotate a finite preference, rather than buying the same stat forever.
	return ["weapon","area","link","power","crit","speed","bounce"][(int(_state.round)+int(actor)-2)%7]

func _ai_last_lost()->bool:
	return not _state.challenge_history.is_empty() and not bool(_state.challenge_history.back().team_won)

func _ai_distance(origin:int,target:int,coins:int)->int:
	# A 54-node breadth-first estimate, used only at a decision. It does not
	# predict later fork selections or guarantee future ferry affordability.
	var distance:Array[int]=[];distance.resize(_tiles.size());distance.fill(-1)
	var queue:Array[int]=[origin];distance[origin]=0;var cursor:=0
	while cursor<queue.size():
		var node:int=queue[cursor];cursor+=1
		if node==target:return distance[node]
		for next in _tiles[node].next:
			if distance[next]>=0 or (Map.is_ferry_edge(node,int(next)) and coins<2):continue
			distance[next]=distance[node]+1;queue.append(int(next))
	return _tiles.size()

func _ai_region_value(district:int,actor:int)->float:
	var player:Dictionary=_state.players[actor];var leader:int=(int(_state.round)-1)%2
	var weight:float=1.0 if actor==leader else .55 # Position for the following leadership turn.
	if _state.round==MAX_ROUNDS and actor!=leader:return 0.0
	var value:float=7.0 if district==1 else (8.0 if district==2 and _ai_last_lost() else (2.5 if district==2 else (5.0 if player.coins<8 else 2.0)))
	if _state.team_successes>=Economy.TEAM_GOAL:value*=.45
	var joint:Dictionary=_state.joint_contract
	if not joint.is_empty() and district==int(joint.target_district):
		# Current leader can fulfil now; the next leader may prepare next round.
		# Never imply a nonleader can switch this already-chosen current arena.
		if actor==leader:value+=14.0 if _state.round==joint.expires_round else 10.0
		elif _state.round<joint.expires_round:value+=10.0
	return value*weight
func _landing_value(node:int,actor:int)->float:
	var player:Dictionary=_state.players[actor]
	if node==_state.star_node:return 40.0 if player.coins>=star_price(actor) else 1.0
	if _tiles[node].kind=="property":
		var property:Dictionary=_property(node)
		return 6.0 if property.owner==-1 and player.coins>=12 else (3.0 if property.owner==actor else 2.0)
	return {"blue":3.0,"red":0.0 if player.protected else -3.0,"coin":5.0,"event":4.0,"shop":2.0 if player.coins>=5 and player.items.size()<ITEM_LIMIT else 0.0,"start":0.0}.get(_tiles[node].kind,0.0)
func choose_ai_branch(actor:Variant)->int:
	var options:Array[int]=branch_options(actor)
	if options.is_empty():return -1
	var best:int=options[0];var value:=-1000.0
	for candidate in options:
		var preview:Dictionary=preview_branch(actor,candidate)
		var score:float=_landing_value(int(preview.node),actor)-float(preview.ferry_cost)
		var player:Dictionary=_state.players[actor];var node:int=preview.node
		var price:int=star_price(actor)
		var star_weight:float=12.0 if player.coins>=price else (5.0 if player.coins>=price-6 else 1.0)
		score+=star_weight/(1.0+_ai_distance(node,int(_state.star_node),int(player.coins)-int(preview.ferry_cost)))
		score+=_ai_region_value(int(_tiles[node].district),actor)
		# The score ends at the next decision; it never invents later choices.
		if preview.stop_reason=="next_fork":score+=1.0
		if score>value:value=score;best=candidate
	return best
func choose_ai_landing(actor:Variant)->int:
	var options:Array[Dictionary]=landing_options(actor)
	if options.is_empty():return -1
	var player:Dictionary=_state.players[actor];var node:int=player.node
	var price:int=star_price(actor)
	if node==_state.star_node:
		if player.coins<price or player.stars>=99:return 1
		var migration:Array[Dictionary]=star_migration_options(actor)
		if migration.size()==2:
			var distances:Array[int]=[]
			for option in migration:distances.append(_ai_distance(node,int(option.migration_node),int(player.coins)-int(option.total_price)))
			var partner:Dictionary=_state.players[1-actor]
			for index in 2:
				var option:Dictionary=migration[index]
				if not option.enabled or player.coins-int(option.total_price)<Economy.WORKSHOP_PRICE:continue
				if distances[index]+2>distances[1-index]:continue
				var partner_distance:int=_ai_distance(int(partner.node),int(option.migration_node),int(partner.coins))
				if distances[index]+2<=partner_distance:return int(option.choice)
		return 0
	var distance:int=_ai_distance(node,int(_state.star_node),int(player.coins))
	var reserve:int=price if distance<=8 and player.coins>=price-6 else 6
	if _tiles[node].kind=="shop":
		var preferred:int=1 if _ai_last_lost() else (0 if _state.round<6 else 2)
		return preferred if options[preferred].enabled and player.coins-int(options[preferred].cost)>=reserve else 3
	if _tiles[node].kind=="event":
		# A near affordable star calls for guaranteed cash. Otherwise accept a
		# plausible partner route, rather than every optional delayed promise.
		var quote:Dictionary=joint_quote(actor)
		if quote.enabled and not (distance<=8 and player.coins>=price-4):
			var leader:int=(int(_state.round)-1)%2
			if actor!=leader and _tiles[_state.players[leader].node].district==quote.target_district:return 2
			var next_leader:int=int(_state.round)%2
			if player.coins>=6 and not _ai_last_lost() and _ai_district_distance(int(_state.players[next_leader].node),int(quote.target_district),int(_state.players[next_leader].coins))<=6:return 2
		return 1 if player.items.size()<ITEM_LIMIT and player.coins>=reserve+4 and _state.round<MAX_ROUNDS else 0
	if _tiles[node].kind=="property":
		var property:Dictionary=_property(node)
		if property.owner==-1:return 0 if player.coins>=8+reserve and _state.round<=5 else 1
		if property.owner==actor and property.level==1 and player.coins>=6+reserve and _state.round<MAX_ROUNDS:return 1
	return 0
func choose_ai_item(actor:Variant)->Dictionary:
	if not _actor(actor,["roll"]) or _state.item_used:return {"kind":"","target":-1}
	var player:Dictionary=_state.players[actor]
	if "shield" in player.items and not player.protected:return {"kind":"shield","target":actor}
	if "boost" in player.items:return {"kind":"boost","target":actor}
	if "swap" in player.items and player.node!=_state.players[1-actor].node:
		var preview:Dictionary=ai_swap_preview(actor)
		if not preview.is_empty() and float(preview.benefit)>=1.5:return {"kind":"swap","target":1-actor}
	return {"kind":"","target":-1}

func ai_swap_preview(actor:Variant)->Dictionary:
	if not _actor(actor,["roll"]) or _state.item_used:return {}
	var player:Dictionary=_state.players[actor]
	if "swap" not in player.items or player.node==_state.players[1-actor].node:return {}
	var evaluator:Callable=func(node:int,coins:int)->float:return _ai_future_landing_value(node,actor,coins)
	var current:Dictionary=RollOutlook.evaluate(_tiles,int(player.node),int(player.coins),int(player.bonus),evaluator)
	var swapped:Dictionary=RollOutlook.evaluate(_tiles,int(_state.players[1-actor].node),int(player.coins),int(player.bonus),evaluator)
	if current.is_empty() or swapped.is_empty():return {}
	return {"current":current,"swapped":swapped,"benefit":float(swapped.value)-float(current.value),"threshold":1.5}

func _ai_future_landing_value(node:int,actor:int,coins:int)->float:
	var player:Dictionary=_state.players[actor];var value:=0.0
	if node==_state.star_node:value=40.0 if coins>=star_price(actor) and player.stars<99 else 1.0
	elif _tiles[node].kind=="property":
		var property:Dictionary=_property(node)
		value=6.0 if property.owner==-1 and coins>=12 else (3.0 if property.owner==actor else 2.0)
	else:value={"blue":3.0,"red":0.0 if player.protected else -3.0,"coin":5.0,"event":4.0,"shop":2.0 if coins>=5 and player.items.size()<ITEM_LIMIT else 0.0,"start":0.0}.get(_tiles[node].kind,0.0)
	# This is endpoint utility after the roll, never an origin landing reward.
	return value+_ai_region_value(int(_tiles[node].district),actor)

func _ai_district_distance(origin:int,district:int,coins:int)->int:
	var distance:Array[int]=[];distance.resize(_tiles.size());distance.fill(-1)
	var queue:Array[int]=[origin];distance[origin]=0;var cursor:=0
	while cursor<queue.size():
		var node:int=queue[cursor];cursor+=1
		if int(_tiles[node].district)==district:return distance[node]
		for next in _tiles[node].next:
			if distance[next]>=0 or (Map.is_ferry_edge(node,int(next)) and coins<2):continue
			distance[next]=distance[node]+1;queue.append(int(next))
	return _tiles.size()
