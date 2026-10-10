class_name FurAdventureModel
extends "res://scripts/party/party_model.gd"

const AdventureMap=preload("res://scripts/party/adventure_map.gd")
const MahjongTable=preload("res://scripts/party/chapter_mahjong_table.gd")
const Commissions=preload("res://scripts/party/chapter_commissions.gd")
var _commissions:=Commissions.new()
const CHAPTER_COUNT:=3
const CHAPTER_GOAL:=2
const TEA_STAKE:=3
const TEA_RETURN:=8
const RESOURCE_KEYS:=["wilds","redraws","rotate_tokens","echo_bonus"]

func _empty_resources()->Array[Dictionary]:
	return [{"wilds":0,"redraws":0,"rotate_tokens":0,"echo_bonus":0},{"wilds":0,"redraws":0,"rotate_tokens":0,"echo_bonus":0}]
func _empty_provisions()->Array[Dictionary]:return [{"health_bonus":0.0,"damage_bonus":0.0},{"health_bonus":0.0,"damage_bonus":0.0}]
func start(seed:Variant,ai_enabled:Variant=true)->Dictionary:
	if not _int(seed,1,2147483647) or typeof(ai_enabled)!=TYPE_BOOL:return _reject("invalid_start","start")
	_tiles=AdventureMap.nodes(0)
	var result:Dictionary=super.start(seed,ai_enabled)
	if not result.ok:return result
	_state.merge({"chapter":0,"chapter_goal":CHAPTER_GOAL,"chapter_cleared":[],"chapter_history":[],"turn":1,"activity_index":0,"chapter_resources":_empty_resources(),"provisions":_empty_provisions(),"resource_history":[],"practice":false,"campaign_completed":false,"estate_resource_grants":[],"latest_estate_supplies":[],"tea_contract":{},"resume_actor":1,"activity_trigger":-1,"activity_actor":-1,"max_rounds":9,"team_goal":6,"supply_claims":{},"latest_commission_receipts":[]})
	var configured:bool=_commissions.configure(0,_tiles)
	assert(configured)
	return _result(true,"","start",0,{"seed":seed,"ai_enabled":ai_enabled,"chapter":0})

func _node_kind(node:int)->String:
	var tile:Dictionary=_tiles[node]
	if not str(tile.get("activity","")).is_empty():return str(tile.activity)
	if not str(tile.get("station","")).is_empty():return str(tile.station)
	return str(tile.kind)
func start_chapter(seed:Variant,ai_enabled:Variant,chapter:Variant)->Dictionary:
	if not _int(chapter,0,2):return _reject("invalid_chapter","start_chapter")
	var result:Dictionary=start(seed,ai_enabled)
	if not result.ok:return result
	_state.chapter=chapter;_state.practice=true;_tiles=AdventureMap.nodes(int(chapter))
	var configured:bool=_commissions.configure(chapter,_tiles)
	assert(configured)
	if chapter>0:_state.phase="roll";_state.players[0].preparation=0
	_bump();return _result(true,"","start_chapter",0,{"chapter":chapter,"practice":true,"seed":seed})

func prepare_options(actor:Variant)->Array[Dictionary]:
	if not _actor(actor,["prepare"]):return []
	return [{"choice":0,"label":"补给：下次实际活动生命 +12","cost":0,"enabled":true},{"choice":1,"label":"口粮：下次实际活动伤害 +12%","cost":0,"enabled":true}]
func choose_preparation(actor:Variant,choice:Variant)->Dictionary:
	if not _actor(actor,["prepare"]):return _reject("wrong_actor_or_phase","choose_preparation")
	if not _int(choice,0,1):return _reject("invalid_choice","choose_preparation")
	_state.players[actor].preparation=choice;_state.players[actor].stake=0;_state.phase="roll";_bump()
	return _result(true,"","choose_preparation",actor,{"choice":choice,"cost":0,"health_bonus":12.0 if choice==0 else 0.0,"damage_bonus":.12 if choice==1 else 0.0})
func choose_ai_preparation(actor:Variant)->int:
	if not _actor(actor,["prepare"]):return -1
	return 0 if _ai_last_lost() or _state.activity_index==0 else 1
func star_migration_options(actor:Variant)->Array[Dictionary]:
	var options:Array[Dictionary]=super.star_migration_options(actor)
	# Adventure does not finish after old round8; that limit belonged to Party.
	for option in options:
		if option.reason=="last_round":
			var player:Dictionary=_state.players[actor]
			option.reason="star_cap" if player.stars>=99 else ("insufficient_coins" if player.coins<option.total_price else "")
			option.enabled=str(option.reason).is_empty()
	return options

func joint_quote(actor:Variant)->Dictionary:
	return {"enabled":false,"reason":"adventure_no_round_contract","origin_node":-1,"target_district":-1,"target_name":"","first_round":0,"expires_round":0,"sponsor":-1,"partner":-1,"star_discount":5,"partner_coins":5}

func preview_branch(actor:Variant,target:Variant)->Dictionary:
	var empty:Dictionary={"ok":false,"reason":"invalid_branch","path":[],"node":-1,"remaining":0,"landing":false,"stop_reason":"","ferry_cost":0,"interrupted_steps":0}
	if not _int(target,0,_tiles.size()-1) or target not in branch_options(actor):return empty
	var player:Dictionary=_state.players[actor]
	var node:int=target;var remaining:int=_state.remaining-1;var path:Array[int]=[int(player.node),node]
	var cost:int=2 if AdventureMap.is_ferry_edge(int(player.node),node) else 0
	while remaining>0 and _tiles[node].next.size()==1 and not _is_stop(node):
		node=int(_tiles[node].next[0]);remaining-=1;path.append(node)
	var interrupted:int=remaining if _is_stop(node) else 0
	if interrupted>0:remaining=0
	return {"ok":true,"reason":"","path":path,"node":node,"remaining":remaining,"landing":remaining==0,"stop_reason":"challenge" if _node_kind(node)=="challenge" else ("chapter_exit" if _node_kind(node)=="chapter_exit" else ("landing" if remaining==0 else "next_fork")),"ferry_cost":cost,"interrupted_steps":interrupted}
func _is_stop(node:int)->bool:return _node_kind(node) in ["challenge","chapter_exit"]
func advance(actor:Variant,choice:Variant=-1)->Dictionary:
	var result:Dictionary=super.advance(actor,choice)
	if not result.ok:return result
	var node:int=_state.players[actor].node
	result.facts["interrupted_steps"]=0;result.facts["trigger_type"]=""
	if _is_stop(node):
		result.facts.interrupted_steps=int(_state.remaining);result.facts.trigger_type=str(_node_kind(node))
		_state.remaining=0;_state.phase="landing";result.facts.remaining=0;result.phase="landing"
	var recorded:bool=_commissions.observe_move(actor,int(result.facts.from),node,int(_state.turn),int(_state.serial))
	assert(recorded)
	result.facts["commission_status"]=commission_status()
	return result

func snapshot()->Dictionary:
	var copy:Dictionary=super.snapshot()
	copy["commissions"]=_commissions.snapshot()
	return copy
func commission_status()->Dictionary:return _commissions.snapshot()
func commission_quote(actor:Variant,kind:Variant)->Dictionary:
	if not _actor(actor,["landing"]) or _state.landing_resolved:return {"enabled":false,"reason":"wrong_actor_or_phase"}
	return _commissions.quote(actor,kind,int(_state.players[actor].node),int(_state.turn),int(_state.players[actor].coins))
func commission_choices(actor:Variant)->Array[Dictionary]:
	if not _actor(actor,["landing"]) or _state.landing_resolved or int(_state.players[actor].node) not in AdventureMap.COMMISSION_STATIONS:return []
	var offers:Array[Dictionary]=[]
	for kind in ["delivery","survey"]:
		var q:Dictionary=commission_quote(actor,kind)
		var route:String="送至%d格，落地交货"%q.target if kind=="delivery" else "经过%d格工坊，再到%d格挑战站"%[q.via,q.target]
		var label:String=("押3金运送" if kind=="delivery" else "投4金勘探")+" · "+route+" · 到账%d金 · 截止第%d手（两人轮流计数）"%[q.reward,q.expires_turn]
		offers.append({"choice":offers.size(),"label":label,"cost":int(q.cost),"enabled":bool(q.enabled),"reason":str(q.reason),"commission_quote":q})
	var own:Dictionary=_commissions.active(actor);var partner:Dictionary=_commissions.active(1-actor)
	var supportable:bool=not partner.is_empty() and int(partner.helper)==-1 and int(_state.turn)<=int(partner.expires_turn)
	offers.append({"choice":2,"label":"取消当前委托（退%d金；支援费不退）"%int(own.refund) if not own.is_empty() else ("付1金支援并延2手，亲自送达额外2金" if supportable else "暂无可支援委托"),"cost":0 if not own.is_empty() else 1,"enabled":not own.is_empty() or (supportable and _state.players[actor].coins>=1),"reason":"" if not own.is_empty() or supportable else "no_contract"})
	offers.append({"choice":3,"label":"交付已完成路线的委托 / 保留现金离开","cost":0,"enabled":true,"reason":""})
	return offers
func _apply_commission_receipts(receipts:Array[Dictionary])->Array[Dictionary]:
	var actual:Array[Dictionary]=[]
	for receipt in receipts:
		var paid:Array[int]=[0,0]
		for actor in 2:
			var before:int=_state.players[actor].coins
			_state.players[actor].coins=mini(COIN_LIMIT,before+int(receipt.promised_coins[actor]))
			paid[actor]=int(_state.players[actor].coins)-before
		var copy:Dictionary=receipt.duplicate(true);copy["actual_coins"]=paid;actual.append(copy)
		_state.latest_commission_receipts.append(copy.duplicate(true))
		if _state.latest_commission_receipts.size()>8:_state.latest_commission_receipts.pop_front()
		_record_economy("commission_"+str(receipt.action),int(receipt.owner),copy)
	return actual
func _with_commission_arrival(result:Dictionary,actor:int,node:int)->Dictionary:
	if result.ok:
		var prior:Array=result.facts.get("commission_receipts",[])
		prior.append_array(_apply_commission_receipts(_commissions.arrive(actor,node,int(_state.turn))))
		result.facts["commission_receipts"]=prior
		result.facts["commission_status"]=commission_status()
	return result
func _resolve_commission(actor:int,choice:int,node:int)->Dictionary:
	var transaction:Dictionary={"ok":true,"reason":"","cost":0,"receipt":{}}
	if choice<2:transaction=_commissions.accept(actor,["delivery","survey"][choice],node,int(_state.turn),int(_state.players[actor].coins))
	elif choice==2:transaction=_commissions.cancel(actor,int(_state.turn)) if not _commissions.active(actor).is_empty() else _commissions.support(actor,int(_state.turn),int(_state.players[actor].coins))
	if not transaction.ok:return _reject(transaction.reason,"resolve_landing")
	_state.players[actor].coins-=int(transaction.cost);_state.landing_resolved=true;_bump()
	var effects:Array[Dictionary]=[]
	if transaction.receipt.get("action","")=="cancelled":effects=_apply_commission_receipts([transaction.receipt])
	var facts:Dictionary={"node":node,"kind":"commission","choice":choice,"cost":int(transaction.cost),"coin_delta":-int(transaction.cost),"coins_after":int(_state.players[actor].coins),"commission_action":transaction.receipt,"commission_receipts":effects,"commission_status":commission_status()}
	_record_economy("commission_station",actor,facts)
	return _with_commission_arrival(_result(true,"","resolve_landing",actor,facts),actor,node)
func _supply_options(actor:int,node:int,offers:Array[Dictionary])->Array[Dictionary]:
	if _state.supply_claims.has("%d:%d"%[actor,node]):
		for option in offers:
			if option.choice in [0,1,2] and not (_node_kind(node)=="forge" and option.choice==2):option.enabled=false;option["reason"]="already_taken_this_chapter";option.label+="（本章已领取）"
	return offers

func _resource_key(choice:int)->String:
	if _state.chapter==1:return "wilds" if choice==0 else "redraws"
	return "rotate_tokens" if choice==0 else "echo_bonus"
func _forge_enabled(actor:int,choice:int)->bool:
	if _state.chapter==0:return _state.provisions[actor].health_bonus<24.0 if choice==0 else _state.provisions[actor].damage_bonus<.48
	return int(_state.chapter_resources[actor][_resource_key(choice)])<3
func _estate_level(actor:int,district:int)->int:
	var level:=0
	for property in _state.properties:
		if property.owner==actor and _tiles[property.node].district==district:level=maxi(level,int(property.level))
	return level
func estate_supply_preview(actor:Variant,node:Variant)->Dictionary:
	var empty:Dictionary={"ok":false,"actor":-1,"node":-1,"chapter":-1,"level":0,"already_given":false,"grants":{}}
	if _state.is_empty() or not _int(actor,0,1) or not _int(node,0,_tiles.size()-1) or _state.chapter==0 or _node_kind(int(node))!="challenge":return empty
	var level:int=_estate_level(int(actor),int(_tiles[node].district))
	var prior:=false
	for entry in _state.estate_resource_grants:
		if entry.chapter==_state.chapter and entry.node==node and entry.actor==actor:prior=true;break
	var first:String=_resource_key(0);var second:String=_resource_key(1)
	var grants:Dictionary={first:0,second:0}
	if level>0 and not prior:
		grants[first]=mini(1,3-int(_state.chapter_resources[actor][first]))
		if level>=2:grants[second]=mini(1,3-int(_state.chapter_resources[actor][second]))
	return {"ok":true,"actor":int(actor),"node":int(node),"chapter":int(_state.chapter),"level":level,"already_given":prior,"grants":grants}
func _issue_estate_supplies(node:int)->Array[Dictionary]:
	var supplied:Array[Dictionary]=[]
	if _state.chapter==0:return supplied
	for actor in 2:
		var preview:Dictionary=estate_supply_preview(actor,node)
		if not preview.ok or preview.level==0 or preview.already_given:continue
		for key in preview.grants:_state.chapter_resources[actor][key]+=int(preview.grants[key])
		var receipt:Dictionary={"chapter":int(_state.chapter),"node":node,"actor":actor,"level":int(preview.level),"grants":preview.grants.duplicate(true),"status":"supplied" if preview.grants.values().any(func(value):return int(value)>0) else "stock_full"}
		_state.estate_resource_grants.append(receipt);supplied.append(receipt.duplicate(true))
	return supplied

func landing_options(actor:Variant)->Array[Dictionary]:
	if not _actor(actor,["landing"]) or _state.landing_resolved:return []
	var node:int=_state.players[actor].node;var kind:String=_node_kind(node)
	if kind=="commission":return commission_choices(actor)
	if kind=="item_shop":
		var offers:Array[Dictionary]=[];var discount:int=_shop_discount(int(actor));var player:Dictionary=_state.players[actor]
		for item in ["boost","shield","swap"]:
			var price:int=Economy.item_cost(item,discount)
			var labels:Dictionary={"boost":"下次骰 +2步","shield":"下一次破财格保钱","swap":"掷骰前交换双方位置"}
			offers.append({"choice":offers.size(),"label":labels[item]+" · %d金币%s"%[price,"（本区地产减%d）"%discount if discount>0 else ""],"item":item,"cost":price,"discount":discount,"enabled":player.coins>=price and player.items.size()<ITEM_LIMIT})
		offers.append({"choice":3,"label":"留钱继续探索","cost":0,"enabled":true});return offers
	if kind=="property" and _state.chapter>0:
		var offers:Array[Dictionary]=super.landing_options(actor);var property:Dictionary=_property(node)
		var primary:String="窥牌" if _state.chapter==1 else "旋转"
		var secondary:String="换牌" if _state.chapter==1 else "余辉"
		if property.owner==-1:offers[0].label="买合作摊位（8金）：本区每座新挑战首试 "+primary+" +1；道具减1金"
		elif property.owner==actor:
			offers[0].label="营业金币 +%d；本区挑战首试供应%s"%[2 if property.level==1 else 3,primary+"+1"+(" / "+secondary+"+1" if property.level==2 else "")]
			if offers.size()>1:offers[1].label="升级6金 / 营业赚3：首试再送 "+secondary+"+1；道具减2金"
		return offers
	if kind=="challenge":
		return [{"choice":0,"label":"进入本章挑战 · "+AdventureMap.ACTIVITY_KINDS[_state.chapter],"cost":0,"enabled":node not in _state.chapter_cleared,"reason":"already_cleared" if node in _state.chapter_cleared else ""},{"choice":1,"label":"保留构筑，继续探索","cost":0,"enabled":true}]
	if kind=="chapter_exit":
		return [{"choice":0,"label":"完成当前章节试玩" if _state.practice else ("前往下一章" if _state.chapter<2 else "完成三章冒险"),"cost":0,"enabled":_state.chapter_cleared.size()>=CHAPTER_GOAL,"reason":"two_distinct_challenges_required" if _state.chapter_cleared.size()<CHAPTER_GOAL else ""},{"choice":1,"label":"继续探索当前章节","cost":0,"enabled":true}]
	if kind=="forge":
		var labels:Array=["同行战备：自己下次生命 +12","强攻配方：自己下次伤害 +12%"] if _state.chapter==0 else (["窥牌券 +1","换牌券 +1"] if _state.chapter==1 else ["机关旋转券 +1","回声接力券 +1"])
		var options:Array[Dictionary]=[{"choice":0,"label":labels[0],"cost":0,"enabled":_forge_enabled(actor,0)},{"choice":1,"label":labels[1],"cost":0,"enabled":_forge_enabled(actor,1)}]
		if _state.chapter==1:options.append({"choice":2,"label":"牌谱工坊：改牌或选规则遗物","cost":0,"enabled":true})
		options.append({"choice":3,"label":"保留现有配方离开","cost":0,"enabled":true})
		return _supply_options(int(actor),node,options)
	if kind=="event":
		if _state.chapter>0:
			var first:String=_resource_key(0);var second:String=_resource_key(1)
			var title:String="窥牌券" if _state.chapter==1 else "机关旋转券"
			var other:String="换牌券" if _state.chapter==1 else "回声接力券"
			return _supply_options(int(actor),node,[{"choice":0,"label":"给伙伴 "+title+" +1","cost":0,"enabled":int(_state.chapter_resources[1-actor][first])<3},{"choice":1,"label":"给自己 "+other+" +1","cost":0,"enabled":int(_state.chapter_resources[actor][second])<3},{"choice":2,"label":"给自己 "+title+" +1","cost":0,"enabled":int(_state.chapter_resources[actor][first])<3},{"choice":3,"label":"不取资源，继续探索","cost":0,"enabled":true}])
		var supply:bool=_state.provisions[0].health_bonus<24.0 or _state.provisions[1].health_bonus<24.0
		return _supply_options(int(actor),node,[{"choice":0,"label":"同行补给：两人下次活动生命各 +6","cost":0,"enabled":supply},{"choice":1,"label":"自己构筑：下次活动伤害 +12%","cost":0,"enabled":_state.provisions[actor].damage_bonus<.48},{"choice":2,"label":"捷行地图：下次骰 +2步","cost":0,"enabled":_state.players[actor].bonus==0},{"choice":3,"label":"不取补给，继续探索","cost":0,"enabled":true}])
	return super.landing_options(actor)

func resolve_landing(actor:Variant,choice:Variant=0)->Dictionary:
	if not _actor(actor,["landing"]) or _state.landing_resolved:return _reject("wrong_actor_or_phase","resolve_landing")
	if not _int(choice,0,3):return _reject("invalid_choice","resolve_landing")
	var node:int=_state.players[actor].node;var kind:String=_node_kind(node)
	if kind not in ["challenge","chapter_exit","forge","event","item_shop","commission"]:
		var inherited:Dictionary=super.resolve_landing(actor,choice)
		if inherited.ok and kind=="property" and _state.chapter>0:
			inherited.facts["estate_supply_kind"]=_resource_key(0)
			inherited.facts["estate_secondary_kind"]=_resource_key(1)
			inherited.facts["supply_when"]="first_attempt_per_distinct_local_challenge"
		return _with_commission_arrival(inherited,int(actor),node)
	var allowed:=false
	for option in landing_options(actor):
		if option.choice==choice and option.enabled:allowed=true
	if not allowed:return _reject("unavailable_choice","resolve_landing")
	if kind=="commission":return _resolve_commission(int(actor),int(choice),node)
	if kind=="item_shop":
		var item:="";var cost:=0;var discount:int=_shop_discount(int(actor));var player:Dictionary=_state.players[actor]
		if choice<3:
			item=["boost","shield","swap"][choice];cost=Economy.item_cost(item,discount)
			player.coins-=cost;player.items.append(item)
		_state.landing_resolved=true;_bump()
		var facts:Dictionary={"node":node,"kind":"item_shop","choice":choice,"item":item,"cost":cost,"discount":discount,"coin_delta":-cost,"coins_after":int(player.coins),"star_delta":0,"protected":false,"property":{},"chapter":int(_state.chapter)}
		_record_economy("item_shop",int(actor),facts);return _with_commission_arrival(_result(true,"","resolve_landing",int(actor),facts),int(actor),node)
	if kind=="challenge" and choice==0:return _with_commission_arrival(_begin_activity(int(actor),node),int(actor),node)
	if kind=="chapter_exit" and choice==0:return next_chapter(actor)
	var before_resources:Dictionary=_state.chapter_resources[actor].duplicate(true)
	var before_provisions:Array=_state.provisions.duplicate(true)
	if kind=="forge" and choice in [0,1]:
		if _state.chapter==0:
			if choice==0:_state.provisions[actor].health_bonus=minf(24.0,float(_state.provisions[actor].health_bonus)+12.0)
			else:_state.provisions[actor].damage_bonus=minf(.48,float(_state.provisions[actor].damage_bonus)+.12)
		else:
			var key:String=_resource_key(choice);_state.chapter_resources[actor][key]+=1
	elif kind=="event" and choice!=3:
		if _state.chapter>0:
			var recipient:int=1-actor if choice==0 else actor
			var key:String=_resource_key(1 if choice==1 else 0)
			_state.chapter_resources[recipient][key]+=1
		elif choice==0:
			for supply in _state.provisions:supply.health_bonus=minf(24.0,float(supply.health_bonus)+6.0)
		elif choice==1:_state.provisions[actor].damage_bonus=minf(.48,float(_state.provisions[actor].damage_bonus)+.12)
		else:_state.players[actor].bonus=2
	if kind=="event" and choice!=3 or kind=="forge" and choice in [0,1]:_state.supply_claims["%d:%d"%[actor,node]]=true
	_state.landing_resolved=true;_bump()
	var facts:Dictionary={"node":node,"kind":kind,"choice":choice,"chapter":int(_state.chapter),"activity_kind":AdventureMap.ACTIVITY_KINDS[_state.chapter],"station_kind":"mahjong_workshop" if kind=="forge" and choice==2 else "","station_token":int(_state.serial),"station_actor":int(actor),"station_chapter":int(_state.chapter),"resources_before":before_resources,"resources_after":_state.chapter_resources[actor].duplicate(true),"provisions_before":before_provisions,"provisions_after":_state.provisions.duplicate(true),"coin_delta":0,"star_delta":0,"item":"","protected":false,"property":{}}
	_state.resource_history.append({"serial":int(_state.serial),"actor":actor,"facts":facts.duplicate(true)})
	if _state.resource_history.size()>32:_state.resource_history.pop_front()
	return _with_commission_arrival(_result(true,"","resolve_landing",actor,facts),int(actor),node)

func _advance_turn(actor:int)->void:
	_state.turn+=1
	_apply_commission_receipts(_commissions.expire(int(_state.turn)))
	_state.active=1-actor;_state.phase="prepare" if _state.chapter==0 else "roll";_state.roll=0;_state.remaining=0;_state.path=[];_state.landing_resolved=false;_state.item_used=false
	if _state.chapter>0:_state.players[_state.active].preparation=0
func finish_turn(actor:Variant)->Dictionary:
	if not _actor(actor,["landing"]) or not _state.landing_resolved:return _reject("unresolved_or_wrong_actor","finish_turn")
	_advance_turn(actor);_bump()
	return _result(true,"","finish_turn",actor,{"next_actor":int(_state.active),"turn":int(_state.turn),"round":int(_state.round),"challenge_token":0})
func _begin_activity(actor:int,node:int)->Dictionary:
	if _serial_clock>=2147483647 or _state.activity_index>=999:return _reject("sequence_exhausted","begin_activity")
	_state.phase="challenge";_state.activity_actor=actor;_state.activity_trigger=node;_state.resume_actor=1-actor;_state.activity_index+=1;_state.round=_state.chapter_cleared.size()+1;_state.landing_resolved=true
	_state.latest_estate_supplies=_issue_estate_supplies(node)
	_bump();_state.challenge_token=_state.serial;_state.tea_contract={"token":int(_state.challenge_token),"actor":actor,"stake":0,"accepted":false,"decided":false};_state.battle_context=_make_battle_context();_state.provisions=_empty_provisions()
	return _result(true,"","begin_activity",actor,{"chapter":int(_state.chapter),"activity_kind":AdventureMap.ACTIVITY_KINDS[_state.chapter],"trigger_node":node,"challenge_token":int(_state.challenge_token),"context":battle_context(),"estate_supplies":_state.latest_estate_supplies.duplicate(true)})
func _make_battle_context()->Dictionary:
	var actor:int=_state.activity_actor;var node:int=_state.activity_trigger;var district:int=_tiles[node].district
	var regional:Dictionary=Economy.region_bonus(district);var bonuses:Array[Dictionary]=[];var preparations:Array[int]=[];var strengths:Array[int]=[]
	for player_index in 2:
		var player:Dictionary=_state.players[player_index];var strength:=0
		for property in _state.properties:
			if property.owner==player_index and _tiles[property.node].district==district:strength+=int(property.level)
		strength=mini(4,strength);strengths.append(strength);preparations.append(int(player.preparation))
		bonuses.append({"health_bonus":float(regional.health)+(12.0 if player.preparation==0 else 0.0)+2.0*strength+float(_state.provisions[player_index].health_bonus),"damage_bonus":float(regional.damage)+(.12 if player.preparation==1 else 0.0)+float(_state.provisions[player_index].damage_bonus)} if _state.chapter==0 else {"health_bonus":0.0,"damage_bonus":0.0})
	return {"ok":true,"reason":"","token":int(_state.challenge_token),"round":int(_state.round),"district":district,"district_name":AdventureMap.districts(_state.chapter)[district].name,"leader":actor,"route":district,"bonuses":bonuses,"reward_bonus":int(regional.reward),"preparations":preparations,"property_strength":strengths,"joint_contract":{},"chapter":int(_state.chapter),"activity_kind":AdventureMap.ACTIVITY_KINDS[_state.chapter],"trigger_node":node,"turn":int(_state.turn),"activity_index":int(_state.activity_index),"combat_wave":int(_state.round),"chapter_resources":_state.chapter_resources.duplicate(true),"estate_supplies":_state.latest_estate_supplies.duplicate(true)}

func choose_mahjong_tea(actor:Variant,accepted:Variant,token:Variant)->Dictionary:
	if _state.is_empty() or _state.chapter!=1 or _state.phase!="challenge" or not _int(actor,0,1) or actor!=_state.activity_actor or not _int(token,1,2147483647) or token!=_state.challenge_token:return _reject("wrong_tea_context","choose_mahjong_tea")
	if typeof(accepted)!=TYPE_BOOL:return _reject("invalid_tea_choice","choose_mahjong_tea")
	if _state.tea_contract.decided:return _reject("tea_already_decided","choose_mahjong_tea")
	if accepted and _state.players[actor].coins<TEA_STAKE:return _reject("insufficient_coins","choose_mahjong_tea")
	var cost:int=TEA_STAKE if accepted else 0
	_state.players[actor].coins-=cost
	_state.tea_contract={"token":int(token),"actor":int(actor),"stake":cost,"accepted":bool(accepted),"decided":true}
	_bump()
	var facts:Dictionary={"token":int(token),"accepted":bool(accepted),"cost":cost,"coin_delta":-cost,"coins_after":int(_state.players[actor].coins),"protected_slot":int(_state.battle_context.district)*3 if accepted else -1,"return_if_qualified":TEA_RETURN if accepted else 0}
	_record_economy("mahjong_tea",int(actor),facts)
	return _result(true,"","choose_mahjong_tea",int(actor),facts)

func _valid_tea_proof(proof:Dictionary,won:bool,token:int)->bool:
	var accepted:bool=bool(_state.tea_contract.get("accepted",false))
	if proof.is_empty():return not accepted
	# The Session binds a real Mahjong result source; this checks its finite receipt,
	# not independently reconstructed private hand/cast history.
	if proof.size()!=2 or not proof.has("token") or not proof.has("tea") or not _int(proof.token,1,2147483647) or proof.token!=token or not proof.tea is Dictionary:return false
	var tea:Dictionary=proof.tea
	if tea.is_empty():return not accepted
	if tea.size()!=5:return false
	for key in ["token","accepted","qualified","protected_slot","patterns"]:
		if not tea.has(key):return false
	if not _int(tea.token,1,2147483647) or tea.token!=token or typeof(tea.accepted)!=TYPE_BOOL or tea.accepted!=accepted or typeof(tea.qualified)!=TYPE_BOOL or not tea.patterns is Array or tea.patterns.size()>3:return false
	if not _int(tea.protected_slot,-1,6):return false
	var seen:Dictionary={}
	for pattern in tea.patterns:
		if typeof(pattern)!=TYPE_STRING or pattern not in ["sequence","triplet","pair"] or seen.has(pattern):return false
		seen[pattern]=true
	if not accepted:return tea.protected_slot==-1 and not tea.qualified
	if tea.protected_slot!=int(_state.battle_context.district)*3:return false
	return not tea.qualified or (won and tea.patterns.size()==3)

func _valid_mahjong_proof(proof:Dictionary,results:Array,won:bool,token:int)->bool:
	# Exact bounded receipt from Session's bound terminal Table source. This
	# validates entities/hand shape, not the private historical sequence of play.
	if proof.size()!=2 or not proof.has_all(["token","mahjong"]) or not _int(proof.token,1,2147483647) or proof.token!=token or not proof.mahjong is Dictionary:return false
	if bool(_state.tea_contract.get("accepted",false)):return false
	var outcome:Dictionary=proof.mahjong
	var fields:Array=["token","success","scores","reason","winner","win_kind","points","style","style_qualified","discard_count","mode","variant","winning_hand","winning_melds"]
	if outcome.size()!=fields.size() or not outcome.has_all(fields):return false
	if not _int(outcome.token,1,2147483647) or outcome.token!=token or typeof(outcome.success)!=TYPE_BOOL or outcome.success!=won or typeof(outcome.style_qualified)!=TYPE_BOOL:return false
	if not outcome.scores is Array or outcome.scores.size()!=2 or not _int(outcome.scores[0],0,100) or not _int(outcome.scores[1],0,100) or outcome.scores!=results:return false
	if outcome.scores!=([100,100] if won else [0,0]):return false
	if typeof(outcome.reason)!=TYPE_STRING or outcome.reason.length()>64 or typeof(outcome.win_kind)!=TYPE_STRING or typeof(outcome.style)!=TYPE_STRING or typeof(outcome.mode)!=TYPE_STRING or outcome.mode not in ["endgame","random"]:return false
	if not _int(outcome.variant,0,2) or outcome.variant!=int(_state.battle_context.district) or not _int(outcome.discard_count,0,64) or not _int(outcome.points,0,10) or not _int(outcome.winner,-1,1):return false
	if not outcome.winning_hand is Array or outcome.winning_hand.size()>14 or not outcome.winning_melds is Array or outcome.winning_melds.size()>4:return false
	if not won:return outcome.reason in ["retreated","discard_limit","wall_empty"] and outcome.winner==-1 and outcome.points==0 and outcome.style=="" and outcome.win_kind=="" and not outcome.style_qualified and outcome.winning_hand.is_empty() and outcome.winning_melds.is_empty()
	if outcome.winner not in [0,1] or outcome.win_kind not in ["tsumo","ron","rob_kong"] or outcome.reason!=outcome.win_kind or outcome.style not in ["closed","triplet","sequence"]:return false
	if outcome.points!=5+(2 if outcome.win_kind=="tsumo" else 0)+(3 if outcome.style_qualified else 0):return false
	var analysis:Dictionary=MahjongTable.winning_hand(outcome.winning_hand,outcome.winning_melds,outcome.style)
	return bool(analysis.valid) and bool(analysis.qualified)==outcome.style_qualified

func settle_challenge(results:Variant,token:Variant,proof:Variant={})->Dictionary:
	if _state.is_empty() or _state.phase!="challenge" or not _int(token,1,2147483647) or token!=_state.challenge_token or token==_state.last_challenge_token:return _reject("stale_challenge","settle_challenge")
	if not results is Array or results.size()!=2 or not _int(results[0],0,10000) or not _int(results[1],0,10000):return _reject("invalid_results","settle_challenge")
	if not proof is Dictionary:return _reject("invalid_proof","settle_challenge")
	var context:Dictionary=_state.battle_context;var won:bool=int(results[0])+int(results[1])>=100
	var is_table:bool=proof.has("mahjong")
	if is_table:
		if _state.chapter!=1 or not _valid_mahjong_proof(proof,results,won,int(token)):return _reject("invalid_mahjong_proof","settle_challenge")
	elif _state.chapter==1 and not _valid_tea_proof(proof,won,int(token)):return _reject("invalid_tea_proof","settle_challenge")
	var reward:int=5+int(context.reward_bonus) if won else 0
	var coin_rewards:Array[int]=[]
	for player in _state.players:
		var before:int=player.coins;player.coins=mini(COIN_LIMIT,player.coins+reward);coin_rewards.append(int(player.coins)-before);player.preparation=-1;player.stake=0
	var tea_returns:Array[int]=[0,0]
	var tea:Dictionary=proof.get("tea",{}) if _state.chapter==1 else {}
	var tea_accepted:bool=_state.chapter==1 and bool(_state.tea_contract.get("accepted",false))
	var tea_qualified:bool=tea_accepted and won and bool(tea.get("qualified",false))
	var signer:int=int(_state.tea_contract.get("actor",-1))
	if tea_qualified:
		var before:int=_state.players[signer].coins
		_state.players[signer].coins=mini(COIN_LIMIT,before+TEA_RETURN)
		tea_returns[signer]=int(_state.players[signer].coins)-before
	var tea_result:Dictionary={"status":"qualified" if tea_qualified else ("unqualified" if tea_accepted and won else ("failed" if tea_accepted else ("declined" if bool(_state.tea_contract.get("decided",false)) else "none"))),"actor":signer,"stake":int(_state.tea_contract.get("stake",0)),"accepted":tea_accepted,"qualified":tea_qualified,"promised_return":TEA_RETURN if tea_qualified else 0,"actual_return":tea_returns[signer] if signer>=0 else 0,"proof":tea.duplicate(true)}
	var mahjong_result:Dictionary={}
	if is_table:
		var outcome:Dictionary=proof.mahjong
		var bonus:=0
		if won and outcome.style_qualified:
			var winner:int=outcome.winner;var before:int=_state.players[winner].coins
			_state.players[winner].coins=mini(COIN_LIMIT,before+3);bonus=int(_state.players[winner].coins)-before
		mahjong_result={"winner":int(outcome.winner),"points":int(outcome.points),"style":str(outcome.style),"style_qualified":bool(outcome.style_qualified),"promised_bonus":3 if won and outcome.style_qualified else 0,"actual_bonus":bonus,"proof":outcome.duplicate(true)}
	_state.last_challenge_token=token;_state.challenge_token=0;_state.team_score+=int(results[0])+int(results[1])
	if won:
		_state.chapter_cleared.append(int(context.trigger_node));_state.team_successes+=1
	var receipt:Dictionary={"round":int(_state.round),"chapter":int(_state.chapter),"token":int(token),"trigger_node":int(context.trigger_node),"activity_kind":str(context.activity_kind),"scores":[int(results[0]),int(results[1])],"team_won":won,"coin_reward_each":reward,"district":int(context.district),"leader":int(context.leader),"reward_bonus":int(context.reward_bonus) if won else 0,"preparations":context.preparations.duplicate(),"contract_returns":[0,0],"coin_rewards":coin_rewards,"tea_returns":tea_returns,"tea_result":tea_result,"mahjong_result":mahjong_result,"joint_result":{"status":"none"},"chapter_cleared":_state.chapter_cleared.duplicate(),"chapter_exit_enabled":_state.chapter_cleared.size()>=CHAPTER_GOAL}
	_state.challenge_history.append(receipt)
	if _state.challenge_history.size()>96:_state.challenge_history.pop_front()
	_state.battle_context={}
	if won:_state.phase="market";_state.active=0;_state.market_actor=0;_state.market_bought=[false,false]
	else:_state.phase="activity_retry";_state.active=int(_state.activity_actor)
	_bump();_record_economy("activity",-1,receipt)
	return _result(true,"","settle_challenge",-1,{"receipt":receipt,"team_successes":int(_state.team_successes),"finished":false,"winners":[]})
func retry_activity(actor:Variant)->Dictionary:
	if not _actor(actor,["activity_retry"]):return _reject("wrong_actor_or_phase","retry_activity")
	return _begin_activity(int(actor),int(_state.activity_trigger))
func leave_activity(actor:Variant)->Dictionary:
	if not _actor(actor,["activity_retry"]):return _reject("wrong_actor_or_phase","leave_activity")
	_advance_turn(int(actor));_bump();return _result(true,"","leave_activity",actor,{"next_actor":int(_state.active),"turn":int(_state.turn)})
func finish_market(actor:Variant)->Dictionary:
	if not _actor(actor,["market"]) or actor!=_state.market_actor:return _reject("wrong_actor_or_phase","finish_market")
	if actor==0:_state.market_actor=1;_state.active=1
	else:_advance_turn(int(_state.activity_actor));_state.market_actor=0
	_bump();return _result(true,"","finish_market",actor,{"next_actor":int(_state.active),"turn":int(_state.turn),"round":int(_state.round)})
func next_chapter(actor:Variant)->Dictionary:
	if not _actor(actor,["landing"]) or _state.landing_resolved or _node_kind(int(_state.players[actor].node))!="chapter_exit":return _reject("not_chapter_exit","next_chapter")
	if _state.chapter_cleared.size()<CHAPTER_GOAL:return _reject("two_distinct_challenges_required","next_chapter")
	var closed:Array[Dictionary]=_apply_commission_receipts(_commissions.close_chapter(int(_state.turn)))
	_state.chapter_history.append({"chapter":int(_state.chapter),"cleared_nodes":_state.chapter_cleared.duplicate(),"turn":int(_state.turn)})
	if _state.chapter==CHAPTER_COUNT-1 or _state.practice:
		_state.phase="finished";_state.team_won=true;_state.winners=[0,1];_state["campaign_completed"]=not bool(_state.practice)
	else:
		_state.chapter+=1;_tiles=AdventureMap.nodes(_state.chapter);_state.chapter_cleared=[];_state.tea_contract={};_state.estate_resource_grants=[];_state.latest_estate_supplies=[];_state.chapter_resources=_empty_resources();_state.provisions=_empty_provisions();_state.supply_claims={};_state.active=0;_state.phase="prepare";_state.turn+=1;_state.roll=0;_state.remaining=0;_state.path=[];_state.landing_resolved=false;_state.item_used=false
		for player in _state.players:player.node=0;player.preparation=-1;player.stake=0;player.bonus=0
		if _state.chapter>0:_state.phase="roll";_state.players[0].preparation=0
		var configured:bool=_commissions.configure(int(_state.chapter),_tiles)
		assert(configured)
	_bump();return _result(true,"","next_chapter",actor,{"chapter":int(_state.chapter),"finished":_state.phase=="finished","turn":int(_state.turn),"preserve_builds":true,"commission_receipts":closed})
func consume_activity_resource(actor:Variant,key:Variant,token:Variant)->Dictionary:
	if _state.is_empty() or _state.phase!="challenge" or not _int(actor,0,1) or not _int(token,1,2147483647) or token!=_state.challenge_token:return _reject("wrong_activity_context","consume_activity_resource")
	if typeof(key)!=TYPE_STRING:return _reject("invalid_resource","consume_activity_resource")
	var allowed:Array=["wilds","redraws"] if _state.chapter==1 else (["rotate_tokens","echo_bonus"] if _state.chapter==2 else [])
	if key not in allowed:return _reject("resource_not_in_chapter","consume_activity_resource")
	if int(_state.chapter_resources[actor][key])<=0:return _reject("empty_resource","consume_activity_resource")
	_state.chapter_resources[actor][key]-=1;_bump()
	return _result(true,"","consume_activity_resource",actor,{"key":key,"remaining":int(_state.chapter_resources[actor][key]),"token":int(token)})

func choose_ai_branch(actor:Variant)->int:
	var options:Array[int]=branch_options(actor)
	if options.is_empty():return -1
	var contract_target:int=_commissions.target_for(actor)
	var desired:Array=[contract_target] if contract_target>=0 else (AdventureMap.EXITS if _state.chapter_cleared.size()>=CHAPTER_GOAL else AdventureMap.CHALLENGES)
	var best:int=options[0];var best_score:=-100000.0
	for candidate in options:
		var preview:Dictionary=preview_branch(actor,candidate);var score:=0.0;var distance:int=_tiles.size()
		for target in desired:
			if contract_target<0 and target in _state.chapter_cleared:continue
			distance=mini(distance,_ai_distance(int(preview.node),int(target),int(_state.players[actor].coins)-int(preview.ferry_cost)))
		score=20.0-float(distance)-float(preview.ferry_cost)
		if preview.node in desired and (contract_target>=0 or preview.node not in _state.chapter_cleared):score+=30.0
		if contract_target>=0 and contract_target in preview.path:score+=25.0
		if _node_kind(int(preview.node))=="red":score-=3.0
		if score>best_score:best_score=score;best=candidate
	return best
func choose_ai_landing(actor:Variant)->int:
	var options:Array[Dictionary]=landing_options(actor)
	if options.is_empty():return -1
	var kind:String=_node_kind(int(_state.players[actor].node))
	if kind=="commission":
		var own:Dictionary=_commissions.active(actor)
		if not own.is_empty():
			# Keep an attainable commitment; cancel only when remaining own turns
			# cannot plausibly cover even a legal minimum path at six steps/roll.
			var target:int=_commissions.target_for(actor)
			var distance:int=_ai_distance(int(_state.players[actor].node),target,int(_state.players[actor].coins))
			return 2 if distance>3*maxi(0,int(own.expires_turn)-int(_state.turn)) else 3
		var partner:Dictionary=_commissions.active(1-actor)
		if not partner.is_empty() and options[2].enabled and _state.players[actor].coins>=7:
			var distance:int=_ai_distance(int(_state.players[actor].node),int(partner.target),int(_state.players[actor].coins)-1)
			if distance<=6:return 2
		# Survey is a longer investment; delivery preserves six coins for growth.
		if options[1].enabled and _state.players[actor].coins>=14 and _state.chapter_cleared.size()<CHAPTER_GOAL:return 1
		return 0 if options[0].enabled and _state.players[actor].coins>=9 else 3
	if kind=="item_shop":
		var player:Dictionary=_state.players[actor]
		var preferred:int=1 if _ai_last_lost() else 0
		return preferred if options[preferred].enabled and player.coins-int(options[preferred].cost)>=6 else 3
	if kind in ["challenge","chapter_exit"]:return 0 if options[0].enabled else 1
	if kind in ["event","forge"]:
		var preferred:int=2 if kind=="event" and _state.chapter==0 else (1 if _state.chapter==1 else 0)
		for option in options:
			if option.choice==preferred and option.enabled:return preferred
		for option in options:
			if option.enabled:return int(option.choice)
		return -1
	return super.choose_ai_landing(actor)
