extends Node3D
# Two fixed candidate markers. Authority alone decides whether a full group is safe.
var markers:Array[MeshInstance3D]=[]
var last_elapsed:=-1.0
var stale_age:=0.0
func _ready()->void:
	var shape:=TorusMesh.new();shape.inner_radius=.70;shape.outer_radius=.88
	shape.rings=24;shape.ring_segments=6
	var material:=StandardMaterial3D.new();material.albedo_color=Color("77dfff")
	material.roughness=.9;material.emission_enabled=true
	material.emission=material.albedo_color;material.emission_energy_multiplier=.55
	for index in 2:
		var marker:=MeshInstance3D.new();marker.mesh=shape;marker.material_override=material
		marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible=false;add_child(marker);markers.append(marker)
func clear()->void:
	for marker in markers:marker.visible=false
	last_elapsed=-1;stale_age=0
func render(preview:Dictionary,now:float,delta:float,network:bool=false)->void:
	if not is_node_ready():return
	if now!=last_elapsed:last_elapsed=now;stale_age=0
	else:stale_age+=maxf(0,delta)
	for marker in markers:marker.visible=false
	if preview.is_empty() or (network and stale_age>=.75):return
	if now+(stale_age if network else 0)>=float(preview.expires_at):return
	for index in 2:
		var point:Vector2=preview.markers[index]
		markers[index].position=Vector3(point.x,.10,point.y);markers[index].visible=true
