class_name FurPartyBridgeGeometry
extends RefCounted
## Authored board-to-board origins are unchanged. Mesh is merged per district.
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")

static func bridge(from:Vector3,to:Vector3)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_uv2(Vector2(1,0));st.set_normal(Vector3.UP)
	var axis:Vector3=(to-from).normalized();var side:=Vector3(-axis.z,0,axis.x).normalized();var forward:=side.cross(Vector3.UP).normalized()
	var basis:=Basis(side,Vector3.UP,forward);var count:int=maxi(3,ceili(from.distance_to(to)/.38));var length:float=from.distance_to(to)/count
	for i in count:
		var p:Vector3=from.lerp(to,(i+.5)/count)+Vector3(0,-.20,0)
		plank(st,Transform3D(basis,p),Vector3(2.10,.21,length*.94),Color("947153").lightened(float(i%3)*.019))
	for sign_side:float in [-1.0,1.0]:
		var line:Array[Vector3]=[]
		for ratio:float in [.10,.50,.90]:
			var p:Vector3=from.lerp(to,ratio)+side*1.16*sign_side
			st.set_uv2(Vector2(1,0));tube(st,[p-Vector3.UP*.34,p+Vector3.UP*.55],.079,Color("775943"),10)
			st.set_uv2(Vector2(3,0));tube(st,[p+Vector3.UP*.42,p+Vector3.UP*.485],.087,Color("b89a66"),10)
			line.append(p+Vector3.UP*.47)
		for section in 2:
			var rope:Array[Vector3]=[]
			for i in 9:
				var t:float=i/8.0;rope.append(line[section].lerp(line[section+1],t)-Vector3.UP*sin(t*PI)*.105)
			st.set_uv2(Vector2(2,0));tube(st,rope,.032,Color("c2ae7d"),6)
		st.set_uv2(Vector2(1,0));tube(st,[from+side*1.00*sign_side-Vector3.UP*.35,to+side*1.00*sign_side-Vector3.UP*.35],.12,Color("6f5947"),8)
	return st.commit()

static func dock(root:Vector3,radial:Vector3)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_uv2(Vector2(1,0));st.set_normal(Vector3.UP)
	var side:=Vector3(-radial.z,0,radial.x);var basis:=Basis(-side,Vector3.UP,radial)
	for i in 8:plank(st,Transform3D(basis,root+radial*(.22+i*.28)-Vector3.UP*.12),Vector3(1.48,.16,.255),Color("997759").lightened(float(i%3)*.017))
	for sign_side:float in [-1.0,1.0]:
		var a:Vector3=root+side*.54*sign_side-Vector3.UP*.29;var b:Vector3=a+radial*2.27
		tube(st,[a,b],.11,Color("715440"),8)
		var p:Vector3=root+radial*1.8+side*.85*sign_side
		st.set_uv2(Vector2(3,0));tube(st,[p+Vector3.UP*.17,p+Vector3.UP*.24],.106,Color("bba16d"),10)
		# A small cleat fixed through the deck, visually tied to the landing use.
		st.set_uv2(Vector2(1,0));tube(st,[root+radial*.75+side*.58*sign_side,root+radial*.75+side*.58*sign_side+Vector3.UP*.18],.048,Color("745741"),8)
		st.set_uv2(Vector2(3,0));tube(st,[root+radial*.61+side*.58*sign_side+Vector3.UP*.18,root+radial*.89+side*.58*sign_side+Vector3.UP*.18],.039,Color("ae9062"),8)
	return st.commit()

static func plank(st:SurfaceTool,transform:Transform3D,size:Vector3,color:Color,family:int=1)->void:
	var half:Vector2=Vector2(size.x,size.z)*.5;var cut:float=minf(.045,half.y*.22)
	var outline:Array[Vector2]=[Vector2(-half.x+cut,-half.y),Vector2(half.x-cut,-half.y),Vector2(half.x,-half.y+cut),Vector2(half.x,half.y-cut),Vector2(half.x-cut,half.y),Vector2(-half.x+cut,half.y),Vector2(-half.x,half.y-cut),Vector2(-half.x,-half.y+cut)]
	st.set_uv2(Vector2(family,0))
	for i in 8:
		var a:=Vector3(outline[i].x,size.y*.5-.02,outline[i].y);var b:=Vector3(outline[(i+1)%8].x,size.y*.5-.02,outline[(i+1)%8].y)
		var at:=Vector3(a.x*.99,size.y*.5,a.z*.88);var bt:=Vector3(b.x*.99,size.y*.5,b.z*.88)
		_triangle(st,transform*Vector3(0,size.y*.5,0),transform*at,transform*bt,transform.basis*Vector3.UP,color)
		_quad(st,transform*at,transform*bt,transform*b,transform*a,transform.basis*(Vector3(a.x,1,a.z).normalized()),color.lightened(.02))
		var down:=Vector3.UP*(size.y-.02)
		_quad(st,transform*a,transform*b,transform*(b-down),transform*(a-down),transform.basis*Vector3(a.x,0,a.z).normalized(),color.darkened(.075))
		_triangle(st,transform*Vector3(0,-size.y*.5,0),transform*(b-down),transform*(a-down),transform.basis*Vector3.DOWN,color.darkened(.075))

static func tube(st:SurfaceTool,points:Array[Vector3],radius:float,color:Color,sides:int)->void:
	for row in points.size()-1:
		var a:Vector3=points[row];var b:Vector3=points[row+1];var axis:Vector3=(b-a).normalized();var right:Vector3=axis.cross(Vector3.UP).normalized()
		if right.length_squared()<.01:right=Vector3.RIGHT
		var forward:Vector3=right.cross(axis).normalized()
		for i in sides:
			var u:Vector3=(right*cos(i*TAU/sides)+forward*sin(i*TAU/sides))*radius
			var v:Vector3=(right*cos((i+1)*TAU/sides)+forward*sin((i+1)*TAU/sides))*radius
			_quad(st,a+u,a+v,b+v,b+u,(u+v).normalized(),color)
			if row==0:_triangle(st,a,a+v,a+u,-axis,color)
			if row==points.size()-2:_triangle(st,b,b+u,b+v,axis,color)

static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3,color:Color)->void:
	Foliage._triangle(st,a,b,c,normal,color)
static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3,color:Color)->void:
	_triangle(st,a,b,c,normal,color);_triangle(st,a,c,d,normal,color)
