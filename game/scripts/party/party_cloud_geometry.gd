class_name FurPartyCloudGeometry
extends RefCounted
## Original closed puff sculpture, shared by both cloud chapter consumers.
## A cached mesh resource only: no scene processing, alpha cards or collision.
const SCENE=preload("res://assets/art/sevenhour_v1/cloud_bank_atelier.glb")
static var _mesh:Mesh
static func mesh()->Mesh:
	if _mesh!=null:return _mesh
	var scene:Node3D=SCENE.instantiate()
	var parts:Array=scene.find_children("*","MeshInstance3D",true,false)
	assert(parts.size()==1,"Cloud sculpture must retain one imported mesh")
	var source:MeshInstance3D=parts[0]
	var transform:Transform3D=source.transform;var parent:Node=source.get_parent()
	while parent!=null and parent!=scene:
		if parent is Node3D:transform=(parent as Node3D).transform*transform
		parent=parent.get_parent()
	var bound:AABB=transform*source.mesh.get_aabb()
	# The primitive consumer requests explicit width/height/depth; normalize the
	# authored connected cloud while retaining its designed lobe proportions.
	var normalize:=Transform3D(Basis.from_scale(Vector3.ONE/bound.size),-bound.get_center()/bound.size)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(source.mesh,0,normalize*transform);_mesh=surface.commit()
	scene.free()
	return _mesh
