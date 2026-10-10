class_name FurPartyMap
extends RefCounted

const COLOURS:=[Color("ee775f"),Color("6cbce7")]
const PLAYER_NAMES:=["小柯","泡泡"]
const LABELS:={"start":"港口起点","blue":"幸运","coin":"金币","red":"破财","event":"奇遇","shop":"道具","property":"合作摊位","star":"星铃"}
const LOCAL_KINDS:=["blue","coin","blue","property","event","red","shop","blue","coin","blue","event","property"]
const STAR_CHOICES:=[8,22,36]
const FERRY_EDGES:=[[3,14],[17,28],[31,0]]

static func districts()->Array[Dictionary]:
	return [
		{"id":0,"name":"暖灯港口","center":Vector3(-18,1.1,9),"radius":Vector2(11.7,8.7),"height":1.1,"theme":"harbor","landmark":Vector3(-21,1.1,6)},
		{"id":1,"name":"风车丘","center":Vector3(0,3.0,-13),"radius":Vector2(11.7,8.7),"height":3.0,"theme":"windmill","landmark":Vector3(-3,3.0,-16)},
		{"id":2,"name":"萤火遗迹林","center":Vector3(18,1.9,9),"radius":Vector2(11.7,8.7),"height":1.9,"theme":"ruins","landmark":Vector3(15,1.9,6)}]

static func _local_point(region:int,index:int)->Vector3:
	var data:Dictionary=districts()[region]
	var incoming:float=[0.0,atan2(22.0,-18.0),atan2(-22.0,-18.0)][region]
	var outgoing:float=[atan2(-22.0,18.0)+TAU,atan2(22.0,18.0)+TAU,PI][region]
	var t:=float(index)/11.0;var angle:=lerpf(incoming,outgoing,t)
	return data.center+Vector3(cos(angle)*10.0,.16*sin(t*PI),sin(angle)*7.0)

static func nodes()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for region in 3:
		var data:Dictionary=districts()[region]
		for local in 12:
			var id:int=region*14+local;var kind:String="start" if id==0 else LOCAL_KINDS[local]
			result.append({"id":id,"pos":_local_point(region,local),"kind":kind,"next":[id+1],"district":region,"name":data.name+" · "+LABELS[kind],"bridge":false})
		var origin:Vector3=_local_point(region,11);var destination:Vector3=_local_point((region+1)%3,0)
		for segment in 2:
			var id:int=region*14+12+segment;var t:=float(segment+1)/3.0
			var position:Vector3=origin.lerp(destination,t)+Vector3.UP*sin(t*PI)*.3
			result.append({"id":id,"pos":position,"kind":"blue","next":[(id+1)%42],"district":region,"name":"跨岛石桥 %d"%(segment+1),"bridge":true})
	var forks:=[[3,8],[17,22],[31,36],[34,38]]
	for route in 4:
		var origin:int=forks[route][0];var destination:int=forks[route][1];var first:int=42+route*3
		result[origin].next.append(first)
		for segment in 3:
			var id:int=first+segment;var t:=float(segment+1)/4.0
			var kind:String=["coin","event","blue"][segment]
			result.append({"id":id,"pos":result[origin].pos.lerp(result[destination].pos,t),"kind":kind,"next":[id+1 if segment<2 else destination],"district":int(result[origin].district),"name":"岛内岔路 · "+LABELS[kind],"bridge":false})
	for edge in FERRY_EDGES:result[edge[0]].next.append(edge[1])
	# Separate the second ruins shortcut from tile50 and keep its connector
	# clear of tile50's disc, rather than only separating the two centres.
	result[52].pos+=Vector3(-.2,0,-2.6)
	if FurIslandComposition.enabled:
		FurIslandComposition.configure(result)
		for tile in result:tile.pos.y+=FurIslandComposition.elevation(tile.pos)
	return result

static func point(index:int)->Vector3:
	var tiles:Array[Dictionary]=nodes()
	return tiles[clampi(index,0,tiles.size()-1)].pos

static func district_steps(origin:int,target_district:int,coins:int)->int:
	# Read-only shortest route with cumulative ferry fares. At most two ferries
	# are needed to reach any other district; higher wallets share this bound.
	var tiles:Array[Dictionary]=nodes()
	if origin<0 or origin>=tiles.size() or target_district<0 or target_district>2 or coins<0:return -1
	var queue:Array[Vector3i]=[Vector3i(origin,mini(coins,4),0)]
	var seen:Dictionary={Vector2i(origin,mini(coins,4)):true}
	var cursor:=0
	while cursor<queue.size():
		var state:Vector3i=queue[cursor];cursor+=1
		if tiles[state.x].district==target_district:return state.z
		for next in tiles[state.x].next:
			var fare:int=2 if is_ferry_edge(state.x,int(next)) else 0
			if state.y<fare:continue
			var key:=Vector2i(int(next),state.y-fare)
			if seen.has(key):continue
			seen[key]=true;queue.append(Vector3i(key.x,key.y,state.z+1))
	return -1

static func edges()->Array:
	var result:Array=[]
	for tile in nodes():
		for target in tile.next:result.append([tile.id,target])
	return result

static func is_bridge_edge(origin:int,destination:int)->bool:
	var tiles:Array[Dictionary]=nodes()
	if origin<0 or destination<0 or origin>=tiles.size() or destination>=tiles.size():return false
	return destination in tiles[origin].next and (bool(tiles[origin].bridge) or bool(tiles[destination].bridge))

static func is_ferry_edge(origin:int,destination:int)->bool:
	for edge in FERRY_EDGES:
		if origin==edge[0] and destination==edge[1]:return true
	return false
