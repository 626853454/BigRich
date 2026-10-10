class_name FurTravelArtAssets
extends RefCounted
## Original Blender accessories; approved character geometry is left intact.
const ROOT:="res://assets/art/sevenhour_v1/"
static var _scenes:Dictionary={}
static var _materials:Dictionary={}
static var _weave:NoiseTexture2D
static func instance(asset:String,atelier:bool=false)->Node3D:
	var path:String=ROOT+asset+".glb"
	if atelier:path="res://assets/art/eighthour_v1/"+asset+".glb"
	if not _scenes.has(path):_scenes[path]=load(path)
	var object:Node3D=(_scenes[path] as PackedScene).instantiate()
	_finish(object,atelier);return object
static func _finish(node:Node,atelier:bool=false)->void:
	if node is MeshInstance3D:
		var mesh_node:MeshInstance3D=node
		var mesh_path:String=mesh_node.mesh.resource_path
		if "garden_bush" in mesh_path or "living_garden" in mesh_path:mesh_node.lod_bias=.24
		elif "garden_tree" in mesh_path or "bamboo" in mesh_path:mesh_node.lod_bias=.34
		elif "cloud_bank" in mesh_path:mesh_node.lod_bias=.5;mesh_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_node.mesh.get_surface_count():
			var original:=mesh_node.mesh.surface_get_material(surface) as StandardMaterial3D
			if original==null:continue
			var key:int=original.get_instance_id()
			if not _materials.has(key):
				if original.resource_name.contains("CloudBillows"):
					var cloud:=ShaderMaterial.new();cloud.shader=load("res://assets/art/eighthour_v1/cloud_soft_scatter.gdshader");_materials[key]=cloud;mesh_node.set_surface_override_material(surface,cloud);continue
				if atelier and original.resource_name.begins_with("Furniture"):
					_materials[key]=FurFurnitureMaterials.surface(original.resource_name);mesh_node.set_surface_override_material(surface,_materials[key]);continue
				if atelier and original.resource_name.begins_with("WovenCloth"):
					var fabric:=ShaderMaterial.new();fabric.shader=load("res://assets/art/eighthour_v1/woven_cloth.gdshader")
					fabric.set_shader_parameter("fabric_color",original.albedo_color)
					_materials[key]=fabric;mesh_node.set_surface_override_material(surface,fabric);continue
				if original.resource_name.begins_with("TaggedPainted_"):
					var crafted:=FurPartyEnvironmentMaterial.material(-1,-100.0,false).duplicate() as ShaderMaterial
					crafted.set_shader_parameter("grain_strength_scale",1.5);crafted.set_shader_parameter("relief_strength",.0035)
					_materials[key]=crafted
					mesh_node.set_surface_override_material(surface,_materials[key]);continue
				var mat:=original.duplicate() as StandardMaterial3D
				if original.resource_name.begins_with("Painted_"):mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=false
				if original.resource_name.begins_with("WovenCloth"):
					if _weave==null:
						var noise:=FastNoiseLite.new();noise.seed=1908;noise.frequency=.28;noise.fractal_octaves=1
						_weave=NoiseTexture2D.new();_weave.width=128;_weave.height=128;_weave.seamless=true;_weave.as_normal_map=true;_weave.noise=noise;_weave.bump_strength=.16
					mat.normal_enabled=true;mat.normal_texture=_weave;mat.normal_scale=.11;mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*19;mat.roughness=.88;mat.metallic_specular=.24
				elif original.resource_name.begins_with("Enamel"):
					mat.clearcoat_enabled=true;mat.clearcoat=.22;mat.clearcoat_roughness=.23
				_materials[key]=mat
			mesh_node.set_surface_override_material(surface,_materials[key])
	for child:Node in node.get_children():_finish(child,atelier)
