class_name FurApprovedCharacter
extends RefCounted
const MODELS=["res://assets/party/characters/approved_v1/nemo_reference.glb","res://assets/party/characters/approved_v1/bear_reference.glb"]
const COAT=preload("res://assets/party/characters/approved_v1/soft_coat.gdshader")
const GROOM=preload("res://assets/party/characters/approved_v1/coat_fibres.gdshader")
const SKIN=preload("res://assets/party/characters/approved_v1/coat_surface.gdshader")
static var _noise:ImageTexture
static var _scenes:Dictionary={}
static var revised_models_enabled:bool=true
static func instantiate(index:int=0,atelier:bool=false,groom_style:String="layered_v1")->Node3D:
	if revised_models_enabled and not atelier:atelier=true;groom_style="shell_v17"
	var path:String=MODELS[clampi(index,0,1)]
	if atelier:path="res://assets/art/eighthour_v1/characters/%s_%s.glb"%[("nemo" if index==0 else "bear"),groom_style]
	if not _scenes.has(path):_scenes[path]=load(path)
	var root:=Node3D.new();root.name="ApprovedNemoReference" if index==0 else "MatchingBearReference"
	var rig:=Node3D.new();rig.name="SoftBodyRig";root.add_child(rig)
	var model:Node3D=(_scenes[path] as PackedScene).instantiate();rig.add_child(model)
	var materials:Array[ShaderMaterial]=[]
	_finish(model,materials)
	if atelier:
		for mat:ShaderMaterial in materials:
			mat.set_shader_parameter("coat_character",index)
			if mat.shader==SKIN:mat.set_shader_parameter("surface_relief",.0010);mat.set_shader_parameter("sheen_strength",.16)
			mat.set_shader_parameter("refined_muzzle",groom_style in ["shell_v11","shell_v12","shell_v13","shell_v14","shell_v15","shell_v16","shell_v17"])
			if mat.shader.resource_path.ends_with("shell_groom.gdshader"):
				if groom_style in ["shell_v14","shell_v15","shell_v16","shell_v17"]:
					mat.set_shader_parameter("flowing_clumps",true);mat.set_shader_parameter("fibre_density",290.0);mat.set_shader_parameter("coat_depth",.011 if groom_style=="shell_v17" else .033);mat.set_shader_parameter("clump_relief",.00035)
				mat.set_shader_parameter("tailored_fur_mask",groom_style in ["shell_v9","shell_v11","shell_v12","shell_v13","shell_v14","shell_v15","shell_v16","shell_v17"])
				mat.set_shader_parameter("legacy_mouth_cut",groom_style in ["shell_v4","shell_v5"])
				mat.set_shader_parameter("eye_center",Vector2(.19825,2.0389) if index==0 else Vector2(.14819,2.15104))
				mat.set_shader_parameter("eye_radius",Vector2(.090,.11) if index==0 else Vector2(.076,.075))
		if groom_style in ["shell_v2","shell_v3","shell_v4","shell_v5","shell_v6","shell_v7","shell_v8","shell_v9","shell_v10","shell_v11","shell_v12","shell_v13","shell_v14","shell_v15","shell_v16","shell_v17"]:
			for mesh_node:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				for i in mesh_node.mesh.get_surface_count():
					var eye_material:Material=mesh_node.get_surface_override_material(i)
					if eye_material is StandardMaterial3D and eye_material.resource_name.begins_with("NemoEyes"):
						eye_material.albedo_texture=null;eye_material.albedo_color=Color("17100d");eye_material.roughness=.18;eye_material.clearcoat=.65
	var outfit_asset:String=("nemo_travel_outfit" if index==0 else "bear_travel_outfit")+("_v4" if groom_style=="shell_v17" else ("_v3" if groom_style in ["shell_v15","shell_v16"] else ""))
	var outfit:=FurTravelArtAssets.instance(outfit_asset,atelier and groom_style in ["shell_v3","shell_v4","shell_v5","shell_v6","shell_v7","shell_v8","shell_v9","shell_v10","shell_v11","shell_v12","shell_v13","shell_v14","shell_v15","shell_v16","shell_v17"]);outfit.name="FittedTravelNeckerchief";rig.add_child(outfit)
	if index==1:
		var cap:=FurTravelArtAssets.instance("bear_travel_cap_v4" if groom_style=="shell_v17" else ("bear_travel_cap_v3" if groom_style in ["shell_v15","shell_v16"] else "bear_travel_cap"),atelier and groom_style in ["shell_v3","shell_v4","shell_v5","shell_v6","shell_v7","shell_v8","shell_v9","shell_v10","shell_v11","shell_v12","shell_v13","shell_v14","shell_v15","shell_v16","shell_v17"]);cap.name="TravelSailorCap";rig.add_child(cap)
	root.set_meta("approved_coat_materials",materials)
	root.set_meta("model_source","Party Animals / Recreate Games, FurryModels community distribution; local reference")
	return root
static func _finish(node:Node,materials:Array[ShaderMaterial])->void:
	if node is MeshInstance3D:
		var instance:MeshInstance3D=node
		if str(instance.name).begins_with("Collar"):instance.visible=false
		for i in instance.mesh.get_surface_count():
			var original:StandardMaterial3D=instance.mesh.surface_get_material(i) as StandardMaterial3D
			if original==null:continue
			if original.resource_name.begins_with("NemoBody") or original.resource_name.begins_with("NemoGroom"):
				var skin:=ShaderMaterial.new();skin.shader=SKIN;skin.set_shader_parameter("coat_texture",original.albedo_texture);skin.set_shader_parameter("fibre_noise",_fibre_noise());instance.set_surface_override_material(i,skin);materials.append(skin)
				if original.resource_name.begins_with("NemoGroom"):
					skin.shader=load("res://assets/art/eighthour_v1/characters/layered_groom.gdshader") if original.resource_name.begins_with("NemoGroomLayered") else GROOM;skin.set_shader_parameter("clump_coverage",load("res://assets/art/eighthour_v1/characters/curved_clumps_coverage_v2.png"));instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					if original.resource_name.begins_with("NemoGroomShell"):skin.shader=load("res://assets/art/eighthour_v1/characters/shell_groom.gdshader")
					instance.lod_bias=.35;instance.visibility_range_end=28.0;instance.visibility_range_end_margin=2.0

			else:
				var mat:StandardMaterial3D=original.duplicate();mat.vertex_color_use_as_albedo=false
				if original.resource_name.begins_with("NemoEyes"):mat.roughness=.16;mat.clearcoat_enabled=true;mat.clearcoat=.5;mat.clearcoat_roughness=.12
				elif original.resource_name.begins_with("NemoMouth"):mat.roughness=.96;mat.metallic_specular=0.0;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
				elif original.resource_name.begins_with("NemoTongue"):mat.roughness=.62;mat.metallic_specular=.2
				elif original.resource_name.begins_with("NemoNose"):
					mat.roughness=.39;mat.metallic_specular=.30;mat.clearcoat_enabled=true;mat.clearcoat=.10
				elif original.resource_name.begins_with("NemoBrow"):mat.roughness=.94;mat.metallic_specular=.10
				else:mat.roughness=.45
				instance.set_surface_override_material(i,mat)
	for child:Node in node.get_children():
		if child.name!="SoftShortCoat":_finish(child,materials)
static func use_table_undercoat(character:Node3D,index:int)->void:
	var target:=character.find_child("BoundedShellGroom",true,false) as MeshInstance3D
	if target==null:return
	var path:String="res://assets/mahjong_teahouse/%s_table_animated.glb"%("nemo" if index==0 else "bear")
	if not _scenes.has(path):_scenes[path]=load(path)
	var source:Node3D=(_scenes[path] as PackedScene).instantiate()
	var meshes:Array=source.find_children("*","MeshInstance3D",true,false)
	for mesh_node:MeshInstance3D in meshes:
		var destination:=character.find_child(str(mesh_node.name),true,false) as MeshInstance3D
		if destination!=null:destination.mesh=mesh_node.mesh
	source.free()
	for material:ShaderMaterial in character.get_meta("approved_coat_materials",[]):
		if material.shader.resource_path.ends_with("shell_groom.gdshader"):material.set_shader_parameter("tabletop_detail",true)
static func motion(character:Node3D,phase:float,weight:float)->void:
	for material:ShaderMaterial in character.get_meta("approved_coat_materials",[]):
		material.set_shader_parameter("gait_phase",phase);material.set_shader_parameter("gait_weight",weight)
static func _fibre_noise()->ImageTexture:
	if _noise!=null:return _noise
	var image:=Image.create(256,256,false,Image.FORMAT_RF)
	var random:=RandomNumberGenerator.new();random.seed=170210
	for y in 256:
		for x in 256:image.set_pixel(x,y,Color(random.randf(),0,0,1))
	image.generate_mipmaps();_noise=ImageTexture.create_from_image(image);return _noise
