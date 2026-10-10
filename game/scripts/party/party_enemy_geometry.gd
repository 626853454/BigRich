class_name FurPartyEnemyGeometry
extends RefCounted
## Three original sculpted toy silhouettes, one bounded MultiMesh per family.
## Faces -Z. Existing scale, kind mapping, warnings and stable identities preserved.
const PATH:="res://assets/art/eighthour_v1/enemies/enemy_jelly_sculpted_v3.glb"
const PATHS:=[PATH,"res://assets/art/eighthour_v1/enemies/enemy_hermit_sculpted_v3.glb","res://assets/art/eighthour_v1/enemies/enemy_armour_sculpted_v3.glb"]
static var _meshes:Dictionary={}
static var _materials:Dictionary={}

static func mesh(kind:int=0,showcase:bool=false)->ArrayMesh:
	kind=clampi(kind,0,2)
	var cache_key:int=kind+(3 if showcase else 0)
	if _meshes.has(cache_key):return _meshes[cache_key]
	var scene:PackedScene=load(str(PATHS[kind]).replace(".glb","_close.glb") if showcase else PATHS[kind])
	var root:Node=scene.instantiate()
	var surface:MeshInstance3D=_find_mesh(root)
	assert(surface!=null and surface.mesh.get_surface_count()==1)
	# GLB child offsets belong to the sculpture, not an enemy's world position.
	# Flatten that transform and orient authored Blender -Y faces to game -Z.
	var local:Transform3D=surface.transform;var parent:Node=surface.get_parent()
	while parent!=null and parent!=root:
		if parent is Node3D:local=(parent as Node3D).transform*local
		parent=parent.get_parent()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(surface.mesh,0,Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)*local)
	var result:ArrayMesh=st.commit();result.surface_set_material(0,material(kind));_meshes[cache_key]=result
	root.free()
	return result

static func _find_mesh(node:Node)->MeshInstance3D:
	if node is MeshInstance3D:return node
	for child:Node in node.get_children():
		var found:MeshInstance3D=_find_mesh(child)
		if found!=null:return found
	return null

static func material(kind:int=0)->ShaderMaterial:
	if not _materials.has(kind):
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/art/eighthour_v1/enemies/creature_surface.gdshader")
		mat.set_shader_parameter("albedo_map",load(str(PATHS[kind]).replace(".glb","_albedo.png")));_materials[kind]=mat
	return _materials[kind]
