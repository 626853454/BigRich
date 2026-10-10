class_name FurPartyContractMarker
extends Node3D
## One reusable, physical notice standard. Rendering only; the model owns expiry.
const Map=preload("res://scripts/party/party_map.gd")
const Palette=preload("res://scripts/party/party_world_palette.gd")
const OFFSETS:=[Vector2(11.7,2.5),Vector2(11.3,2.3),Vector2(11.7,-2.5)]
var _built:bool=false
var _flag_material:StandardMaterial3D
var _deadline:Label3D
var displayed_district:int=-1

static func anchor(district:int)->Vector3:
	if district<0 or district>=3:return Vector3.ZERO
	var center:Vector3=Map.districts()[district].center;var offset:Vector2=OFFSETS[district]
	return center+Vector3(offset.x,-.22,offset.y)

func build()->void:
	if _built:return
	_built=true;name="JointContractStandard";visible=false
	var stone:=_material(Palette.STONE);var wood:=_material(Color("735b46"));var copper:=_material(Color("ae8859"));var dark:=_material(Color("524741"));var cream:=_material(Palette.CREAM)
	_cylinder(Vector3(0,.08,0),.16,.46,stone)
	_cylinder(Vector3(0,.23,0),.20,.32,stone)
	_cylinder(Vector3(0,1.43,0),2.3,.064,wood)
	for height:float in [.36,1.62,2.46]:_cylinder(Vector3(0,height,0),.10,.085,copper)
	_sphere(Vector3(0,2.62,0),Vector3(.16,.16,.16),copper)
	_box(Vector3(.80,2.43,0),Vector3(1.69,.065,.075),wood)
	_flag_material=_material(Map.COLOURS[0].darkened(.05));_flag_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 8:
		var x0:float=.08+column*.19;var x1:float=x0+.19
		var z0:float=.026*sin(float(column)*.7);var z1:float=.026*sin(float(column+1)*.7)
		var low0:float=1.63+.08*sin(float(column)*.45);var low1:float=1.63+.08*sin(float(column+1)*.45)
		var points:Array[Vector3]=[Vector3(x0,low0,z0),Vector3(x1,low1,z1),Vector3(x1,2.39,z1),Vector3(x0,2.39,z0)]
		for idx:int in [0,2,1,0,3,2]:surface.add_vertex(points[idx])
	surface.generate_normals();_mesh(surface.commit(),Vector3.ZERO,Vector3.ONE,_flag_material)
	# Copper linked loops communicate partnership, unlike the yellow star-bell destination.
	for x:float in [.69,.99]:
		var loop:=TorusMesh.new();loop.inner_radius=.135;loop.outer_radius=.187;loop.rings=18;loop.ring_segments=6
		var icon:MeshInstance3D=_mesh(loop,Vector3(x,2.025,.088),Vector3.ONE,cream);icon.rotation.x=PI/2
	# The text is mounted to a real wooden plaque, never a floating HUD or billboard.
	_box(Vector3(.68,1.08,.02),Vector3(1.40,.47,.115),wood)
	_box(Vector3(.68,1.08,.087),Vector3(1.23,.33,.027),dark)
	for x:float in [.10,1.26]:_sphere(Vector3(x,1.08,.109),Vector3(.035,.035,.024),copper)
	_deadline=Label3D.new();_deadline.name="DeadlineOnPlaque";_deadline.font_size=32;_deadline.pixel_size=.006;_deadline.position=Vector3(.68,1.08,.113);_deadline.modulate=Palette.CREAM;_deadline.outline_size=3;_deadline.outline_modulate=Color("3e3939");add_child(_deadline)

func show_contract(contract:Dictionary)->void:
	build();visible=false;displayed_district=-1
	if contract.is_empty():return
	for key:String in ["target_district","sponsor","expires_round"]:
		if typeof(contract.get(key))!=TYPE_INT:return
	var district:int=contract.target_district;var sponsor:int=contract.sponsor;var deadline:int=contract.expires_round
	if district<0 or district>2 or sponsor<0 or sponsor>1 or deadline<1 or deadline>7:return
	position=anchor(district);displayed_district=district
	_flag_material.albedo_color=Map.COLOURS[sponsor].darkened(.05)
	_deadline.text="截止第%d轮"%deadline;visible=true

func _material(colour:Color)->StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_color=colour;result.roughness=.88;result.metallic_specular=.28;return result

func _mesh(shape:Mesh,point:Vector3,size3:Vector3,material:Material)->MeshInstance3D:
	var result:=MeshInstance3D.new();result.mesh=shape;result.position=point;result.scale=size3;result.material_override=material;add_child(result);return result

func _cylinder(point:Vector3,height:float,radius:float,material:Material)->void:
	var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=16;_mesh(shape,point,Vector3.ONE,material)

func _box(point:Vector3,size3:Vector3,material:Material)->void:
	var shape:=BoxMesh.new();shape.size=size3;_mesh(shape,point,Vector3.ONE,material)

func _sphere(point:Vector3,size3:Vector3,material:Material)->void:
	var shape:=SphereMesh.new();shape.radius=.5;shape.height=1.0;shape.radial_segments=12;shape.rings=6;_mesh(shape,point,size3,material)
