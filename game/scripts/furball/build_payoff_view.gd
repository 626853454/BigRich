class_name FurBuildPayoffView
extends Node3D
const LIMIT:=4
const ChainView = preload("res://scripts/furball/chain_route_view.gd")
var nodes:Array[Dictionary]=[]
var chain_view: ChainView
func _ready() -> void:
	chain_view = ChainView.new(); chain_view.name = "ChainRoute"; add_child(chain_view)
	for index in LIMIT:
		var node:=MeshInstance3D.new();var mesh:=FurFeedbackMeshes.mesh("directional_payoff_wave_atelier")
		node.mesh=mesh;node.visible=false;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color("ffd374")
		material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=false
		node.material_override=material;add_child(node);nodes.append({"node":node,"id":-1})
func _directional_wave_mesh() -> ArrayMesh:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray();var normals:=PackedVector3Array()
	var path:=[Vector3(-1,.0,.2),Vector3(0,.0,-.65),Vector3(1,.0,.2)]
	for index in 2:
		var a:Vector3=path[index];var b:Vector3=path[index+1]
		var side:Vector3=Vector3(-(b-a).z,0,(b-a).x).normalized()*.11
		for point in [a-side,a+side,b+side,a-side,b+side,b-side]:vertices.append(point);colors.append(Color.WHITE);normals.append(Vector3.UP)
	# A pale trail points backward, avoiding confusion with stationary stalls.
	for point in [Vector3(-.82,0,.3),Vector3(.82,0,.3),Vector3(.3,0,1.5),Vector3(-.82,0,.3),Vector3(.3,0,1.5),Vector3(-.3,0,1.5)]:
		vertices.append(point);colors.append(Color(1,1,1,.03 if point.z>1 else .38));normals.append(Vector3.UP)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func clear() -> void:
	for entry in nodes:entry.node.visible=false;entry.id=-1
	if chain_view != null: chain_view.clear()
func render_baits(baits: Variant, low_fx: bool = false) -> Dictionary:
	return chain_view.render_baits(baits, low_fx) if chain_view != null else {"segments":0,"steps":0,"rejected":0}
func render(state:Dictionary,delta:float,low_fx:bool) -> void:
	var waves:Array=state.get("waves",[])
	for index in LIMIT:
		var entry:Dictionary=nodes[index]
		entry.node.visible=index<waves.size()
		if index>=waves.size():entry.id=-1;continue
		var wave:Dictionary=waves[index]
		var position:=Vector3(wave.pos.x,.62,wave.pos.y)
		if entry.id!=wave.id:entry.node.position=position;entry.id=wave.id
		else:entry.node.position=entry.node.position.lerp(position,1-exp(-delta*30))
		entry.node.rotation.y=atan2(-float(wave.direction.x),-float(wave.direction.y))
		entry.node.scale=Vector3(clampf(float(wave.radius),.2,3),1,1)
		var color:=Color("ffffd9") if wave.owner==0 else Color("a1f6ff")
		color.a=.8 if low_fx else .95
		entry.node.material_override.albedo_color=color
