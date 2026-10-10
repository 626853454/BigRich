class_name FurPartyRollOutlook
extends RefCounted

const Map=preload("res://scripts/party/party_map.gd")
# Decision-only bounded route evaluation. Landing callback is read-only and
# receives the remaining real wallet after each ferry's cumulative cost.
static func evaluate(tiles:Array[Dictionary],origin:int,coins:int,bonus:int,landing_value:Callable)->Dictionary:
	if tiles.size()!=54 or origin<0 or origin>=tiles.size() or coins<0 or coins>999 or bonus<0 or bonus>2 or not landing_value.is_valid():return {}
	var memo:Dictionary={};var faces:Array[Dictionary]=[];var total:=0.0
	for face in range(1,7):
		var route:Dictionary=_route(tiles,origin,face+bonus,coins,landing_value,memo)
		if route.is_empty():return {}
		var row:Dictionary=route.duplicate(true);row["face"]=face;row["steps"]=face+bonus;faces.append(row);total+=float(row.value)
	return {"value":total/6.0,"faces":faces,"memo_states":memo.size()}

static func _route(tiles:Array[Dictionary],node:int,remaining:int,coins:int,landing_value:Callable,memo:Dictionary)->Dictionary:
	var key:Vector3i=Vector3i(node,remaining,coins)
	if memo.has(key):return memo[key]
	if remaining==0:
		var value:float=landing_value.call(node,coins)
		if not is_finite(value):return {}
		var terminal:Dictionary={"value":value,"landing":node,"path":[node],"ferry_cost":0,"coins_after":coins}
		memo[key]=terminal;return terminal
	var best:Dictionary={}
	for next in tiles[node].next:
		var cost:int=2 if Map.is_ferry_edge(node,int(next)) else 0
		if coins<cost:continue
		var tail:Dictionary=_route(tiles,int(next),remaining-1,coins-cost,landing_value,memo)
		if tail.is_empty():continue
		var score:float=float(tail.value)-float(cost)
		# Equal utility keeps immutable Map edge order, independent of RNG.
		if best.is_empty() or score>float(best.value):
			var path:Array=[node];path.append_array(tail.path)
			best={"value":score,"landing":int(tail.landing),"path":path,"ferry_cost":cost+int(tail.ferry_cost),"coins_after":int(tail.coins_after)}
	memo[key]=best
	return best
