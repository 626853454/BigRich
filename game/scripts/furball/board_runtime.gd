class_name FurBoardRuntime
extends RefCounted

# Shared cart: one authority RNG, twelve persistent spaces, six alternating turns.
const NAMES := ["开市补助","串串账台","街头抢单","奶茶执照","机会扭蛋","物流执照","串串分店","巡街收账","奶茶分店","合作驿站","物流分店","关门奖池"]
const DISTRICTS := [0,0,1,2,2,1,0,0,2,2,1,1]
const PROPERTY := {1:0,3:2,5:1,6:0,8:2,10:1}
const PURCHASE_PRICE:=22
const UPGRADE_PRICE:=18
const DELIVERY_FEE:=6
const Supplies=preload("res://scripts/furball/team_supplies.gd")
const Events=preload("res://scripts/furball/board_events.gd")
const Suggestions=preload("res://scripts/furball/route_suggestion.gd")
const Challenge=preload("res://scripts/furball/challenge_contract.gd")
const Routes=preload("res://scripts/furball/dice_routes.gd")
static var _run_counter:int=int(Time.get_unix_time_from_system()*1000)%2147480000
var run_seed:=1
var rng := RandomNumberGenerator.new()
var state: Dictionary = {}

func start(seed_value:int, count:int,provided_run_token:int=0) -> void:
	run_seed=clampi(seed_value,0,2147483647)
	_run_counter=(_run_counter%2147483647)+1
	var token:int=provided_run_token if provided_run_token>0 and provided_run_token<=2147483647 else _run_counter
	rng.seed=seed_value ^ 0x19640abc
	state={"position":0,"cash":60,"round":1,"active":0,"players":clampi(count,1,2),"stage":"roll","face":0,"steps":0,"path":[],"licenses":[0,0,0],"nudges":2,"income":0,"history":[],"message":"先掷骰，预览落点后决定是否使用步数券。","challenge":false,"operation":false,"settled":false,"event_serial":0,"event_resolved":false,"event_choice_id":"","event_pressure_add":0.0,"event_resources":[]}
	state.run_token=token;state.suggestion={}

func begin_round(round_number:int) -> void:
	state.round=round_number;state.active=(round_number-1)%int(state.players)
	state.stage="roll";state.face=0;state.steps=0;state.path=[];state.challenge=false;state.operation=false;state.settled=false
	state.event_serial=0;state.event_resolved=false;state.event_choice_id="";state.event_pressure_add=0.0;state.event_resources=[]
	state.suggestion={}
	state.message="P%d 操骰 · 共享钱袋 %d" % [int(state.active)+1,int(state.cash)]

func roll(forced_face:int=0) -> bool:
	if state.get("stage","")!="roll" or forced_face<0 or forced_face>6:return false
	state.face=forced_face if forced_face>0 else rng.randi_range(1,6)
	state.suggestion={}
	state.stage="move";state.message="骰子 %d：倒车按骰点花2券，原步数不花券，正向加一步花1券。" % int(state.face)
	return true

func preview(adjustment:int=0) -> Array:
	var projected:Dictionary=preview_details(adjustment)
	return projected.path.duplicate() if projected.ok else []

func preview_details(adjustment:int=0) -> Dictionary:
	if state.get("stage","")!="move":return {"ok":false,"code":"wrong_stage","reason":"仅掷骰后可以预览骰路","path":[]}
	return Routes.project(state.get("position"),state.get("face"),state.get("nudges"),adjustment)

func move(adjustment:int) -> bool:
	var projected:Dictionary=preview_details(adjustment)
	if not projected.ok:return false
	var path:Array=projected.path.duplicate()
	state.nudges-=int(projected.ticket_cost)
	state.suggestion={}
	state.steps=path.size();state.path=path;state.position=path.back()
	if projected.cross_subsidy>0:state.cash+=int(projected.cross_subsidy);state.message="正向经过开市：补助 +12。"
	else:state.message="落在 %s。" % NAMES[int(state.position)]
	if projected.direction==-1:state.message="倒车花2券；"+str(state.message)+(" 倒车经过开市不领绕圈补助。" if path.has(0) else "")
	match int(state.position):
		0:state.cash+=4;state.message+=" 起点营业 +4。"
		11:state.cash+=10;state.message+=" 关门奖池 +10。"
	state.cash=clampi(int(state.cash),0,999)
	if int(state.position) in Events.TILES:
		state.stage="event_choice";state.event_serial=int(state.round);state.event_resolved=false
		state.message+=" 请先选事件，再进行本轮经营。"
	else:state.stage="business";state.event_resolved=true
	return true

func suggest(request:Dictionary,seed_value:int,actor:int,now_ms:int,authority:bool=true)->Dictionary:
	var context:Dictionary=Suggestions.context(state,seed_value,actor,now_ms,authority)
	var result:Dictionary=Suggestions.submit(context,request,state.get("suggestion",{}))
	if result.ok:state.suggestion=result.suggestion_after.duplicate(true)
	return result

func resolve_event(choice:int,player_facts:Array,seed_value:int,event_serial:int,actor:int,authority:bool=true)->Dictionary:
	if choice not in [0,1,2]:return {"ok":false,"reason":"事件选择必须为0/1/2"}
	if event_serial<1 or event_serial!=int(state.get("event_serial",0)) or event_serial!=int(state.get("round",0)):return {"ok":false,"reason":"事件回合令牌失效"}
	var context:=Events.from_board(state,player_facts,seed_value,actor,authority)
	if not context.has("stage"):return context
	var transaction:=Events.resolve(int(state.position),-1 if choice==2 else choice,context)
	if not transaction.ok:return transaction
	state.cash=transaction.cash_after;state.nudges=transaction.nudges_after
	state.event_resolved=true;state.event_choice_id=transaction.choice_id;state.event_pressure_add=transaction.event_pressure_add
	state.event_resources=transaction.pending_effects.duplicate(true);state.stage="business"
	state.message+=" 事件已选择：%s；本轮经营机会保留。" % {"cash":"现收现金","ticket":"路线券","pay_fee":"缴路费","take_collection":"接追缴","kit_support":"免费资源","no_benefit_skip":"无收益继续"}.get(transaction.choice_id,"")
	return transaction

func property_district() -> int:
	return int(PROPERTY.get(int(state.get("position",0)),-1))

func price() -> int:
	return investment_price(property_district())

func investment_price(district:int) -> int:
	if district<0 or district>2 or state.is_empty():return -1
	var level:int=state.licenses[district]
	if level>=2:return -1
	return (PURCHASE_PRICE if level==0 else UPGRADE_PRICE)+(0 if property_district()==district else DELIVERY_FEE)

func invest(district:int) -> bool:
	if state.get("stage","")!="business" or state.get("operation",false):return false
	var cost:=investment_price(district)
	if cost<0 or int(state.cash)<cost:return false
	var delivery:int=0 if property_district()==district else DELIVERY_FEE
	state.cash-=cost;state.licenses[district]+=1;state.operation=true
	state.message+=" %s%s执照升至 %d 级，花费 %d%s；所有后续营业分红 +2。" % ["本地" if delivery==0 else "异地",["串串","物流","奶茶"][district],int(state.licenses[district]),cost,"（含运费6）" if delivery else ""]
	_commit_turn(0,district,delivery)
	return true

func business(choice:int) -> bool:
	if state.get("stage","")!="business" or state.get("operation",false) or choice<0 or choice>2:return false
	if choice==0:
		return invest(property_district())
	elif choice==1:state.challenge=true;state.message+=" 接抢档挑战：限时清标记群 + 完整委托 + 存活闭站，才额外 +8；本场刷新压力保持。"
	else:state.message+=" 留钱准备下一轮。"
	_commit_turn(choice)
	return true

func purchase_supply(id:String,player_facts:Array)->Dictionary:
	var offer:Dictionary=Supplies.offer(state,player_facts,id)
	if not offer.ok:return offer
	state.cash=offer.cash_after;state.operation=true
	if id=="route_ticket":state.nudges+=1
	state.message+=" %s -%d 金；本轮经营已锁定。" % [offer.name,int(offer.price)]
	_commit_turn(3+Supplies.IDS.find(id),-1,0,id)
	return offer

func _commit_turn(choice:int,investment_district:int=-1,delivery:int=0,supply_id:String="") -> void:
	state.stage="ready";state.operation=true
	state.history.append({"round":state.round,"face":state.face,"steps":state.steps,"path":state.path.duplicate(),"position":state.position,"choice":choice,"cash":state.cash,"licenses":state.licenses.duplicate(),"investment_district":investment_district,"delivery":delivery,"supply_id":supply_id,"event_choice_id":state.event_choice_id,"event_pressure_add":state.event_pressure_add})
	if state.history.size()>6:state.history.pop_front()

func district_id() -> int:return int(DISTRICTS[int(state.get("position",0))])

func finish_battle(objective_complete:bool,challenge_result:Dictionary={}) -> int:
	if state.get("settled",false):return 0
	if state.get("stage","")!="ready" or not state.get("operation",false) or state.get("history",[]).is_empty():return 0
	var turn:Dictionary=state.history.back()
	if turn.round!=state.round or (turn.choice==1)!=bool(state.challenge):return 0
	if not Challenge.valid_result(challenge_result,run_seed,int(state.run_token),int(state.round),bool(state.challenge),objective_complete,true):return 0
	state.settled=true
	var dividend:int=0
	for level in state.licenses:dividend+=int(level)*2
	var earned:int=10+dividend+(8 if challenge_result.get("qualified",false) else 0)+(4+int(state.licenses[district_id()])*2 if objective_complete else 0)
	state.cash=mini(999,int(state.cash)+earned);state.income=earned
	return earned

func snapshot() -> Dictionary:return state.duplicate(true)

func apply_state(value:Dictionary,seed_value:int=-1) -> bool:
	if not value.has_all(["position","cash","round","active","players","stage","face","steps","path","licenses","nudges","income","history","message","challenge","operation","settled"]):return false
	for key in ["position","cash","round","active","players","face","steps","nudges","income"]:
		if not value[key] is int:return false
	if value.position<0 or value.position>11 or value.cash<0 or value.cash>999 or value.round<1 or value.round>6:return false
	if value.players not in [1,2] or value.active<0 or value.active>=value.players:return false
	if not value.get("run_token") is int or value.run_token<1 or value.run_token>2147483647:return false
	if not Suggestions.valid_state(value,run_seed if seed_value<0 else seed_value):return false
	if value.face<0 or value.face>6 or value.steps<0 or value.steps>7 or value.nudges<0 or value.nudges>3 or value.income<0 or value.income>999:return false
	if not value.stage is String or value.stage not in ["roll","move","event_choice","business","ready"] or not value.message is String or value.message.length()>500:return false
	if not value.has_all(["event_serial","event_resolved","event_choice_id","event_pressure_add","event_resources"]):return false
	if not value.event_serial is int or value.event_serial<0 or value.event_serial>6 or not value.event_resolved is bool:return false
	if not value.event_choice_id is String or value.event_choice_id not in ["","cash","ticket","pay_fee","take_collection","kit_support","no_benefit_skip"]:return false
	if not (value.event_pressure_add is int or value.event_pressure_add is float) or not is_finite(float(value.event_pressure_add)) or float(value.event_pressure_add) not in [0.0,.25]:return false
	if not Supplies.valid_event_resources(value.event_resources,value.players):return false
	if (value.event_pressure_add==.25)!=(value.event_choice_id=="take_collection"):return false
	if not value.event_resources.is_empty() and value.event_choice_id!="kit_support":return false
	if value.event_serial>0 and value.event_serial!=value.round:return false
	if value.event_serial==0 and (value.event_choice_id!="" or value.event_pressure_add!=0 or not value.event_resources.is_empty()):return false
	if value.event_serial>0:
		if value.position not in Events.TILES:return false
		var legal_ids:Array={4:["cash","ticket","no_benefit_skip"],7:["pay_fee","take_collection"],9:["ticket","kit_support","no_benefit_skip"]}[value.position]
		if value.event_resolved and value.event_choice_id not in legal_ids:return false
		if not value.event_resolved and (value.event_choice_id!="" or value.event_pressure_add!=0 or not value.event_resources.is_empty()):return false
		if value.stage in ["business","ready"] and not value.event_resolved:return false
	if value.stage=="event_choice" and (value.position not in Events.TILES or value.event_serial!=value.round or value.event_resolved or value.operation):return false
	for key in ["challenge","operation","settled"]:
		if not value[key] is bool:return false
	if not value.licenses is Array or value.licenses.size()!=3:return false
	for level in value.licenses:
		if not level is int or level<0 or level>2:return false
	if not value.path is Array or value.path.size()>7:return false
	for point in value.path:
		if not point is int or point<0 or point>11:return false
	if value.steps==0:
		if not value.path.is_empty():return false
	elif not Routes.valid_path(value.face,value.steps,value.path,value.position):return false
	if not value.history is Array or value.history.size()>6:return false
	for turn in value.history:
		if not turn is Dictionary or not turn.has_all(["round","face","steps","path","position","choice","cash","licenses"]):return false
		if not turn.path is Array or turn.path.size()>7 or not turn.licenses is Array or turn.licenses.size()!=3:return false
		for key in ["round","face","steps","position","choice","cash"]:
			if not turn[key] is int:return false
		if turn.round<1 or turn.round>6 or turn.face<1 or turn.face>6 or turn.steps<1 or turn.steps>7 or turn.position<0 or turn.position>11 or turn.choice<0 or turn.choice>5 or turn.cash<0 or turn.cash>999:return false
		if turn.has("supply_id") and (not turn.supply_id is String or turn.supply_id not in ["","milk","resources","route_ticket"]):return false
		if turn.choice>=3 and (turn.get("supply_id","")!=Supplies.IDS[turn.choice-3]):return false
		if turn.choice<3 and turn.get("supply_id","")!="":return false
		if turn.has("event_choice_id") and (not turn.event_choice_id is String or turn.event_choice_id not in ["","cash","ticket","pay_fee","take_collection","kit_support","no_benefit_skip"]):return false
		if turn.has("event_pressure_add") and (not (turn.event_pressure_add is int or turn.event_pressure_add is float) or not is_finite(float(turn.event_pressure_add)) or float(turn.event_pressure_add) not in [0.0,.25]):return false
		if (float(turn.get("event_pressure_add",0))==.25)!=(turn.get("event_choice_id","")=="take_collection"):return false
		if not Routes.valid_path(turn.face,turn.steps,turn.path,turn.position):return false
		for point in turn.path:
			if not point is int or point<0 or point>11:return false
		for level in turn.licenses:
			if not level is int or level<0 or level>2:return false
	state=value.duplicate(true);return true
