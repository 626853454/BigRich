class_name FurPartyHarborGeometry
extends RefCounted
const Bridge=preload("res://scripts/party/party_bridge_geometry.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
static var _boat:ArrayMesh

static func rowboat()->ArrayMesh:
	if _boat!=null:return _boat
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP);st.set_uv2(Vector2(1,0))
	var rings:Array[Vector3]=[Vector3(.06,-.34,.10),Vector3(.32,-.28,.98),Vector3(.61,-.13,1.40),Vector3(.765,.12,1.645),Vector3(.735,.29,1.615)]
	for i in 32:
		var a:float=i*TAU/32;var b:float=(i+1)*TAU/32
		Foliage._triangle(st,Vector3(0,-.34,0),Vector3(cos(a)*.06,-.34,sin(a)*.10),Vector3(cos(b)*.06,-.34,sin(b)*.10),Vector3.DOWN,Color("795c43"))
	for row in rings.size()-1:
		for i in 32:
			var points:Array[Vector3]=[]
			for pair:Vector2i in [Vector2i(row,i),Vector2i(row,i+1),Vector2i(row+1,i+1),Vector2i(row+1,i)]:
				var r:Vector3=rings[pair.x];var a:float=pair.y*TAU/32
				points.append(Vector3(cos(a)*r.x,r.y,sin(a)*r.z))
			var outward:=Vector3(cos((i+.5)*TAU/32),-.15,sin((i+.5)*TAU/32)).normalized()
			Foliage._quad(st,points[0],points[1],points[2],points[3],outward,Color("906749").lightened(row*.025))
			# A real inner cavity follows the shell instead of a dark oval on top.
			var inside:Array[Vector3]=[]
			for p:Vector3 in points:inside.append(Vector3(p.x*.90,p.y+.065,p.z*.95))
			Foliage._quad(st,inside[3],inside[2],inside[1],inside[0],-outward,Color("7b5e45").lightened(row*.02))
	# Clinker overlaps and the teal gunwale trace the actual hollow hull.
	for row in [1,2,4]:
		var ring:Vector3=rings[row];var path:Array[Vector3]=[]
		for i in 33:
			var a:float=i*TAU/32;path.append(Vector3(cos(a)*(ring.x+.004),ring.y+.012,sin(a)*(ring.z+.004)))
		st.set_uv2(Vector2(1,0));Bridge.tube(st,path,.021 if row<4 else .039,Color("74533e") if row<4 else Color("3f6f73"),6)
	for z:float in [-.78,0,.78]:Bridge.plank(st,Transform3D(Basis.IDENTITY,Vector3(0,.275,z)),Vector3(1.10,.11,.22),Color("be9868"))
	for side:float in [-1.0,1.0]:
		var p:=Vector3(side*.73,.31,.08)
		st.set_uv2(Vector2(3,0));Bridge.tube(st,[p-Vector3(0,0,.06),p+Vector3(0,0,.06)],.041,Color("b79b65"),8)
	_boat=st.commit();_boat.surface_set_material(0,Crafted.material(-1));return _boat
