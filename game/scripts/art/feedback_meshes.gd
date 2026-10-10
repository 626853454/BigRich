class_name FurFeedbackMeshes
extends RefCounted
## Cached meshes from authored Blender assets. No additional objects per effect.
static var _cache:Dictionary={}
static func mesh(asset:String)->ArrayMesh:
	if _cache.has(asset):return _cache[asset]
	var source:Node3D=FurTravelArtAssets.instance(asset)
	var parts:Array=source.find_children("*","MeshInstance3D",true,false)
	assert(parts.size()==1,"Feedback asset must keep one draw surface")
	var part:MeshInstance3D=parts[0];var local:Transform3D=part.transform;var parent:Node=part.get_parent()
	while parent!=null and parent!=source:
		if parent is Node3D:local=(parent as Node3D).transform*local
		parent=parent.get_parent()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.append_from(part.mesh,0,local)
	var result:ArrayMesh=st.commit();_cache[asset]=result;source.free();return result
