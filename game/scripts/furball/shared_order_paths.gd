class_name FurSharedOrderPaths
extends RefCounted

const Catalog=preload("res://scripts/furball/district_catalog.gd")
const CLEARANCE:=.46
const CACHE_LIMIT:=64
static var _cache:Dictionary={}

# Cache contains pure canonical geometry only: no elapsed/players/global RNG.
static func options(battle:Dictionary,origin:Vector2,charges:Array,seed:int)->Dictionary:
	var key:String=var_to_str([battle.district_id,battle.wave,battle.seed,battle.points,battle.obstacles,battle.routes,origin,charges,seed])
	if _cache.has(key):return _cache[key].duplicate(true)
	var direct:Array[Vector2]=_direct(battle,origin,charges,seed)
	var direct_length:float=_length(origin,direct,battle.obstacles)
	var inset:Rect2=Catalog.BOUNDS.grow(-1.0)
	var anchors:Array[Vector2]=[inset.position,Vector2(inset.end.x,inset.position.y),inset.end,Vector2(inset.position.x,inset.end.y)]
	var outer:Array[Vector2]=[];var outer_length:=INF
	for anchor in anchors:
		var candidate:Array[Vector2]=[anchor,direct[1]]
		var distance:float=_length(origin,candidate,battle.obstacles)
		if distance>=direct_length+2.0 and distance<outer_length:
			outer=candidate;outer_length=distance
	var result:Dictionary={"direct":direct,"outer":outer,"direct_length":direct_length,"outer_length":outer_length}
	if _cache.size()>=CACHE_LIMIT:_cache.clear()
	_cache[key]=result.duplicate(true)
	return result

static func _direct(battle:Dictionary,origin:Vector2,charges:Array,seed:int)->Array[Vector2]:
	var nodes:Array[Vector2]=[];var points:Array=battle.points
	match int(battle.district_id):
		0:
			var first:=-1
			if charges.size()==3:
				for index in 3:
					if float(charges[index])<1.0:first=index;break
			if first<0:
				first=0
				for index in 3:
					if points[index].distance_squared_to(origin)>points[first].distance_squared_to(origin):first=index
			var second:=(first+1)%3
			for index in 3:
				if index!=first and points[index].distance_squared_to(points[first])>points[second].distance_squared_to(points[first]):second=index
			nodes.assign([points[first],points[second]])
		1:
			var route:Dictionary=battle.routes[(battle.wave+seed)%3]
			nodes.assign([route.from.lerp(route.to,.18),route.to.lerp(route.from,.18)])
		2:
			var first:int=0 if points[0].distance_squared_to(points[2])>=points[1].distance_squared_to(points[2]) else 1
			nodes.assign([points[first],points[1-first]])
	return nodes

static func _length(origin:Vector2,nodes:Array[Vector2],walls:Array)->float:
	var distance:=0.0;var point:=origin
	for target in nodes:
		var path:Array[Vector2]=leg(point,target,walls)
		if path.is_empty():return INF
		for next in path:distance+=point.distance_to(next);point=next
	return distance

# <=10 vertices / <=90 segment tests per leg, bounded visibility graph.
# Expanded walls match radius .4 with .06 clearance; no physics/GPU sampling.
static func leg(from:Vector2,to:Vector2,walls:Array)->Array[Vector2]:
	if from.is_equal_approx(to):return [to]
	var points:Array[Vector2]=[from,to]
	for wall in walls:
		var rect:Rect2=wall.grow(CLEARANCE+.02)
		points.append_array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var distances:Array[float]=[];var previous:Array[int]=[];var visited:Array[bool]=[]
	for index in points.size():distances.append(INF);previous.append(-1);visited.append(false)
	distances[0]=0.0
	for iteration in points.size():
		var current:=-1
		for index in points.size():
			if not visited[index] and (current<0 or distances[index]<distances[current]):current=index
		if current<0 or not is_finite(distances[current]):break
		if current==1:break
		visited[current]=true
		for index in points.size():
			if visited[index] or index==current or not _clear(points[current],points[index],walls):continue
			var candidate:float=distances[current]+points[current].distance_to(points[index])
			if candidate<distances[index]:distances[index]=candidate;previous[index]=current
	if not is_finite(distances[1]):return []
	var path:Array[Vector2]=[];var cursor:=1
	while cursor!=0 and cursor>=0:path.push_front(points[cursor]);cursor=previous[cursor]
	return path if cursor==0 else []

static func _clear(from:Vector2,to:Vector2,walls:Array)->bool:
	for wall in walls:
		var rect:Rect2=wall.grow(CLEARANCE)
		var lo:=0.0;var hi:=1.0;var delta:=to-from;var intersects:=true
		for axis in 2:
			if absf(delta[axis])<.000001:
				if from[axis]<rect.position[axis] or from[axis]>rect.end[axis]:intersects=false;break
			else:
				var a:float=(rect.position[axis]-from[axis])/delta[axis]
				var b:float=(rect.end[axis]-from[axis])/delta[axis]
				lo=maxf(lo,minf(a,b));hi=minf(hi,maxf(a,b))
				if lo>hi:intersects=false;break
		if intersects:return false
	return true
