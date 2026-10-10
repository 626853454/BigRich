class_name FurPartyWindmillGeometry
extends RefCounted
## Sculpted toy mill. Two cached surfaces replace the box-assembled landmark.
## Root/rotor transforms and old navigation envelope belong to the caller.
static var _cache:Dictionary={}
const Crafted=preload("res://scripts/party/party_environment_material.gd")

static func material()->ShaderMaterial:
	return Crafted.material(-1)

static func body()->ArrayMesh:
	if _cache.has("body"):return _cache.body
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_uv2(Vector2.ZERO)
	var plaster:=Color("c5bba3");var stone:=Color("a69782");var wood:=Color("795b43");var roof:=Color("8c7461")
	_lathe(st,[Vector2(1.00,.02),Vector2(1.00,.18),Vector2(.94,.28),Vector2(.91,.65),Vector2(.83,1.75),Vector2(.76,2.77),Vector2(.80,3.10),Vector2(.80,3.19)],plaster,32)
	# A broad stone foot and masonry courses describe weight without stacked rings.
	_lathe(st,[Vector2(1.01,.015),Vector2(1.01,.16),Vector2(.97,.21)],stone,32)
	for row in 2:
		for brick in 16:
			var a:float=(brick+row*.5)*TAU/16.0;var b:float=a+TAU/16*.86
			_arc_block(st,.951-row*.013,a,b,.24+row*.20,.405+row*.20,stone.lightened(.022*float((brick+row)%3)))
	# Segmented bell-shaped timber cap: two real changes of pitch and soft valleys.
	st.set_uv2(Vector2(1,0))
	var roof_profile:Array[Vector2]=[Vector2(1.265,2.99),Vector2(1.285,3.045),Vector2(1.235,3.14),Vector2(1.11,3.43),Vector2(.72,3.78),Vector2(.30,3.99),Vector2(.035,3.99),Vector2(0,3.99)]
	_lathe(st,roof_profile,roof,32,.018,16)
	for tier in [0,2,4]:
		var r:Vector2=roof_profile[tier]
		_lathe(st,[Vector2(r.x+.012,r.y-.022),Vector2(r.x+.018,r.y+.023)],roof.lightened(.065),32,.022,16)
	# Fine radial shingles change actual silhouette at the eave, not a dark texture.
	for slat in 16:
		var a:float=slat*TAU/16
		var points:Array[Vector3]=[]
		for v:Vector2 in roof_profile:
			points.append(Vector3(cos(a)*(v.x+.012),v.y+.01,sin(a)*(v.x+.012)))
		_tube(st,points,.017,roof.darkened(.07),5)
	# Arched dark recess is inside the old door plane. Surround gives visible depth.
	_arch_face(st,Vector3(0,.10,.966),.30,.92,Color("4d4842"))
	for i in 5:
		var x:float=-.225+i*.1125
		_box(st,Vector3(x,.56,.983),Vector3(.101,.83,.027),wood.lightened(.018*float(i%2)))
	for y:float in [.32,.82]:_box(st,Vector3(0,y,1.007),Vector3(.52,.055,.028),wood.darkened(.12))
	st.set_uv2(Vector2(0,0))
	_arch_frame(st,Vector3(0,.10,.987),.36,1.00,.056,Color("b4a185"))
	st.set_uv2(Vector2(3,0))
	_tube(st,[Vector3(.16,.56,1.035),Vector3(.16,.65,1.035)],.038,Color("c4a56c"),8)
	# Two deep round-topped windows, timber frame and crosspieces, warm glass inset.
	for side:float in [-1.0,1.0]:
		var p:=Vector3(side*.43,2.04,.751)
		st.set_uv2(Vector2(4,0));_arch_face(st,p,.155,.33,Color("7d9d9c"))
		st.set_uv2(Vector2(1,0));_arch_frame(st,p+Vector3(0,0,.032),.19,.37,.030,wood)
		_box(st,p+Vector3(0,.18,.047),Vector3(.025,.34,.026),wood)
		_box(st,p+Vector3(0,.15,.050),Vector3(.29,.022,.028),wood)
		st.set_uv2(Vector2(0,0));_box(st,p+Vector3(0,-.035,.068),Vector3(.46,.078,.18),stone)
	# Existing side stair: rounded noses and one stone stringer, same old footprint.
	st.set_uv2(Vector2(0,0))
	for i in 4:
		_box(st,Vector3(1.13,.15+i*.11,.30-i*.34),Vector3(.62,.22,.50),stone)
		_tube(st,[Vector3(.83,.267+i*.11,.532-i*.34),Vector3(1.43,.267+i*.11,.532-i*.34)],.025,stone.lightened(.035),6)
	return _finish(st,"body")

static func rotor()->ArrayMesh:
	if _cache.has("rotor"):return _cache.rotor
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood:=Color("775943");var fabric:=Color("dccdab")
	for blade in 4:
		var angle:float=blade*PI/2
		var basis:=Basis(Vector3.FORWARD,angle);st.set_uv2(Vector2(1,0))
		_beam(st,basis,Vector3(0,-.22,0),Vector3(0,2.37,0),.045,wood)
		_beam(st,basis,Vector3(.55,.29,.045),Vector3(.55,2.09,.045),.026,wood)
		# Five-by-eight cells make a smooth inflated cloth with a bound hem.
		st.set_uv2(Vector2(2,0))
		for row in 8:
			for col in 5:
				var u:float=float(col)/5;var v:float=float(row)/8
				var points:Array[Vector3]=[_cloth(u,v),_cloth(u+.2,v),_cloth(u+.2,v+.125),_cloth(u,v+.125)]
				for i in 4:points[i]=basis*points[i]
				_quad(st,points[0],points[1],points[2],points[3],basis*Vector3.BACK,fabric.lightened(.016*sin(v*PI)))
				_quad(st,points[3]-basis*Vector3(0,0,.014),points[2]-basis*Vector3(0,0,.014),points[1]-basis*Vector3(0,0,.014),points[0]-basis*Vector3(0,0,.014),basis*Vector3.FORWARD,fabric.darkened(.055))
		st.set_uv2(Vector2(1,0))
		for rib in 6:
			var y:float=.39+rib*.31
			_beam(st,basis,Vector3(-.012,y,.086),Vector3(.574,y,.086),.016,wood.lightened(.09))
		st.set_uv2(Vector2(2,0))
		for side:float in [0.0,1.0]:
			var hem:Array[Vector3]=[]
			for row in 9:hem.append(basis*(_cloth(side,float(row)/8)+Vector3(0,0,.004)))
			_tube(st,hem,.018,fabric.lightened(.07),5)
	# A spindle and copper collar replace the old sphere hub.
	st.set_uv2(Vector2(3,0))
	_disc(st,Vector3(0,0,.077),.18,.029,Color("a48856"),24)
	_disc(st,Vector3(0,0,.111),.104,.026,Color("cfb274"),20)
	for i in 4:
		var a:float=i*PI/2+PI/4
		_disc(st,Vector3(cos(a)*.135,sin(a)*.135,.109),.019,.009,wood,8)
	return _finish(st,"rotor")

static func _cloth(u:float,v:float)->Vector3:
	return Vector3(.038+u*.478,.32+v*1.74,.040+.022*sin(u*PI)*sin(v*PI))

static func _finish(st:SurfaceTool,key:String)->ArrayMesh:
	var result:ArrayMesh=st.commit();result.surface_set_material(0,material());_cache[key]=result
	return result

static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3,color:Color)->void:
	var points:Array[Vector3]=[a,b,c]
	if (b-a).cross(c-a).dot(normal)>0:points=[a,c,b]
	for p:Vector3 in points:st.set_normal(normal);st.set_color(color);st.add_vertex(p)

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3,color:Color)->void:
	_triangle(st,a,b,c,normal,color);_triangle(st,a,c,d,normal,color)

static func _lathe(st:SurfaceTool,profile:Array[Vector2],color:Color,sides:int,wave:float=0,wave_count:int=0)->void:
	for row in profile.size()-1:
		var slope:Vector2=profile[row+1]-profile[row]
		for i in sides:
			var points:Array[Vector3]=[];var normals:Array[Vector3]=[]
			for pair:Vector2i in [Vector2i(row,i),Vector2i(row,i+1),Vector2i(row+1,i+1),Vector2i(row+1,i)]:
				var a:float=pair.y*TAU/sides;var p:Vector2=profile[pair.x];var r:float=p.x+wave*cos(a*wave_count)*minf(1.0,p.x)
				points.append(Vector3(cos(a)*r,p.y,sin(a)*r));normals.append(Vector3(cos(a)*slope.y,-slope.x,sin(a)*slope.y).normalized())
			for index:int in [0,1,2,0,2,3]:
				st.set_normal(normals[index]);st.set_color(color.lightened(.014*cos(i*TAU/sides)));st.add_vertex(points[index])

static func _arc_block(st:SurfaceTool,radius:float,a:float,b:float,low:float,high:float,color:Color)->void:
	for i in 3:
		var aa:float=lerpf(a,b,i/3.0);var bb:float=lerpf(a,b,(i+1)/3.0)
		var p:=Vector3(cos(aa)*radius,low,sin(aa)*radius);var q:=Vector3(cos(bb)*radius,low,sin(bb)*radius)
		_quad(st,p,q,q+Vector3.UP*(high-low),p+Vector3.UP*(high-low),Vector3(cos((aa+bb)*.5),0,sin((aa+bb)*.5)),color)
		_quad(st,p+Vector3.UP*(high-low),q+Vector3.UP*(high-low),q*.97+Vector3.UP*(high-low+.01),p*.97+Vector3.UP*(high-low+.01),Vector3.UP,color.lightened(.02))

static func _tube(st:SurfaceTool,points:Array[Vector3],radius:float,color:Color,sides:int)->void:
	for row in points.size()-1:
		var a:Vector3=points[row];var b:Vector3=points[row+1];var axis:Vector3=(b-a).normalized();var right:Vector3=axis.cross(Vector3.UP).normalized()
		if right.length_squared()<.01:right=Vector3.RIGHT
		var forward:Vector3=right.cross(axis).normalized()
		for i in sides:
			var u:Vector3=(right*cos(i*TAU/sides)+forward*sin(i*TAU/sides))*radius
			var v:Vector3=(right*cos((i+1)*TAU/sides)+forward*sin((i+1)*TAU/sides))*radius
			_quad(st,a+u,a+v,b+v,b+u,(u+v).normalized(),color)

static func _beam(st:SurfaceTool,basis:Basis,a:Vector3,b:Vector3,radius:float,color:Color)->void:
	_tube(st,[basis*a,basis*b],radius,color,8)

static func _arch_face(st:SurfaceTool,p:Vector3,radius:float,height:float,color:Color)->void:
	var center:Vector3=p+Vector3(0,height-radius,0)
	_quad(st,p+Vector3(-radius,0,0),p+Vector3(radius,0,0),center+Vector3(radius,0,0),center-Vector3(radius,0,0),Vector3.BACK,color)
	for i in 12:
		var a:float=i*PI/12;var b:float=(i+1)*PI/12
		_triangle(st,center,center+Vector3(cos(a)*radius,sin(a)*radius,0),center+Vector3(cos(b)*radius,sin(b)*radius,0),Vector3.BACK,color)

static func _arch_frame(st:SurfaceTool,p:Vector3,radius:float,height:float,width:float,color:Color)->void:
	var points:Array[Vector3]=[p+Vector3(-radius,0,0)]
	for i in 13:
		var a:float=PI-i*PI/12;points.append(p+Vector3(cos(a)*radius,height-radius+sin(a)*radius,0))
	points.append(p+Vector3(radius,0,0));_tube(st,points,width,color,8)

static func _disc(st:SurfaceTool,p:Vector3,radius:float,depth:float,color:Color,sides:int)->void:
	for i in sides:
		var a:=Vector3(cos(i*TAU/sides)*radius,sin(i*TAU/sides)*radius,0);var b:=Vector3(cos((i+1)*TAU/sides)*radius,sin((i+1)*TAU/sides)*radius,0)
		_triangle(st,p,p+a,p+b,Vector3.BACK,color)
		_quad(st,p+a,p+b,p+b-Vector3(0,0,depth),p+a-Vector3(0,0,depth),(a+b).normalized(),color.darkened(.03))

static func _box(st:SurfaceTool,p:Vector3,size:Vector3,color:Color)->void:
	var mesh:=BoxMesh.new();mesh.size=size
	var arrays:Array=mesh.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for index:int in arrays[Mesh.ARRAY_INDEX]:st.set_normal(normals[index]);st.set_color(color);st.add_vertex(p+vertices[index])
