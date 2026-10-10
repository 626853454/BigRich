class_name FurDiceRoutes
extends RefCounted

# Three existing choices, with reverse replacing the old minus-one choice.
# Pure input projection: no RNG, money, state, authority or transport writes.
const TILES:=12
const CHOICES:=[-1,0,1]
const MAX_TICKET_COST:=2

static func project(position:Variant,face:Variant,nudges:Variant,adjustment:Variant)->Dictionary:
	if not _integer(position,0,11) or not _integer(face,1,6) or not _integer(nudges,0,3):return _reject("bad_facts","骰路位置/骰点/共享券须是范围内整数")
	if not adjustment is int or adjustment not in CHOICES:return _reject("bad_choice","只能选倒车、原步数或加一步")
	var ticket_cost:int=MAX_TICKET_COST if adjustment==-1 else (1 if adjustment==1 else 0)
	if nudges<ticket_cost:return _reject("no_ticket","倒车需要2张共享券" if adjustment==-1 else "加一步需要1张共享券")
	var steps:int=int(face)+(1 if adjustment==1 else 0)
	var direction:int=-1 if adjustment==-1 else 1
	var path:Array[int]=[]
	for index in steps:path.append(posmod(int(position)+direction*(index+1),TILES))
	var crosses:bool=path.has(0)
	return {"ok":true,"code":"","reason":"","adjustment":adjustment,"path":path,"steps":steps,"ticket_cost":ticket_cost,"direction":direction,"landing":path.back(),"passes_start":crosses,"cross_subsidy":12 if direction==1 and crosses else 0,"caption":caption(adjustment)}

static func caption(adjustment:Variant)->String:
	if not adjustment is int or adjustment not in CHOICES:return "无效路线"
	return "倒车按骰点 / 花2券" if adjustment==-1 else ("原骰点 / 不花券" if adjustment==0 else "正向加一步 / 花1券")

static func remaining_ticket_limit(round_number:Variant)->int:
	if not _integer(round_number,1,6):return 0
	return mini(3,MAX_TICKET_COST*(6-int(round_number)))

static func valid_path(face:Variant,steps:Variant,path:Variant,landing:Variant)->bool:
	if not _integer(face,1,6) or not _integer(steps,1,7) or not _integer(landing,0,11) or not path is Array or path.size()!=steps:return false
	for tile in path:
		if not _integer(tile,0,11):return false
	if path.back()!=landing:return false
	# No old minus-one history conversion. A one-step path can be either direction;
	# that ambiguity is harmless because its exact path/landing is authoritative.
	for choice in CHOICES:
		var direction:int=-1 if choice==-1 else 1
		var origin:int=posmod(int(path[0])-direction,TILES)
		var projected:Dictionary=project(origin,face,3,choice)
		if projected.ok and projected.steps==steps and projected.path==path:return true
	return false

static func _integer(value:Variant,minimum:int,maximum:int)->bool:
	return value is int and value>=minimum and value<=maximum

static func _reject(code:String,reason:String)->Dictionary:
	return {"ok":false,"code":code,"reason":reason,"path":[]}
