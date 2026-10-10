class_name FurSoftCharacterAssets
extends RefCounted
## Attributed reference characters with locally adapted groom and gait.
## Original authored props and all legacy character files remain preserved.
const PATHS:=FurApprovedCharacter.MODELS
const WEAPON_PATHS:=["res://assets/art/sevenhour_v1/weapon_pan_atelier.glb","res://assets/art/sevenhour_v1/weapon_blaster_atelier.glb","res://assets/art/sevenhour_v1/weapon_cookie_atelier.glb"]
const HAT_PATHS:=["res://assets/art/sevenhour_v1/hat_cookpot_atelier.glb","res://assets/art/sevenhour_v1/hat_mechanic_atelier.glb","res://assets/art/sevenhour_v1/hat_pastry_beret_atelier.glb"]
const GroomedFur=preload("res://scripts/party/party_groomed_fur.gd")
const DenseFur=preload("res://scripts/party/party_dense_fur.gd")
const PropFinish=preload("res://scripts/party/party_prop_finish.gd")
static var _scenes:Dictionary={}
static var _materials:Dictionary={}
static var _fur_counts:Dictionary={}
static var _grain:NoiseTexture2D

static func instantiate(index:int)->Node3D:
	return FurApprovedCharacter.instantiate(clampi(index,0,1))

static func weapon(style:int)->Node3D:
	return FurTravelArtAssets.instance(["weapon_pan_atelier","weapon_blaster_atelier","weapon_cookie_atelier"][clampi(style,0,2)])

static func hat(style:int)->Node3D:
	return FurTravelArtAssets.instance(["hat_cookpot_atelier","hat_mechanic_atelier","hat_pastry_beret_atelier"][clampi(style,0,2)])

static func _instance(path:String)->Node3D:
	if not _scenes.has(path):_scenes[path]=load(path)
	var result:Node3D=(_scenes[path] as PackedScene).instantiate()
	var fur_triangles:int=_finish_surfaces(result)
	result.set_meta("fur_extra_triangles",fur_triangles)
	return result

static func _finish_surfaces(node:Node,remaining:int=150000)->int:
	if node.has_meta("short_fur_shell"):return 0
	var extra:int=0
	if node is MeshInstance3D:
		var instance:MeshInstance3D=node
		# Catchlights and the small glass islands sit against an opaque sculpted
		# head. Keep the body/ears/clothes/hat shadow silhouette; these embedded
		# eye details do not need additional directional shadow submissions.
		if str(instance.name).begins_with("EyeSurface_"):
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.set_meta("embedded_eye_shadow_omitted",true)
		for surface in instance.mesh.get_surface_count():
			var original:Material=instance.mesh.surface_get_material(surface)
			if original is StandardMaterial3D:
				instance.set_surface_override_material(surface,_soft_material(original))
				if original.resource_name.begins_with("ShortFurGeometry") or original.resource_name.begins_with("DenseFurGeometry"):
					instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					instance.set_meta("physical_short_fur",true)
					# The bounded cached scenes share imported meshes between avatars,
					# pawns and table figures. Read large hair arrays once per surface.
					var count_key:String=str(instance.mesh.get_instance_id())+":"+str(surface)
					if not _fur_counts.has(count_key):
						var arrays:Array=instance.mesh.surface_get_arrays(surface)
						var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
						_fur_counts[count_key]=indices.size()/3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
					extra+=int(_fur_counts[count_key])
	for child:Node in node.get_children():extra+=_finish_surfaces(child,remaining-extra)
	return extra

static func _soft_material(original:StandardMaterial3D)->Material:
	if original.resource_name.begins_with("DenseFurGeometry"):return DenseFur.material()
	if original.resource_name.begins_with("ShortFurGeometry"):return GroomedFur.material()
	var key:int=original.get_instance_id()
	if _materials.has(key):return _materials[key]
	var material:StandardMaterial3D=original.duplicate()
	var name:String=original.resource_name
	# Importing a white glTF material with COLOR_0 does not consistently enable
	# this flag for every material. Only sculpt-painted groups opt into it;
	# merged plain-color cloth/eyes must not multiply an absent/default attribute.
	if name=="SoftFurSculpt" or name=="EarVelvetSculpt":material.vertex_color_use_as_albedo=true
	if name.begins_with("WovenCloth"):
		if _grain==null:
			var noise:=FastNoiseLite.new();noise.seed=7413;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=.12;noise.fractal_octaves=2
			_grain=NoiseTexture2D.new();_grain.width=128;_grain.height=128;_grain.noise=noise;_grain.seamless=true;_grain.as_normal_map=true;_grain.bump_strength=.32
		material.normal_enabled=true;material.normal_texture=_grain;material.normal_scale=.15 if name.begins_with("Woven") else .10
		material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*18.0 if name.begins_with("Woven") else Vector3(55,18,55)
		material.roughness=.91 if name.begins_with("Woven") else .94;material.metallic_specular=.25 if name.begins_with("Woven") else .10
		if not name.begins_with("Woven"):material.rim_enabled=true;material.rim=.07;material.rim_tint=.42
	if name.begins_with("SoftFur") or name.begins_with("CreamFur") or name.begins_with("EarVelvet"):
		# Actual groom geometry supplies the fibre structure. Triplanar simplex
		# normal previously read as woven mesh on skin; keep it on clothes only.
		material.normal_enabled=false;material.roughness=.98;material.metallic_specular=.055
		material.rim_enabled=true;material.rim=.10;material.rim_tint=.35
	if name.begins_with("GlassEye"):
		material.clearcoat_enabled=true;material.clearcoat=.35;material.clearcoat_roughness=.2
	if PropFinish.recognized(name):PropFinish.apply(material,name)
	_materials[key]=material
	return material

static func catalog()->Dictionary:
	return {"version":11,"candidate":"Approved source silhouette with real short-fibre groom; original crafted accessories","characters":PATHS.duplicate(),"weapons":WEAPON_PATHS.duplicate(),"hats":HAT_PATHS.duplicate(),"enemies":FurPartyEnemyGeometry.PATHS.duplicate(),"legacy_policy":"Original GLB retained; board, arena, menu and table consume this version.","rig":"Body and groom carry original source skin weights into a shared distance-driven vertex gait.","source":"Characters: Recreate Games via FurryModels community distribution; commercial license unverified. Accessories and scenery: original local Blender work."}
