class_name FurAuthoredBridgeMesh
extends RefCounted
## The edited Blender crossing is flattened once, then placed on exact route ends.
static var _mesh:ArrayMesh
static func bridge(from:Vector3,to:Vector3)->ArrayMesh:
	if _mesh==null:
		var scene:=FurTravelArtAssets.instance("stone_crossing_atelier")
		var part:MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0]
		var local:Transform3D=part.transform;var parent:Node=part.get_parent()
		while parent!=null and parent!=scene:
			if parent is Node3D:local=(parent as Node3D).transform*local
			parent=parent.get_parent()
		var source:=SurfaceTool.new();source.begin(Mesh.PRIMITIVE_TRIANGLES);source.append_from(part.mesh,0,local);source.deindex();_mesh=source.commit();scene.free()
	var axis:Vector3=(to-from).normalized();var right:Vector3=Vector3.UP.cross(axis).normalized();var up:Vector3=axis.cross(right)
	var pose:=Transform3D(Basis(right,up,axis).scaled_local(Vector3(1,1,from.distance_to(to)/3.0)),(from+to)*.5)
	var arrays:Array=_mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colours:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var normal_basis:=pose.basis.inverse().transposed()
	for i in vertices.size():
		st.set_normal((normal_basis*normals[i]).normalized());st.set_color(colours[i].linear_to_srgb());st.set_uv2(Vector2.ZERO);st.add_vertex(pose*vertices[i])
	return st.commit()
