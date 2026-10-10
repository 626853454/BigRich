class_name FurPartyHouseGeometry
extends RefCounted
## Harbour house joinery: a broken-pitch roof, recessed loft window and gabled
## porch share one cached surface. Existing body, tiles and footprint are reused.
static var _cache:Dictionary={}
const Crafted=preload("res://scripts/party/party_environment_material.gd")

static func roof_height(size:Vector3,ratio:float)->float:
	var edge:float=size.y+.24;var top:float=size.y+size.x*.33+.40
	var knee:float=lerpf(top,edge,.44)
	return lerpf(top,knee,ratio/.64) if ratio<=.64 else lerpf(knee,edge,(ratio-.64)/.36)

static func roof_angle(size:Vector3,ratio:float)->float:
	var width:float=size.x*.5+.36
	if ratio<=.64:return atan2(roof_height(size,0)-roof_height(size,.64),width*.64)
	return atan2(roof_height(size,.64)-roof_height(size,1),width*.36)

static func mesh(size:Vector3,roof:Color)->ArrayMesh:
	var key:String=str(size)+roof.to_html()
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood:=Color("775943");var width:float=size.x*.5+.36;var depth:float=size.z*.5+.35
	var profile:Array[Vector2]=[]
	for ratio:float in [-1.0,-.64,0.0,.64,1.0]:profile.append(Vector2(ratio*width,roof_height(size,absf(ratio))))
	for i in profile.size()-1:
		var a:=Vector3(profile[i].x,profile[i].y,depth);var b:=Vector3(profile[i+1].x,profile[i+1].y,depth)
		var back:=Vector3(0,0,-depth*2)
		var normal:=Vector3(-(b.y-a.y),b.x-a.x,0).normalized()
		_quad(st,a,b,b+back,a+back,normal,roof.lightened(.01 if i in [1,2] else -.025))
		# Round-edged verge timbers define each real pitch change without wider eaves.
		for z:float in [depth-.025,-depth+.09]:
			_beam(st,Vector3(a.x,a.y-.055,z),Vector3(b.x,b.y-.055,z),.064,wood)
	for z:float in [depth-.07,-depth+.03]:
		var normal:Vector3=Vector3.BACK if z>0 else Vector3.FORWARD
		var center:=Vector3(0,size.y+.24,z)
		for i in profile.size()-1:
			_triangle(st,center,Vector3(profile[i].x,profile[i].y,z),Vector3(profile[i+1].x,profile[i+1].y,z),normal,wood.lightened(.07))
	_beam(st,Vector3(0,roof_height(size,0),-depth+.04),Vector3(0,roof_height(size,0),depth-.025),.08,roof.lightened(.14))
	# Recessed circular attic pane, with a solid wooden rim and real cross mullions.
	var loft:=Vector3(0,size.y+.66,depth-.005)
	_disc(st,loft,.265,.028,Color("dfb572"))
	_ring(st,loft+Vector3(0,0,.013),.29,.049,wood,20)
	_beam(st,loft+Vector3(-.245,0,.05),loft+Vector3(.245,0,.05),.020,wood)
	_beam(st,loft+Vector3(0,-.245,.05),loft+Vector3(0,.245,.05),.020,wood)
	# Replace the old flat canopy within exactly its former X/Z footprint.
	var porch_depth:float=size.z*.71;var front:float=porch_depth+.375;var back:float=porch_depth-.375
	var a:=Vector3(-.58,1.61,front);var b:=Vector3(0,1.94,front);var c:=Vector3(.58,1.61,front)
	for side in 2:
		var l:Vector3=a if side==0 else b;var r:Vector3=b if side==0 else c
		_quad(st,l,r,Vector3(r.x,r.y,back),Vector3(l.x,l.y,back),Vector3(-(r.y-l.y),r.x-l.x,0).normalized(),roof)
		_beam(st,l+Vector3(0,-.045,-.05),r+Vector3(0,-.045,-.05),.045,wood)
	_triangle(st,a+Vector3(0,-.035,-.045),b+Vector3(0,-.035,-.045),c+Vector3(0,-.035,-.045),Vector3.BACK,wood.lightened(.055))
	for x:float in [-.53,.53]:_beam(st,Vector3(x,1.56,back+.02),Vector3(x,1.56,front-.03),.04,wood)
	var result:ArrayMesh=st.commit();result.surface_set_material(0,material());_cache[key]=result
	return result

static func material()->ShaderMaterial:
	return Crafted.material(1)

static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3,colour:Color)->void:
	var points:Array[Vector3]=[a,b,c]
	if (b-a).cross(c-a).dot(normal)>0:points=[a,c,b]
	for point:Vector3 in points:st.set_normal(normal);st.set_color(colour);st.add_vertex(point)

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3,colour:Color)->void:
	_triangle(st,a,b,c,normal,colour);_triangle(st,a,c,d,normal,colour)

static func _beam(st:SurfaceTool,a:Vector3,b:Vector3,radius:float,colour:Color)->void:
	var axis:Vector3=(b-a).normalized();var right:Vector3=axis.cross(Vector3.UP).normalized()
	if right.length_squared()<.01:right=Vector3.RIGHT
	var forward:Vector3=right.cross(axis).normalized()
	for i in 10:
		var v:Vector3=(right*cos(i*TAU/10.0)+forward*sin(i*TAU/10.0))*radius
		var w:Vector3=(right*cos((i+1)*TAU/10.0)+forward*sin((i+1)*TAU/10.0))*radius
		_quad(st,a+v,a+w,b+w,b+v,(v+w).normalized(),colour)
		_triangle(st,a,a+w,a+v,-axis,colour);_triangle(st,b,b+v,b+w,axis,colour)

static func _disc(st:SurfaceTool,p:Vector3,radius:float,thickness:float,colour:Color)->void:
	for i in 20:
		var a:=Vector3(cos(i*TAU/20.0)*radius,sin(i*TAU/20.0)*radius,0)
		var b:=Vector3(cos((i+1)*TAU/20.0)*radius,sin((i+1)*TAU/20.0)*radius,0)
		_triangle(st,p,p+a,p+b,Vector3.BACK,colour)
		_quad(st,p+a,p+b,p+b-Vector3(0,0,thickness),p+a-Vector3(0,0,thickness),(a+b).normalized(),colour.darkened(.06))

static func _ring(st:SurfaceTool,p:Vector3,radius:float,thickness:float,colour:Color,steps:int)->void:
	for i in steps:
		var a:=p+Vector3(cos(i*TAU/steps)*radius,sin(i*TAU/steps)*radius,0)
		var b:=p+Vector3(cos((i+1)*TAU/steps)*radius,sin((i+1)*TAU/steps)*radius,0)
		_beam(st,a,b,thickness,colour)
