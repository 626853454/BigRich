class_name FurPlushGait
extends RefCounted

# Small paw deformation for the existing static plush asset. The source GLB is
# untouched. This is a procedural walk layer, not a skeleton or new character.
const WALK_SHADER=preload("res://assets/furball/plush-walk.gdshader")
var materials:Array[ShaderMaterial]=[]
func attach(body:Node3D) -> void:
	materials.clear()
	var meshes:=body.find_children("*","MeshInstance3D",true,false)
	if body is MeshInstance3D:meshes.push_front(body)
	for child in meshes:
		var instance:MeshInstance3D=child
		for surface in instance.mesh.get_surface_count():
			var original:=instance.get_active_material(surface) as StandardMaterial3D
			if original==null:continue
			# Current plush uses six constant-color surfaces. Textured future assets
			# keep their original material rather than silently losing textures.
			if original.albedo_texture!=null:continue
			var material:=ShaderMaterial.new();material.shader=WALK_SHADER
			material.set_shader_parameter("plush_color",original.albedo_color)
			material.set_shader_parameter("plush_roughness",original.roughness)
			material.set_shader_parameter("plush_metallic",original.metallic)
			instance.set_surface_override_material(surface,material);materials.append(material)
func update(phase:float,weight:float,body_height:float) -> void:
	for material in materials:
		material.set_shader_parameter("gait_phase",phase)
		material.set_shader_parameter("gait_weight",clampf(weight,0,1))
		material.set_shader_parameter("body_height",body_height)
