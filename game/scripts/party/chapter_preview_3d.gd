class_name FurChapterPreview3D
extends Control
## Decorative real 3D chapter dioramas. No board/domain/hand snapshot is consumed.
## Frozen render at rest; only an explicit short focus tween requests live frames.
const Shapes=preload("res://scripts/party/pawn_geometry.gd")
const Tiles=preload("res://scripts/party/mahjong_tile_geometry.gd")
const Surfaces=preload("res://scripts/party/mahjong_surface_materials.gd")
const Lighting=preload("res://scripts/art/art_lighting.gd")
const HeroHouse=preload("res://scripts/party/party_harbor_house_geometry.gd")
const TreeShapes=preload("res://scripts/party/party_tree_geometry.gd")
const PREVIEW_SIZE:=Vector2i(512,440)
var chapter:int=0
var scene_view:SubViewport
var diorama:Node3D
var _built:bool=false
var _hover:Tween
var _materials:Dictionary={}
static var _small_box:ArrayMesh

func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true

func configure(index:int)->void:
	chapter=clampi(index,0,2)
	if _built:_rebuild()

func _ready()->void:
	scene_view=SubViewport.new();scene_view.name="DecorativeChapterViewport"
	# Cards are about398px wide: the former320 texture was being magnified.
	# These three bounded targets stay frozen except the existing .22s focus.
	scene_view.size=PREVIEW_SIZE;scene_view.own_world_3d=true
	scene_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	scene_view.msaa_3d=Viewport.MSAA_4X;scene_view.transparent_bg=false;add_child(scene_view)
	var picture:=TextureRect.new();picture.name="FrozenChapterTexture"
	picture.texture=scene_view.get_texture();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var rounded:=ShaderMaterial.new();rounded.shader=preload("res://assets/ui/eighthour_v1/rounded_preview.gdshader");picture.material=rounded
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(picture)
	var stage:=Node3D.new();scene_view.add_child(stage)
	var env:=Environment.new();Lighting.apply(env,chapter)
	env.background_mode=Environment.BG_COLOR
	env.background_color=[Color("93c4d7"),Color("adc4bc"),Color("b7c3db")][chapter]
	FurAtelierLighting.studio(env);env.sky.sky_material.energy_multiplier=.30;env.ssao_enabled=true;env.ssao_radius=.24;env.ssao_intensity=.70;env.glow_enabled=false
	var world:=WorldEnvironment.new();world.environment=env;stage.add_child(world)
	var light:=DirectionalLight3D.new();Lighting.key(light);light.shadow_enabled=true;light.directional_shadow_max_distance=18
	light.light_energy=1.5;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-35,145,0)
	fill.light_color=Color("c3e5f0");fill.light_energy=.24;stage.add_child(fill)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=5.1;camera.position=Vector3(3.5,3.35,7.5);camera.keep_aspect=Camera3D.KEEP_WIDTH
	stage.add_child(camera);camera.look_at(Vector3(0,.83,0));camera.current=true
	diorama=Node3D.new();stage.add_child(diorama);_built=true;_rebuild()

func _rebuild()->void:
	if not _built:return
	if is_instance_valid(_hover):_hover.kill()
	for child in diorama.get_children():diorama.remove_child(child);child.queue_free()
	diorama.rotation.y=-.10
	if chapter==0:_harbor()
	elif chapter==1:_tea()
	else:_echo()
	_merge_geometry()
	scene_view.render_target_update_mode=SubViewport.UPDATE_ONCE

func set_emphasis(value:bool)->void:
	if not _built or FurUIPreferences.reduced_motion:return
	if is_instance_valid(_hover):_hover.kill()
	scene_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_hover=create_tween();_hover.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover.tween_property(diorama,"rotation:y",.06 if value else -.10,.22)
	_hover.finished.connect(func():
		if is_instance_valid(scene_view):scene_view.render_target_update_mode=SubViewport.UPDATE_ONCE)

func diagnostics()->Dictionary:
	return {"chapter":chapter,"decorative":true,"viewport_size":scene_view.size if is_instance_valid(scene_view) else Vector2i.ZERO,"mesh_nodes":diorama.get_child_count() if is_instance_valid(diorama) else 0,"rest_update":SubViewport.UPDATE_ONCE}

func _merge_geometry()->void:
	# Three bounded batches: painted miniature, ceramic tile bodies, tile faces.
	var tools:Dictionary={};var materials:Dictionary={}
	for child:Node in diorama.get_children():
		if not child is MeshInstance3D or child.name=="LitCoastalWaterV2":continue
		var node:MeshInstance3D=child
		var group:String=str(node.get_meta("preview_surface","paint"))
		if not tools.has(group):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);tools[group]=st
			materials[group]=node.material_override
		var st:SurfaceTool=tools[group]
		var normal_basis:Basis=node.transform.basis.inverse().transposed()
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var colours:=PackedColorArray();var indices:=PackedInt32Array()
			if arrays[Mesh.ARRAY_COLOR]!=null:colours=arrays[Mesh.ARRAY_COLOR]
			if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
			for index in indices.size() if not indices.is_empty() else vertices.size():
				var at:int=indices[index] if not indices.is_empty() else index
				var colour:Color=Color.WHITE
				if group=="paint":
					colour=(node.material_override as StandardMaterial3D).albedo_color
					if not colours.is_empty():colour*=colours[at]
				elif not colours.is_empty():colour=colours[at]
				st.set_color(colour);st.set_normal((normal_basis*normals[at]).normalized())
				st.add_vertex(node.transform*vertices[at])
		diorama.remove_child(node);node.queue_free()
	for group in tools:
		var batch:=MeshInstance3D.new();batch.name="MiniatureBatch_"+str(group)
		batch.mesh=tools[group].commit()
		if group=="paint":
			var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true
			material.roughness=.52;batch.material_override=material
		else:batch.material_override=materials[group]
		diorama.add_child(batch)

func _material(colour:Color,roughness:float=.55,metallic:float=0.0)->StandardMaterial3D:
	var key:=colour.to_html()+str(roughness)+str(metallic)
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new();mat.albedo_color=colour.srgb_to_linear()
		mat.roughness=roughness;mat.metallic=metallic;_materials[key]=mat
	return _materials[key]

func _part(mesh:Mesh,at:Vector3,extent:Vector3,colour:Color,rotation:Vector3=Vector3.ZERO)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=_material(colour)
	node.position=at;node.scale=extent;node.rotation_degrees=rotation;diorama.add_child(node);return node

func _box(at:Vector3,extent:Vector3,colour:Color,rotation:Vector3=Vector3.ZERO)->MeshInstance3D:
	return _part(_bevel_box(),at,extent*.5,colour,rotation)

static func _bevel_box()->ArrayMesh:
	if _small_box!=null:return _small_box
	# 108 triangles for a sub-pixel miniature beam, instead of the animal's972.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var values:Array[float]=[-1.0,-.80,.80,1.0]
	for face in 6:
		var axis:int=face/2;var sign_value:float=-1.0 if face%2==0 else 1.0
		for y in 3:
			for x in 3:
				var points:Array[Vector3]=[]
				for uv:Vector2 in [Vector2(values[x],values[y]),Vector2(values[x+1],values[y]),Vector2(values[x+1],values[y+1]),Vector2(values[x],values[y+1])]:
					var point:=Vector3(sign_value,uv.x,uv.y) if axis==0 else (Vector3(uv.y,sign_value,uv.x) if axis==1 else Vector3(uv.x,uv.y,sign_value))
					var inner:=point.clamp(Vector3.ONE*-.8,Vector3.ONE*.8)
					points.append(inner+(point-inner).normalized()*.2)
				for index in [0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]:st.add_vertex(points[index])
	st.generate_normals();_small_box=st.commit();return _small_box

func _cylinder(at:Vector3,radius:float,height:float,colour:Color)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius*1.02
	mesh.height=height;mesh.radial_segments=20;mesh.rings=1
	return _part(mesh,at,Vector3.ONE,colour)

func _sphere(at:Vector3,radius:float,colour:Color)->void:
	var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2
	mesh.radial_segments=16;mesh.rings=8;_part(mesh,at,Vector3.ONE,colour)

func _harbor()->void:
	_asset("harbor_invitation_terrace",Vector3(0,.10,0),.45)
	var water:=FurPartyWaterSurface.sea(diorama,Vector2(16,14),-.63,[{"center":Vector3.ZERO,"radius":Vector2(2.0,1.5)}]);water.material_override.set_shader_parameter("geometry_wave_scale",.35)
	var boat:=FurHarborCraftedAssets.prop("harbor_sailboat_crafted");boat.position=Vector3(-1.15,-.58,1.48);boat.scale=Vector3.ONE*.44;diorama.add_child(boat)
	var house:=FurHarborCraftedAssets.house(Vector3(1.65,1.13,1.17));house.position=Vector3(.70,.14,-.37);diorama.add_child(house)
	_asset("lighthouse_atelier",Vector3(-.88,.12,-.78),.46)
	_asset("garden_tree_atelier",Vector3(1.37,.13,.35),.37)
	_asset("garden_bush_atelier",Vector3(.96,.15,1.11),.39)
	_asset("maritime_lantern",Vector3(.35,.15,1.22),.36)

func _tea()->void:
	_cylinder(Vector3(0,-.08,0),2.1,.22,Color("c8af8d"))
	var table:=FurTravelArtAssets.instance("mahjong_table_sculpted_v2",true);table.position=Vector3(0,.22,.14);table.scale=Vector3.ONE*.195;diorama.add_child(table)
	_asset("tea_pavilion_atelier",Vector3(-.30,.12,-1.14),.63)
	# Symbolic public decorative faces. They are never the user's actual hand.
	for i in 3:
		var tile:=_part(Tiles.body(),Vector3(-.68+i*.66,.68,.33),Vector3(.273,.39,.117),Color("fff0d5"),Vector3(-10,-7+i*7,0))
		tile.material_override=Surfaces.surface("ceramic",Color("faf2e1"))
		tile.set_meta("preview_surface","ceramic")
		var face:=_part(Tiles.face(i),tile.position+tile.basis.orthonormalized()*Vector3(0,0,.025),Vector3.ONE*.65,Color.WHITE,tile.rotation_degrees)
		face.material_override=Tiles.material();face.set_meta("preview_surface","face")
		var jade:=_part(Tiles.body(),tile.position+tile.basis.orthonormalized()*Vector3(0,0,-.06),Vector3(.261,.37,.06),Color("276756"),tile.rotation_degrees)
		jade.set_meta("preview_surface","jade")
	for i in 3:
		var tile:=_part(Tiles.body(),Vector3(-.75+i*.64,.36,-.68),Vector3(.26,.39,.13),Color("fff0d5"),Vector3(-90,0,0))
		tile.material_override=Surfaces.surface("ceramic",Color("faf2e1"))
		tile.set_meta("preview_surface","ceramic")
	_cylinder(Vector3(1.30,.42,-.52),.22,.20,Color("c8e5d5"))
	_cylinder(Vector3(1.30,.53,-.52),.16,.015,Color("6d9c87"))
	_asset("bamboo_atelier",Vector3(-1.60,.29,-.42),.38)
	_box(Vector3(-1.55,.30,-.42),Vector3(.38,.14,.38),Color("dabd92"))
	for x in [-1.55,1.55]:
		_box(Vector3(x,.15,0),Vector3(.13,.38,1.84),Color("957249"))
	_cylinder(Vector3(.96,.45,-.43),.28,.30,Color("e3d5b6"))
	_cylinder(Vector3(.96,.615,-.43),.23,.045,Color("aabda4"))

func _echo()->void:
	_cylinder(Vector3(0,-.05,0),2.1,.24,Color("beb5c9"))
	var echo_case:=FurTravelArtAssets.instance("echo_board_sculpted_v2",true);echo_case.position=Vector3(0,.18,0);echo_case.scale=Vector3.ONE*.42;diorama.add_child(echo_case)
	var clock:=FurTravelArtAssets.instance("echo_clock_sculpted_v2",true);clock.position=Vector3(-.22,.20,-.76);clock.scale=Vector3.ONE*.90;diorama.add_child(clock)
	_asset("echo_mailbox_atelier",Vector3(1.1,.25,.3),.75)
	_asset("echo_pressure_ring_atelier",Vector3(-1.05,.25,.5),.75)
	for actor in 2:
		var x:float=-1.25 if actor==0 else 1.25
		var colour:Color=Color("d29262") if actor==0 else Color("8abae0")
		_cylinder(Vector3(x,.29,.64),.27,.10,colour)
		_sphere(Vector3(x,.56,.64),.20,colour)
		_box(Vector3(x,.88,.64),Vector3(.16,.28,.16),colour)
		for z:float in [.02,-.45]:_cylinder(Vector3(x,.25,z),.10,.035,colour.lightened(.18))

func _asset(asset:String,at:Vector3,uniform_scale:float)->void:
	var model:=FurTravelArtAssets.instance(asset);model.position=at;model.scale=Vector3.ONE*uniform_scale;diorama.add_child(model)
