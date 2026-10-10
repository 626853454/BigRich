class_name FurRouteSuggestion
extends RefCounted

# One authority-owned current flag; initial suggestion plus at most two revisions.
const MAX_REVISION:=3
const MIN_UPDATE_MS:=750
const Catalog=preload("res://scripts/furball/district_catalog.gd")
const Routes=preload("res://scripts/furball/dice_routes.gd")
const NAMES:=["开市补助","串串账台","街头抢单","奶茶执照","机会扭蛋","物流执照","串串分店","巡街收账","奶茶分店","合作驿站","物流分店","关门奖池"]
const DISTRICTS:=[0,0,1,2,2,1,0,0,2,2,1,1]

static func preview(context:Variant,adjustment:Variant)->Dictionary:
	var checked:=_context(context)
	if not checked.ok:return checked
	if context.players!=2:return _reject("solo_hidden","单人不显示队友建议")
	if context.stage!="move":return _reject("wrong_stage","仅选路时可以建议")
	if not adjustment is int or adjustment not in [-1,0,1]:return _reject("bad_adjustment","建议只允许倒车/原步/加一步")
	var projected:Dictionary=Routes.project(context.position,context.face,context.nudges,adjustment)
	if not projected.ok:return projected
	var path:Array[int]=[];path.assign(projected.path)
	var landing:int=path.back();var district:int=DISTRICTS[landing]
	var layout:Dictionary=Catalog.layout(district,context.round,context.seed+context.round*101)
	return {"ok":true,"adjustment":adjustment,"path":path,"landing":landing,"tile_name":NAMES[landing],"district_id":district,"variant_id":layout.variant_id,"variant_title":layout.variant_title,"requires_ticket":adjustment!=0,"round":context.round}

static func submit(context:Variant,request:Variant,current:Variant)->Dictionary:
	var checked:=_context(context)
	if not checked.ok:return checked
	if not context.authority:return _reject("not_authority","客户端只能请求，host验证后广播建议")
	if context.players!=2:return _reject("solo_hidden","单人不产生队友建议")
	if context.sender_actor==context.active:return _reject("active_cannot_suggest","当前操骰者直接选择路线，不能冒充队友建议")
	if not request is Dictionary or request.size()!=4 or not request.has_all(["run_token","round_token","adjustment","expected_revision"]):return _reject("bad_request","请求只包含局/轮令牌、步数调整、预期版本")
	for key in ["run_token","round_token","adjustment","expected_revision"]:
		if not request[key] is int:return _reject("bad_type",key+"必须为整数")
	if request.run_token!=context.run_token or request.round_token!=context.round:return _reject("stale_token","旧局或旧轮建议不能跨轮保留")
	var proposed:=preview(context,request.adjustment)
	if not proposed.ok:return proposed
	if not current is Dictionary:return _reject("bad_current","当前建议必须为字典")
	var revision:=0
	if not current.is_empty():
		if not _current(context,current):return _reject("bad_current","当前建议未通过host规范校验；新轮必须先清空")
		revision=current.revision
		if context.now_ms<current.last_update_ms:return _reject("clock_regression","host计时不能倒退")
	if request.expected_revision!=revision:return _reject("stale_revision","重复或乱序请求不能覆盖更新建议")
	if revision>=MAX_REVISION:return _reject("update_limit","本轮最多一面旗、首次加两次修改")
	if revision>0:
		if proposed.adjustment==current.adjustment:return _reject("same_suggestion","相同建议不重新播放、不消耗修改次数")
		if context.now_ms-current.last_update_ms<MIN_UPDATE_MS:return _reject("rate_limit","建议改动至少间隔750毫秒")
	var flag:Dictionary=proposed.duplicate(true);flag.erase("ok")
	flag.merge({"run_token":context.run_token,"round_token":context.round,"actor":context.sender_actor,"revision":revision+1,"last_update_ms":context.now_ms})
	return {"ok":true,"suggestion_after":flag,"commit_scope":"只更新一面建议旗；不掷骰、不花券、不扣钱、不替操骰者承诺。"}

static func presentation(context:Variant,current:Variant)->Dictionary:
	var checked:=_context(context)
	if not checked.ok:return {"visible":false,"reason":checked.reason}
	if context.players!=2 or context.stage!="move" or not current is Dictionary or current.is_empty() or not _current(context,current):return {"visible":false}
	var projected:Dictionary=Routes.project(context.position,context.face,context.nudges,current.adjustment)
	return {"visible":true,"actor":current.actor,"landing":current.landing,"path":current.path.duplicate(),"variant_title":current.variant_title,"ticket_cost":projected.ticket_cost,"direction":projected.direction,"steps":projected.steps,"label":"P%d建议%s → %02d %s · %s" % [current.actor+1,Routes.caption(current.adjustment),current.landing,current.tile_name,current.variant_title],"hint":"建议不扣券；P%d实际采用才扣相应券，无需队友确认。" % (context.active+1)}

static func _current(context:Dictionary,current:Dictionary)->bool:
	if current.size()!=14 or not current.has_all(["adjustment","path","landing","tile_name","district_id","variant_id","variant_title","requires_ticket","round","run_token","round_token","actor","revision","last_update_ms"]):return false
	# Fourteen fields: keep exact key count to reject unbounded packet decorations.
	return _current_fields(context,current)

static func _current_fields(context:Dictionary,current:Dictionary)->bool:
	for key in ["adjustment","landing","district_id","variant_id","round","run_token","round_token","actor","revision","last_update_ms"]:
		if not current[key] is int:return false
	if current.run_token!=context.run_token or current.round_token!=context.round or current.round!=context.round or current.actor!=1-context.active or current.revision<1 or current.revision>MAX_REVISION or current.last_update_ms<0 or current.last_update_ms>context.now_ms:return false
	var expected:=preview(context,current.adjustment)
	if not expected.ok:return false
	if not current.requires_ticket is bool or not current.tile_name is String or not current.variant_title is String or not current.path is Array or current.path.size()>7:return false
	for point in current.path:
		if not point is int:return false
	for key in ["adjustment","path","landing","tile_name","district_id","variant_id","variant_title","requires_ticket","round"]:
		if current[key]!=expected[key]:return false
	return true

static func _context(value:Variant)->Dictionary:
	if not value is Dictionary or not value.has_all(["stage","position","face","nudges","round","active","players","seed","run_token","sender_actor","authority","now_ms"]):return _reject("missing_context","host骰路事实缺字段")
	for key in ["position","face","nudges","round","active","players","seed","run_token","sender_actor","now_ms"]:
		if not value[key] is int:return _reject("bad_type",key+"必须为整数")
	if not value.stage is String or value.stage not in ["roll","move","event_choice","business","ready"] or not value.authority is bool:return _reject("bad_context","阶段或authority类型无效")
	if value.position<0 or value.position>11 or value.face<0 or value.face>6 or value.nudges<0 or value.nudges>3 or value.round<1 or value.round>6 or value.players<1 or value.players>2 or value.active<0 or value.active>=value.players or value.sender_actor<0 or value.sender_actor>=value.players or value.seed<0 or value.seed>2147483647 or value.run_token<1 or value.run_token>2147483647 or value.now_ms<0:return _reject("bad_context","骰路事实或角色编号越界")
	if value.stage=="move" and value.face<1:return _reject("bad_context","选路阶段必须已掷1..6点")
	return {"ok":true}

static func _reject(code:String,reason:String)->Dictionary:return {"ok":false,"code":code,"reason":reason}

static func context(board:Dictionary,seed_value:int,sender:int,now_ms:int,authority:bool=false)->Dictionary:
	return {"stage":board.get("stage",""),"position":board.get("position",0),"face":board.get("face",0),"nudges":board.get("nudges",0),"round":board.get("round",0),"active":board.get("active",0),"players":board.get("players",1),"seed":seed_value,"run_token":board.get("run_token",0),"sender_actor":sender,"authority":authority,"now_ms":now_ms}

static func valid_state(board:Dictionary,seed_value:int)->bool:
	var current:Variant=board.get("suggestion")
	if not current is Dictionary:return false
	if current.is_empty():return true
	if not current.get("last_update_ms") is int or current.last_update_ms<0 or current.last_update_ms>1000000000000000:return false
	# Host monotonic timestamps have no common epoch with the client clock.
	# Flags live until leaving move; do not invent a client-side time expiry.
	var state_context:=context(board,seed_value,1-int(board.get("active",0)),current.last_update_ms,false)
	return presentation(state_context,current).get("visible",false)

static func display(board:Dictionary,seed_value:int,sender:int)->Dictionary:
	var flag:Variant=board.get("suggestion",{})
	var host_time:int=flag.get("last_update_ms",0) if flag is Dictionary and flag.get("last_update_ms",0) is int else 0
	return presentation(context(board,seed_value,sender,host_time,false),flag)
