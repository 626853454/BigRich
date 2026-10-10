class_name FurChallengeContract
extends RefCounted

const Catalog=preload("res://scripts/furball/district_catalog.gd")
const Patrol=preload("res://scripts/furball/patrol_rival.gd")
const CURRENT_VERSION:=2
const RULE_VERSION:=CURRENT_VERSION
const LEGACY_VERSION:=1
const ARM_CUTOFF:=11.0
const ARM_LEAD:=.75
const MAX_STEP:=.05
const CLOCK_EPSILON:=.000001
const MAX_CLOCK:=2147483647.0
const District=preload("res://scripts/furball/district_runtime.gd")
const WINDOW:=8.0
const STATE_KEYS:=["rule_version","seed","run_token","wave","district","accepted","phase","group_serial","group","killed_records","spawn_at","deadline","objective_sequence","clear_at","settled","outcome","reason","arm_source","arm_sequence","arm_at","battle_started_at"]
const RESULT_KEYS:=["rule_version","seed","run_token","wave","accepted","available","group_serial","group_size","killed_count","spawn_at","clear_at","objective_sequence","objective_complete","battle_completed","clear_in_time","qualified","bonus","receipt_id","reason"]
const RESULT_REASONS:=["qualified","objective_incomplete","timeout","identity_lost","group_unavailable","no_group","defeat","cancel"]
var state:Dictionary={}
var _last_now:float=-1.0

func configure(seed:Variant,token:Variant,wave:Variant,district:Variant,accepted:Variant,battle_started_at:Variant=0.0) -> bool:
	if not _identity(seed,token) or not _int(wave,0,6) or not _int(district,-1,2) or not accepted is bool:return false
	if (wave==0 and (district!=-1 or accepted or battle_started_at!=0)) or (wave>0 and district<0) or not _clock(battle_started_at):return false
	state={"rule_version":RULE_VERSION,"seed":seed,"run_token":token,"wave":wave,"district":district,"accepted":accepted,
		"phase":"waiting" if accepted else "inactive","group_serial":0,"group":[],"killed_records":[],"spawn_at":-1.0,"deadline":-1.0,"objective_sequence":0,"clear_at":-1.0,"settled":false,"outcome":"","reason":"waiting" if accepted else "not_accepted","arm_source":"","arm_sequence":0,"arm_at":-1.0,"battle_started_at":float(battle_started_at)}
	_last_now=float(battle_started_at)
	return true

func snapshot() -> Dictionary:return state.duplicate(true)

func apply_state(value:Variant,seed:int,token:int,wave:int,district:int,now:float=-1.0) -> bool:
	if not valid_state(value,seed,token,wave,district,now):return false
	state=value.duplicate(true);_last_now=maxf(float(state.battle_started_at),maxf(float(state.arm_at),float(state.spawn_at)))
	for record in state.killed_records:_last_now=maxf(_last_now,float(record.time))
	if now>=0:_last_now=maxf(_last_now,now)
	return true

func bind_group(serial:Variant,chapter:Variant,now:Variant,entities:Variant,token:Variant,wave:Variant,authority:Variant=true) -> Dictionary:
	if not _context(now,token,wave,authority) or not _int(serial,1,2147483647) or not chapter is String or not _entities(entities):return _reject("invalid_group")
	if not state.accepted or state.phase!="waiting":return _reject("already_bound")
	if chapter!="pressure":return {"ok":true,"bound":false,"reason":"non_pressure"}
	if state.arm_source=="":return {"ok":true,"bound":false,"reason":"unarmed"}
	var local_time:float=float(now)-float(state.battle_started_at)
	if local_time<6 or local_time>=15:return {"ok":true,"bound":false,"reason":"outside_pressure"}
	if float(now)<float(state.arm_at)+ARM_LEAD:return {"ok":true,"bound":false,"reason":"arming_lead"}
	_last_now=float(now);state.group_serial=serial;state.spawn_at=float(now);state.deadline=float(now)+WINDOW
	if entities.size()<2:
		state.phase="failed";state.reason="group_unavailable"
		return {"ok":true,"bound":false,"reason":"group_unavailable"}
	state.group=entities.duplicate(true);state.group.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.identity<b.identity)
	state.phase="marked";state.reason="marked"
	return {"ok":true,"bound":true,"reason":"marked"}

func on_killed(slot:Variant,identity:Variant,actor:Variant,now:Variant,token:Variant,wave:Variant,serial:Variant,authority:Variant=true) -> Dictionary:
	if not _context(now,token,wave,authority) or not _int(slot,0,255) or not identity is int or identity<1 or not _int(actor,0,1) or not serial is int or serial!=state.group_serial:return _reject("invalid_kill")
	if not state.accepted or state.group.size()<2 or state.phase not in ["marked","failed"]:return _reject("inactive_kill")
	if state.reason=="identity_lost":return _reject("identity_lost")
	var matched:=false
	for entity in state.group:
		if entity.identity==identity and entity.slot==slot:matched=true;break
	if not matched or _killed(state,identity) or float(now)<float(state.spawn_at):return _reject("stale_kill")
	_last_now=float(now)
	state.killed_records.append({"identity":identity,"actor":actor,"time":float(now)})
	state.killed_records.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.time<b.time or (a.time==b.time and a.identity<b.identity))
	if state.killed_records.size()==state.group.size():
		state.clear_at=float(state.killed_records.back().time)
		if state.reason!="identity_lost" and float(state.clear_at)<=float(state.deadline):state.phase="cleared";state.reason="cleared"
		elif state.reason!="identity_lost":state.phase="failed";state.reason="timeout"
	return {"ok":true,"cleared":state.phase=="cleared"}

func on_district_complete(event:Variant,district_snapshot:Variant,token:Variant,wave:Variant,authority:Variant=true) -> Dictionary:
	if state.is_empty() or not authority is bool or not authority or not token is int or token!=state.run_token or not wave is int or wave!=state.wave or state.settled or not state.accepted or state.objective_sequence>0:return _reject("invalid_objective")
	var context:Dictionary={"seed":state.seed,"battle_wave":state.wave,"battle_district":state.district}
	if not Patrol._completion(event,district_snapshot,context):return _reject("invalid_objective")
	state.objective_sequence=event.sequence
	return {"ok":true,"objective_complete":true}

func tick(now:Variant,observed_entities:Variant,phase:Variant,token:Variant,wave:Variant,authority:Variant=true) -> Dictionary:
	if not _context(now,token,wave,authority) or not phase is String or phase.length()>24 or not _observations(observed_entities,state.group):return _reject("invalid_tick")
	_last_now=float(now)
	if phase!="battle":
		state.phase="closed";state.settled=true;state.outcome="cancel";state.reason="cancel" if state.accepted else "not_accepted"
		return {"ok":true,"reason":"cancel"}
	if state.phase not in ["marked","failed"]:return {"ok":true,"reason":state.reason}
	for entity in state.group:
		if _killed(state,entity.identity):continue
		for observation in observed_entities:
			if observation.slot==entity.slot and (not observation.active or observation.identity!=entity.identity):state.phase="failed";state.reason="identity_lost"
	if state.phase=="marked" and float(now)>float(state.deadline):state.phase="failed";state.reason="timeout"
	return {"ok":true,"reason":state.reason}

func finish(wave:Variant,outcome:Variant,token:Variant,authority:Variant=true) -> Dictionary:
	if state.is_empty() or not authority is bool or not authority or not wave is int or wave!=state.wave or wave<1 or not token is int or token!=state.run_token or state.settled or not outcome is String or outcome not in ["completed","defeat","cancel"]:return _reject("invalid_finish")
	state.settled=true;state.outcome=outcome;state.phase="closed"
	if not state.accepted:state.reason="not_accepted";return {"ok":true,"result":{}}
	var result:=_result(state)
	state.reason=result.reason
	return {"ok":true,"result":result}

static func valid_state(value:Variant,seed:Variant,token:Variant,wave:Variant,district:Variant,now:Variant=-1.0) -> bool:
	if not _identity(seed,token) or not _int(wave,0,6) or not _int(district,-1,2) or not _number(now) or float(now)<-1 or not _keys(value,STATE_KEYS):return false
	for key in ["rule_version","seed","run_token","wave","district","group_serial","objective_sequence"]:
		if not value[key] is int:return false
	if value.rule_version!=RULE_VERSION or value.seed!=seed or value.run_token!=token or value.wave!=wave or value.district!=district or not value.accepted is bool or not value.settled is bool:return false
	if (wave==0 and (district!=-1 or value.accepted)) or (wave>0 and district<0):return false
	if not value.phase is String or value.phase not in ["inactive","waiting","marked","cleared","failed","closed"] or not value.outcome is String or not value.reason is String or not _int(value.group_serial,0,2147483647) or not _int(value.objective_sequence,0,2147483647):return false
	if not _valid_arm(value,now):return false
	for key in ["spawn_at","deadline","clear_at"]:
		if not _number(value[key]) or float(value[key])< -1:return false
	if not _entities(value.group) or not value.killed_records is Array or value.killed_records.size()>value.group.size():return false
	var previous_id:=0
	for entity in value.group:
		if entity.identity<=previous_id:return false
		previous_id=entity.identity
	var previous_time:float=-1;var previous_kill_id:=0;var seen:Dictionary={}
	for record in value.killed_records:
		if not _keys(record,["identity","actor","time"]) or not record.identity is int or record.identity<1 or seen.has(record.identity) or not _int(record.actor,0,1) or not _number(record.time) or float(record.time)<float(value.spawn_at):return false
		var found:=false
		for entity in value.group:
			if entity.identity==record.identity:found=true
		if not found or float(record.time)<previous_time or (float(record.time)==previous_time and record.identity<=previous_kill_id):return false
		seen[record.identity]=true;previous_time=float(record.time);previous_kill_id=record.identity
		if float(now)>=0 and float(record.time)>float(now):return false
	if value.group_serial==0:
		if not value.group.is_empty() or not value.killed_records.is_empty() or value.spawn_at!=-1 or value.deadline!=-1 or value.clear_at!=-1:return false
	else:
		if value.spawn_at<0 or value.deadline!=float(value.spawn_at)+WINDOW or value.group.size()==1:return false
		if value.arm_source=="" or float(value.spawn_at)<float(value.arm_at)+ARM_LEAD or float(value.spawn_at)<float(value.battle_started_at)+6 or float(value.spawn_at)>=float(value.battle_started_at)+15:return false
		if float(now)>=0 and value.spawn_at>float(now):return false
	var all_killed:bool=value.group.size()>=2 and value.group.size()==value.killed_records.size()
	if value.reason=="identity_lost" and all_killed:return false
	if value.clear_at!=(float(value.killed_records.back().time) if all_killed else -1.0):return false
	if not value.accepted:
		return value.group_serial==0 and value.objective_sequence==0 and value.reason=="not_accepted" and ((value.phase=="inactive" and not value.settled and value.outcome=="") or (value.phase=="closed" and value.settled and value.outcome in ["completed","defeat","cancel"]))
	if value.settled:
		if value.phase!="closed" or value.outcome not in ["completed","defeat","cancel"]:return false
		return value.reason==_result(value).reason
	if value.outcome!="":return false
	match value.phase:
		"waiting":return value.group_serial==0 and value.reason==("waiting" if value.arm_source=="" else "armed")
		"marked":return value.group.size()>=2 and not all_killed and value.reason=="marked" and (float(now)<0 or float(now)<=float(value.deadline))
		"cleared":return all_killed and value.clear_at<=value.deadline and value.reason=="cleared"
		"failed":
			if value.reason=="group_unavailable":return value.group_serial>0 and value.group.is_empty() and value.killed_records.is_empty()
			if value.reason=="identity_lost":return value.group.size()>=2 and not all_killed
			return value.reason=="timeout" and value.group.size()>=2 and (not all_killed or value.clear_at>value.deadline) and (float(now)<0 or float(now)>float(value.deadline))
	return false

static func valid_result(value:Variant,seed:Variant,token:Variant,wave:Variant,accepted:Variant,objective:Variant,battle_completed:Variant) -> bool:
	return _valid_result_version(value,seed,token,wave,accepted,objective,battle_completed,CURRENT_VERSION)

static func valid_history_result(value:Variant,seed:Variant,token:Variant,wave:Variant,accepted:Variant,objective:Variant,battle_completed:Variant) -> bool:
	if not value is Dictionary:return false
	if value.is_empty():return _valid_result_version(value,seed,token,wave,accepted,objective,battle_completed,CURRENT_VERSION)
	if not value.get("rule_version") is int or value.rule_version not in [LEGACY_VERSION,CURRENT_VERSION]:return false
	return _valid_result_version(value,seed,token,wave,accepted,objective,battle_completed,int(value.rule_version))

static func _valid_result_version(value:Variant,seed:Variant,token:Variant,wave:Variant,accepted:Variant,objective:Variant,battle_completed:Variant,version:int) -> bool:
	if not _identity(seed,token) or not _int(wave,1,6) or not accepted is bool or not objective is bool or not battle_completed is bool or not value is Dictionary:return false
	if value.is_empty():return not accepted
	if not accepted or not _keys(value,RESULT_KEYS):return false
	for key in ["rule_version","seed","run_token","wave","group_serial","group_size","killed_count","objective_sequence","bonus"]:
		if not value[key] is int:return false
	for key in ["accepted","available","objective_complete","battle_completed","clear_in_time","qualified"]:
		if not value[key] is bool:return false
	if value.rule_version!=version or value.seed!=seed or value.run_token!=token or value.wave!=wave or not value.accepted or value.objective_complete!=objective or value.battle_completed!=battle_completed:return false
	if not _int(value.group_serial,0,2147483647) or not _int(value.group_size,0,5) or value.group_size==1 or not _int(value.killed_count,0,value.group_size) or not _int(value.objective_sequence,0,2147483647) or not _number(value.spawn_at) or not _number(value.clear_at) or value.spawn_at< -1 or value.clear_at< -1:return false
	if value.objective_complete!=(value.objective_sequence>0) or value.available!=(value.group_size>=2):return false
	if value.group_serial==0:
		if value.group_size!=0 or value.spawn_at!=-1 or value.clear_at!=-1:return false
	elif value.spawn_at<0:return false
	var all_killed:bool=value.available and value.killed_count==value.group_size
	if (not all_killed and value.clear_at!=-1) or (all_killed and value.clear_at<value.spawn_at):return false
	var clear_in_time:bool=all_killed and value.clear_at<=float(value.spawn_at)+WINDOW
	if value.clear_in_time!=clear_in_time or not value.reason is String or value.reason not in RESULT_REASONS:return false
	var qualified:bool=value.battle_completed and value.objective_complete and clear_in_time and value.reason!="identity_lost"
	if value.qualified!=qualified or value.bonus!=(8 if qualified else 0) or not value.receipt_id is String or value.receipt_id!=_receipt(token,wave,value.group_serial,version):return false
	if not value.battle_completed:return value.reason in ["defeat","cancel"] and not value.qualified
	if not value.available:return value.reason==("no_group" if value.group_serial==0 else "group_unavailable")
	if value.reason=="identity_lost":return not value.qualified and not all_killed
	return value.reason==("timeout" if not clear_in_time else ("objective_incomplete" if not objective else "qualified"))

static func _result(value:Dictionary) -> Dictionary:
	var available:bool=value.group.size()>=2
	var clear_in_time:bool=available and value.killed_records.size()==value.group.size() and value.clear_at>=value.spawn_at and value.clear_at<=value.deadline
	var completed:bool=value.outcome=="completed"
	var objective:bool=value.objective_sequence>0
	var reason:String=value.outcome if not completed else ("no_group" if value.group_serial==0 else ("group_unavailable" if not available else ("identity_lost" if value.reason=="identity_lost" else ("timeout" if not clear_in_time else ("objective_incomplete" if not objective else "qualified")))))
	var qualified:bool=completed and available and clear_in_time and objective and reason!="identity_lost"
	return {"rule_version":RULE_VERSION,"seed":value.seed,"run_token":value.run_token,"wave":value.wave,"accepted":true,"available":available,"group_serial":value.group_serial,"group_size":value.group.size(),"killed_count":value.killed_records.size(),"spawn_at":value.spawn_at,"clear_at":value.clear_at,"objective_sequence":value.objective_sequence,"objective_complete":objective,"battle_completed":completed,"clear_in_time":clear_in_time,"qualified":qualified,"bonus":8 if qualified else 0,"receipt_id":_receipt(value.run_token,value.wave,value.group_serial),"reason":reason}

func _context(now:Variant,token:Variant,wave:Variant,authority:Variant) -> bool:
	return not state.is_empty() and not state.settled and authority is bool and authority and token is int and token==state.run_token and wave is int and wave==state.wave and wave>0 and _clock(now) and float(now)>=float(state.battle_started_at) and float(now)>=_last_now

static func _entities(value:Variant) -> bool:
	if not value is Array or value.size()>5:return false
	var ids:Dictionary={};var slots:Dictionary={}
	for entity in value:
		if not _keys(entity,["identity","slot","kind","pos"]) or not entity.identity is int or entity.identity<1 or ids.has(entity.identity) or not _int(entity.slot,0,255) or slots.has(entity.slot) or not entity.kind is int or entity.kind not in [0,1,3,4] or not entity.pos is Vector2 or not entity.pos.is_finite() or not Catalog.BOUNDS.has_point(entity.pos):return false
		ids[entity.identity]=true;slots[entity.slot]=true
	return true

static func _observations(value:Variant,entities:Array) -> bool:
	if not value is Array or value.size()!=entities.size():return false
	var slots:Dictionary={}
	for observation in value:
		if not _keys(observation,["slot","identity","active"]) or not _int(observation.slot,0,255) or slots.has(observation.slot) or not observation.identity is int or observation.identity<0 or not observation.active is bool:return false
		var found:=false
		for entity in entities:
			if entity.slot==observation.slot:found=true
		if not found:return false
		slots[observation.slot]=true
	return true

static func _killed(value:Dictionary,identity:int) -> bool:
	for record in value.killed_records:
		if record.identity==identity:return true
	return false
static func _receipt(token:int,wave:int,serial:int,version:int=CURRENT_VERSION)->String:return "v%d:%d:%d:%d" % [version,token,wave,serial]
static func _keys(value:Variant,keys:Array)->bool:return value is Dictionary and value.size()==keys.size() and value.has_all(keys)
static func _identity(seed:Variant,token:Variant)->bool:return _int(seed,1,2147483647) and _int(token,1,2147483647)
static func _int(value:Variant,minimum:int,maximum:int)->bool:return value is int and value>=minimum and value<=maximum
static func _number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason}


func observe_milestone(event:Variant,district_snapshot:Variant,now:Variant,token:Variant,wave:Variant,authority:Variant=true,previous_district_snapshot:Variant=null)->Dictionary:
	if not _context(now,token,wave,authority) or not state.accepted or state.phase!="waiting":return _reject("invalid_milestone_context")
	if state.arm_source!="":return _arm_result(false,"already_armed")
	if float(now)>float(state.battle_started_at)+ARM_CUTOFF:return _reject("milestone_after_cutoff")
	if not _first_milestone(event,district_snapshot,previous_district_snapshot,state,float(now)):return _reject("invalid_milestone")
	_last_now=float(now);state.arm_source="milestone";state.arm_sequence=int(event.sequence);state.arm_at=float(now);state.reason="armed"
	return _arm_result(true,"armed")

func tick_arm(now:Variant,phase:Variant,token:Variant,wave:Variant,authority:Variant=true)->Dictionary:
	if not _context(now,token,wave,authority) or not phase is String:return _reject("invalid_arm_tick")
	if phase!="battle" or not state.accepted or state.phase!="waiting" or state.arm_source!="":return _arm_result(false,"not_pending")
	var local_time:float=float(now)-float(state.battle_started_at)
	if local_time<ARM_CUTOFF:_last_now=float(now);return _arm_result(false,"waiting")
	if local_time>ARM_CUTOFF+MAX_STEP+CLOCK_EPSILON:return _reject("late_cutoff")
	_last_now=float(now);state.arm_source="cutoff";state.arm_sequence=0;state.arm_at=float(now);state.reason="armed"
	return _arm_result(true,"armed")

func _arm_result(armed_now:bool,reason:String)->Dictionary:
	return {"ok":true,"armed_now":armed_now,"arm_source":state.arm_source,"arm_at":state.arm_at,"reason":reason}

static func _clock(value:Variant)->bool:return _number(value) and float(value)>=0 and float(value)<=MAX_CLOCK

static func _valid_arm(value:Dictionary,now:Variant)->bool:
	if not _clock(value.battle_started_at) or not value.arm_source is String or value.arm_source not in ["","milestone","cutoff"] or not _int(value.arm_sequence,0,2147483647) or not _number(value.arm_at) or float(value.arm_at)>MAX_CLOCK:return false
	if value.wave==0 and value.battle_started_at!=0:return false
	if float(now)>=0 and float(value.battle_started_at)>float(now):return false
	if value.arm_source=="":return value.arm_sequence==0 and value.arm_at==-1.0 and value.group_serial==0 and value.objective_sequence==0
	if not value.accepted or value.wave==0 or float(value.arm_at)<float(value.battle_started_at):return false
	if float(now)>=0 and float(value.arm_at)>float(now):return false
	var local_time:float=float(value.arm_at)-float(value.battle_started_at)
	if value.arm_source=="cutoff":return value.arm_sequence==0 and local_time>=ARM_CUTOFF and local_time<=ARM_CUTOFF+MAX_STEP+CLOCK_EPSILON
	if local_time>ARM_CUTOFF or value.arm_sequence<1:return false
	return value.arm_sequence==1 if value.district in [0,2] else value.arm_sequence>=2

static func _canonical_district(snapshot:Variant,value:Dictionary)->bool:
	if not snapshot is Dictionary:return false
	var runtime:=District.new()
	if not runtime.apply_state(snapshot):return false
	if snapshot.district_id!=value.district or snapshot.wave!=value.wave or snapshot.seed!=value.seed+value.wave*101:return false
	var content:Dictionary=Catalog.entry(value.district)
	if snapshot.name!=content.name+" · "+snapshot.variant_title or snapshot.goal!=content.goal+"（"+snapshot.variant_title+"）" or snapshot.target!=content.target:return false
	for key in ["activated","cycle","caught","missed","cash_paid","event_serial"]:
		if not _int(snapshot[key],0,2147483647):return false
	if not _clock(snapshot.elapsed):return false
	match int(value.district):
		0:
			var count:=0
			for charge in snapshot.charges:
				if charge>1:return false
				if charge>=1:count+=1
			return count<=2 and snapshot.activated==count and snapshot.progress==float(count) and snapshot.completed==(count==2) and snapshot.cash_paid==([0,3,16][count]) and snapshot.event_serial==([0,2,6][count]) and snapshot.caught==0 and snapshot.cycle==0 and snapshot.missed==0 and snapshot.packets.is_empty() and not snapshot.feast_ready and snapshot.feast_progress==0
		1:
			return snapshot.caught<=3 and snapshot.progress==float(snapshot.caught) and snapshot.completed==(snapshot.caught==3) and snapshot.cash_paid==snapshot.caught*3+(10 if snapshot.completed else 0) and snapshot.activated==0 and snapshot.charges==[0.0,0.0,0.0] and not snapshot.feast_ready and snapshot.feast_progress==0 and snapshot.cycle>=snapshot.caught+snapshot.missed
		2:
			var count:=0
			for index in 2:
				if snapshot.charges[index]>=1.2:count+=1
			return snapshot.activated==count and snapshot.progress==float(count) and snapshot.charges[2]==0 and snapshot.feast_ready==(count==2) and snapshot.completed==(snapshot.feast_progress==.8) and (not snapshot.completed or snapshot.feast_ready) and snapshot.cash_paid==(10 if snapshot.completed else 0) and snapshot.event_serial==(5 if snapshot.completed else (3 if count==2 else count)) and snapshot.caught==0 and snapshot.cycle==0 and snapshot.missed==0 and snapshot.packets.is_empty()
	return false

static func valid_district_context(value:Variant,snapshot:Variant)->bool:
	if not _keys(value,STATE_KEYS) or not valid_state(value,value.seed,value.run_token,value.wave,value.district):return false
	if value.wave==0:return value.arm_source==""
	if not _canonical_district(snapshot,value):return false
	if value.objective_sequence>0 and (not snapshot.completed or snapshot.event_serial!=value.objective_sequence):return false
	if value.arm_source!="milestone":return true
	if value.arm_sequence>snapshot.event_serial:return false
	if value.district==1:return snapshot.caught>=1 and snapshot.cash_paid>=3
	return snapshot.activated>=1

static func _first_milestone(event:Variant,snapshot:Variant,previous:Variant,value:Dictionary,now:float)->bool:
	if not _keys(event,["kind","point","pos","value","owner","cash","xp","health","source","sequence"]) or not event.kind is String or event.source!="district" or not _int(event.sequence,1,2147483647) or not _int(event.owner,0,1):return false
	if not event.point is Vector2 or not event.point.is_finite() or event.pos!=event.point or event.value!=1 or event.cash!=0 or event.xp!=0 or event.health!=0:return false
	if not _canonical_district(snapshot,value) or event.sequence>snapshot.event_serial or absf(float(snapshot.elapsed)-(now-float(value.battle_started_at)))>CLOCK_EPSILON:return false
	if value.district in [0,2]:
		if event.kind!="district_checkpoint" or event.sequence!=1:return false
		var index:int=snapshot.points.find(event.point)
		if index<0 or (value.district==2 and index>1):return false
		return snapshot.charges[index]>=(1.0 if value.district==0 else 1.2)
	if event.kind!="district_parcel" or snapshot.caught not in [1,2,3] or not _canonical_district(previous,value) or previous.caught!=0 or event.sequence<=previous.event_serial:return false
	var dt:float=float(snapshot.elapsed)-float(previous.elapsed)
	if dt<=0 or dt>.1+CLOCK_EPSILON:return false
	for packet in previous.packets:
		if packet.id>previous.cycle or packet.lane!=posmod(packet.id-1+int(snapshot.seed),3) or packet.direction!=(1 if posmod(packet.id-1+int(snapshot.seed),2)==0 else -1):continue
		var travel:float=float(packet.age)+dt-.8
		if travel+CLOCK_EPSILON<.6:continue
		var route:Dictionary=snapshot.logistics_routes[packet.lane]
		var origin:Vector2=route.from if packet.direction>0 else route.to
		var end:Vector2=route.to if packet.direction>0 else route.from
		var expected:Vector2=origin+(end-origin).normalized()*3.8*maxf(0,travel-.6)
		if expected.distance_squared_to(event.point)>.000001:continue
		var remains:=false
		for current in snapshot.packets:
			if current.id==packet.id:remains=true;break
		if not remains:return true
	return false
