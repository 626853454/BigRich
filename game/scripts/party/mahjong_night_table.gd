class_name FurMahjongNightTable
extends ChapterMahjongTable
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
const Score=preload("res://scripts/party/mahjong_night_score.gd")
const TURN_LIMIT:=6
const Direction=preload("res://scripts/party/mahjong_night_direction.gd")
const Reshape=preload("res://scripts/party/mahjong_night_reshape.gd")
var _reshape_revision:int=-1
var _reshape_cache:Array=[]
var _plan_revision:int=-1
var _plan_cache:Array=[]
var _continuation_revision:int=-1
var _continuation_cache:Array=[]
var _river_plan_revision:int=-1
var _river_plan_cache:Array=[]

func begin_night(config:Dictionary)->Dictionary:
	super.start(int(config.seed),bool(config.ai));super.begin_challenge(0,1,0,false)
	var first:int=_s.drawn_tile;_s.hands[0].erase(first);_s.wall.push_front(first);_s.drawn_tile=-1
	for i in 2:_s.tea.tray.append(_s.wall.pop_back())
	_s.tea.charge=4
	_s.night={"venue":config.get("venue","river" if config.table==2 else ("duet" if config.table==3 else "opening")),"table":config.table,"target":config.target,"boss":config.boss,"build":config.build.duplicate(true),"wallets":config.coins.duplicate(),"stage":0,"revealed":0,"turns":[0,0],"ready":[false,false],"contracts":["sequence","triplet"],"tiers":[0,0],"paid":[0,0],"scores":[0,0],"contexts":[_empty_context(),_empty_context()],"self_used":[false,false],"mulligan_used":[false,false],"relay_owner":{},"relay_used":[],"gold_paid":[],"events":[],"last_score":{},"next_phase":"discard","hu_groups":[[],[]],"meld_values":[{},{}]}
	for actor in 2:
		var carried:Array=_s.night.build.get("keepsakes",[[],[]])[actor]
		if carried.is_empty() and _s.night.build.heirlooms[actor]>=0:carried=[_s.night.build.heirlooms[actor]]
		for id:int in carried:_put_heirloom(id,actor)
	Direction.begin(_s.night,int(config.seed))
	_s.night.reshape={"used":[[],[]],"history":[],"borrowed":[[],[]],"followup":[[],[]],"chains":[]}
	_s.night.contract_seen=[[],[]]
	_s.night.continuations=[]
	_reshape_revision=-1;_reshape_cache.clear()
	_plan_revision=-1;_plan_cache.clear()
	_continuation_revision=-1;_continuation_cache.clear()
	_river_plan_revision=-1;_river_plan_cache.clear()
	_s.night.refresh_used=false
	_s.night.stamina=config.get("stamina",3)
	_s.night.encore={"base_target":int(config.target),"asked":false,"active":false,"reward":4}
	_s.night.promised_tiles=config.get("promised_tiles",[-1,-1]).duplicate()
	_s.night.requests=config.get("planned_requests",[-1,-1]).duplicate();_s.night.deliveries=[-1,-1];_s.night.assist_note=""
	_s.night.ensemble={"last_actor":-1,"last_kind":"","chain":0}
	_s.night.fresh_river=[];_s.night.bounty_claimed=false
	_s.styles=["sequence","triplet"]
	for actor in 2:
		if "coal" in _s.night.build.items[actor] or "anvil" in _s.night.build.items[actor]:_s.styles[actor]="triplet";_s.night.contracts[actor]="triplet"
	_s.phase="night_offer";_s.actor=0;_s.table_event={"kind":"deal","actor":0,"tiles":[]}
	_s.scenario={"title":"百番夜宴 · 第%d桌"%config.table,"condition":"136张真牌 · 河牌3+1+1 · 每人6次打牌","target":"合作达到 %d 分"%config.target}
	_s.revision+=1
	return _reply(true,"")

func _empty_context()->Dictionary:
	return {"chi_count":0,"starts":[],"suits":[],"heat":0,"growth":0,"kinds":[]}

func _put_heirloom(id:int,actor:int)->void:
	if id in _s.hands[actor]:return
	var outgoing:int=-1
	var reserved:Array=[]
	for pocket:Array in _s.night.build.get("keepsakes",[[],[]]):reserved.append_array(pocket)
	reserved.append_array(_s.night.build.heirlooms)
	for candidate:int in _s.hands[actor]:
		if candidate not in reserved:outgoing=candidate;break
	if outgoing<0:return
	var zones:Array=[_s.wall,_s.tea.tray,_s.hands[1-actor]]
	for zone:Array in zones:
		var index:int=zone.find(id)
		if index>=0:
			zone[index]=outgoing;_s.hands[actor][_s.hands[actor].find(outgoing)]=id;_s.hands[actor].sort();_s.hands[1-actor].sort();return

func offer(contract:String,tier:int,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["night_offer"]) or contract not in Catalog.CONTRACTS or tier<0 or tier>2:return _reply(false,"invalid_offer")
	var n:Dictionary=_s.night
	if n.stage>0 and contract!=n.contracts[actor]:return _reply(false,"contract_locked")
	if tier<n.tiers[actor]:return _reply(false,"stake_already_locked")
	if tier>n.tiers[actor] and (_contract_met(actor,contract) or contract in n.contract_seen[actor]):return _reply(false,"cannot_bet_completed_contract")
	var difference:int=Catalog.STAKES[tier]-n.paid[actor]
	if n.wallets[actor]<difference:return _reply(false,"not_enough_coins")
	n.wallets[actor]-=difference;n.paid[actor]+=difference;n.tiers[actor]=tier;n.contracts[actor]=contract
	_s.revision+=1;_s.table_event={"kind":"offer","actor":actor,"tiles":[]}
	return _reply(true,"")

func mulligan(indices:Array,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["night_offer"]) or _s.night.stage!=0 or _s.night.mulligan_used[actor] or indices.size()>3 or indices.is_empty():return _reply(false,"mulligan_unavailable")
	var ids:Array=[]
	for index in indices:
		if typeof(index)!=TYPE_INT or index<0 or index>=_s.hands[actor].size() or _s.hands[actor][index] in ids:return _reply(false,"invalid_mulligan")
		ids.append(_s.hands[actor][index])
	for id:int in ids:_s.hands[actor].erase(id);_s.discards[actor].append(id);_s.hands[actor].append(_s.wall.pop_front())
	_s.hands[actor].sort();_s.night.mulligan_used[actor]=true;_s.revision+=1;_s.table_event={"kind":"mulligan","actor":actor,"tiles":ids}
	return _reply(true,"")

func mulligan_suggestion()->Array:
	if _s.phase!="night_offer" or _s.night.stage!=0 or _s.night.mulligan_used[_s.actor]:return []
	var hand:Array=_s.hands[_s.actor];var candidates:Array=[]
	var protected:Array=_s.night.build.get("keepsakes",[[],[]])[_s.actor].duplicate()
	protected.append(_s.night.build.heirlooms[_s.actor])
	for index in hand.size():
		var id:int=hand[index];var face:int=int(id/4)
		if id in protected or _s.night.build.stamps.has(str(id)):continue
		var same:int=0;var nearby:int=0
		for other:int in hand:
			var type:int=int(other/4)
			if type==face:same+=1
			elif face<27 and type<27 and int(type/9)==int(face/9) and absi(type-face)<=2:nearby+=1
		if same==1 and nearby==0:candidates.append({"index":index,"priority":2 if face>=27 else 1})
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.priority>b.priority or (a.priority==b.priority and a.index<b.index))
	var indices:Array=[]
	for entry:Dictionary in candidates.slice(0,3):indices.append(entry.index)
	return indices

func ready_offer(actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["night_offer"]):return _reply(false,"invalid_ready")
	var n:Dictionary=_s.night;n.ready[actor]=true
	if n.ready[0] and n.ready[1]:
		var old_revealed:int=n.revealed
		n.stage+=1;n.revealed=mini(n.stage+2,5);n.ready=[false,false];n.refresh_used=false
		n.fresh_river=_s.tea.tray.slice(old_revealed,n.revealed);n.bounty_claimed=false
		_s.actor=n.get("resume_actor",0);_s.phase=n.next_phase
		if n.stage==1:_draw(_s.actor,false)
		_s.table_event={"kind":"reveal","actor":actor,"tiles":_s.tea.tray.slice(0,n.revealed)}
	else:_s.actor=1-actor
	_s.revision+=1;return _reply(true,"")

func choose_tea(recipe:Variant,actor:Variant,revision:Variant)->Dictionary:
	if _s.get("phase","")=="night_offer" and _s.night.stage==0:
		if not _operation(actor,revision,["night_offer"]) or typeof(recipe)!=TYPE_STRING or not Tea.choose(_s,recipe):return _reply(false,"tea_locked")
		_s.revision+=1;_s.table_event={"kind":"recipe","actor":actor,"tiles":[]};return _reply(true,"")
	return super.choose_tea(recipe,actor,revision)

func choices()->Array:
	var options:Array=super.choices()
	if not _s.has("night"):return options
	for option:Dictionary in options:
		if option.kind=="skill":
			option.label="观潮 · 排好真实墙顶3张" if option.key=="wilds" else "换摸 · 换走刚摸入的牌"
			option.detail+="；本桌仅一次，入口在同桌协作。"
		elif option.kind in ["tsumo","ron"]:
			var forecast:Dictionary=_preview_hu(option)
			option.preview_total=forecast.total
			option.label=("自摸" if option.kind=="tsumo" else "荣和")+" · 预计%s分\n"%str(forecast.total)+("现在可过桌" if forecast.success else "仍低于目标，可继续做牌")
		elif option.kind in ["chi","pon","kong","closed_kong","added_kong"]:
			option.preview=_preview_exposed(option)
			option.label+="\n"+("成杠后 " if option.kind=="added_kong" else "")+"+%d分"%option.preview.total
	var actor:int=_s.actor
	if _s.phase=="claim" and _s.discard_count>=TURN_LIMIT*2 and _s.pending_kong.is_empty():
		return options.filter(func(v:Dictionary)->bool:return v.kind in ["ron","pass"])
	var followup:Array=_s.night.reshape.followup[actor]
	if _s.phase!="discard" or (_s.night.self_used[actor] and followup.is_empty()) or _s.melds[actor].size()>=4:return options
	var hand:Array=_s.hands[actor]
	for kind in 34:
		var same:Array=_ids_of_type(hand,kind)
		if same.size()>=3:
			if _s.night.self_used[actor]:same.sort_custom(func(a:int,b:int)->bool:return (a in followup and b not in followup) or ((a in followup)==(b in followup) and a<b))
			var chosen:Array=same.slice(0,3)
			if not _s.night.self_used[actor] or chosen.any(func(id:int)->bool:return id in followup):options.append(_self_option("pon",chosen,actor))
		if kind<27 and kind%9<=6:
			var group:Array=[]
			for t in range(kind,kind+3):
				var ids:Array=_ids_of_type(hand,t)
				if _s.night.self_used[actor]:ids.sort_custom(func(a:int,b:int)->bool:return (a in followup and b not in followup) or ((a in followup)==(b in followup) and a<b))
				if not ids.is_empty():group.append(ids[0])
			if group.size()==3 and (not _s.night.self_used[actor] or group.any(func(id:int)->bool:return id in followup)):options.append(_self_option("chi",group,actor))
	return options

func _preview_hu(option:Dictionary)->Dictionary:
	var simulated=get_script().new();simulated._s=_s.duplicate(true)
	if option.kind=="ron":
		simulated._s.discards[_s.last_discard.actor].erase(_s.last_discard.tile)
		simulated._s.hands[_s.actor].append(_s.last_discard.tile);simulated._s.hands[_s.actor].sort()
	simulated._finish(true,"tsumo" if option.kind=="tsumo" else "ron",_s.actor)
	return simulated.result()

func _preview_exposed(option:Dictionary)->Dictionary:
	# Project only public meld/tea effects. Never draw the hidden kong supplement.
	var actor:int=_s.actor;var tiles:Array=option.tiles.duplicate();var kind:String=option.kind
	var prior:int=0;var projected:Dictionary=_s.duplicate(true)
	if kind in ["chi","pon","kong"]:tiles.append(_s.last_discard.tile)
	if kind=="added_kong":
		tiles.append_array(_s.melds[actor][option.meld_index].tiles)
		prior=int(_s.night.meld_values[actor].get(str(option.meld_index),0));projected.melds[actor][option.meld_index].kind="kong"
	else:projected.melds[actor].append({"kind":"kong" if kind=="closed_kong" else kind,"tiles":tiles.duplicate()})
	tiles.sort();Tea.after_meld(projected,actor,kind)
	if kind in ["added_kong","closed_kong"]:kind="kong"
	var context:Dictionary=_context(actor,tiles);context.tea=projected.tea.charge
	context.both_melded=not projected.melds[0].is_empty() and not projected.melds[1].is_empty()
	context.ensemble_factor=ensemble_factor(kind,actor,prior==0)
	context.inspiration_factor=boost_factor(actor) if prior==0 and _s.night.direction.boost[actor] else 1.0
	context.refrain=prior==0 and _s.night.direction.refrain[actor]>0
	var score:Dictionary=Score.meld(kind,tiles,actor,_s.night,context)
	if prior>0:score.ledger.append({"source":"已入账的原碰","op":"paid","value":prior})
	score.total=maxi(0,score.total-prior);Score.trace_ledger(score.ledger,tiles);return score

func _self_option(kind:String,tiles:Array,actor:int)->Dictionary:
	var projected:Dictionary=_s.duplicate(true)
	projected.melds[actor].append({"kind":kind,"tiles":tiles.duplicate(),"from":actor,"concealed":false})
	Tea.after_meld(projected,actor,kind)
	var context:Dictionary=_context(actor,tiles);context.tea=projected.tea.charge
	context.both_melded=not projected.melds[0].is_empty() and not projected.melds[1].is_empty()
	context.ensemble_factor=ensemble_factor(kind,actor,true)
	context.inspiration_factor=boost_factor(actor) if _s.night.direction.boost[actor] else 1.0
	context.refrain=_s.night.direction.refrain[actor]>0
	var estimate:Dictionary=Score.meld(kind,tiles,actor,_s.night,context)
	var names:Array[String]=[]
	for id:int in tiles:names.append(tile_name(id))
	return {"kind":"self_"+kind,"tiles":tiles,"label":"亮%s · %s  +%d"%["顺" if kind=="chi" else "刻","/".join(names),estimate.total],"detail":"将手中完整面子锁定副露，失去门清/七对。默认每回合一次；续奏或借形追击可多亮一组。预计%d分。"%estimate.total,"preview":estimate}

func apply(choice:Variant,actor:Variant,revision:Variant)->Dictionary:
	if not _operation(actor,revision,["claim","discard","peek"]) or typeof(choice)!=TYPE_INT:return _reply(false,"invalid_operation")
	var options:Array=choices()
	if choice<0 or choice>=options.size():return _reply(false,"unavailable_choice")
	var option:Dictionary=options[choice]
	if option.kind.begins_with("self_"):
		var kind:String=option.kind.trim_prefix("self_")
		var is_followup:bool=_s.night.self_used[actor] and not _s.night.reshape.followup[actor].is_empty()
		for id:int in option.tiles:_s.hands[actor].erase(id)
		_s.melds[actor].append({"kind":kind,"tiles":option.tiles.duplicate(),"from":actor,"concealed":false})
		_s.night.self_used[actor]=true;Tea.after_meld(_s,actor,kind);_record_meld(actor,_s.melds[actor].size()-1)
		_s.night.events.back().self_formed=true;_s.night.last_score.self_formed=true
		if is_followup:
			_s.night.reshape.chains.append({"actor":actor,"tiles":option.tiles.duplicate(),"total":_s.night.last_score.total,"street":_s.night.stage})
			_mark_two_chimes(actor,"reshape")
		_s.night.reshape.followup[actor]=[]
		_s.table_event={"kind":"self_"+kind,"actor":actor,"tiles":option.tiles.duplicate()};_s.revision+=1
		_s.table_event.reshape_chain=is_followup
		return _reply(true,"")
	if option.kind=="pass" and _s.phase=="claim" and _s.pending_kong.is_empty() and _s.discard_count>=TURN_LIMIT*2:
		_s.last_discard={};_finish(false,"night_limit");_s.revision+=1;return _reply(true,"")
	var before:Array=_s.melds.duplicate(true)
	var reply:Dictionary=super.apply(choice,actor,revision)
	if not reply.ok:return reply
	for a in 2:
		for index in _s.melds[a].size():
			if index>=before[a].size() or before[a][index].kind!=_s.melds[a][index].kind:
				_record_meld(a,index)
	return _reply(true,"")

func discard(index:Variant,actor:Variant,revision:Variant)->Dictionary:
	var reply:Dictionary=super.discard(index,actor,revision)
	if not reply.ok:return reply
	var n:Dictionary=_s.night;n.turns[actor]+=1;n.self_used[actor]=false
	n.reshape.followup[actor]=[]
	n.direction.trick_used[actor]=false;n.direction.trick_count[actor]=0;n.direction.recalled[actor]=false
	if technique(actor)!="encore":n.direction.boost[actor]=false;n.direction.boost_left[actor]=0;n.direction.pledge[actor]=0
	if _s.discard_count in [4,8]:
		n.next_phase="claim";n.resume_actor=_s.actor;_s.phase="night_offer";_s.actor=0
		Direction.prepare(n,n.stage)
	return _reply(true,"")

func exchange_tea(index:Variant,slot:Variant,actor:Variant,revision:Variant)->Dictionary:
	if typeof(slot)!=TYPE_INT or slot<0 or slot>=_s.night.revealed:return _reply(false,"river_tile_hidden")
	if typeof(index)!=TYPE_INT or actor not in [0,1] or index<0 or index>=_s.hands[actor].size():return _reply(false,"invalid_exchange")
	var outgoing:int=_s.hands[actor][index];var incoming:int=_s.tea.tray[slot]
	var reply:Dictionary=super.exchange_tea(index,slot,actor,revision)
	if reply.ok:
		if incoming not in _s.night.direction.river_taken[actor]:_s.night.direction.river_taken[actor].append(incoming)
		_s.night.relay_owner[str(outgoing)]=actor
		for a in 2:
			if _s.night.deliveries[a] not in _s.tea.tray:_s.night.deliveries[a]=-1
		if _s.night.requests[1-actor]==int(outgoing/4):
			_s.night.assist_note=["小柯","泡泡"][actor]+"递出"+tile_name(outgoing)+"，可从公开河牌接力。"
			_s.night.requests[1-actor]=-1;_s.night.deliveries[1-actor]=outgoing
	return _reply(reply.ok,reply.get("error",""))

func forecast_exchange(index:int,slot:int)->Dictionary:
	# Simulate only the visible exchange. No draw, future-wall peek, or canonical mutation.
	var actor:int=_s.actor
	if _s.phase!="discard" or index<0 or index>=_s.hands[actor].size() or slot<0 or slot>=_s.night.revealed:return {"ok":false,"error":"unavailable"}
	var outgoing:int=_s.hands[actor][index];var incoming:int=_s.tea.tray[slot]
	var simulated=get_script().new();simulated._s=_s.duplicate(true)
	var reply:Dictionary=simulated.exchange_tea(index,slot,actor,_s.revision)
	var result:Dictionary={"ok":reply.ok,"error":reply.get("error",""),"outgoing":outgoing,"incoming":incoming,"cost":Tea.cost(_s,actor),"best":{}}
	if not reply.ok:return result
	var best_value:int=-1
	for option:Dictionary in simulated.choices():
		var value:int=-1
		if option.kind=="tsumo":value=int(option.preview_total)
		elif option.has("preview") and incoming in option.tiles:value=int(option.preview.total)
		if value>best_value:best_value=value;result.best=option.duplicate(true)
	for option:Dictionary in simulated.continuation_options():
		if incoming in option.tiles and int(option.preview.total)>best_value:
			best_value=option.preview.total;result.best=option.duplicate(true);result.best.needs_continuation=true
	return result

func river_opportunities()->Array:
	# Bounded own-hand / revealed-river forecast. Called on deliberate UI opening.
	# Suggestions never commit the swap or auto-play its resulting group.
	if _s.phase!="discard":return []
	if _river_plan_revision==int(_s.revision):return _river_plan_cache.duplicate(true)
	var actor:int=_s.actor;var plans:Array=[]
	for slot in int(_s.night.revealed):
		var best:Dictionary={}
		for index in _s.hands[actor].size():
			if not Tea.can_swap(_s,index,slot,actor):continue
			var forecast:Dictionary=forecast_exchange(index,slot)
			if not forecast.ok or forecast.best.is_empty():continue
			var choice:Dictionary=forecast.best
			var points:int=choice.get("preview_total",choice.get("preview",{}).get("total",0))
			var remainder:Array=_s.hands[actor].duplicate();remainder.erase(forecast.outgoing);remainder.append(forecast.incoming)
			for tile:int in choice.get("tiles",[]):remainder.erase(tile)
			var shape:float=_shape_value(remainder,_s.styles[actor])
			if best.is_empty() or points>best.points or (points==best.points and shape>best.shape):
				best={"index":index,"slot":slot,"outgoing":forecast.outgoing,"incoming":forecast.incoming,"cost":forecast.cost,"choice":choice,"points":points,"shape":shape,"clue":hand_clue(index)}
		if not best.is_empty():plans.append(best)
	plans.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.points>b.points or (a.points==b.points and a.slot<b.slot))
	_river_plan_revision=int(_s.revision);_river_plan_cache=plans.duplicate(true)
	return plans

func hand_clue(index:int)->Dictionary:
	# This hand plus a public request only; no promise about hidden future tiles.
	var actor:int=_s.actor
	if _s.phase!="discard" or index<0 or index>=_s.hands[actor].size():return {}
	var tile:int=_s.hands[actor][index];var face:int=int(tile/4);var same:int=0;var near:Array=[]
	for id:int in _s.hands[actor]:
		var other:int=int(id/4)
		if other==face:same+=1
		elif face<27 and other<27 and int(face/9)==int(other/9) and absi(face-other)<=2 and other not in near:near.append(other)
	var wanted:bool=_s.night.requests[1-actor]==face
	var text:String="伙伴正在要这张牌，可先用递彩或河牌交换送过去。" if wanted else ("这是同牌组合，打出会减少碰/刻/杠的材料。" if same>=2 else ("与手中近邻能衔接；留顺子还是拿它交换，由你决定。" if not near.is_empty() else "目前无同牌或两格内近邻，可拿来换河牌，也可打出换下一摸。"))
	return {"tile":tile,"same":same,"near":near,"partner_wants":wanted,"text":text}

func request_tile(index:int,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["discard"]) or index< -1 or index>=_s.hands[actor].size():return _reply(false,"invalid_tile_request")
	return request_type(int(_s.hands[actor][index]/4) if index>=0 else -1,actor,revision)

func request_type(type:int,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["discard"]) or type< -1 or type>=34:return _reply(false,"invalid_tile_request")
	_s.night.requests[actor]=type;_s.night.deliveries[actor]=-1
	_s.night.assist_note=["小柯","泡泡"][actor]+("公开要牌："+tile_name(type*4) if type>=0 else "已取消要牌。")
	_s.table_event={"kind":"offer","actor":actor,"tiles":[]};_s.revision+=1;return _reply(true,"")

func ai_assist_exchange()->Array:
	if _s.phase!="discard":return []
	var actor:int=_s.actor;var wanted:int=_s.night.requests[1-actor]
	if wanted<0:return []
	# Uses only a public request, own hand and visible river. Reserve the tea
	# the partner needs to retrieve this actual physical tile.
	if _s.tea.charge<Tea.cost(_s,actor)+Tea.cost(_s,1-actor):return []
	var hand:Array=_s.hands[actor];var before:float=_shape_value(hand,_s.styles[actor]);var best:Array=[];var quality:float=-6.0
	for index in hand.size():
		if int(hand[index]/4)!=wanted:continue
		for slot in int(_s.night.revealed):
			if not Tea.can_swap(_s,index,slot,actor) or int(_s.tea.tray[slot]/4)==wanted:continue
			var trial:Array=hand.duplicate();trial[index]=_s.tea.tray[slot]
			var gain:float=_shape_value(trial,_s.styles[actor])-before
			if hand[index]==_s.night.get("promised_tiles",[-1,-1])[actor]:gain+=100
			if gain>quality:quality=gain;best=[index,slot]
	return best

func ai_request_type()->int:
	if _s.phase!="discard" or _s.night.deliveries[_s.actor] in _s.tea.tray:return -1
	var actor:int=_s.actor;var counts:Array=[];counts.resize(34);counts.fill(0)
	var public_counts:Array=counts.duplicate();var visible_river:Array=[]
	for id:int in _s.hands[actor]:counts[int(id/4)]+=1;public_counts[int(id/4)]+=1
	for a in 2:
		for id:int in _s.discards[a]:public_counts[int(id/4)]+=1
		for meld:Dictionary in _s.melds[a]:
			for id:int in meld.tiles:public_counts[int(id/4)]+=1
	for id:int in _s.tea.tray.slice(0,int(_s.night.revealed)):public_counts[int(id/4)]+=1;visible_river.append(int(id/4))
	var triplets:bool="coal" in _s.night.build.items[actor] or "anvil" in _s.night.build.items[actor]
	var best:int=-1;var value:float=0
	for type in 34:
		if public_counts[type]>=4 or type in visible_river:continue
		var need:float=0
		if counts[type]==2:need=25 if triplets else 19
		elif counts[type]==3 and triplets:need=22
		if type<27:
			for start in range(maxi(int(type/9)*9,type-2),mini(int(type/9)*9+6,type)+1):
				var complete:bool=true
				for other in range(start,start+3):
					if other!=type and counts[other]==0:complete=false
				if complete and counts[type]==0:need+=9 if triplets else 12
		if need>value:value=need;best=type
	return best

func refresh_river(slot:int,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["discard"]) or slot<0 or slot>=_s.night.revealed or _s.night.refresh_used or _s.tea.charge<2 or _s.wall.is_empty():return _reply(false,"river_refresh_unavailable")
	var outgoing:int=_s.tea.tray[slot];var incoming:int=_s.wall.pop_front()
	_s.discards[actor].append(outgoing);_s.tea.tray[slot]=incoming
	_s.tea.charge-=2;_s.night.refresh_used=true;_s.tea.locked=true
	_s.table_event={"kind":"river_refresh","actor":actor,"tiles":[outgoing,incoming]};_s.revision+=1
	return _reply(true,"")

func request_cash_out(actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["discard"]) or bank_total()<_s.night.target:return _reply(false,"target_not_met")
	_s.night.cash_resume={"actor":actor,"phase":_s.phase};_s.actor=1-actor;_s.phase="night_cash_offer"
	_s.table_event={"kind":"offer","actor":actor,"tiles":[]};_s.revision+=1;return _reply(true,"")

func encore_target()->int:return ceili(float(_s.night.encore.base_target)*1.6)

func encore_advice()->Dictionary:
	# A cooperative risk stance based exclusively on public, already-earned evidence.
	# No private hand, covered river, wall or future RNG is consulted.
	var n:Dictionary=_s.night;var remaining:int=maxi(0,TURN_LIMIT*2-_s.discard_count)
	var gap:int=maxi(0,encore_target()-bank_total());var best:int=0
	for event:Dictionary in n.events:
		if event.kind in ["chi","pon","kong","closed_kong","added_kong"]:best=maxi(best,int(event.total))
	var cushion:float=1.25 if int(n.stamina)<=1 else 1.0
	var accept:bool=remaining>=4 and float(best)*3.0>=float(gap)*cushion
	if remaining>=2 and float(best)*.65>=float(gap)*cushion:accept=true
	var text:String=("愿意加演：还剩%d次打牌，差%d分，已有单组最高%d分。" if accept else "建议收桌：还剩%d次打牌，差%d分；已打出的最高单组%d分，余量不够。")%[remaining,gap,best]
	if n.stamina<=1:text+=" 仅剩1耐力，我会更谨慎。"
	return {"accept":accept,"text":text,"remaining":remaining,"gap":gap,"public_best":best}

func can_invite_encore()->bool:
	if not _s.has("night") or _s.phase!="discard":return false
	var n:Dictionary=_s.night;var bank:int=bank_total()
	return n.table<3 and not n.encore.asked and bank>=n.target and bank<encore_target() and _s.discard_count<TURN_LIMIT*2

func request_encore(actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["discard"]) or not can_invite_encore():return _reply(false,"encore_unavailable")
	_s.night.encore.asked=true;_s.night.encore.resume=actor
	_s.actor=1-actor;_s.phase="night_encore_offer"
	_s.table_event={"kind":"offer","actor":actor,"tiles":[]};_s.revision+=1
	return _reply(true,"")

func answer_encore(accept:bool,actor:int,revision:int,decision_note:String="")->Dictionary:
	if not _operation(actor,revision,["night_encore_offer"]):return _reply(false,"invalid_encore_response")
	if accept:_s.night.encore.active=true;_s.night.target=encore_target()
	_s.night.encore.answer="accepted" if accept else "declined"
	_s.night.encore.note=decision_note
	_s.actor=_s.night.encore.resume;_s.phase="discard"
	_s.table_event={"kind":"encore" if accept else "offer","actor":actor,"tiles":[]};_s.revision+=1
	return _reply(true,"")

func answer_cash_out(accept:bool,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["night_cash_offer"]):return _reply(false,"invalid_cash_response")
	if accept:_finish(false,"banked_early")
	else:_s.actor=_s.night.cash_resume.actor;_s.phase=_s.night.cash_resume.phase
	_s.revision+=1;return _reply(true,"")

func bank_total()->int:
	if _s.phase=="finished":return _s.night.scores[0]+_s.night.scores[1]
	var total:int=0
	for actor in 2:
		var score:int=_s.night.scores[actor]
		total+=score+ (roundi(score*(Catalog.STAKE_MULT[_s.night.tiers[actor]]-1.0)) if _contract_met(actor,_s.night.contracts[actor]) else 0)
	return total

func ensemble_factor(kind:String,actor:int,new_group:bool)->float:
	var ensemble:Dictionary=_s.night.ensemble
	var chain:int=ensemble.chain
	if new_group and ensemble.last_actor>=0 and ensemble.last_actor!=actor and ensemble.last_kind!=kind:chain=mini(4,chain+1)
	return 1.0+.25*chain

func state()->Dictionary:
	var snapshot:Dictionary=super.state()
	if snapshot.has("night"):snapshot.night.bank_preview=bank_total()
	return snapshot

func _context(actor:int,tiles:Array)->Dictionary:
	var c:Dictionary=_s.night.contexts[actor].duplicate(true)
	c.tea=_s.tea.charge;c.relay=false
	c.applause=_s.night.direction.applause[actor]
	if _s.night.venue=="prism":c.boss_unsealed=prism_open()
	c.ensemble_factor=1.0+.25*int(_s.night.ensemble.chain)
	for id:int in tiles:
		if _s.night.relay_owner.get(str(id),actor)!=actor and id not in _s.night.relay_used:c.relay=true
	c.both_melded=not _s.melds[0].is_empty() and not _s.melds[1].is_empty()
	c.partner_kinds=_s.night.contexts[1-actor].kinds.duplicate()
	c.river_bounty=false
	if _s.night.table==2 and _s.night.venue=="river" and not _s.night.bounty_claimed:
		for id:int in tiles:
			if id in _s.night.fresh_river:c.river_bounty=true
	return c

func _record_meld(actor:int,index:int)->void:
	var meld:Dictionary=_s.melds[actor][index]
	var prior:int=_s.night.meld_values[actor].get(str(index),0)
	var context:Dictionary=_context(actor,meld.tiles);context.ensemble_factor=ensemble_factor(meld.kind,actor,prior==0)
	context.inspiration_factor=boost_factor(actor) if prior==0 and _s.night.direction.boost[actor] else 1.0
	context.refrain=prior==0 and _s.night.direction.refrain[actor]>0
	var score:Dictionary=Score.meld(meld.kind,meld.tiles,actor,_s.night,context)
	if prior==0:
		_s.night.ensemble.chain=roundi((context.ensemble_factor-1.0)*4)
		_s.night.ensemble.last_actor=actor;_s.night.ensemble.last_kind=meld.kind
	_s.night.meld_values[actor][str(index)]=maxi(prior,score.total)
	if prior>0:score.ledger.append({"source":"已入账的原碰","op":"paid","value":prior})
	score.total=maxi(0,score.total-prior)
	if prior==0:
		var direction:Dictionary=_s.night.direction
		if context.refrain:direction.refrain[actor]-=1
		if direction.boost[actor]:
			direction.boost_left[actor]=maxi(0,direction.boost_left[actor]-1);direction.boost[actor]=direction.boost_left[actor]>0
			if direction.pledge[actor]>0:
				_s.night.wallets[actor]+=direction.pledge[actor];direction.pledge[actor]=0;_s.tea.charge=mini(9,_s.tea.charge+1)
				score.ledger.append({"source":"压轴成功 · 退本金1币 / 返1茶气","op":"refund","value":1})
		if context.relay and technique(1-actor)=="partner" and not direction.support_refunded[1-actor]:
			direction.support_refunded[1-actor]=true;direction.inspiration[1-actor]=mini(3,direction.inspiration[1-actor]+1)
			score.ledger.append({"source":"接棒师 · 给递牌伙伴返1灵感","op":"support","value":1})
		var lamp:Dictionary=Direction.complete(_s.night,actor,meld.kind,meld.tiles,context)
		if not lamp.is_empty():
			score.lamp=lamp;score.ledger.append({"source":"亮灯 · "+Direction.GOALS[lamp.goal].name,"op":"lamp","value":2})
			if lamp.get("duo_refrain",false):score.ledger.append({"source":"双灯齐亮 · 双方各获得一次返场","op":"refrain_gain","value":1})
	_commit_score(score,actor,true)
	var c:Dictionary=_s.night.contexts[actor]
	if meld.kind=="chi":
		c.chi_count+=1;var first:int=int(meld.tiles.min()/4)
		if first not in c.starts:c.starts.append(first)
		if int(first/9) not in c.suits:c.suits.append(int(first/9))
	if meld.kind not in c.kinds:c.kinds.append(meld.kind)
	if score.used_heat:c.heat=0
	c.heat=mini(2,int(c.heat)+int(score.heat_gain))
	c.growth+=score.growth
	_s.tea.charge=mini(9,_s.tea.charge+score.tea_return)
	if score.get("river_bounty",false):_s.night.bounty_claimed=true
	if score.relay:
		for id:int in meld.tiles:
			if _s.night.relay_owner.get(str(id),actor)!=actor and id not in _s.night.relay_used:_s.night.relay_used.append(id)
	_remember_contracts(actor)

func _commit_score(score:Dictionary,actor:int,pay_gold:bool)->void:
	score.id=_s.night.events.size()+1
	score.personal_turn=_s.night.turns[actor]
	_s.night.scores[actor]+=score.total
	var earned_coins:int=0
	if pay_gold:
		for id:int in score.tiles:
			if _s.night.build.stamps.get(str(id),"")=="gold" and id not in _s.night.gold_paid:_s.night.wallets[actor]+=1;_s.night.gold_paid.append(id);earned_coins+=1
	if earned_coins>0:score.ledger.append({"source":"金封·实体首次使用","op":"coin","value":earned_coins})
	Score.trace_ledger(score.ledger,score.tiles)
	score.earned_coins=earned_coins
	_s.night.events.append(score.duplicate(true));_s.night.last_score=score.duplicate(true)

func _contract_met(actor:int,contract:String)->bool:return _contract_with_groups(actor,contract,_s.night.hu_groups[actor])

func _contract_with_groups(actor:int,contract:String,closed_groups:Array)->bool:
	var groups:Array=_s.melds[actor].duplicate(true);groups.append_array(closed_groups)
	if contract=="suit":
		if closed_groups.is_empty():return false
		var counts:Array=[0,0,0]
		for group:Dictionary in groups:
			for id:int in group.tiles:
				if id<108:counts[int(id/36)]+=1
		return counts.max()>=9
	var count:int=0
	for group:Dictionary in groups:
		if (contract=="sequence" and group.kind=="chi") or (contract=="triplet" and group.kind in ["pon","kong"]):count+=1
	return count>=(3 if contract=="sequence" else 2)

func _evaluate_hu_layout(groups:Array,winner:int,reason:String)->Dictionary:
	var n:Dictionary=_s.night
	var value:int=n.scores[winner];var ledger:Array=[]
	var virtual_context:Dictionary=_context(winner,[])
	var virtual_bounty:bool=n.bounty_claimed
	ledger.append({"source":"此前面子已入账","op":"base","value":value})
	var same_suits:Array=[0,0,0,0];var pairs:int=0
	var all_groups:Array=_s.melds[winner].duplicate(true);all_groups.append_array(groups)
	for group:Dictionary in all_groups:
		for id:int in group.tiles:same_suits[mini(int(id/36),3)]+=1
	for group:Dictionary in groups:
		if group.kind=="pair":value+=40;pairs+=1;ledger.append({"source":"雀头 / 对子","op":"add","value":40})
		else:
			virtual_context.relay=_context(winner,group.tiles).relay
			virtual_context.river_bounty=_context(winner,group.tiles).river_bounty and not virtual_bounty
			var sc:Dictionary=Score.meld(group.kind,group.tiles,winner,n,virtual_context);value+=sc.total
			if sc.get("river_bounty",false):virtual_bounty=true
			ledger.append({"source":"暗"+("顺" if group.kind=="chi" else "刻"),"op":"add","value":sc.total,"detail":sc.ledger,"replay_sample":sc.duplicate(true)})
			if group.kind=="chi":
				virtual_context.chi_count+=1;var first:int=int(group.tiles.min()/4)
				if first not in virtual_context.starts:virtual_context.starts.append(first)
				if int(first/9) not in virtual_context.suits:virtual_context.suits.append(int(first/9))
			if sc.used_heat:virtual_context.heat=0
			virtual_context.heat=mini(2,int(virtual_context.heat)+sc.heat_gain)
			virtual_context.growth+=sc.growth
	var fan:int=4+(2 if reason=="tsumo" else 0)+(6 if pairs==7 else 0)
	var concealed:bool=true
	for meld:Dictionary in _s.melds[winner]:
		if not meld.get("concealed",false):concealed=false
	if concealed:fan+=2
	var physical_count:int=0
	for count:int in same_suits:physical_count+=count
	var pure:bool=same_suits.slice(0,3).max()==physical_count and same_suits[3]==0
	if pure:fan+=6
	ledger.append({"source":"合法胡牌"+(" · 自摸" if reason=="tsumo" else "")+(" · 门清" if concealed else "")+(" · 七对" if pairs==7 else "")+(" · 清一色" if pure else ""),"op":"multiply","value":fan})
	var full:int=value*fan;var increase:int=maxi(0,full-n.scores[winner])
	ledger.append({"source":"扣除已入账部分","op":"paid","value":n.scores[winner]})
	return {"groups":groups.duplicate(true),"full":full,"total":increase,"chips":value,"fan":fan,"ledger":ledger}

func _finish(success:bool,reason:String,winner:int=-1)->void:
	if not _s.has("night"):super._finish(success,reason,winner);return
	var n:Dictionary=_s.night
	if success and winner>=0:
		var best:Dictionary={};var best_rank:float=-1
		for groups:Array in Score.hand_layouts(_s.hands[winner]):
			var candidate:Dictionary=_evaluate_hu_layout(groups,winner,reason)
			var rank:float=candidate.full
			if _contract_with_groups(winner,n.contracts[winner],groups):rank*=Catalog.STAKE_MULT[n.tiers[winner]]
			if rank>best_rank:best=candidate;best_rank=rank
		if best.is_empty():_finish(false,"invalid_hu_layout");return
		n.hu_groups[winner]=best.groups
		_commit_score({"kind":"hu","actor":winner,"tiles":_s.hands[winner].duplicate(),"chips":best.chips,"factor":best.fan,"repeats":1,"total":best.total,"ledger":best.ledger},winner,true)

	var contracts:Array=[]
	for actor in 2:
		var met:bool=_contract_met(actor,n.contracts[actor]);var tier:int=n.tiers[actor]
		var extra:int=roundi(n.scores[actor]*(Catalog.STAKE_MULT[tier]-1.0)) if met else 0
		if met:n.wallets[actor]+=n.paid[actor]
		if extra>0:_commit_score({"kind":"contract","actor":actor,"tiles":[],"chips":n.scores[actor],"factor":Catalog.STAKE_MULT[tier],"repeats":1,"total":extra,"ledger":[{"source":"本桌本人已得分","op":"base","value":n.scores[actor]},{"source":Catalog.CONTRACTS[n.contracts[actor]].name,"op":"multiply","value":Catalog.STAKE_MULT[tier]},{"source":"本金得分已记，仅加契约奖励","op":"paid","value":n.scores[actor]}]},actor,false)
		contracts.append({"id":n.contracts[actor],"met":met,"stake":n.paid[actor],"extra":extra})
	var total:int=n.scores[0]+n.scores[1];var owned:Array=[_s.hands[0].duplicate(),_s.hands[1].duplicate()]
	for actor in 2:
		for meld:Dictionary in _s.melds[actor]:owned[actor].append_array(meld.tiles)
	_s.result={"success":total>=n.target and reason!="retreated","hu":success,"reason":reason,"winner":winner,"scores":n.scores.duplicate(),"total":total,"target":n.target,"wallets":n.wallets.duplicate(),"contracts":contracts,"owned_tiles":owned,"ledger":n.events.duplicate(true),"table":n.table,"venue":n.venue,"build":n.build.duplicate(true),"direction":n.direction.duplicate(true)}
	_s.result.encore=n.encore.duplicate(true)
	_s.result.reshape=n.reshape.duplicate(true)
	_s.result.continuations=n.continuations.duplicate(true)
	_s.result.encore_bonus=n.encore.reward if n.encore.active and _s.result.success else 0
	_s.phase="finished";_s.table_event={"kind":"win" if success else "finish","actor":maxi(winner,0),"tiles":_s.hands[maxi(winner,0)].duplicate()}

func ai_choice()->int:
	var options:Array=choices()
	for kind in ["ron","tsumo","closed_kong","kong","added_kong"]:
		for index in options.size():
			if options[index].kind==kind:return index
	if _s.phase=="peek":return super.ai_choice()
	var best:int=-1;var points:float=-1
	for index in options.size():
		var option:Dictionary=options[index]
		if option.kind in ["self_chi","self_pon","chi","pon"]:
			var value:float=option.preview.total
			var d:Dictionary=_s.night.direction;var actor:int=_s.actor
			if not d.done[actor] and Direction.matches(d.selected[actor],option.kind.trim_prefix("self_"),option.preview.tiles,option.preview.replay_context,d.river_taken[actor]):
				value+=90
				if _s.night.venue=="refrain" and d.done[1-actor]:value+=120
			if value>points:points=value;best=index
	if best>=0:return best
	if _s.phase=="claim":
		for index in options.size():
			if options[index].kind=="pass":return index
	return -1

func ai_exchange()->Array:
	if _s.phase!="discard":return []
	var assist:Array=ai_assist_exchange()
	if not assist.is_empty():return assist
	var actor:int=_s.actor;var hand:Array=_s.hands[actor]
	if _s.night.deliveries[1-actor] in _s.tea.tray:return []
	var best:Array=[];var gain:float=1.0
	var before:float=_shape_value(hand,_s.styles[actor])
	for index in hand.size():
		for slot in int(_s.night.revealed):
			if not Tea.can_swap(_s,index,slot,actor) or _s.tea.charge-Tea.cost(_s,actor)<1:continue
			var trial:Array=hand.duplicate();trial[index]=_s.tea.tray[slot]
			var value:float=_shape_value(trial,_s.styles[actor])-before
			if _analysis(trial,_s.melds[actor],_s.styles[actor]).valid:value+=100
			if value>gain:gain=value;best=[index,slot]
	return best

func ai_refresh_slot()->int:
	if _s.phase!="discard" or _s.night.refresh_used or _s.tea.charge<5:return -1
	var actor:int=_s.actor;var hand:Array=_s.hands[actor];var before:float=_shape_value(hand,_s.styles[actor])
	if _s.night.deliveries[1-actor] in _s.tea.tray:return -1
	var worst:int=-1;var least:float=INF
	for slot in int(_s.night.revealed):
		var best:float=-INF
		for index in hand.size():
			var trial:Array=hand.duplicate();trial[index]=_s.tea.tray[slot]
			best=maxf(best,_shape_value(trial,_s.styles[actor])-before)
		if best<least:least=best;worst=slot
	return worst if least<1.0 else -1

func ai_offer()->void:
	if _s.phase!="night_offer":return
	var actor:int=_s.actor;var contract:String=_s.night.contracts[actor]
	if _s.night.stage==0:
		var pairs:int=0
		for kind in 34:
			if _ids_of_type(_s.hands[actor],kind).size()>=2:pairs+=1
		contract="triplet" if pairs>=2 else "sequence"
	var tier:int=_s.night.tiers[actor]
	# No wall access or unseen river access. AI risks at most its own 2 coins.
	if tier==0 and _s.night.wallets[actor]>=4 and not _contract_met(actor,contract):tier=1
	choose_spotlight(ai_spotlight(),actor,_s.revision)
	offer(contract,tier,actor,_s.revision);ready_offer(actor,_s.revision)


func choose_spotlight(id:String,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["night_offer"]) or id not in _s.night.direction.offers[actor]:return _reply(false,"invalid_spotlight")
	_s.night.direction.selected[actor]=id;_s.revision+=1;_s.table_event={"kind":"offer","actor":actor,"tiles":[]}
	return _reply(true,"")

func perform_trick(id:String,index:int,target:int,actor:int,revision:int)->Dictionary:
	if not _operation(actor,revision,["discard"]):return _reply(false,"invalid_trick_phase")
	var d:Dictionary=_s.night.direction
	if d.inspiration[actor]<=0 or d.trick_used[actor]:return _reply(false,"inspiration_unavailable")
	if id not in ["recall","boost","relay","stoke"]:return _reply(false,"unknown_trick")
	var tiles:Array=[]
	if id=="stoke":
		if "coal" not in _s.night.build.items[actor] or int(_s.night.contexts[actor].heat)>=2:return _reply(false,"furnace_unavailable")
		_s.night.contexts[actor].heat+=1
	elif id=="boost":
		if _s.night.self_used[actor]:return _reply(false,"already_performed")
		if d.boost[actor]:return _reply(false,"boost_already_armed")
		if technique(actor)=="spotlight":
			if _s.night.wallets[actor]<1:return _reply(false,"not_enough_coins")
			_s.night.wallets[actor]-=1;d.pledge[actor]=1
		d.boost[actor]=true;d.boost_left[actor]=2 if technique(actor)=="encore" else 1
	else:
		if index<0 or index>=_s.hands[actor].size():return _reply(false,"trick_requires_tile")
		var outgoing:int=_s.hands[actor][index];var incoming:int=-1
		if id=="recall":
			if d.recalled[actor]:return _reply(false,"already_recalled")
			if target not in _s.discards[actor] or int(target/4)==int(outgoing/4):return _reply(false,"invalid_recall")
			incoming=target;_s.discards[actor][_s.discards[actor].find(target)]=outgoing
		else:
			if target<0 or target>=_s.night.revealed:return _reply(false,"river_tile_hidden")
			incoming=_s.tea.tray[target]
			if int(incoming/4)==int(outgoing/4) or incoming==_s.night.deliveries[1-actor]:return _reply(false,"reserved_delivery")
			_s.tea.tray[target]=outgoing;_s.night.relay_owner[str(outgoing)]=actor
			if incoming not in d.river_taken[actor]:d.river_taken[actor].append(incoming)
			if _s.night.requests[1-actor]==int(outgoing/4):_s.night.requests[1-actor]=-1;_s.night.deliveries[1-actor]=outgoing
		_s.hands[actor][index]=incoming;_s.hands[actor].sort()
		if _s.drawn_tile==outgoing:_s.drawn_tile=incoming
		for a in 2:
			if _s.night.deliveries[a] not in _s.tea.tray:_s.night.deliveries[a]=-1
		tiles=[outgoing,incoming]
	d.trick_history.append({"id":id,"actor":actor,"street":_s.night.stage,"tiles":tiles.duplicate()})
	d.inspiration[actor]-=1;d.trick_count[actor]+=1
	if id=="recall":d.recalled[actor]=true
	d.trick_used[actor]=not (technique(actor)=="rewind" and id=="recall" and d.trick_count[actor]==1)
	_s.tea.locked=true
	d.last_notice={"recall":"回手：换回自己的弃牌，没有额外摸牌或茶气。","relay":"递彩：以灵感换牌，给伙伴留下公开接力牌。","boost":"催演已点亮：下个新亮面子 ×1.8；本回合弃牌即失效。","stoke":"添火：花1灵感积1炉温，跨回合保留。满2后下一组顺/刻再计一次！"}[id]
	if id=="boost":d.last_notice=boost_description(actor)
	_s.table_event={"kind":"trick_"+id,"actor":actor,"tiles":tiles,"factor":boost_factor(actor)};_s.revision+=1
	return _reply(true,"")

func forecast_trick(id:String,index:int,target:int)->Dictionary:
	var simulated=get_script().new();simulated._s=_s.duplicate(true)
	var reply:Dictionary=simulated.perform_trick(id,index,target,_s.actor,_s.revision)
	if not reply.ok:return {"ok":false}
	var incoming:int=target if id=="recall" else (_s.tea.tray[target] if id=="relay" else -1)
	var best:Dictionary={};var value:int=0
	for option:Dictionary in simulated.choices():
		if id not in ["boost","stoke"] and option.kind!="tsumo" and incoming not in option.get("tiles",[]):continue
		var points:int=int(option.get("preview",{}).get("total",0))
		if option.kind=="tsumo":points=int(option.preview_total)
		if points>value:best=option.duplicate(true);value=points
	return {"ok":true,"best":best,"score":value}


func ai_spotlight()->String:
	var actor:int=_s.actor;var d:Dictionary=_s.night.direction
	var best:String=d.offers[actor][0];var quality:int=-1
	var faces:Array=[]
	for tile:int in _s.hands[actor]:faces.append(int(tile/4))
	for id:String in d.offers[actor]:
		var value:int=0
		for face:int in faces:
			match id:
				"triplet":value+=faces.count(face)*2
				"sequence":
					if face<27 and face%9<7:value+=3*(int(face+1 in faces)+int(face+2 in faces))
				"edge":value+=2 if face>=27 or face%9 in [0,8] else 0
				"middle":value+=2 if face<27 and face%9 not in [0,8] else 0
				"relay":value+=6 if _s.night.deliveries[actor] in _s.tea.tray else 0
				"river":value+=1
		if value>quality:quality=value;best=id
	return best

func ai_trick()->Array:
	if _s.phase!="discard":return []
	var actor:int=_s.actor;var d:Dictionary=_s.night.direction
	if d.inspiration[actor]<=0 or d.trick_used[actor]:return []
	var hand:Array=_s.hands[actor];var before:float=_shape_value(hand,_s.styles[actor])
	# Deliver only from this actor's own cards in response to a public request.
	var wanted:int=_s.night.requests[1-actor]
	if wanted>=0:
		for index in hand.size():
			if int(hand[index]/4)!=wanted:continue
			for slot in int(_s.night.revealed):
				var incoming:int=_s.tea.tray[slot]
				if int(incoming/4)==wanted or incoming==_s.night.deliveries[1-actor]:continue
				var trial:Array=hand.duplicate();trial[index]=incoming
				if hand[index]==_s.night.get("promised_tiles",[-1,-1])[actor] or _shape_value(trial,_s.styles[actor])-before>=-3:return ["relay",index,slot]
	var best:Array=[];var gain:float=4.0
	# Public boss instruction: if the partner already boosted, choose a useful
	# different trick instead of repeatedly paying for the same sealed approach.
	if _s.night.venue=="prism" and not prism_open():
		var partner_kinds:Array=[]
		for entry:Dictionary in d.trick_history:
			if entry.actor==1-actor and entry.id not in partner_kinds:partner_kinds.append(entry.id)
		if partner_kinds==["boost"]:
			var alternative:Array=[];var quality:float=-2.0
			for slot in int(_s.night.revealed):
				var incoming:int=_s.tea.tray[slot]
				if incoming==_s.night.deliveries[1-actor]:continue
				for index in hand.size():
					if int(hand[index]/4)==int(incoming/4):continue
					var trial:Array=hand.duplicate();trial[index]=incoming
					var value:float=_shape_value(trial,_s.styles[actor])-before
					if value>quality:quality=value;alternative=["relay",index,slot]
			if not alternative.is_empty():return alternative
	# Own relic and own visible group only: charge a nearly-ready furnace instead
	# of the ordinary x1.8 boost when the real repeat pays more immediately.
	if "coal" in _s.night.build.items[actor] and int(_s.night.contexts[actor].heat)==1 and not _s.night.self_used[actor]:
		for option:Dictionary in choices():
			if option.kind in ["self_chi","self_pon"] and option.preview.repeats==1 and boost_factor(actor)<2.0:return ["stoke",-1,-1]
	for tile:int in ([] if d.recalled[actor] else _s.discards[actor]):
		for index in hand.size():
			if int(hand[index]/4)==int(tile/4):continue
			var trial:Array=hand.duplicate();trial[index]=tile
			var value:float=_shape_value(trial,_s.styles[actor])-before
			if value>gain:gain=value;best=["recall",index,tile]
	if not best.is_empty():return best
	# Spend a private resource only when an exposed group is actually available.
	if not _s.night.self_used[actor] and not d.boost[actor] and (technique(actor)!="spotlight" or _s.night.wallets[actor]>0):
		for option:Dictionary in choices():
			if option.kind in ["self_chi","self_pon","closed_kong"]:return ["boost",-1,-1]
	if "coal" in _s.night.build.items[actor] and int(_s.night.contexts[actor].heat)<2 and int(d.inspiration[actor])>=2:return ["stoke",-1,-1]
	return []


func technique(actor:int)->String:return _s.night.build.get("techniques",["",""])[actor]
func boost_factor(actor:int)->float:return {"spotlight":2.6,"encore":1.5}.get(technique(actor),1.8)
func boost_description(actor:int)->String:
	if technique(actor)=="spotlight":return "催演 ×2.6 · 额外押1金币，新亮组成功退还；弃牌/胡牌不退"
	if technique(actor)=="encore":return "催演 ×1.5 · 连续两组，跨回合保留到本街结束"
	return "催演 ×1.8 · 下个新亮面子，弃牌前没亮出就消散"


func prism_open()->bool:
	var actors:Array=[];var kinds:Array=[]
	for trick:Dictionary in _s.night.direction.trick_history:
		if trick.actor not in actors:actors.append(trick.actor)
		if trick.id not in kinds:kinds.append(trick.id)
	return actors.size()==2 and kinds.size()>=2

func can_reshape()->bool:
	if _s.get("phase","")!="discard" or not _s.has("night"):return false
	var actor:int=_s.actor;var d:Dictionary=_s.night.direction
	return int(d.inspiration[actor])>0 and not d.trick_used[actor] and not _s.melds[actor].is_empty()

func reshape_options()->Array:
	if not can_reshape():return []
	if _reshape_revision==int(_s.revision):return _reshape_cache.duplicate(true)
	var actor:int=_s.actor
	var options:Array=Reshape.candidates(_s.hands[actor],_s.melds[actor],_s.night.reshape.used[actor])
	for option:Dictionary in options:
		var simulated=get_script().new();simulated._s=_s.duplicate(true);simulated._commit_reshape(option)
		var best:Dictionary={};var points:int=0
		for choice:Dictionary in simulated.choices():
			if choice.kind not in ["tsumo","self_chi","self_pon","closed_kong","added_kong"]:continue
			if choice.kind!="tsumo" and not option.take.any(func(id:int)->bool:return id in choice.get("tiles",[])):continue
			var amount:int=int(choice.preview_total) if choice.kind=="tsumo" else int(choice.get("preview",{}).get("total",0))
			if amount>points:points=amount;best=choice.duplicate(true)
		option.best=best;option.score=points
		option.contract_before=contract_progress(actor);option.contract_after=simulated.contract_progress(actor)
		option.bank_before=bank_total();option.bank_after=simulated.bank_total()
		option.bank_after_chain=simulated._project_group_bank(best)
		option.shape_gain=_shape_value(simulated._s.hands[actor],_s.styles[actor])-_shape_value(_s.hands[actor],_s.styles[actor])
	options.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		if a.score!=b.score:return a.score>b.score
		if a.shape_gain!=b.shape_gain:return a.shape_gain>b.shape_gain
		if a.give.size()!=b.give.size():return a.give.size()<b.give.size()
		return a.key<b.key)
	_reshape_revision=int(_s.revision);_reshape_cache=options.duplicate(true)
	return options

func reshape(key:Variant,actor:Variant,revision:Variant)->Dictionary:
	if not _operation(actor,revision,["discard"]) or typeof(key)!=TYPE_STRING or not can_reshape():return _reply(false,"reshape_unavailable")
	# Re-enumerate authoritative physical IDs; never trust a client-supplied group.
	for option:Dictionary in Reshape.candidates(_s.hands[actor],_s.melds[actor],_s.night.reshape.used[actor]):
		if option.key==key:
			_commit_reshape(option);_s.revision+=1;return _reply(true,"")
	return _reply(false,"reshape_invalid")

func _commit_reshape(option:Dictionary)->void:
	var actor:int=_s.actor;var n:Dictionary=_s.night;var d:Dictionary=n.direction
	_remember_contracts(actor)
	for id:int in option.give:_s.hands[actor].erase(id)
	_s.hands[actor].append_array(option.take);_s.hands[actor].sort()
	_s.melds[actor][option.meld].tiles=option.after.duplicate()
	_s.melds[actor][option.meld].kind=option.kind
	_remember_contracts(actor)
	if _s.drawn_tile in option.give:_s.drawn_tile=option.take[option.give.find(_s.drawn_tile)]
	n.reshape.used[actor].append(option.meld)
	if n.self_used[actor]:n.reshape.followup[actor]=option.take.duplicate()
	for id:int in option.take:
		if id not in n.reshape.borrowed[actor]:n.reshape.borrowed[actor].append(id)
	var entry:Dictionary=option.duplicate(true);entry.actor=actor;entry.street=n.stage
	n.reshape.history.append(entry)
	d.trick_history.append({"id":"reshape","actor":actor,"street":n.stage,"tiles":option.give+option.take})
	d.inspiration[actor]-=1;d.trick_count[actor]+=1;d.trick_used[actor]=true
	_s.tea.locked=true
	d.last_notice="借形改组：旧组不再得分。可用借回的真牌追击亮一组；弃牌后追击消失。本明组已用过改组。"
	_s.table_event={"kind":"reshape","actor":actor,"tiles":option.give+option.take,"give":option.give.duplicate(),"take":option.take.duplicate(),"meld":option.meld}

func ai_reshape()->String:
	if not can_reshape():return ""
	var before:int=0
	for choice:Dictionary in choices():
		if choice.kind in ["tsumo","ron","closed_kong","kong","added_kong"]:return ""
		before=maxi(before,int(choice.get("preview",{}).get("total",0)))
	var ordinary:Array=continuation_options()
	if not ordinary.is_empty():before=maxi(before,ordinary[0].preview.total)
	var options:Array=reshape_options()
	if options.is_empty():return ""
	var best:Dictionary={};var gain:int=-1
	for option:Dictionary in options:
		# A cheap extra group must not sacrifice a completed wager on all old points.
		var projected:int=option.bank_after_chain
		var net:int=projected-option.bank_before if projected>=0 else option.score+option.bank_after-option.bank_before
		if net>gain:gain=net;best=option
	if best.is_empty():return ""
	# The alternative is a useful ordinary boost, not simply the unboosted score.
	if gain>=maxi(65,ceili(before*(1.0 if _s.night.self_used[_s.actor] else boost_factor(_s.actor)))+20):return best.key
	return ""

func _project_group_bank(option:Dictionary)->int:
	# Only a deterministic own-hand expose; never execute kong supplement draws.
	if option.get("kind","") not in ["self_chi","self_pon"]:return -1
	var simulated=get_script().new();simulated._s=_s.duplicate(true)
	for i in simulated.choices().size():
		var candidate:Dictionary=simulated.choices()[i]
		if candidate.kind==option.kind and candidate.get("tiles",[])==option.tiles:
			if simulated.apply(i,_s.actor,_s.revision).ok:return simulated.bank_total()
	return -1

func contract_progress(actor:int)->int:
	var contract:String=_s.night.contracts[actor];var count:int=0
	if contract=="suit":return -1 # Only certified by a legal winning layout.
	for meld:Dictionary in _s.melds[actor]:
		if (contract=="sequence" and meld.kind=="chi") or (contract=="triplet" and meld.kind in ["pon","kong"]):count+=1
	return count

func _remember_contracts(actor:int)->void:
	for contract:String in Catalog.CONTRACTS:
		if _contract_met(actor,contract) and contract not in _s.night.contract_seen[actor]:_s.night.contract_seen[actor].append(contract)

func presented_choices()->Array:
	if int(_s.revision)==_plan_revision:return _plan_cache.duplicate(true)
	var options:Array=choices()
	if _s.phase=="discard" and not _s.night.self_used[_s.actor]:
		for index in options.size():
			var option:Dictionary=options[index]
			if not option.kind.begins_with("self_"):continue
			var simulated=get_script().new();simulated._s=_s.duplicate(true)
			var reply:Dictionary=simulated.apply(index,_s.actor,_s.revision)
			if not reply.ok:continue
			var next:Array=simulated.reshape_options();var ordinary:Array=simulated.continuation_options()
			var second:int=0;var method:String="";var plan:Dictionary={}
			if not next.is_empty() and int(next[0].score)>0 and next[0].best.kind!="tsumo":second=next[0].score;method="reshape";plan=next[0].duplicate(true)
			if not ordinary.is_empty() and int(ordinary[0].preview.total)>second:second=ordinary[0].preview.total;method="continue";plan=ordinary[0].duplicate(true)
			if second<=0:continue
			option.chain={"total":int(option.preview.total)+second,"first":int(option.preview.total),"second":second,"method":method,"plan":plan}
			option.detail+=" 可接"+("借形" if method=="reshape" else "续奏")+"再得%d，合计%d；需1灵感和技艺额度。"%[second,option.chain.total]
	_plan_revision=int(_s.revision);_plan_cache=options.duplicate(true)
	return options

func ai_chain_choice()->int:
	if _s.phase!="discard" or _s.night.self_used[_s.actor]:return -1
	var options:Array=presented_choices();var alternative:int=0
	var can_boost:bool=_s.night.direction.inspiration[_s.actor]>0 and not _s.night.direction.trick_used[_s.actor] and not _s.night.direction.boost[_s.actor] and (technique(_s.actor)!="spotlight" or _s.night.wallets[_s.actor]>0)
	for option:Dictionary in options:
		if option.kind in ["tsumo","ron","closed_kong","kong","added_kong"]:return -1
		alternative=maxi(alternative,ceili(int(option.get("preview",{}).get("total",0))*(boost_factor(_s.actor) if can_boost else 1.0)))
	var chosen:int=-1;var points:int=alternative+10
	for i in options.size():
		if int(options[i].get("chain",{}).get("total",0))>points:chosen=i;points=options[i].chain.total
	return chosen

func can_continue_group()->bool:
	if _s.get("phase","")!="discard" or not _s.has("night"):return false
	var actor:int=_s.actor;var d:Dictionary=_s.night.direction
	return _s.night.self_used[actor] and _s.melds[actor].size()<4 and int(d.inspiration[actor])>0 and not d.trick_used[actor]

func _arm_continuation()->void:
	var actor:int=_s.actor;var d:Dictionary=_s.night.direction
	d.inspiration[actor]-=1;d.trick_count[actor]+=1;d.trick_used[actor]=true
	d.trick_history.append({"id":"continue","actor":actor,"street":_s.night.stage,"tiles":[]})
	_s.night.self_used[actor]=false

func continuation_options()->Array:
	if not can_continue_group():return []
	if _continuation_revision==int(_s.revision):return _continuation_cache.duplicate(true)
	var simulated=get_script().new();simulated._s=_s.duplicate(true);simulated._arm_continuation()
	var options:Array=[]
	for option:Dictionary in simulated.choices():
		if not option.kind.begins_with("self_"):continue
		option.continuation_key=option.kind+":"+str(option.tiles);options.append(option)
	options.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.preview.total>b.preview.total or (a.preview.total==b.preview.total and a.continuation_key<b.continuation_key))
	_continuation_revision=int(_s.revision);_continuation_cache=options.duplicate(true)
	return options

func continue_group(key:Variant,actor:Variant,revision:Variant)->Dictionary:
	if not _operation(actor,revision,["discard"]) or typeof(key)!=TYPE_STRING or not can_continue_group():return _reply(false,"continuation_unavailable")
	var options:Array=continuation_options()
	if not options.any(func(o:Dictionary)->bool:return o.continuation_key==key):return _reply(false,"continuation_invalid")
	var before:Dictionary=_s.duplicate(true);_arm_continuation()
	var choices_now:Array=choices()
	for index in choices_now.size():
		var choice:Dictionary=choices_now[index]
		if choice.kind+":"+str(choice.get("tiles",[]))!=key:continue
		var reply:Dictionary=apply(index,actor,revision)
		if not reply.ok:_s=before;return _reply(false,"continuation_invalid")
		var entry:Dictionary={"actor":actor,"tiles":choice.tiles.duplicate(),"total":_s.night.last_score.total,"street":_s.night.stage}
		_s.night.continuations.append(entry);_s.night.direction.trick_history.back().tiles=choice.tiles.duplicate()
		_s.table_event.continuation=true;_s.night.direction.last_notice="续奏再亮：花1灵感多亮一组，仍然使用真实手牌；本回合技艺已用。"
		_mark_two_chimes(actor,"continue")
		return _reply(true,"")
	_s=before;return _reply(false,"continuation_invalid")

func ai_continuation()->String:
	var options:Array=continuation_options()
	return options[0].continuation_key if not options.is_empty() and options[0].preview.total>=50 else ""

func _mark_two_chimes(actor:int,method:String)->void:
	# Presentation evidence references two actually paid events. Never add score.
	var n:Dictionary=_s.night;var current:Dictionary=n.events.back()
	for index in range(n.events.size()-2,-1,-1):
		var prior:Dictionary=n.events[index]
		if prior.actor!=actor:continue
		if prior.get("personal_turn",-1)!=current.personal_turn:break
		if not prior.get("self_formed",false):continue
		var pair:Dictionary={"method":method,"first":prior.total,"second":current.total,"total":prior.total+current.total,"first_event":prior.id,"second_event":current.id}
		current.two_chimes=pair;n.last_score.two_chimes=pair.duplicate(true);return
