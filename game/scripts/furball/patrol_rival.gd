class_name FurPatrolRival
extends RefCounted

# One external board opponent. Pure authority lifecycle; no money/players/RNG writes.
const Catalog=preload("res://scripts/furball/district_catalog.gd")
const District=preload("res://scripts/furball/district_runtime.gd")
const TILE_DISTRICTS:=[0,0,1,2,2,1,0,0,2,2,1,1]
const KEYS:=["seed","run_token","id","position","settled_round","battle_wave","battle_district","objective_id","objective_sequence","repelled","battle_landing","phase","history"]
const HISTORY_KEYS:=["round","district_id","position_before","objective_id","objective_sequence","repelled","position_after"]
var state:Dictionary={}

static func initial_position(seed:int)->int:return posmod(seed^0x3073cd,12)
static func threat(position:int)->Array[int]:return [position,(position+1)%12]

func configure(seed:Variant,run_token:Variant)->Dictionary:
	if not _identity(seed,run_token):return _reject("bad_identity","巡街种子与局令牌须为正INT31整数")
	state={"seed":seed,"run_token":run_token,"id":0,"position":initial_position(seed),"settled_round":0,"battle_wave":0,"battle_district":-1,"objective_id":-1,"objective_sequence":0,"repelled":false,"battle_landing":-1,"phase":"board","history":[]}
	return {"ok":true}

func snapshot()->Dictionary:return state.duplicate(true)

func apply_state(value:Variant,expected_seed:int,expected_run_token:int)->bool:
	if not valid_state(value,expected_seed,expected_run_token):return false
	state=value.duplicate(true)
	return true

func preview(landing:Variant=-1)->Dictionary:return preview_state(state,landing)

static func preview_state(value:Variant,landing:Variant=-1)->Dictionary:
	if not value is Dictionary or not value.get("seed") is int or not value.get("run_token") is int or not valid_state(value,value.seed,value.run_token):return _reject("bad_state","巡街状态不完整")
	if not landing is int or landing<-1 or landing>11:return _reject("bad_landing","预览落点须为-1或0..11整数")
	var tiles:Array[int]=threat(value.position)
	var active:bool=value.phase!="closed" and landing in tiles
	return {"ok":true,"position":value.position,"threat_tiles":tiles,"pressure_active":active,"pressure_add":.25 if active else 0.0,"next_if_complete":(value.position+1)%12,"next_if_incomplete":(value.position+2)%12,"phase":value.phase}

static func combined_pressure(event_pressure:Variant,patrol_active:Variant,challenge:Variant)->Dictionary:
	if not _finite(event_pressure) or float(event_pressure) not in [0.0,.25] or not patrol_active is bool or not challenge is bool:return _reject("bad_pressure","已有追缴为0/.25，巡街与挑战须为bool")
	var pressure:float=maxf(float(event_pressure),.25 if patrol_active else 0.0)
	return {"ok":true,"pressure_add":pressure,"spawn_multiplier":1.0+pressure+(.5 if challenge else 0.0),"enemy_hp_multiplier":1.0}

func begin_battle(wave:Variant,district:Variant,landing:Variant,token:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有host启动巡街战斗状态")
	if state.is_empty() or state.phase!="board":return _reject("bad_phase","巡街本局已关闭或上一战未结束")
	if not wave is int or wave!=state.settled_round+1 or wave<1 or wave>6 or not district is int or district<0 or district>2 or not landing is int or landing<0 or landing>11 or not token is int or token!=state.run_token:return _reject("bad_battle","需要当前局的顺序回合/真实街区/落点")
	if TILE_DISTRICTS[landing]!=district:return _reject("wrong_district","巡街街区须对应真实棋盘落点")
	state.phase="battle";state.battle_wave=wave;state.battle_district=district;state.battle_landing=landing;state.objective_id=wave*3+district;state.objective_sequence=0;state.repelled=false
	var active:bool=landing in threat(state.position)
	return {"ok":true,"pressure_active":active,"pressure_add":.25 if active else 0.0,"objective_id":state.objective_id}

func on_district_complete(event:Variant,district_snapshot:Variant,token:Variant,objective_id:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","客机不能提交巡街击退")
	if state.is_empty() or state.phase!="battle" or state.repelled:return _reject("bad_phase","只接受本场唯一真实驱退回执")
	if not token is int or token!=state.run_token or not objective_id is int or objective_id!=state.objective_id:return _reject("stale_objective","局/回合目标ID过期")
	if not _completion(event,district_snapshot,state):return _reject("bad_completion","需要当前District的完整真实完成事实与末尾完成事件")
	state.repelled=true;state.objective_sequence=event.sequence
	return {"ok":true,"repelled":true,"events":[{"kind":"patrol_repelled","source":"patrol","id":0,"run_token":state.run_token,"wave":state.battle_wave,"objective_id":state.objective_id,"sequence":event.sequence,"point":event.point,"next_position":(state.position+1)%12}]}

func finish_battle(wave:Variant,outcome:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有host结算巡街推进")
	if state.is_empty() or state.phase!="battle" or not wave is int or wave!=state.battle_wave or not outcome is String or outcome not in ["completed","defeat","cancel"]:return _reject("bad_finish","巡街阶段/结束回合/结果不符")
	var before:int=state.position;var repelled:bool=state.repelled
	if outcome=="completed":
		state.position=(before+2-(1 if repelled else 0))%12
		state.history.append({"round":wave,"district_id":state.battle_district,"position_before":before,"objective_id":state.objective_id,"objective_sequence":state.objective_sequence,"repelled":repelled,"position_after":state.position})
		state.settled_round=wave;state.phase="closed" if wave==6 else "board"
	else:state.phase="closed"
	state.battle_wave=0;state.battle_district=-1;state.battle_landing=-1;state.objective_id=-1;state.objective_sequence=0;state.repelled=false
	return {"ok":true,"position_before":before,"position_after":state.position,"repelled":repelled,"phase":state.phase}

static func valid_state(value:Variant,expected_seed:int,expected_run_token:int)->bool:
	if not _identity(expected_seed,expected_run_token) or not _keys(value,KEYS):return false
	for key in ["seed","run_token","id","position","settled_round","battle_wave","battle_district","objective_id","objective_sequence","battle_landing"]:
		if not value[key] is int:return false
	if value.seed!=expected_seed or value.run_token!=expected_run_token or value.id!=0 or value.position<0 or value.position>11 or value.settled_round<0 or value.settled_round>6 or not value.repelled is bool or not value.phase is String or value.phase not in ["board","battle","closed"]:return false
	if not value.history is Array or value.history.size()!=value.settled_round or value.history.size()>6:return false
	var position:int=initial_position(expected_seed)
	for index in value.history.size():
		var item:Variant=value.history[index]
		if not _keys(item,HISTORY_KEYS):return false
		for key in ["round","district_id","position_before","objective_id","objective_sequence","position_after"]:
			if not item[key] is int:return false
		if not item.repelled is bool or item.round!=index+1 or item.district_id<0 or item.district_id>2 or item.position_before!=position or item.objective_id!=item.round*3+item.district_id or item.objective_sequence<0 or item.objective_sequence>2147483647 or item.repelled!=(item.objective_sequence>0):return false
		position=(position+2-(1 if item.repelled else 0))%12
		if item.position_after!=position:return false
	if value.position!=position:return false
	if value.phase=="battle":
		if value.settled_round>=6 or value.battle_wave!=value.settled_round+1 or value.battle_district<0 or value.battle_district>2 or value.battle_landing<0 or value.battle_landing>11 or TILE_DISTRICTS[value.battle_landing]!=value.battle_district or value.objective_id!=value.battle_wave*3+value.battle_district:return false
		return value.objective_sequence>=0 and value.objective_sequence<=2147483647 and value.repelled==(value.objective_sequence>0)
	if value.phase=="board" and value.settled_round>=6:return false
	return value.battle_wave==0 and value.battle_district==-1 and value.battle_landing==-1 and value.objective_id==-1 and value.objective_sequence==0 and not value.repelled

static func _completion(event:Variant,snapshot:Variant,run:Dictionary)->bool:
	if not event is Dictionary or not event.has_all(["kind","source","sequence","point"]) or not event.kind is String or event.kind!="district_complete" or not event.source is String or event.source!="district" or not event.sequence is int or event.sequence<1 or event.sequence>2147483647 or not event.point is Vector2 or not event.point.is_finite() or not Catalog.BOUNDS.has_point(event.point):return false
	if not snapshot is Dictionary:return false
	# Reuse District's bounded snapshot/geometry validation, then actual goal invariants.
	var district=District.new()
	if not district.apply_state(snapshot):return false
	var content:Dictionary=Catalog.entry(run.battle_district)
	if snapshot.district_id!=run.battle_district or snapshot.wave!=run.battle_wave or snapshot.seed!=run.seed+run.battle_wave*101 or not snapshot.completed or snapshot.event_serial!=event.sequence or snapshot.target!=content.target:return false
	if snapshot.name!=content.name+" · "+snapshot.variant_title or snapshot.goal!=content.goal+"（"+snapshot.variant_title+"）" or snapshot.cycle<0 or snapshot.missed<0 or snapshot.cash_paid<0:return false
	match int(run.battle_district):
		0:
			var count:=0
			for charge in snapshot.charges:
				if charge>1.0:return false
				if charge>=1.0:count+=1
			var index:int=snapshot.points.find(event.point)
			return count==2 and snapshot.activated==2 and snapshot.progress==2.0 and index>=0 and snapshot.charges[index]>=1.0 and snapshot.caught==0 and snapshot.cash_paid==16 and snapshot.event_serial==6 and snapshot.cycle==0 and snapshot.missed==0 and snapshot.packets.is_empty() and not snapshot.feast_ready and snapshot.feast_progress==0.0
		1:return event.point==Vector2.ZERO and snapshot.caught==3 and snapshot.progress==3.0 and snapshot.activated==0 and snapshot.charges==[0.0,0.0,0.0] and snapshot.cash_paid==19 and snapshot.event_serial>=11 and snapshot.cycle>=3+snapshot.missed and snapshot.packets.is_empty() and not snapshot.feast_ready and snapshot.feast_progress==0.0
		2:return event.point==snapshot.points[2] and snapshot.activated==2 and snapshot.progress==2.0 and snapshot.charges==[1.2,1.2,0.0] and snapshot.feast_ready and is_equal_approx(snapshot.feast_progress,.8) and snapshot.caught==0 and snapshot.cash_paid==10 and snapshot.event_serial==5 and snapshot.cycle==0 and snapshot.missed==0 and snapshot.packets.is_empty()
	return false

static func _identity(seed:Variant,token:Variant)->bool:return seed is int and token is int and seed>=1 and seed<=2147483647 and token>=1 and token<=2147483647
static func _keys(value:Variant,keys:Array)->bool:return value is Dictionary and value.size()==keys.size() and value.has_all(keys)
static func _finite(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _authority(value:Variant)->bool:return value is bool and value
static func _reject(code:String,reason:String)->Dictionary:return {"ok":false,"code":code,"reason":reason}
