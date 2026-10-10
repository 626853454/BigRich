class_name FurTeamSupplies
extends RefCounted

# Pure authority/UI quote shared by both. No input writes, reward application or RNG.
const IDS:=["milk","resources","route_ticket"]
const NAMES:=["续航奶","开锅资源包","路线券"]
const PRICES:=[12,10,14]
const CHARGE_CAP:=2.5
const BAIT_CAP:=12
const Routes=preload("res://scripts/furball/dice_routes.gd")

static func quote(id:Variant)->Dictionary:
	if not id is String or id not in IDS:return {"ok":false,"reason":"补给编号无效","effects":[]}
	var index:=IDS.find(id)
	return {"ok":true,"id":id,"name":NAMES[index],"price":PRICES[index],"effects":[],"reason":"",
		"description":["购买时存活队友各回复最多20生命；满血无收益，奶不复活。","入场地产补给之后，购买时存活队友再获锅能20 / 蓄能1 / 诱饵1，实际收益按上限裁剪。","共享步数券+1，倒车花2券，加一步花1券；最多3张，现有券够余下骰路时不出售。"][index]}

static func facts(players:Array)->Array:
	var result:Array=[]
	for player in players:
		if not player is Dictionary or not player.get("build") is Dictionary:return []
		var build:Dictionary=player.build
		result.append({"hp":maxf(0,float(player.get("hp",0))),"max_hp":build.get("health",0),"down":player.get("down"),"style":build.get("style"),"pot":player.get("pot",0),"pot_cap":build.get("pot_cap",50),"charge":player.get("charge",0)})
	return result

static func offer(board:Dictionary,player_facts:Array,id:Variant)->Dictionary:
	var result:=quote(id)
	if not result.ok:return result
	if not board.has_all(["cash","stage","operation","nudges","round","position","licenses"]):return _reject(result,"棋盘报价字段缺失")
	for key in ["cash","nudges","round","position"]:
		if not board[key] is int:return _reject(result,"棋盘报价类型无效")
	if board.cash<0 or board.cash>999 or board.nudges<0 or board.nudges>3 or board.round<1 or board.round>6 or board.position<0 or board.position>11:return _reject(result,"棋盘报价范围无效")
	if not board.stage is String or not board.operation is bool:return _reject(result,"本轮经营记录无效")
	if not board.licenses is Array or board.licenses.size()!=3:return _reject(result,"执照记录无效")
	for level in board.licenses:
		if not level is int or level<0 or level>2:return _reject(result,"执照等级无效")
	if player_facts.is_empty() or player_facts.size()>2:return _reject(result,"需1–2名完整玩家事实")
	for fact in player_facts:
		if not fact is Dictionary or not fact.has_all(["hp","max_hp","down","style","pot","pot_cap","charge"]):return _reject(result,"玩家报价字段缺失")
		if not fact.down is bool or not fact.style is int or fact.style<0 or fact.style>2:return _reject(result,"玩家报价类型无效")
		for key in ["hp","max_hp","pot","pot_cap","charge"]:
			if not _finite(fact[key]):return _reject(result,"玩家报价含无效资源数值")
		if fact.max_hp<=0 or fact.max_hp>10000 or fact.hp<0 or fact.hp>fact.max_hp or fact.pot_cap<=0 or fact.pot_cap>10000 or fact.pot<0 or fact.pot>fact.pot_cap or fact.charge<0 or fact.charge>CHARGE_CAP:return _reject(result,"玩家报价资源超出上限")
	var projection:=project_entry(board,player_facts,true)
	if not projection.ok:return _reject(result,str(projection.reason))
	var projected_baits:int=projection.projected_baits
	var benefit:=0.0
	if id=="route_ticket":
		var amount:int=1 if int(board.nudges)<Routes.remaining_ticket_limit(board.round) else 0
		result.effects.append({"player_index":-1,"kind":"nudges","eligible":true,"before":board.nudges,"amount":amount,"after":board.nudges+amount})
		benefit=amount
	else:
		for index in player_facts.size():
			var fact:Dictionary=player_facts[index]
			var eligible:bool=not fact.down
			var kind:String="heal" if id=="milk" else ["pot","charge","bait"][fact.style]
			var before:float=float(fact.hp)
			var amount:=0.0
			if kind=="heal":amount=minf(20,float(fact.max_hp)-before) if eligible else 0.0
			elif kind=="pot":
				before=float(projection.entry_facts[index].pot)
				amount=minf(20,float(fact.pot_cap)-before) if eligible else 0.0
			elif kind=="charge":
				before=float(projection.entry_facts[index].charge)
				amount=minf(1,CHARGE_CAP-before) if eligible else 0.0
			else:
				before=projected_baits;amount=1.0 if eligible and projected_baits<BAIT_CAP else 0.0
				projected_baits+=int(amount)
			result.effects.append({"player_index":index,"kind":kind,"eligible":eligible,"before":before,"amount":amount,"after":before+amount})
			benefit+=amount
	if board.stage!="business" or board.operation:return _reject(result,"本轮已经营或尚未到站；投资、挑战、留钱、补给互斥")
	if id=="route_ticket" and board.round==6:return _reject(result,"最后一轮没有下一次骰路，不出售路线券")
	if id=="route_ticket" and board.nudges>=Routes.remaining_ticket_limit(board.round):return _reject(result,"余下%d次骰路，现有%d张券已够用，不扣钱"%[6-int(board.round),board.nudges])
	if benefit<=0:return _reject(result,"没有实际收益，不扣钱")
	if board.cash<int(result.price):return _reject(result,"钱袋不足，不扣钱")
	result.cash_after=int(board.cash)-int(result.price)
	return result

static func project_entry(board:Dictionary,player_facts:Array,include_events:bool=false)->Dictionary:
	if not board.get("position") is int or board.position<0 or board.position>11 or not board.get("licenses") is Array or board.licenses.size()!=3:return {"ok":false,"reason":"棋盘入场字段无效"}
	for level in board.licenses:
		if not level is int or level<0 or level>2:return {"ok":false,"reason":"入场执照等级无效"}
	if player_facts.is_empty() or player_facts.size()>2:return {"ok":false,"reason":"入场玩家事实无效"}
	var destination:int=[0,0,1,2,2,1,0,0,2,2,1,1][board.position]
	var level:int=board.licenses[destination]
	var entry:Array=[];var baits:=0
	for fact in player_facts:
		if not fact is Dictionary or not fact.has_all(["style","down","pot","pot_cap","charge"]):return {"ok":false,"reason":"入场资源事实缺失"}
		if not fact.style is int or fact.style<0 or fact.style>2 or not fact.down is bool:return {"ok":false,"reason":"入场角色事实无效"}
		for key in ["pot","pot_cap","charge"]:
			if not _finite(fact[key]):return {"ok":false,"reason":"入场资源非有限"}
		if fact.pot_cap<=0 or fact.pot_cap>10000 or fact.pot<0 or fact.pot>fact.pot_cap or fact.charge<0 or fact.charge>2.5:return {"ok":false,"reason":"入场资源超上限"}
		var projected:Dictionary=fact.duplicate(true)
		projected.pot=minf(float(fact.pot_cap),float(fact.pot)+(15 if level==1 else 22 if level==2 else 0))
		projected.charge=minf(2.5,float(fact.charge)+(1.0 if level==1 else 22.0/15.0 if level==2 else 0.0))
		entry.append(projected)
		if level>0 and fact.style==2:baits+=1
	if include_events:
		var effects:Variant=board.get("event_resources",[])
		if not valid_event_resources(effects,player_facts.size()):return {"ok":false,"reason":"事件资源快照无效"}
		for effect in effects:
			if not effect.eligible:continue
			var projected:Dictionary=entry[effect.player_index]
			if effect.kind!=["pot","charge","bait"][projected.style]:return {"ok":false,"reason":"事件资源与玩家流派不一致"}
			match effect.kind:
				"pot":projected.pot=minf(float(projected.pot_cap),float(projected.pot)+float(effect.amount))
				"charge":projected.charge=minf(2.5,float(projected.charge)+float(effect.amount))
				"bait":baits=mini(12,baits+int(effect.amount))
	return {"ok":true,"entry_facts":entry,"projected_baits":baits}

static func valid_event_resources(effects:Variant,player_count:int)->bool:
	if not effects is Array or effects.size()>2:return false
	var seen:Dictionary={}
	for effect in effects:
		if not effect is Dictionary or not effect.has_all(["player_index","kind","eligible","before","amount","after"]):return false
		if not effect.player_index is int or effect.player_index<0 or effect.player_index>=player_count or seen.has(effect.player_index):return false
		seen[effect.player_index]=true
		if not effect.kind is String or effect.kind not in ["pot","charge","bait"] or not effect.eligible is bool:return false
		for key in ["before","amount","after"]:
			if not _finite(effect[key]) or effect[key]<0:return false
		var cap:float={"pot":10000.0,"charge":2.5,"bait":12.0}[effect.kind]
		var maximum:float={"pot":10.0,"charge":.5,"bait":1.0}[effect.kind]
		if effect.before>cap or effect.after>cap or effect.amount>maximum or not is_equal_approx(float(effect.after),float(effect.before)+float(effect.amount)):return false
		if not effect.eligible and effect.amount!=0:return false
		if effect.kind=="bait" and (effect.amount!=0 and effect.amount!=1):return false
	return true

static func _finite(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _reject(result:Dictionary,reason:String)->Dictionary:
	result.ok=false;result.reason=reason
	return result
