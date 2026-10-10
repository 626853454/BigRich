class_name FurMahjongNightMeshBatch
extends RefCounted

# The authored night props are opaque, untextured, unskinned material islands.
# Preserve every vertex/normal and material parameter in one draw surface.
# Editable GLBs and Blender material assignments remain the source of truth.
static var _cache:Dictionary={}
static var _material:ShaderMaterial

static func combine_children(source:Node3D)->bool:
	# Keep the original node pivot and children for editable/reference identity.
	# This path is used only for opaque, untextured, rigid PBR tableware.
	var data:Dictionary={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"uv":PackedVector2Array(),"uv2":PackedVector2Array(),"indices":PackedInt32Array(),"valid":true}
	for child in source.get_children():_collect(child,Transform3D.IDENTITY,data)
	if not data.valid or data.vertices.is_empty():return false
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_COLOR]=data.colors;arrays[Mesh.ARRAY_TEX_UV]=data.uv;arrays[Mesh.ARRAY_TEX_UV2]=data.uv2;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_ensure_material()
	for child in source.get_children():
		if child is Node3D:child.hide()
	var instance:=MeshInstance3D.new();instance.name="PreservedPBRBatch";instance.mesh=mesh;instance.material_override=_material;source.add_child(instance)
	return true

static func _ensure_material()->void:
	if _material!=null:return
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode cull_disabled; void fragment(){ ALBEDO=COLOR.rgb; ROUGHNESS=UV.x; METALLIC=UV.y; CLEARCOAT=UV2.x; CLEARCOAT_ROUGHNESS=UV2.y; }"
	_material=ShaderMaterial.new();_material.shader=shader

static func instantiate(path:String)->Node3D:
	var packed:PackedScene=load(path)
	var baked:String="res://assets/mahjong_night/batched/"+path.get_file().get_basename()+".res"
	if not _cache.has(path) and ResourceLoader.exists(baked):_cache[path]=load(baked)
	if not _cache.has(path):
		var source:Node3D=packed.instantiate()
		var data:Dictionary={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"uv":PackedVector2Array(),"uv2":PackedVector2Array(),"indices":PackedInt32Array(),"valid":true}
		_collect(source,Transform3D.IDENTITY,data)
		if not data.valid:source.free();return packed.instantiate()
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_COLOR]=data.colors
		arrays[Mesh.ARRAY_TEX_UV]=data.uv;arrays[Mesh.ARRAY_TEX_UV2]=data.uv2;arrays[Mesh.ARRAY_INDEX]=data.indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);_cache[path]=mesh;source.free()
	_ensure_material()
	var root:=Node3D.new();root.name=path.get_file().get_basename()+"_batched"
	var instance:=MeshInstance3D.new();instance.name="PreservedMaterialIslands";instance.mesh=_cache[path];instance.material_override=_material;root.add_child(instance)
	return root

static func _collect(node:Node,transform:Transform3D,data:Dictionary)->void:
	var local:Transform3D=transform
	if node is Node3D:local=transform*node.transform
	if node is MeshInstance3D and node.mesh!=null:
		if node.skin!=null:data.valid=false;return
		for surface in node.mesh.get_surface_count():
			var material:Material=node.get_active_material(surface)
			if not material is StandardMaterial3D:data.valid=false;return
			if material.albedo_texture!=null or material.normal_enabled or material.emission_enabled or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:data.valid=false;return
			var arrays:Array=node.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var offset:int=data.vertices.size();var color:Color=material.albedo_color.srgb_to_linear()
			var normal_basis:Basis=local.basis.inverse().transposed()
			for i in vertices.size():
				data.vertices.append(local*vertices[i]);data.normals.append((normal_basis*normals[i]).normalized());data.colors.append(color)
				data.uv.append(Vector2(material.roughness,material.metallic));data.uv2.append(Vector2(material.clearcoat if material.clearcoat_enabled else 0.0,material.clearcoat_roughness))
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():data.indices.append(offset+i)
			else:
				for index in indices:data.indices.append(offset+index)
	for child in node.get_children():_collect(child,local,data)
