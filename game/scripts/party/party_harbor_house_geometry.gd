class_name FurPartyHarborHouseGeometry
extends RefCounted
## Harbour guild house: one authored surface, curved roof and inset joinery.
## Origin and former hero-house footprint remain unchanged in Board and Arena.
const Bridge=preload("res://scripts/party/party_bridge_geometry.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
static var _cache:Dictionary={}
static var _base:ArrayMesh
const TIMBER:=Color("704c33")
const STONE:=Color("baa489")
const PLASTER:=Color("dfc49a")
const ROOF:=Color("447b87")

static func mesh(size:Vector3)->ArrayMesh:
	var key:String=str(size)
	if _cache.has(key):return _cache[key]
	if _base==null:_base=_build()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP);st.set_uv2(Vector2.ZERO)
	var scale3:=Vector3(size.x/3.5,(size.y+size.x*.33+.4)/3.555,size.z/2.7)
	Foliage.append(st,_base,Transform3D(Basis.from_scale(scale3),Vector3.ZERO))
	var result:ArrayMesh=st.commit();result.surface_set_material(0,Crafted.material(-1));_cache[key]=result;return result

static func _block(st:SurfaceTool,p:Vector3,size:Vector3,color:Color,family:int=1,rotation:Vector3=Vector3.ZERO)->void:
	Bridge.plank(st,Transform3D(Basis.from_euler(rotation),p),size,color,family)

static func _beam(st:SurfaceTool,a:Vector3,b:Vector3,width:float,color:Color=TIMBER,family:int=1)->void:
	st.set_uv2(Vector2(family,0));Bridge.tube(st,[a,b],width,color,8)

static func roof_point(side:float,u:float,z:float)->Vector3:
	var y:float=2.19+1.35*(1.0-pow(u,1.45))+.09*pow(u,8.0)
	y+=.055*pow(absf(z)/1.69,4.0)*u
	return Vector3(side*u*2.08,y,z)

static func _shingle_point(side:float,u:float,v:float,ua:float,ub:float,za:float,zb:float)->Vector3:
	var point:Vector3=roof_point(side,lerpf(ua,ub,u),lerpf(za,zb,v))
	point.y+=.034+.055*sin(PI*u)*sin(PI*v)
	return point

static func _shingle_normal(side:float,u:float,v:float,ua:float,ub:float,za:float,zb:float)->Vector3:
	var du:Vector3=_shingle_point(side,u+.002,v,ua,ub,za,zb)-_shingle_point(side,u-.002,v,ua,ub,za,zb)
	var dv:Vector3=_shingle_point(side,u,v+.002,ua,ub,za,zb)-_shingle_point(side,u,v-.002,ua,ub,za,zb)
	var n:Vector3=du.cross(dv).normalized()
	return n if n.y>0 else -n

static func _shingle(st:SurfaceTool,side:float,ua:float,ub:float,za:float,zb:float,color:Color)->void:
	# Rounded cap with interpolated sculpt normals, not four flat diamonds.
	# All tiles remain in the same authored surface and the same footprint.
	for row in 2:
		for col in 2:
			var uv:Array[Vector2]=[Vector2(row*.5,col*.5),Vector2((row+1)*.5,col*.5),Vector2((row+1)*.5,(col+1)*.5),Vector2(row*.5,(col+1)*.5)]
			var order:Array=[0,1,2,0,2,3] if side>0 else [0,2,1,0,3,2]
			for idx in order:
				var q:Vector2=uv[idx]
				st.set_color(color);st.set_normal(_shingle_normal(side,q.x,q.y,ua,ub,za,zb));st.add_vertex(_shingle_point(side,q.x,q.y,ua,ub,za,zb))
	var edge:Array[Vector2]=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for i in 4:
		var a:Vector3=_shingle_point(side,edge[i].x,edge[i].y,ua,ub,za,zb)
		var b:Vector3=_shingle_point(side,edge[(i+1)%4].x,edge[(i+1)%4].y,ua,ub,za,zb)
		Foliage._quad(st,a,b,b-Vector3.UP*.059,a-Vector3.UP*.059,Vector3(a.x,0,a.z).normalized(),color.darkened(.10))

static func _roof(st:SurfaceTool)->void:
	st.set_uv2(Vector2(1,0))
	for side:float in [-1.0,1.0]:
		# Continuous bowed substrate and actual thickness at both eaves.
		for row in 8:
			var u:float=float(row)/8;var v:float=float(row+1)/8
			var a:Vector3=roof_point(side,u,-1.69);var b:Vector3=roof_point(side,v,-1.69);var c:Vector3=roof_point(side,v,1.69);var d:Vector3=roof_point(side,u,1.69)
			Foliage._quad(st,a,b,c,d,Vector3(side*.3,1,0),ROOF.darkened(.12))
			for z:float in [-1.69,1.69]:
				var p:Vector3=roof_point(side,u,z);var q:Vector3=roof_point(side,v,z)
				Foliage._quad(st,p,q,q-Vector3.UP*.11,p-Vector3.UP*.11,Vector3(0,0,signf(z)),TIMBER)
		# Overlapping, staggered shingle rows follow the bend instead of a box grid.
		for row in 7:
			for col in 7:
				var za:float=-1.66+col*.475+(.17 if row%2 else 0.0)
				var zb:float=minf(1.66,za+.452)
				if za>1.62:continue
				var u:float=maxf(.018,float(row)/7-.014);var v:float=minf(.987,float(row+1)/7+.006)
				var color:Color=ROOF.lightened([.0,.025,.055][posmod(row*3+col,3)])
				_shingle(st,side,u,v,za,zb,color)
		var verge:Array[Vector3]=[]
		for i in 17:verge.append(roof_point(side,float(i)/16,1.655)-Vector3.UP*.065)
		Bridge.tube(st,verge,.069,TIMBER,8)
		_beam(st,roof_point(side,1,-1.64)-Vector3.UP*.045,roof_point(side,1,1.64)-Vector3.UP*.045,.060)
	_beam(st,Vector3(0,3.56,-1.66),Vector3(0,3.56,1.66),.066,ROOF.lightened(.16))

static func _arch_panel(st:SurfaceTool,origin:Vector3,width:float,height:float,depth:float,color:Color,family:int)->void:
	var points:Array[Vector3]=[Vector3(-width*.5,0,0),Vector3(width*.5,0,0)]
	for i in 9:
		var a:float=i*PI/8;points.append(Vector3(cos(a)*width*.5,height-width*.5+sin(a)*width*.5,0))
	st.set_uv2(Vector2(family,0))
	var center:Vector3=origin+Vector3(0,height*.43,0)
	for i in points.size():
		var a:Vector3=origin+points[i];var b:Vector3=origin+points[(i+1)%points.size()]
		Foliage._triangle(st,center,a,b,Vector3.BACK,color)
		Foliage._quad(st,a,b,b-Vector3.BACK*depth,a-Vector3.BACK*depth,(a+b-center*2).normalized(),color.darkened(.17))

static func _window(st:SurfaceTool,x:float,z:float)->void:
	var p:=Vector3(x,1.22,z)
	_block(st,p,Vector3(.79,.90,.10),TIMBER)
	_block(st,p+Vector3(0,0,.055),Vector3(.61,.71,.04),Color("f4c77b"),8)
	for dx:float in [-.31,.0,.31]:_block(st,p+Vector3(dx,0,.094),Vector3(.035,.74,.035),TIMBER)
	for dy:float in [-.36,.0,.36]:_block(st,p+Vector3(0,dy,.094),Vector3(.65,.035,.035),TIMBER)
	for side:float in [-1.0,1.0]:
		var center:Vector3=p+Vector3(side*.46,0,.035)
		_block(st,center,Vector3(.21,.80,.075),ROOF.darkened(.05),1,Vector3(0,side*.35,0))
		_beam(st,center+Vector3(-.065,-.31,.065),center+Vector3(.065,.31,.065),.015,ROOF.lightened(.14))
	_block(st,p+Vector3(0,-.51,.11),Vector3(1.0,.17,.29),TIMBER)
	for i in 3:
		var stem:Vector3=p+Vector3(-.27+i*.27,-.38,.17)
		Foliage.leaf_piece(st,stem,stem+Vector3(-.10,.12,.08),.18,Color("71946b"),5)
		Foliage.leaf_piece(st,stem,stem+Vector3(.12,.10,.035),.17,Color("83a076"),5)

static func _build()->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP);st.set_uv2(Vector2.ZERO)
	_block(st,Vector3(0,.16,0),Vector3(3.78,.32,2.99),STONE,0)
	_block(st,Vector3(0,1.16,0),Vector3(3.48,1.90,2.67),PLASTER,0)
	# Gable shape is integrated into the wall, with joinery in front of its recess.
	st.set_uv2(Vector2.ZERO)
	for z:float in [-1.335,1.335]:Foliage._triangle(st,Vector3(-1.74,2.08,z),Vector3(0,3.42,z),Vector3(1.74,2.08,z),Vector3(0,0,signf(z)),PLASTER.darkened(.025))
	for x:float in [-1.67,1.67]:
		_block(st,Vector3(x,1.17,1.38),Vector3(.13,1.96,.16),TIMBER)
		for z:float in [-.75,.65]:_beam(st,Vector3(x,.42,z),Vector3(x,1.93,z),.047)
	for y:float in [.48,1.94]:_block(st,Vector3(0,y,1.40),Vector3(3.45,.115,.16),TIMBER)
	_window(st,-.96,1.43);_window(st,.96,1.43)
	_arch_panel_door(st)
	# Timber porch is a coherent framed volume, contained in the former steps.
	for x:float in [-.52,.52]:
		_block(st,Vector3(x,.87,2.04),Vector3(.105,1.30,.105),TIMBER)
		_beam(st,Vector3(x,1.26,2.04),Vector3(x,1.63,1.74),.046)
	var a:=Vector3(-.68,1.66,2.26);var b:=Vector3(0,2.04,2.26);var c:=Vector3(.68,1.66,2.26)
	st.set_uv2(Vector2(1,0));Foliage._quad(st,a,b,b-Vector3.BACK*.81,a-Vector3.BACK*.81,Vector3(-.4,1,0),ROOF);Foliage._quad(st,b,c,c-Vector3.BACK*.81,b-Vector3.BACK*.81,Vector3(.4,1,0),ROOF)
	_beam(st,a-Vector3.UP*.05,b-Vector3.UP*.05,.051);_beam(st,b-Vector3.UP*.05,c-Vector3.UP*.05,.051)
	for step in 3:_block(st,Vector3(0,.08+step*.085,2.17-step*.19),Vector3(1.18,.15,.34),STONE,0)
	_roof(st)
	# One offset dormer creates a recognisable asymmetrical workshop silhouette.
	_block(st,Vector3(.83,3.14,.57),Vector3(.65,.53,.84),PLASTER,0)
	_block(st,Vector3(.83,3.23,1.01),Vector3(.43,.36,.06),TIMBER)
	_block(st,Vector3(.83,3.23,1.047),Vector3(.30,.24,.025),Color("ebc586"),8)
	_beam(st,Vector3(.83,3.10,1.066),Vector3(.83,3.36,1.066),.014)
	st.set_uv2(Vector2(1,0))
	for side:float in [-1.0,1.0]:Foliage._quad(st,Vector3(.83,3.61,1.04),Vector3(.83+side*.42,3.37,1.04),Vector3(.83+side*.42,3.37,.10),Vector3(.83,3.61,.10),Vector3(side*.4,1,0),ROOF.lightened(.045))
	_block(st,Vector3(-1.12,3.10,-.69),Vector3(.43,.86,.48),STONE.darkened(.07),0)
	_block(st,Vector3(-1.12,3.57,-.69),Vector3(.56,.16,.61),STONE,0)
	# A substantial hanging round guild sign; the paw glyph is original geometry.
	st.set_uv2(Vector2(3,0));Bridge.tube(st,[Vector3(.05,2.03,1.48),Vector3(.05,2.25,1.48)],.027,Color("c5a05e"),8)
	_arch_panel_sign(st)
	return st.commit()

static func _arch_panel_door(st:SurfaceTool)->void:
	_arch_panel_door_frame(st)
	_arch_panel(st,Vector3(0,.29,1.469),.74,1.22,.035,Color("835832"),1)
	for x:float in [-.23,-.115,0,.115,.23]:_beam(st,Vector3(x,.33,1.513),Vector3(x,1.19,1.513),.008,Color("66442c"))
	_block(st,Vector3(.21,.85,1.54),Vector3(.07,.07,.055),Color("d5b26a"),3)

static func _arch_panel_door_frame(st:SurfaceTool)->void:
	_arch_panel(st,Vector3(0,.28,1.44),.92,1.40,.12,TIMBER,1)

static func _arch_panel_sign(st:SurfaceTool)->void:
	st.set_uv2(Vector2(1,0))
	var p:=Vector3(.05,2.31,1.46)
	for i in 20:
		var a:float=i*TAU/20;var b:float=(i+1)*TAU/20
		Foliage._triangle(st,p+Vector3(0,0,.035),p+Vector3(cos(a)*.19,sin(a)*.19,.035),p+Vector3(cos(b)*.19,sin(b)*.19,.035),Vector3.BACK,Color("ba965e"))
	_block(st,p+Vector3(0,-.032,.062),Vector3(.11,.10,.028),TIMBER)
	for i in 3:_block(st,p+Vector3(-.075+i*.075,.073,.062),Vector3(.045,.05,.028),TIMBER)
