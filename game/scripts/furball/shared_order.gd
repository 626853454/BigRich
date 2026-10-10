class_name FurSharedOrder
extends RefCounted

# Authority-owned pure lifecycle. No wallet/build/player writes and no game RNG.
const Catalog=preload("res://scripts/furball/district_catalog.gd")
const Paths=preload("res://scripts/furball/shared_order_paths.gd")
const Validator=preload("res://scripts/furball/shared_order_validator.gd")
const RECIPES:=[{"id":0,"title":"账单到货","mask":3},{"id":1,"title":"宵夜冷链","mask":6},{"id":2,"title":"奶摊赊账","mask":5}]
const MAX_EVENTS:=4
const ENTITLEMENT_RULE:="下一正常draft由正式BuildCatalog校验，每演员一次合法选择；不直接改build。"
var state:Dictionary={}

static func choices(seed:Variant)->Dictionary:
	if not seed is int or seed<1 or seed>2147483647:return _reject("bad_seed","订单种子必须为1..INT31整数")
	var first:int=posmod(int(seed)^0x3219ab,3)
	var second:int=(first+1+int(seed)%2)%3
	return {"ok":true,"offers":[RECIPES[first].duplicate(true),RECIPES[second].duplicate(true)]}

func configure(seed:Variant,players:Variant,run_token:Variant)->Dictionary:
	var options:=choices(seed)
	if not options.ok:return options
	if not players is int or players<1 or players>2 or not run_token is int or run_token<1 or run_token>2147483647:return _reject("bad_run","角色数或局令牌无效")
	state={"seed":seed,"players":players,"run_token":run_token,"offers":options.offers,"selected":-1,"required_mask":0,"collected_mask":0,"receipts":[],"fulfilled":false,"fulfilled_wave":0,"entitlement":{},"attempts":0,"cargo_serial":0,"event_serial":0,"last_wave":0,"run_closed":false,"battle":{},"cargo":{}}
	return {"ok":true}

func snapshot()->Dictionary:return state.duplicate(true)

static func valid_state(value:Variant,expected_seed:int,expected_players:int,expected_run_token:int)->bool:
	return Validator.valid_state(value,expected_seed,expected_players,expected_run_token)

func apply_state(value:Variant,expected_seed:int,expected_players:int,expected_run_token:int)->bool:
	if not valid_state(value,expected_seed,expected_players,expected_run_token):return false
	state=value.duplicate(true)
	return true

func select(index:Variant,context:Variant)->Dictionary:
	if state.is_empty():return _reject("not_configured","订单未配置")
	if not context is Dictionary or context.size()!=6 or not context.has_all(["stage","round","actor","active","authority","run_token"]):return _reject("bad_context","选单上下文缺失")
	for key in ["round","actor","active","run_token"]:
		if not context[key] is int:return _reject("bad_type","选单角色/回合/局令牌须为整数")
	if not context.authority is bool or not context.stage is String or not index is int or index not in [0,1]:return _reject("bad_type","选单阶段/authority/候选类型无效")
	if not context.authority or context.actor!=0 or context.active!=0:return _reject("wrong_authority","首次host操骰者选单；actor必须绑定transport")
	if context.run_token!=state.run_token or context.round!=1 or context.stage!="order_select" or state.selected!=-1 or state.last_wave!=0 or state.run_closed:return _reject("already_selected","只在第一骰前选单一次")
	state.selected=state.offers[index].id;state.required_mask=state.offers[index].mask
	return {"ok":true,"recipe":state.offers[index].duplicate(true),"business_operation_consumed":false}

func begin_battle(district:Variant,wave:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有host推动订单生命周期")
	if state.is_empty() or state.run_closed or not state.battle.is_empty():return _reject("bad_phase","本局关闭或上场尚未结束")
	if not wave is int or wave<1 or wave>6 or wave!=state.last_wave+1 or not district is int or district<0 or district>2:return _reject("bad_battle","需要顺序1..6的真实街区")
	var geometry:Dictionary=Catalog.layout(district,wave,state.seed+wave*101)
	state.last_wave=wave;state.battle={"wave":wave,"district_id":district,"seed":state.seed+wave*101,"elapsed":0.0,"points":geometry.points,"obstacles":geometry.obstacles,"routes":geometry.logistics_routes,"variant_id":geometry.variant_id,"variant_title":geometry.variant_title}
	state.cargo={}
	if state.selected>=0 and state.collected_mask==state.required_mask and not state.fulfilled:
		var origin:Vector2=state.battle.points[0] if district==0 else (state.battle.routes[0].from.lerp(state.battle.routes[0].to,.5) if district==1 else state.battle.points[2])
		_spawn_cargo(origin,[])
	return {"ok":true,"retry":not state.cargo.is_empty(),"cargo":state.cargo.duplicate(true)}

func on_district_complete(event:Variant,district:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有真实model委托事件能收货")
	if state.is_empty() or state.run_closed or state.battle.is_empty() or state.selected<0:return _reject("not_selected","未选单或不在真实战斗中，不能收货")
	if not event is Dictionary or not event.has_all(["kind","source","sequence","point"]) or not event.kind is String or event.kind!="district_complete" or event.source!="district" or not event.sequence is int or event.sequence<1 or event.sequence>2147483647 or not _point(event.point):return _reject("bad_event","仅接受真实district_complete/source/有限point/序号")
	if not _district_fact(district):return _reject("bad_district_fact","委托未完成或几何/回合与当前真实战斗不符")
	if (state.battle.district_id==0 and event.point not in district.points) or (state.battle.district_id==2 and event.point!=district.points[2]) or (state.battle.district_id==1 and event.point!=Vector2.ZERO):return _reject("bad_event_point","出箱只使用实际委托完成锚点")
	for receipt in state.receipts:
		if receipt.wave==state.battle.wave:return _reject("duplicate_receipt","每轮委托只收货一次")
	var bit:int=1<<int(state.battle.district_id)
	var received:bool=(state.required_mask&bit)!=0 and (state.collected_mask&bit)==0
	state.receipts.append({"wave":state.battle.wave,"district_id":state.battle.district_id,"sequence":event.sequence,"received":received})
	if received:state.collected_mask|=bit
	if received and state.collected_mask==state.required_mask and state.cargo.is_empty() and not state.fulfilled:_spawn_cargo(event.point,district.charges)
	return {"ok":true,"received":received,"collected_mask":state.collected_mask,"cargo_ready":not state.cargo.is_empty()}

func tick(delta:Variant,players:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","客机不模拟搬箱结果")
	if state.is_empty() or state.run_closed or state.battle.is_empty():return _reject("bad_phase","搬箱仅在战斗内推进")
	if not _finite(delta) or float(delta)<=0:return _reject("bad_delta","delta须为有限正数")
	if not _players(players):return _reject("bad_players","需要有限、场内、严格down状态的当前角色事实")
	var next_elapsed:float=float(state.battle.elapsed)+minf(.1,float(delta))
	if not is_finite(next_elapsed):return _reject("bad_clock","搬箱时钟溢出，不能改变当前状态")
	state.battle.elapsed=next_elapsed
	var events:Array[Dictionary]=[]
	if state.cargo.is_empty() or state.fulfilled:return {"ok":true,"events":events}
	var cargo:Dictionary=state.cargo
	if cargo.phase=="carrying":
		cargo.point=players[cargo.carrier].pos
		if players[cargo.carrier].down:_drop("down",players,events)
	if cargo.phase=="carrying":
		# At most one node per physics tick; the second cannot be reached out of order.
		var target:Vector2=cargo.nodes[cargo.checkpoint]
		if cargo.point.distance_squared_to(target)<=1.44:
			cargo.checkpoint+=1;_emit(events,"order_checkpoint",cargo.carrier)
			if cargo.checkpoint==2:_fulfill(events)
	return {"ok":true,"events":events}

# Explicit actor commitment, host only. Players are read-only facts.
func pickup(actor:Variant,choice:Variant,players:Variant,expected_revision:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","客机不能自行提交发货结果")
	if state.is_empty() or state.run_closed or state.battle.is_empty() or state.fulfilled or state.cargo.is_empty():return _reject("bad_phase","仅本场未兑现的落地货箱可拾取")
	if not actor is int or actor<0 or actor>=state.players or not choice is int or choice not in [0,1] or not expected_revision is int or not _players(players):return _reject("bad_pickup","角色/线路/版本/当前角色事实无效")
	var cargo:Dictionary=state.cargo
	if cargo.phase!="ground" or expected_revision!=cargo.pickup_revision or cargo.pickup_revision>=256:return _reject("stale_pickup","货箱已被接走或拾取版本过期")
	if players[actor].down or players[actor].pos.distance_squared_to(cargo.point)>1.44 or state.battle.elapsed<float(cargo.regrab_until[actor]):return _reject("not_near","须存活、近箱1.2米且自己的掉箱冷却已结束")
	if cargo.route_choice>=0 and choice!=0:return _reject("route_locked","已选线路本场锁定；E只恢复原线路")
	if cargo.route_choice<0:
		var nodes:Array[Vector2]=canonical_nodes(state.battle,cargo.origin,cargo.source_charges,state.seed,choice)
		if nodes.size()!=2:return _reject("no_route","当前布局没有合法发货线路")
		cargo.route_choice=choice;cargo.nodes=nodes
	cargo.pickup_revision+=1;cargo.carrier=actor;cargo.phase="carrying";cargo.point=players[actor].pos
	var events:Array[Dictionary]=[];_emit(events,"order_pickup",actor)
	return {"ok":true,"events":events,"route_choice":cargo.route_choice,"pickup_revision":cargo.pickup_revision}

func on_dash(actor:Variant,executed:Variant,players:Variant,authority:Variant=true)->Dictionary:
	return _interaction_drop(actor,executed,1.0,"dash",players,authority)

func on_damage(actor:Variant,accepted:Variant,actual_damage:Variant,players:Variant,authority:Variant=true)->Dictionary:
	return _interaction_drop(actor,accepted,actual_damage,"damage",players,authority)

func end_battle(wave:Variant,outcome:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有host结束战斗")
	if state.is_empty() or state.battle.is_empty() or not wave is int or wave!=state.battle.wave or not outcome is String or outcome not in ["completed","defeat","cancel"]:return _reject("bad_end","战斗回合或结束类型无效")
	var retry:bool=not state.fulfilled and state.collected_mask==state.required_mask and state.selected>=0
	state.cargo={};state.battle={}
	if outcome!="completed" or wave==6:state.run_closed=true
	return {"ok":true,"retry_next_wave":retry and not state.run_closed,"fulfilled":state.fulfilled}

func claim_entitlement(wave:Variant,stage:Variant,authority:Variant=true)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有host给正常draft队列资格")
	if state.is_empty() or state.run_closed or not state.battle.is_empty() or not wave is int or not stage is String or stage!="draft" or state.entitlement.is_empty() or wave!=state.entitlement.delivery_wave or state.last_wave!=wave or state.entitlement.claimed:return _reject("no_entitlement","仅交付后下一正常draft可领取一次；第六站无本局改装")
	state.entitlement.claimed=true
	return {"ok":true,"entitlement":state.entitlement.duplicate(true)}

func _interaction_drop(actor:Variant,confirmed:Variant,amount:Variant,reason:String,players:Variant,authority:Variant)->Dictionary:
	if not _authority(authority):return _reject("not_authority","只有host已执行的dash/实际伤害会掉箱")
	if state.is_empty() or state.run_closed or state.battle.is_empty() or not actor is int or actor<0 or actor>=state.players or not confirmed is bool or not _finite(amount) or float(amount)<0 or not _players(players):return _reject("bad_interaction","掉箱角色/真实执行资格/伤害/位置无效")
	var events:Array[Dictionary]=[]
	if confirmed and float(amount)>0 and not state.cargo.is_empty() and state.cargo.phase=="carrying" and state.cargo.carrier==actor:_drop(reason,players,events)
	return {"ok":true,"events":events}

func _spawn_cargo(origin:Vector2,charges:Array)->void:
	if state.attempts>=6:return
	state.attempts+=1;state.cargo_serial+=1
	var nodes:Array[Vector2]=[]
	var cooldowns:Array[float]=[]
	for actor in state.players:cooldowns.append(0.0)
	state.cargo={"id":state.cargo_serial,"phase":"ground","point":origin,"origin":origin,"source_charges":charges.duplicate(),"spawn_kind":"completion" if not charges.is_empty() else "retry","carrier":-1,"last_carrier":-1,"regrab_until":cooldowns,"checkpoint":0,"nodes":nodes,"route_choice":-1,"pickup_revision":0}

static func canonical_nodes(battle:Dictionary,origin:Vector2,charges:Array,seed:int,choice:int=0)->Array[Vector2]:
	var result:Dictionary=Paths.options(battle,origin,charges,seed)
	var nodes:Array[Vector2]=[]
	if choice in [0,1]:nodes.assign(result.direct if choice==0 else result.outer)
	return nodes

func _drop(reason:String,players:Array,events:Array[Dictionary])->void:
	var actor:int=state.cargo.carrier
	state.cargo.point=players[actor].pos;state.cargo.last_carrier=actor;state.cargo.carrier=-1;state.cargo.phase="ground";state.cargo.regrab_until[actor]=state.battle.elapsed+1.0
	_emit(events,"order_drop_"+reason,actor)

func _fulfill(events:Array[Dictionary])->void:
	if state.fulfilled:return
	state.fulfilled=true;state.fulfilled_wave=state.battle.wave;state.cargo.phase="delivered";state.cargo.carrier=-1
	if state.battle.wave<=5:
		var actors:Array[int]=[]
		for index in state.players:actors.append(index)
		state.entitlement={"kind":"extra_legal_draft_choice","delivery_wave":state.battle.wave,"actors":actors,"choices_per_actor":1,"claimed":false,"apply_rule":ENTITLEMENT_RULE}
	_emit(events,"order_fulfilled",-1)

func _emit(events:Array[Dictionary],kind:String,actor:int)->void:
	if events.size()>=MAX_EVENTS:return
	state.event_serial+=1;events.append({"kind":kind,"actor":actor,"wave":state.battle.wave,"sequence":state.event_serial,"point":state.cargo.point})

func _district_fact(value:Variant)->bool:
	if not value is Dictionary or not value.has_all(["district_id","wave","seed","completed","points","obstacles","charges","caught","feast_ready","feast_progress"]):return false
	for key in ["district_id","wave","seed"]:
		if not value[key] is int:return false
	if not value.completed is bool or not value.completed or value.district_id!=state.battle.district_id or value.wave!=state.battle.wave or value.seed!=state.battle.seed:return false
	if not value.points is Array or value.points.size()!=3 or not value.obstacles is Array or value.obstacles.size()>2 or not value.charges is Array or value.charges.size()!=3:return false
	for point in value.points:
		if not _point(point):return false
	for charge in value.charges:
		if not _finite(charge) or float(charge)<0 or float(charge)>1.2:return false
	match int(value.district_id):
		0:
			var completed:=0
			for charge in value.charges:
				if float(charge)>=1.0:completed+=1
			if completed<2:return false
		1:
			if not value.caught is int or value.caught!=3:return false
		2:
			if not value.feast_ready is bool or not value.feast_ready or not _finite(value.feast_progress) or not is_equal_approx(float(value.feast_progress),.8) or float(value.charges[0])<1.2 or float(value.charges[1])<1.2:return false
	return value.points==state.battle.points and value.obstacles==state.battle.obstacles

func _players(value:Variant)->bool:
	if not value is Array or value.size()!=state.players:return false
	for player in value:
		if not player is Dictionary or not player.has_all(["pos","down"]) or not player.down is bool or not _point(player.pos):return false
		for obstacle in state.battle.obstacles:
			if obstacle.has_point(player.pos):return false
	return true

static func _point(value:Variant)->bool:return value is Vector2 and value.is_finite() and Catalog.BOUNDS.has_point(value)
static func _finite(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _authority(value:Variant)->bool:return value is bool and value
static func _reject(code:String,reason:String)->Dictionary:return {"ok":false,"code":code,"reason":reason}
