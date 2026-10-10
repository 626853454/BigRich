extends Node3D
# Five fixed rings follow the same stable identities used by authority receipts.
var markers:Array[MeshInstance3D]=[]
var last_simulation_now:=-1.0
var stale_age:=0.0
func _ready()->void:
	var shape:=TorusMesh.new();shape.inner_radius=.40;shape.outer_radius=.53
	shape.rings=20;shape.ring_segments=6
	var material:=StandardMaterial3D.new();material.albedo_color=Color("ffdc70")
	material.roughness=.9;material.emission_enabled=true
	material.emission=material.albedo_color;material.emission_energy_multiplier=.4
	for index in 5:
		var marker:=MeshInstance3D.new();marker.mesh=shape;marker.material_override=material
		marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible=false;add_child(marker);markers.append(marker)
func clear()->void:
	for marker in markers:marker.visible=false
	last_simulation_now=-1;stale_age=0
func render(state:Dictionary,pool:FurEntityPool,motion:FurNetworkMotion,now:float,network:bool,simulation_now:float,delta:float)->void:
	if not is_node_ready():return
	for marker in markers:marker.visible=false
	if simulation_now!=last_simulation_now:last_simulation_now=simulation_now;stale_age=0
	else:stale_age+=maxf(0,delta)
	if network and stale_age>=.75:return
	if state.is_empty() or not state.accepted or state.phase!="marked":return
	if simulation_now+(stale_age if network else 0)>float(state.deadline):return
	for index in state.group.size():
		var target:Dictionary=state.group[index];var slot:int=target.slot
		if pool.rank[slot]<0 or pool.identity[slot]!=target.identity:continue
		if state.killed_records.any(func(record):return record.identity==target.identity):continue
		var point:Vector2=pool.pos[slot]
		if network:point=motion.sample(target.identity,point,now)
		markers[index].position=Vector3(point.x,.11,point.y);markers[index].visible=true
