class_name FurCartImpact
extends RefCounted

# Authority-only contact planner. Runtime supplies actual linear cart sweeps;
# Model applies bounded motion and feedback. No damage, rewards, AI or RNG here.
const Catalog=preload("res://scripts/furball/district_catalog.gd")
const PACKET_LIMIT:=4
const CONTACT_LIMIT:=8
const ENEMY_LIMIT:=256
const RADIUS:=1.1
const PUSH:=2.4
const MAX_SWEEP:=.65
const EPSILON:=.000001
var run_token:=0
var wave:=0
var district:=-1
var ledger:Dictionary={}

func configure(token:Variant,round_number:Variant,district_id:Variant)->bool:
	if not _integer(token,1,2147483647) or not _integer(round_number,1,6) or not _integer(district_id,0,2):return false
	run_token=token;wave=round_number;district=district_id;ledger.clear()
	return true

func reset()->void:
	run_token=0;wave=0;district=-1;ledger.clear()

func snapshot()->Dictionary:
	return {"run_token":run_token,"wave":wave,"district":district,"ledger":ledger.duplicate(true)}

func process(sweeps:Variant,enemies:Variant,active_packet_ids:Variant,token:Variant,round_number:Variant,authority:Variant=true)->Dictionary:
	if not authority is bool or not authority:return _reject("not_authority")
	if not _integer(token,1,2147483647) or token!=run_token or not _integer(round_number,1,6) or round_number!=wave:return _reject("stale_context")
	if district!=1:return _reject("not_logistics")
	if not _inputs(sweeps,enemies,active_packet_ids):return _reject("invalid_inputs")
	# Preflight is complete before any ledger write. Removed carts with a genuine
	# final sweep remain for this call; caught/expired carts with no sweep prune.
	var retained:Dictionary={}
	for packet_id in active_packet_ids:retained[packet_id]=true
	for sweep in sweeps:retained[sweep.packet_id]=true
	var next_ledger:Dictionary={}
	for packet_id in ledger:
		if retained.has(packet_id):next_ledger[packet_id]=ledger[packet_id].duplicate()
	var ordered_sweeps:Array=sweeps.duplicate()
	ordered_sweeps.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.packet_id<b.packet_id)
	var ordered_enemies:Array=enemies.duplicate()
	ordered_enemies.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.identity<b.identity)
	var moves:Array[Dictionary]=[]
	var claimed:Dictionary={}
	for sweep in ordered_sweeps:
		var packet_id:int=sweep.packet_id
		if not next_ledger.has(packet_id):next_ledger[packet_id]=[]
		var contacts:Array=next_ledger[packet_id]
		var heading:Vector2=sweep.heading.normalized()
		var normal:=Vector2(-heading.y,heading.x)
		for enemy in ordered_enemies:
			if contacts.size()>=CONTACT_LIMIT:break
			if enemy.kind not in [0,1] or claimed.has(enemy.identity) or enemy.identity in contacts:continue
			var nearest:Vector2=_closest(enemy.pos,sweep.from,sweep.to)
			if enemy.pos.distance_squared_to(nearest)>RADIUS*RADIUS+EPSILON:continue
			var signed_distance:float=(enemy.pos-nearest).dot(normal)
			var side:float=1.0 if signed_distance>EPSILON else (-1.0 if signed_distance< -EPSILON else (1.0 if posmod(enemy.identity,2)==0 else -1.0))
			var target:Vector2=enemy.pos+normal*side*PUSH
			moves.append({"packet_id":packet_id,"slot":enemy.slot,"identity":enemy.identity,"from":enemy.pos,"to":target})
			contacts.append(enemy.identity);claimed[enemy.identity]=true
	ledger=next_ledger
	return {"ok":true,"moves":moves,"contacts":moves.size(),"reason":""}

static func _inputs(sweeps:Variant,enemies:Variant,active_ids:Variant)->bool:
	if not sweeps is Array or sweeps.size()>PACKET_LIMIT or not enemies is Array or enemies.size()>ENEMY_LIMIT or not active_ids is Array or active_ids.size()>PACKET_LIMIT:return false
	var packet_ids:Dictionary={};var active_seen:Dictionary={};var sweep_seen:Dictionary={}
	for packet_id in active_ids:
		if not _integer(packet_id,1,2147483647) or active_seen.has(packet_id):return false
		active_seen[packet_id]=true;packet_ids[packet_id]=true
	for sweep in sweeps:
		if not _keys(sweep,["packet_id","from","to","heading"]) or not _integer(sweep.packet_id,1,2147483647) or sweep_seen.has(sweep.packet_id):return false
		if not _point(sweep.from) or not _point(sweep.to) or not sweep.heading is Vector2 or not sweep.heading.is_finite() or absf(sweep.heading.length_squared()-1.0)>.00001:return false
		var delta:Vector2=sweep.to-sweep.from
		if delta.length()>MAX_SWEEP+EPSILON or delta.dot(sweep.heading)<-EPSILON or absf(delta.cross(sweep.heading))>EPSILON:return false
		sweep_seen[sweep.packet_id]=true;packet_ids[sweep.packet_id]=true
	if packet_ids.size()>PACKET_LIMIT:return false
	var identities:Dictionary={};var slots:Dictionary={}
	for enemy in enemies:
		if not _keys(enemy,["slot","identity","kind","pos"]) or not _integer(enemy.slot,0,255) or not enemy.identity is int or enemy.identity<1 or identities.has(enemy.identity) or slots.has(enemy.slot) or not _integer(enemy.kind,0,4) or not _point(enemy.pos):return false
		identities[enemy.identity]=true;slots[enemy.slot]=true
	return true

static func _closest(point:Vector2,from:Vector2,to:Vector2)->Vector2:
	var delta:=to-from
	if delta.length_squared()<EPSILON*EPSILON:return from
	return from+delta*clampf((point-from).dot(delta)/delta.length_squared(),0,1)

static func _point(value:Variant)->bool:
	return value is Vector2 and value.is_finite() and Catalog.BOUNDS.has_point(value)

static func _integer(value:Variant,minimum:int,maximum:int)->bool:
	return value is int and value>=minimum and value<=maximum

static func _keys(value:Variant,fields:Array)->bool:
	return value is Dictionary and value.size()==fields.size() and value.has_all(fields)

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"moves":[],"contacts":0,"reason":reason}
