class_name FurCoastalSculptAssets
extends RefCounted
const ROOT:="res://assets/art/eighthour_v1/coast/"
const STONE=preload("res://assets/art/eighthour_v1/sculpted_stone.gdshader")
const GROUND=preload("res://assets/art/eighthour_v1/living_ground.gdshader")
static var scenes:Dictionary={}
static var materials:Dictionary={}
static func instance(asset:String)->Node3D:
	if asset.begins_with("sculpted_island_"):asset=asset.replace("sculpted_island_","continuous_island_v10_")
	if asset=="island_tree_recessed_canopy":asset="island_tree_rounded_leaves_v4"
	if asset=="coastal_leaf_shrub":asset="coastal_rounded_shrub_v4"
	if not scenes.has(asset):scenes[asset]=load(ROOT+asset+".glb")
	var result:Node3D=(scenes[asset] as PackedScene).instantiate();_finish(result);return result
static func _finish(node:Node)->void:
	if node is MeshInstance3D:
		var source_path:String=node.mesh.resource_path
		if "shrub" in source_path:node.lod_bias=.24
		elif "tree_rounded" in source_path:node.lod_bias=.34
		else:node.lod_bias=.75
		for i in node.mesh.get_surface_count():
			var original:=node.mesh.surface_get_material(i) as StandardMaterial3D
			if original==null:continue
			var key:=original.get_instance_id()
			if not materials.has(key):
				if original.resource_name.begins_with("CoastalScan_"):
					var stone:=ShaderMaterial.new();stone.shader=STONE;stone.set_shader_parameter("scan_color",original.albedo_texture);stone.set_shader_parameter("scan_normal",original.normal_texture)
					if original.ao_texture:stone.set_shader_parameter("scan_orm",original.ao_texture)
					materials[key]=stone
				elif original.resource_name.begins_with("ContinuousCoastBaked"):
					var coast:=ShaderMaterial.new();coast.shader=load("res://assets/art/eighthour_v1/continuous_coast.gdshader");coast.set_shader_parameter("surface_color",original.albedo_texture);coast.set_shader_parameter("surface_normal",original.normal_texture);materials[key]=coast
				elif original.resource_name.begins_with("Painted_PathAwareGround"):
					var ground:=ShaderMaterial.new();ground.shader=GROUND;ground.set_shader_parameter("surface_noise",FurPartySurfaceNoise.texture());materials[key]=ground
				else:
					var material:StandardMaterial3D=original.duplicate()
					if original.resource_name.begins_with("Painted_"):material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=false;material.roughness=.9
					if original.resource_name.begins_with("CoastalTree_"):
						material.roughness=.86;material.normal_scale=.48
						if "leaves" in original.resource_name or "branches" in original.resource_name:
							material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.40;material.cull_mode=BaseMaterial3D.CULL_DISABLED
					materials[key]=material
			node.set_surface_override_material(i,materials[key])
	for child in node.get_children():_finish(child)
