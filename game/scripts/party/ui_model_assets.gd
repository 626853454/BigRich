class_name FurUIModelAssets
extends RefCounted
## Original Blender UI geometry, cached independently from game domains.
static var _scenes:Dictionary={}
static var _meshes:Dictionary={}
static func instance(key:String)->Node3D:
	assert(key in ["echo_case","echo_tile","echo_obstacle","echo_pressure_ring"])
	if key=="echo_case":return FurTravelArtAssets.instance("echo_board_sculpted_v2",true)
	if key=="echo_tile":return FurTravelArtAssets.instance("echo_tile_porcelain_v2",true)
	if key!="echo_tile":return FurTravelArtAssets.instance(key+"_atelier")
	if not _scenes.has(key):_scenes[key]=load("res://assets/ui/premium_v1/models/"+key+".glb")
	return (_scenes[key] as PackedScene).instantiate()
static func tile_mesh()->Mesh:
	if not _meshes.has("tile"):
		var source:=instance("echo_tile");var parts:Array=source.find_children("*","MeshInstance3D",true,false)
		assert(parts.size()==1);_meshes["tile"]=parts[0].mesh;source.free()
	return _meshes.tile
