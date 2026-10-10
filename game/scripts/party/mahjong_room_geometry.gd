class_name FurMahjongRoomGeometry
extends RefCounted
const Surfaces=preload("res://scripts/party/mahjong_surface_materials.gd")
## A physical tea pavilion around the table. One static vertex-colour surface.
## Tile identity, picking and the authority state belong to their own modules.
static func build()->MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var porcelain:=SurfaceTool.new();porcelain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brass:=SurfaceTool.new();brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box:=BoxMesh.new();box.size=Vector3.ONE
	var cylinder:=CylinderMesh.new();cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.height=1;cylinder.radial_segments=16;cylinder.rings=1
	var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=5
	# A continuous underfloor prevents staggered plank ends revealing the sky.
	_piece(st,box,Vector3(0,-1.54,0),Vector3(36,.12,32.0),Color("48372d"))
	# Staggered long timber boards with narrow real seams, not oversized tiles.
	for row in 26:
		for col in 9:
			var p:=Vector3((col-4)*3.8+(.95 if row%2 else 0),-1.46,(row-12.5)*1.22)
			_piece(st,box,p,Vector3(3.77,.12,1.20),Color("785844").lightened(.018*float((row+col*3)%4)))
	for sign_value in [-1.0,1.0]:
		var x:float=sign_value*12.2
		# Real cloud-shaped moon-screen, wooden lattice and brass feet.
		_piece(st,box,Vector3(x,-.8,-3.7),Vector3(3.6,.30,1.1),Color("735742"))
		for a in 32:
			var theta:float=float(a)*TAU/32
			var p:=Vector3(x+cos(theta)*1.75,.9+sin(theta)*1.7,-4.15)
			_piece(st,box,p,Vector3(.35,.20,.20),Color("7c614c"),Vector3(0,0,theta+PI/2))
		for k in [-1.0,0.0,1.0]:
			_piece(st,box,Vector3(x+k*.72,.9,-4.12),Vector3(.055,2.9,.07),Color("c5b18a"))
			_piece(st,box,Vector3(x,.9+k*.65,-4.12),Vector3(3.15,.055,.07),Color("c5b18a"))
		# Lanterns are rounded hanging objects; their light remains the shared sun.
		_piece(st,box,Vector3(x,3.07,-4.1),Vector3(.09,.65,.10),Color("76553d"))
		_piece(st,sphere,Vector3(x,2.55,-4.1),Vector3(.56,.70,.56),Color("deb77c"))
		for cap_y in [2.20,2.90]:_piece(st,cylinder,Vector3(x,cap_y,-4.1),Vector3(.35,.09,.35),Color("8b6346"))
		# Small tea station and porcelain: clearly separate from playable tiles.
		_piece(st,box,Vector3(sign_value*12.1,-.85,4.9),Vector3(2.3,.22,2.0),Color("755641"))
		for dx in [-.8,.8]:
			for dz in [-.65,.65]:_piece(st,box,Vector3(sign_value*12.1+dx,-1.12,4.9+dz),Vector3(.13,.65,.13),Color("725742"))
		_piece(porcelain,sphere,Vector3(sign_value*12.1,-.47,4.9),Vector3(.70,.63,.70),Color("eee9d8"))
		_piece(brass,cylinder,Vector3(sign_value*12.1,-.11,4.9),Vector3(.34,.10,.34),Color("b69a72"))
		_piece(porcelain,cylinder,Vector3(sign_value*12.1+.42,-.45,4.9),Vector3(.18,.50,.18),Color("eee9d8"),Vector3(0,0,-.65))
		for dz in [-.6,.6]:
			_piece(porcelain,cylinder,Vector3(sign_value*12.1-.60,-.60,4.9+dz),Vector3(.38,.28,.38),Color("eee9d8"))
			_piece(brass,cylinder,Vector3(sign_value*12.1-.60,-.445,4.9+dz),Vector3(.27,.025,.27),Color("af8559"))
	var mesh:ArrayMesh=st.commit();porcelain.commit(mesh);brass.commit(mesh)
	mesh.surface_set_material(0,Surfaces.surface("wood",Color.WHITE,true));mesh.surface_set_material(1,Surfaces.surface("ceramic",Color.WHITE,true));mesh.surface_set_material(2,Surfaces.surface("brass",Color.WHITE,true))
	var instance:=MeshInstance3D.new();instance.name="CloudTeaPavilion";instance.mesh=mesh
	return instance

static func _piece(st:SurfaceTool,mesh:Mesh,pos:Vector3,size3:Vector3,color:Color,rotation3:Vector3=Vector3.ZERO)->void:
	var transform:=Transform3D(Basis.from_euler(rotation3)*Basis.from_scale(size3),pos)
	var normal_basis:Basis=transform.basis.inverse().transposed()
	var arrays:Array=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in indices.size() if not indices.is_empty() else vertices.size():
		var at:int=indices[i] if not indices.is_empty() else i
		st.set_color(color.srgb_to_linear());st.set_normal((normal_basis*normals[at]).normalized());st.add_vertex(transform*vertices[at])
