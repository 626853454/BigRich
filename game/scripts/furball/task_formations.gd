class_name FurTaskFormations
extends RefCounted

const Catalog=preload("res://scripts/furball/district_catalog.gd")
const District=preload("res://scripts/furball/district_runtime.gd")
const LEAD_TIME:=.35
const TTL:=1.8
const PLAYER_CLEARANCE:=5.0
const WALL_MARGIN:=.6
const INSET:=1.1
const SPACING:=.95
var _seed:int=0
var _token:int=0
var _wave:int=0
var _district:int=-1
var _enabled:=false
var _last_seen:int=0
var _last_now:float=-1.0
var _pending:Dictionary={}

func configure(seed:Variant,run_token:Variant,wave:Variant,district:Variant) -> bool:
	if not _integer(seed,1,2147483647) or not _integer(run_token,1,2147483647) or not _integer(wave,1,6) or not _integer(district,0,2):return false
	_seed=seed;_token=run_token;_wave=wave;_district=district
	clear()
	_enabled=true
	return true

func clear() -> void:
	_pending.clear();_last_seen=0;_last_now=-1.0;_enabled=false

func pending_preview() -> Dictionary:
	if _pending.is_empty():return {}
	var heading:Vector2=(_pending.to-_pending.from).normalized()
	return {"packet_id":_pending.packet_id,"lane":_pending.lane,"direction":_pending.direction,"wave":_wave,"run_token":_token,
		"created_at":_pending.created_at,"expires_at":_pending.expires_at,"markers":[_pending.from+heading*INSET,_pending.to-heading*INSET]}

static func valid_preview(value:Variant,seed:Variant,token:Variant,wave:Variant,now:Variant,phase:Variant,district:Variant) -> bool:
	if not value is Dictionary or not _integer(seed,1,2147483647) or not _integer(token,1,2147483647) or not _integer(wave,0,6) or not _integer(district,0,2) or not _number(now) or float(now)<0 or not phase is String or phase.length()>24:return false
	if value.is_empty():return true
	if phase!="battle" or district!=1 or wave<1:return false
	var keys:=["packet_id","lane","direction","wave","run_token","created_at","expires_at","markers"]
	if value.size()!=keys.size() or not value.has_all(keys):return false
	if not _integer(value.packet_id,1,2147480000) or not _integer(value.lane,0,2) or not _integer(value.direction,-1,1) or value.direction==0 or not value.wave is int or value.wave!=wave or not value.run_token is int or value.run_token!=token:return false
	if not _number(value.created_at) or not _number(value.expires_at) or float(value.created_at)<0 or float(value.created_at)>float(now) or float(value.expires_at)!=float(value.created_at)+TTL or float(now)>=float(value.expires_at):return false
	var salted:int=seed+wave*101
	if value.lane!=posmod(value.packet_id-1+salted%3,3) or value.direction!=(1 if (value.packet_id-1+salted)%2==0 else -1):return false
	if not value.markers is Array or value.markers.size()!=2:return false
	for marker in value.markers:
		if not marker is Vector2 or not marker.is_finite():return false
	var route:Dictionary=Catalog.layout(1,wave,salted).logistics_routes[value.lane]
	var origin:Vector2=route.from if value.direction==1 else route.to
	var destination:Vector2=route.to if value.direction==1 else route.from
	var heading:Vector2=(destination-origin).normalized()
	return value.markers==[origin+heading*INSET,destination-heading*INSET]

func queue_warning(event:Variant,district_snapshot:Variant,now:Variant,phase:Variant,run_token:Variant,authority:Variant=true) -> Dictionary:
	var result:Dictionary={"ok":false,"queued":false,"reason":"invalid_context","packet_id":0}
	if not _context(now,phase,run_token,authority):return result
	if phase!="battle" or _district!=1:
		clear();result.ok=true;result.reason="inactive";return result
	if not _warning_valid(event,district_snapshot):result.reason="invalid_warning";return result
	var packet:Dictionary={}
	for candidate in district_snapshot.packets:
		if candidate.id==district_snapshot.cycle:packet=candidate;break
	if packet.is_empty():result.reason="missing_packet";return result
	var id:int=packet.id
	result.packet_id=id
	if id<=_last_seen:result.reason="duplicate_packet";return result
	_expire(float(now))
	_last_seen=id;_last_now=float(now)
	result.ok=true
	if not _pending.is_empty():result.reason="pending_busy";return result
	var route:Dictionary=district_snapshot.logistics_routes[packet.lane]
	_pending={"packet_id":id,"lane":packet.lane,"direction":packet.direction,
		"from":route.from if packet.direction==1 else route.to,
		"to":route.to if packet.direction==1 else route.from,
		"created_at":float(now),"expires_at":float(now)+TTL,"wave":_wave,"run_token":_token}
	result.queued=true;result.reason="queued"
	return result

func replace_group(requests:Variant,players:Variant,now:Variant,phase:Variant,wave:Variant,run_token:Variant,authority:Variant=true) -> Dictionary:
	var result:Dictionary={"ok":false,"requests":requests.duplicate(true) if requests is Array else [],"applied":false,"consumed":false,"packet_id":0,"reason":"invalid_context"}
	if not _context(now,phase,run_token,authority) or not _integer(wave,1,6):return result
	if not _requests_valid(requests) or not _players_valid(players):result.reason="invalid_group";return result
	if phase!="battle" or wave!=_wave or _district!=1:
		clear();result.ok=true;result.reason="inactive";return result
	_last_now=float(now);result.ok=true
	if _pending.is_empty():result.reason="no_pending";return result
	result.packet_id=_pending.packet_id
	if _expire(float(now)):
		result.consumed=true;result.reason="expired";return result
	if requests.is_empty():result.reason="waiting_group";return result
	var pending:=_pending.duplicate(true)
	_pending.clear();result.consumed=true
	if requests.size()==1:result.reason="single_group";return result
	if float(now)<float(pending.created_at)+LEAD_TIME:result.reason="short_lead";return result
	var heading:Vector2=(pending.to-pending.from).normalized()
	var normal:=Vector2(-heading.y,heading.x)
	var anchors:Array[Vector2]=[pending.from+heading*INSET,pending.to-heading*INSET]
	# Bounded integer calculation, no random generator or navigation sampling.
	var first:int=posmod(_seed*31+int(pending.packet_id)*17+int(pending.lane)*7+int(pending.direction),2)
	var walls:Array=Catalog.obstacles(1,Catalog.variant_id(_wave,_seed+_wave*101))
	for attempt in 2:
		var points:Array[Vector2]=[]
		for index in requests.size():points.append(anchors[(first+attempt)%2]+normal*(float(index)-float(requests.size()-1)*.5)*SPACING)
		if not _safe_group(points,players,walls):continue
		for index in points.size():result.requests[index]["pos"]=points[index]
		result.applied=true;result.reason="applied";return result
	result.reason="unsafe_entrances"
	return result

func _context(now:Variant,phase:Variant,token:Variant,authority:Variant) -> bool:
	return _enabled and _seed>0 and _token>0 and authority is bool and authority and token is int and token==_token and phase is String and phase.length()<=24 and _number(now) and float(now)>=0 and float(now)>=_last_now

func _expire(now:float) -> bool:
	if not _pending.is_empty() and now>=float(_pending.expires_at):_pending.clear();return true
	return false

func _warning_valid(event:Variant,snapshot:Variant) -> bool:
	if not event is Dictionary or not snapshot is Dictionary:return false
	var keys:=["kind","point","pos","value","owner","cash","xp","health","source","sequence"]
	if event.size()!=keys.size() or not event.has_all(keys):return false
	if event.kind!="district_warning" or event.source!="district" or not event.kind is String or not event.source is String:return false
	if not event.point is Vector2 or not event.point.is_finite() or not event.pos is Vector2 or event.pos!=event.point:return false
	if not _number(event.value) or float(event.value)!=.8 or not _number(event.health) or float(event.health)!=0:return false
	if not _integer(event.owner,-1,-1) or not _integer(event.cash,0,0) or not _integer(event.xp,0,0) or not _integer(event.sequence,1,2147483647):return false
	var checker:=District.new()
	if snapshot.size()!=checker.state.size() or not snapshot.has_all(checker.state.keys()):return false
	if not checker.apply_state(snapshot):return false
	if snapshot.district_id!=1 or snapshot.wave!=_wave or snapshot.seed!=_seed+_wave*101 or snapshot.completed or event.sequence>snapshot.event_serial:return false
	var content:Dictionary=Catalog.entry(1)
	if snapshot.name!=content.name+" · "+snapshot.variant_title or snapshot.goal!=content.goal+"（"+snapshot.variant_title+"）" or snapshot.target!=3 or snapshot.activated!=0 or snapshot.caught<0 or snapshot.caught>2 or snapshot.missed<0 or snapshot.progress!=float(snapshot.caught) or snapshot.cash_paid!=snapshot.caught*3 or snapshot.feast_ready or snapshot.feast_progress!=0 or snapshot.charges!=[0.0,0.0,0.0]:return false
	if float(snapshot.elapsed)<1 or absf(float(snapshot.next_launch)-(float(snapshot.elapsed)+5.5))>.000001:return false
	if snapshot.cycle<1 or snapshot.cycle>2147480000:return false
	var ids:Dictionary={}
	var found:=false
	for packet in snapshot.packets:
		if packet.size()!=8 or packet.id>snapshot.cycle or ids.has(packet.id):return false
		ids[packet.id]=true
		if packet.lane!=posmod(packet.id-1+snapshot.seed%3,3) or packet.direction!=(1 if (packet.id-1+snapshot.seed)%2==0 else -1):return false
		var route:Dictionary=snapshot.logistics_routes[packet.lane]
		var origin:Vector2=route.from if packet.direction==1 else route.to
		var destination:Vector2=route.to if packet.direction==1 else route.from
		var heading:Vector2=(destination-origin).normalized()
		var age:float=float(packet.age)
		if age<.8:
			if packet.phase!="warning" or packet.point!=origin or packet.cart_point!=origin or packet.hit_mask!=0:return false
		else:
			var travel:=age-.8
			if packet.phase!="moving" or packet.cart_point!=origin+heading*6.5*travel or packet.point!=origin+heading*3.8*maxf(0,travel-.6) or packet.point.distance_to(origin)>origin.distance_to(destination)+1.2:return false
		if packet.id!=snapshot.cycle:continue
		if packet.phase!="warning" or float(packet.age)>.100001 or packet.point!=origin or packet.cart_point!=origin or packet.hit_mask!=0 or event.point!=origin:return false
		found=true
	return found

static func _requests_valid(requests:Variant) -> bool:
	if not requests is Array or requests.size()>5:return false
	for request in requests:
		if not request is Dictionary or not request.has_all(["kind","pos"]):return false
		if not _integer(request.kind,0,4) or not request.pos is Vector2 or not request.pos.is_finite() or not Catalog.BOUNDS.has_point(request.pos):return false
	return true

static func _players_valid(players:Variant) -> bool:
	if not players is Array or players.size()<1 or players.size()>2:return false
	for player in players:
		if not player is Dictionary or not player.has_all(["pos","down"]) or not player.pos is Vector2 or not player.pos.is_finite() or not Catalog.BOUNDS.has_point(player.pos) or not player.down is bool:return false
	return true

static func _safe_group(points:Array,players:Array,walls:Array) -> bool:
	var bounds:=Catalog.BOUNDS.grow(-WALL_MARGIN)
	for point in points:
		if not point is Vector2 or not point.is_finite() or not bounds.has_point(point):return false
		for wall in walls:
			if not wall is Rect2 or not wall.position.is_finite() or not wall.size.is_finite() or wall.size.x<=0 or wall.size.y<=0 or wall.grow(WALL_MARGIN).has_point(point):return false
		for player in players:
			if point.distance_squared_to(player.pos)<PLAYER_CLEARANCE*PLAYER_CLEARANCE:return false
	return true

static func _integer(value:Variant,minimum:int,maximum:int) -> bool:
	return value is int and value>=minimum and value<=maximum

static func _number(value:Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
