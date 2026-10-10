class_name FurDistrictRuntime
extends RefCounted

const Catalog=preload("res://scripts/furball/district_catalog.gd")
var state:Dictionary={}
# Ephemeral authority cart sweep requests; never serialized or counted as events.
var cart_sweeps:Array[Dictionary]=[]

func _init() -> void:
	configure(0,1,1)

func configure(district_id:int,wave:int,seed:int) -> void:
	cart_sweeps.clear()
	var id:=clampi(district_id,0,2)
	var content:Dictionary=Catalog.entry(id)
	var layout:Dictionary=Catalog.layout(id,wave,seed)
	state={"district_id":id,"wave":clampi(wave,1,6),"seed":maxi(1,seed),"elapsed":0.0,
		"completed":false,"name":content.name+" · "+layout.variant_title,"goal":content.goal+"（"+layout.variant_title+"）","target":content.target,
		"variant_id":layout.variant_id,"variant_title":layout.variant_title,"logistics_routes":layout.logistics_routes,
		"points":layout.points,"obstacles":layout.obstacles,"charges":[0.0,0.0,0.0],
		"activated":0,"progress":0.0,"packets":[],"next_launch":1.0,"cycle":0,
		"caught":0,"missed":0,"feast_ready":false,"feast_progress":0.0,
		"cash_paid":0,"event_serial":0}

func reset() -> void:
	configure(int(state.get("district_id",0)),int(state.get("wave",1)),int(state.get("seed",1)))

func snapshot() -> Dictionary:
	return state.duplicate(true)

func apply_state(next:Dictionary) -> bool:
	# Network presentation consumes authority state, never arbitrary-sized arrays.
	if not next.has_all(["district_id","wave","seed","elapsed","completed","name","goal","target","charges","packets","points","obstacles","activated","progress","next_launch","cycle","caught","missed","feast_ready","feast_progress","cash_paid","event_serial","variant_id","variant_title","logistics_routes"]):return false
	for key in ["district_id","wave","seed","variant_id","target","activated","cycle","caught","missed","cash_paid","event_serial"]:
		if not next[key] is int:return false
	if next.district_id<0 or next.district_id>2 or next.wave<1 or next.wave>6 or next.seed<1 or next.variant_id<0 or next.variant_id>2:return false
	if not next.name is String or not next.goal is String or not next.variant_title is String or next.name.length()>150 or next.goal.length()>150 or next.variant_title.length()>30:return false
	for key in ["completed","feast_ready"]:
		if not next[key] is bool:return false
	for key in ["elapsed","progress","next_launch","feast_progress"]:
		if not (next[key] is float or next[key] is int) or not is_finite(float(next[key])) or float(next[key])<0:return false
	if not next.charges is Array or next.charges.size()!=3:return false
	if not next.packets is Array or next.packets.size()>Catalog.PACKAGE_LIMIT:return false
	if not next.points is Array or next.points.size()!=3:return false
	if not next.obstacles is Array or next.obstacles.size()>2:return false
	for charge in next.charges:
		if not (charge is float or charge is int) or not is_finite(float(charge)) or float(charge)<0 or float(charge)>1.2:return false
	for point in next.points:
		if not point is Vector2 or not point.is_finite() or not Catalog.BOUNDS.has_point(point):return false
	for rect in next.obstacles:
		if not rect is Rect2 or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<=0 or rect.size.y<=0 or not Catalog.BOUNDS.encloses(rect):return false
	if not next.logistics_routes is Array or next.logistics_routes.size()!=3:return false
	for route in next.logistics_routes:
		if not route is Dictionary or not route.has_all(["from","to"]):return false
		if not route.from is Vector2 or not route.to is Vector2 or not route.from.is_finite() or not route.to.is_finite():return false
		if not Catalog.BOUNDS.has_point(route.from) or not Catalog.BOUNDS.has_point(route.to) or route.from.distance_to(route.to)<5:return false
	var expected:=Catalog.layout(next.district_id,next.wave,next.seed)
	if next.variant_id!=expected.variant_id or next.variant_title!=expected.variant_title or next.points!=expected.points or next.obstacles!=expected.obstacles or next.logistics_routes!=expected.logistics_routes:return false
	for packet in next.packets:
		if not packet is Dictionary or not packet.has_all(["id","lane","direction","age","point","cart_point","phase","hit_mask"]):return false
		if not packet.point is Vector2 or not packet.cart_point is Vector2 or not packet.point.is_finite() or not packet.cart_point.is_finite():return false
		if packet.point.length()>100 or packet.cart_point.length()>100:return false
		for key in ["id","lane","direction","hit_mask"]:
			if not packet[key] is int:return false
		if packet.lane<0 or packet.lane>2 or packet.direction not in [-1,1] or packet.id<1 or packet.hit_mask<0 or packet.hit_mask>15:return false
		if not (packet.age is float or packet.age is int) or not is_finite(float(packet.age)) or float(packet.age)<0 or float(packet.age)>30 or packet.phase not in ["warning","moving"]:return false
	cart_sweeps.clear()
	state=next.duplicate(true)
	return true

func tick(delta:float,players:Array) -> Array[Dictionary]:
	cart_sweeps.clear()
	var events:Array[Dictionary]=[]
	if delta<=0 or not is_finite(delta) or bool(state.completed):return events
	# Same bound as presentation; authority should call once per physics step.
	var dt:=minf(delta,.1)
	state.elapsed=float(state.elapsed)+dt
	match int(state.district_id):
		0:_tick_alley(dt,players,events)
		1:_tick_logistics(dt,players,events)
		2:_tick_milk(dt,players,events)
	return events

func _living(player:Variant) -> bool:
	return player is Dictionary and player.get("pos") is Vector2 and not bool(player.get("down",false))

func _event(events:Array[Dictionary],kind:String,point:Vector2,value:float=0,owner:int=-1,cash:int=0,xp:int=0,health:float=0) -> void:
	if events.size()>=Catalog.EVENT_LIMIT:return
	state.event_serial=int(state.event_serial)+1
	events.append({"kind":kind,"point":point,"pos":point,"value":value,"owner":owner,
		"cash":cash,"xp":xp,"health":health,"source":"district","sequence":state.event_serial})
	if kind=="district_reward":state.cash_paid=int(state.cash_paid)+cash

func _complete(events:Array[Dictionary],point:Vector2,cash:int,xp:int,health:float=0) -> void:
	if bool(state.completed):return
	state.completed=true
	_event(events,"district_reward",point,cash,-1,cash,xp,health)
	_event(events,"district_complete",point,1)

func _tick_alley(dt:float,players:Array,events:Array[Dictionary]) -> void:
	for index in 3:
		if float(state.charges[index])>=1.0:continue
		var operator:=-1
		for player_index in mini(players.size(),4):
			if _living(players[player_index]) and players[player_index].pos.distance_squared_to(state.points[index])<=2.56:
				operator=player_index;break
		if operator<0:continue
		state.charges[index]=minf(1.0,float(state.charges[index])+dt)
		if float(state.charges[index])>=1.0:
			state.activated=int(state.activated)+1
			state.progress=float(state.activated)
			_event(events,"district_checkpoint",state.points[index],1,operator)
			_event(events,"district_reward",state.points[index],3,operator,3,3)
			if int(state.activated)>=2:
				_complete(events,state.points[index],10,12)
				return

func _tick_logistics(dt:float,players:Array,events:Array[Dictionary]) -> void:
	if float(state.elapsed)>=float(state.next_launch) and state.packets.size()<Catalog.PACKAGE_LIMIT:
		var cycle:int=int(state.cycle)
		var lane:int=(cycle+int(state.seed)%3)%3
		var direction:int=1 if (cycle+int(state.seed))%2==0 else -1
		var route:Dictionary=state.logistics_routes[lane]
		var point:Vector2=route.from if direction>0 else route.to
		state.packets.append({"id":cycle+1,"lane":lane,"direction":direction,"age":0.0,
			"point":point,"cart_point":point,"phase":"warning","hit_mask":0})
		state.cycle=cycle+1;state.next_launch=float(state.elapsed)+5.5
		_event(events,"district_warning",point,.8)
	for index in range(state.packets.size()-1,-1,-1):
		var packet:Dictionary=state.packets[index]
		var previous_age:float=float(packet.age)
		packet.age=previous_age+dt
		if float(packet.age)<.8:continue
		packet.phase="moving"
		var travel:float=float(packet.age)-.8
		var direction:int=int(packet.direction)
		var route:Dictionary=state.logistics_routes[int(packet.lane)]
		var origin:Vector2=route.from if direction>0 else route.to
		var destination:Vector2=route.to if direction>0 else route.from
		var heading:Vector2=(destination-origin).normalized()
		packet.cart_point=origin+heading*6.5*travel
		packet.point=origin+heading*3.8*maxf(0,travel-.6)
		var route_length:float=origin.distance_to(destination)
		var old_distance:float=6.5*maxf(0,previous_age-.8)
		var cart_in_route:bool=old_distance<route_length and travel>=0
		var sweep_from:Vector2=origin+heading*minf(old_distance,route_length)
		var sweep_to:Vector2=origin+heading*minf(6.5*travel,route_length)
		var caught:=false
		for player_index in mini(players.size(),4):
			var player:Variant=players[player_index]
			if not _living(player):continue
			if travel*6.5<=origin.distance_to(destination) and player.pos.distance_squared_to(packet.cart_point)<=1.21 and (int(packet.hit_mask)&(1<<player_index))==0:
				packet.hit_mask=int(packet.hit_mask)|(1<<player_index)
				_event(events,"district_damage",packet.cart_point,8.0,player_index)
			if travel>=.6 and player.pos.distance_squared_to(packet.point)<=1.44:
				caught=true;state.caught=int(state.caught)+1;state.progress=float(state.caught)
				_event(events,"district_parcel",packet.point,1,player_index)
				_event(events,"district_reward",packet.point,3,player_index,3,2)
				break
		# A collected parcel removes its cart now, so it cannot push from a stale
		# sweep. Clip the last actual moving segment to the route endpoint once.
		if not caught and cart_in_route and cart_sweeps.size()<Catalog.PACKAGE_LIMIT:
			cart_sweeps.append({"packet_id":int(packet.id),"from":sweep_from,"to":sweep_to,"heading":heading})
		if caught:
			state.packets.remove_at(index)
			if int(state.caught)>=3:
				state.packets.clear();cart_sweeps.clear();_complete(events,Vector2.ZERO,10,12);return
		elif packet.point.distance_to(origin)>origin.distance_to(destination)+1.2:
			state.missed=int(state.missed)+1
			_event(events,"district_missed",packet.point,1)
			state.packets.remove_at(index)

func _tick_milk(dt:float,players:Array,events:Array[Dictionary]) -> void:
	for index in 2:
		if float(state.charges[index])>=1.2:continue
		var operator:=-1
		for player_index in mini(players.size(),4):
			var player:Variant=players[player_index]
			if _living(player) and player.pos.distance_squared_to(state.points[index])<=2.56 and player.get("input",Vector2.ZERO).length_squared()<.02:
				operator=player_index;break
		if operator<0:continue
		state.charges[index]=minf(1.2,float(state.charges[index])+dt)
		if float(state.charges[index])>=1.2:
			state.activated=int(state.activated)+1;state.progress=float(state.activated)
			_event(events,"district_checkpoint",state.points[index],1,operator)
	if int(state.activated)==2 and not bool(state.feast_ready):
		state.feast_ready=true
		_event(events,"district_ready",state.points[2],1)
	if not bool(state.feast_ready):return
	var guests:=0
	for player_index in mini(players.size(),4):
		if _living(players[player_index]) and players[player_index].pos.distance_squared_to(state.points[2])<=4.0:guests+=1
	if guests==0:return
	state.feast_progress=minf(.8,float(state.feast_progress)+dt*(1.5 if guests>1 else 1.0))
	if float(state.feast_progress)>=.8:_complete(events,state.points[2],10,10,8)

func resolve_motion(from:Vector2,to:Vector2,radius:float=.4) -> Vector2:
	var margin:=clampf(radius,0,1.4)
	var bounds:Rect2=Catalog.BOUNDS.grow(-margin)
	var start:=Vector2(clampf(from.x,bounds.position.x,bounds.end.x),clampf(from.y,bounds.position.y,bounds.end.y))
	var target:=Vector2(clampf(to.x,bounds.position.x,bounds.end.x),clampf(to.y,bounds.position.y,bounds.end.y))
	for obstacle in state.obstacles:start=_push_out(start,obstacle.grow(margin))
	var point:=Vector2(target.x,start.y)
	for obstacle in state.obstacles:
		var wall:Rect2=obstacle.grow(margin)
		if start.y<wall.position.y or start.y>wall.end.y:continue
		if start.x<=wall.position.x and point.x>wall.position.x:point.x=minf(point.x,wall.position.x-.001)
		elif start.x>=wall.end.x and point.x<wall.end.x:point.x=maxf(point.x,wall.end.x+.001)
	var horizontal:=point
	point.y=target.y
	for obstacle in state.obstacles:
		var wall:Rect2=obstacle.grow(margin)
		if horizontal.x<wall.position.x or horizontal.x>wall.end.x:continue
		if horizontal.y<=wall.position.y and point.y>wall.position.y:point.y=minf(point.y,wall.position.y-.001)
		elif horizontal.y>=wall.end.y and point.y<wall.end.y:point.y=maxf(point.y,wall.end.y+.001)
	return Vector2(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.y,bounds.position.y,bounds.end.y))

func _push_out(point:Vector2,wall:Rect2) -> Vector2:
	if not wall.has_point(point):return point
	var distances:=[absf(point.x-wall.position.x),absf(wall.end.x-point.x),absf(point.y-wall.position.y),absf(wall.end.y-point.y)]
	var nearest:=0
	for index in range(1,4):
		if distances[index]<distances[nearest]:nearest=index
	match nearest:
		0:point.x=wall.position.x-.001
		1:point.x=wall.end.x+.001
		2:point.y=wall.position.y-.001
		3:point.y=wall.end.y+.001
	return point

func _segment_blocked(from:Vector2,to:Vector2,wall:Rect2) -> bool:
	# Slab intersection without sampling: long dash/path cannot tunnel through.
	var low:=0.0;var high:=1.0;var direction:=to-from
	for axis in 2:
		var source:float=from[axis];var step:float=direction[axis]
		var minimum:float=wall.position[axis];var maximum:float=wall.end[axis]
		if absf(step)<.00001:
			if source<minimum or source>maximum:return false
		else:
			var enter:float=(minimum-source)/step;var leave:float=(maximum-source)/step
			if enter>leave:var saved:=enter;enter=leave;leave=saved
			low=maxf(low,enter);high=minf(high,leave)
			if low>high:return false
	return true

func steer_enemy(from:Vector2,target:Vector2,radius:float=.45) -> Vector2:
	for obstacle in state.obstacles:
		var wall:Rect2=obstacle.grow(clampf(radius,0,1.4)+.10)
		if wall.has_point(from):return (_push_out(from,wall)-from).normalized()
		if not _segment_blocked(from,target,wall):continue
		var corners:=[wall.position-Vector2(.06,.06),Vector2(wall.end.x+.06,wall.position.y-.06),wall.end+Vector2(.06,.06),Vector2(wall.position.x-.06,wall.end.y+.06)]
		var waypoint:Vector2=from;var best:=INF
		for corner in corners:
			if _segment_blocked(from,corner,wall):continue
			if not _segment_blocked(corner,target,wall):
				var direct_cost:float=from.distance_to(corner)+corner.distance_to(target)
				if direct_cost<best:best=direct_cost;waypoint=corner
				continue
			# A near corner is not a valid route if its next leg crosses the stall.
			# Evaluate the second visible corner; constant four-corner graph only.
			for exit_corner in corners:
				if _segment_blocked(corner,exit_corner,wall) or _segment_blocked(exit_corner,target,wall):continue
				var cost:float=from.distance_to(corner)+corner.distance_to(exit_corner)+exit_corner.distance_to(target)
				if cost<best:
					best=cost
					waypoint=exit_corner if from.distance_squared_to(corner)<.04 else corner
		if best<INF:return (waypoint-from).normalized()
	return (target-from).normalized()
