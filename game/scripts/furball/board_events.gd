class_name FurBoardEvents
extends RefCounted

# Pure event offers and transactions; board runtime owns once-only commit.
const Supplies=preload("res://scripts/furball/team_supplies.gd")
const Routes=preload("res://scripts/furball/dice_routes.gd")
const TILES:=[4,7,9]
const TITLES:={4:"机会扭蛋 · 现金还是控路",7:"巡街收账 · 缴费还是追缴",9:"合作驿站 · 路线还是开场"}

static func options(tile:Variant,context:Variant)->Dictionary:
	var checked:=_validate(tile,context)
	if not checked.ok:return checked
	var offers:Array[Dictionary]=[]
	match int(tile):
		4:
			var amount:int=mini(6,999-int(context.cash))
			offers.append({"id":"cash","name":"现收现金 +%d" % amount,"available":amount>0,"reason":"钱袋已满，无收益" if amount==0 else "","cash_delta":amount,"nudges_delta":0,"pressure_add":0.0,"effects":[]})
			offers.append(_ticket(context))
		7:
			offers.append({"id":"pay_fee","name":"缴路费8金，正常营业","available":int(context.cash)>=8,"reason":"不足8金，不能部分缴费" if int(context.cash)<8 else "","cash_delta":-8,"nudges_delta":0,"pressure_add":0.0,"effects":[]})
			offers.append({"id":"take_collection","name":"保留钱袋，接追缴压力","available":true,"reason":"","cash_delta":0,"nudges_delta":0,"pressure_add":.25,"effects":[],"risk":"仅下一战刷新压力+25%；与挑战组合为1.75，不加敌血或扩实体上限。"})
		9:
			offers.append(_ticket(context))
			offers.append(_resources(context))
	return {"ok":true,"tile":tile,"title":TITLES[tile],"offers":offers,
		"auto_skip_allowed":not offers[0].available and not offers[1].available,
		"can_commit":context.authority and context.actor==context.active,
		"phase_contract":"事件二选一先兑现一次再进入business；不消耗本轮经营操作。"}

static func resolve(tile:Variant,choice:Variant,context:Variant)->Dictionary:
	var proposed:=options(tile,context)
	if not proposed.ok:return proposed
	if not context.authority:return _reject("not_authority","只有authority可提交事件")
	if context.actor!=context.active:return _reject("wrong_actor","只有本轮操骰者承诺事件")
	if not choice is int or choice not in [-1,0,1]:return _reject("bad_choice","二选一编号无效")
	if choice==-1:
		if not proposed.auto_skip_allowed:return _reject("skip_has_benefit","仍有有效选项，不能跳过事件")
		return _result(tile,"no_benefit_skip",context,0,0,0.0,[])
	var selected:Dictionary=proposed.offers[choice]
	if not selected.available:return _reject("unavailable",str(selected.reason))
	return _result(tile,selected.id,context,selected.cash_delta,selected.nudges_delta,selected.pressure_add,selected.effects)

static func battle_modifiers(event_pressure_add:Variant,challenge:Variant)->Dictionary:
	if not _finite(event_pressure_add) or float(event_pressure_add) not in [0.0,.25] or not challenge is bool:return _reject("bad_modifier","压力只能来自已承诺事件0/0.25与真实挑战布尔值")
	return {"ok":true,"spawn_multiplier":1.0+float(event_pressure_add)+(.5 if challenge else 0.0),
		"enemy_hp_multiplier":1.0,"scope":"仅下一场波次；既有实体/敌弹/警示预算保持不变。"}

static func _ticket(context:Dictionary)->Dictionary:
	var remaining:int=6-int(context.round)
	var reason:="最后一轮没有下一次骰路" if remaining==0 else ("余下%d次骰路，现有%d张券已够用"%[remaining,context.nudges] if context.nudges>=Routes.remaining_ticket_limit(context.round) else "")
	return {"id":"ticket","name":"拿路线券 +1","available":reason.is_empty(),"reason":reason,"cash_delta":0,"nudges_delta":1,"pressure_add":0.0,"effects":[]}

static func _resources(context:Dictionary)->Dictionary:
	var effects:Array[Dictionary]=[];var benefit:=0.0;var baits:int=context.projected_baits
	for index in context.entry_facts.size():
		var fact:Dictionary=context.entry_facts[index]
		var kind:String=["pot","charge","bait"][fact.style]
		var amount:=0.0;var before:float=0
		if kind=="pot":before=float(fact.pot);amount=minf(10,float(fact.pot_cap)-before) if not fact.down else 0.0
		elif kind=="charge":before=float(fact.charge);amount=minf(.5,2.5-before) if not fact.down else 0.0
		else:before=baits;amount=1.0 if not fact.down and baits<12 else 0.0;baits+=int(amount)
		effects.append({"player_index":index,"kind":kind,"eligible":not fact.down,"before":before,"amount":amount,"after":before+amount})
		benefit+=amount
	return {"id":"kit_support","name":"搭档开场资源援助","available":benefit>0,"reason":"存活角色资源全满或无人可受益" if benefit<=0 else "","cash_delta":0,"nudges_delta":0,"pressure_add":0.0,"effects":effects}

static func _result(tile:int,id:String,context:Dictionary,cash_delta:int,nudges_delta:int,pressure:float,effects:Array)->Dictionary:
	return {"ok":true,"tile":tile,"round":context.round,"actor":context.actor,"choice_id":id,"event_serial":context.event_serial,"seed":context.seed,
		"cash_after":int(context.cash)+cash_delta,"nudges_after":int(context.nudges)+nudges_delta,
		"event_resolved_after":true,"phase_after":"business","pending_effects":effects.duplicate(true),"event_pressure_add":pressure,
		"business_operation_done_after":false,"commit_rule":"只有一次authority事务可应用；重复提交依据当前phase/event_serial/event_resolved拒绝，不能重复发奖。"}

static func _validate(tile:Variant,context:Variant)->Dictionary:
	if not tile is int or tile not in TILES:return _reject("bad_tile","只有4/7/9格使用二选一原型")
	if not context is Dictionary or not context.has_all(["stage","position","event_resolved","business_operation_done","authority","actor","active","cash","round","nudges","seed","event_serial","entry_facts","projected_baits"]):return _reject("missing_facts","事件事实字段缺失")
	for key in ["position","actor","active","cash","round","nudges","seed","event_serial","projected_baits"]:
		if not context[key] is int:return _reject("bad_type",key+"必须是整数")
	for key in ["event_resolved","business_operation_done","authority"]:
		if not context[key] is bool:return _reject("bad_type",key+"必须是布尔值")
	if not context.stage is String:return _reject("bad_type","stage必须是字符串")
	if context.cash<0 or context.cash>999 or context.round<1 or context.round>6 or context.nudges<0 or context.nudges>3 or context.seed<0 or context.seed>2147483647 or context.event_serial<1 or context.event_serial>6 or context.projected_baits<0 or context.projected_baits>12:return _reject("bad_range","经营资源或事件回合超范围")
	if context.event_serial!=context.round:return _reject("wrong_serial","事件标识必须绑定当前回合，不能拿旧回合重放")
	if context.position!=tile:return _reject("wrong_tile","事件格必须是当前真实落点")
	if context.stage!="event_choice" or context.event_resolved or context.business_operation_done:return _reject("already_committed","事件未到阶段、已处理或经营已承诺")
	if not context.entry_facts is Array or context.entry_facts.is_empty() or context.entry_facts.size()>2:return _reject("bad_team","需要1..2名入场资源事实")
	if context.actor<0 or context.actor>=context.entry_facts.size() or context.active<0 or context.active>=context.entry_facts.size():return _reject("bad_actor","操骰角色编号无效")
	for fact in context.entry_facts:
		if not fact is Dictionary or not fact.has_all(["style","down","pot","pot_cap","charge"]):return _reject("bad_player","入场资源事实缺字段")
		if not fact.style is int or fact.style<0 or fact.style>2 or not fact.down is bool:return _reject("bad_player","流派/存活资格类型无效")
		for key in ["pot","pot_cap","charge"]:
			if not _finite(fact[key]):return _reject("bad_player","资源含非有限数值")
		if fact.pot_cap<=0 or fact.pot_cap>10000 or fact.pot<0 or fact.pot>fact.pot_cap or fact.charge<0 or fact.charge>2.5:return _reject("bad_player","资源超上限")
	return {"ok":true}

static func _finite(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _reject(code:String,reason:String)->Dictionary:return {"ok":false,"code":code,"reason":reason}

static func from_board(board:Dictionary,player_facts:Array,seed_value:int,actor:int,authority:bool=false)->Dictionary:
	var projection:=Supplies.project_entry(board,player_facts,false)
	if not projection.ok:return _reject("bad_projection",str(projection.get("reason","入场资源事实无效")))
	return {"stage":board.get("stage",""),"position":board.get("position",-1),"event_resolved":board.get("event_resolved",false),"business_operation_done":board.get("operation",false),"authority":authority,"actor":actor,"active":board.get("active",0),"cash":board.get("cash",0),"round":board.get("round",0),"nudges":board.get("nudges",0),"seed":seed_value,"event_serial":board.get("event_serial",0),"entry_facts":projection.entry_facts,"projected_baits":projection.projected_baits}
