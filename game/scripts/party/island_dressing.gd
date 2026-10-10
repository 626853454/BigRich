class_name FurIslandDressing
extends RefCounted
## Static, physically grounded island infrastructure. One merged mesh per island.
## No gameplay, no collision, no process, and no change to any map coordinate.
const Crafted=preload("res://scripts/party/party_environment_material.gd")
const Palette=preload("res://scripts/party/party_world_palette.gd")
const WOOD:=Color("82604a")
const STONE:=Color("a99982")
const GOLD:=Color("be985c")
var _world:Node3D
var _tiles:Array=[]
var _edges:Array=[]
var _painter:RefCounted
var _cache:Dictionary={}
var _st:SurfaceTool
var _triangles:int=0
var _matrix:=Transform3D.IDENTITY
var _features:Array[Dictionary]=[]
var _inner_sites:Array[Dictionary]=[]
var _ruin_sites:Array[Dictionary]=[]
var _feature_max_y:float=-INF

func build(host:Node3D,tiles:Array,edges:Array,districts:Array,painter:RefCounted)->Dictionary:
	_world=host;_tiles=tiles;_edges=edges;_painter=painter
	var report:Array[Dictionary]=[];var total:int=0
	for d:Dictionary in districts:
		_st=SurfaceTool.new();_st.begin(Mesh.PRIMITIVE_TRIANGLES);_st.set_normal(Vector3.UP);_st.set_uv2(Vector2.ZERO);_triangles=0
		_features=[];_inner_sites=[];_ruin_sites=[]
		_coastal_infrastructure(d)
		_inner_infrastructure(d)
		if int(d.id)==2:_ruin_fragments(d)
		var node:=MeshInstance3D.new();node.name="IslandFunctionalTerrain_%d"%int(d.id)
		node.mesh=_st.commit()
		node.material_override=Crafted.material(-1,-2.96)
		host.add_child(node);total+=_triangles
		report.append({"district":int(d.id),"triangles":_triangles,"features":_features.duplicate(true),"interior":_inner_sites.duplicate(true),"ruin_fragments":_ruin_sites.duplicate(true),"draw_objects":1})
	return {"triangles":total,"draw_objects":3,"districts":report,"tile_coordinates_modified":false,"animated_nodes":0,"surface_top_modified":false}

func _coastal_infrastructure(d:Dictionary)->void:
	var id:int=int(d.id)
	# Below the coast's exact top. These face the player's camera and establish
	# why each island exists: an inhabited port, irrigated hill, ancient aqueduct.
	for j in 3:
		# One intentional shore entrance per island; the former three identical
		# stairs/channels read as floating brackets and collided with ferry docks.
		if j!=0:continue
		var angle:float=[.61,1.54,2.54][j]+float(id)*.07
		if id==0:angle=1.04
		var p:Vector3=_painter._cliff_point(d,angle,.06,1.0)
		var radial:=Vector3(cos(angle),0,sin(angle))
		var basis:=Basis(Vector3(radial.z,0,-radial.x),Vector3.UP,radial)
		_matrix=Transform3D(basis,p)
		_feature_max_y=-INF
		if id==0:
			var model:=FurTravelArtAssets.instance("quay_steps_atelier")
			var top:Vector3=_painter._cliff_point(d,angle,0,1.0)+radial*.08
			model.transform=Transform3D(basis,top);model.scale.y=(float(d.height)-.24+3.08)/3.6
			_world.add_child(model);_feature_max_y=top.y+.70*model.scale.y
			_features.append({"kind":"blender_stone_steps_to_water","top":top,"water_y":-3.0,"closed_supported_stairs":true})
		elif id==1:
			# The actual flowing waterfall is the hill's water infrastructure.
			# Removed unsupported ornamental cyan trays from its cliff face.
			_feature_max_y=p.y
		else:
			var arch:=FurTravelArtAssets.instance("ruin_arch_atelier")
			arch.transform=Transform3D(basis,p+Vector3(0,-2.0,0)+radial*.10);arch.scale*=.55
			_world.add_child(arch);_feature_max_y=p.y-.30
		_features.append({"kind":["harbor_arch_quay","irrigation_terrace","broken_aqueduct"][id],"position":p,"maximum_y":_feature_max_y,"coastal_below_top":_feature_max_y<=float(d.height)-.24})
	_matrix=Transform3D.IDENTITY

func _harbor_quay(index:int)->void:
	# True wedge stones with a recessed opening, a lintel, and stepped water landing.
	_arch(Vector3(0,-1.48,.13),.66,.19,.31,0.0,PI,Color("af9c81"),9)
	for side in [-1,1]:
		_stone(Vector3(side*.76,-1.63,.13),Vector3(.22,.62,.31),STONE.darkened(.1),.025)
	_stone(Vector3(0,-.39,.17),Vector3(2.16,.24,.60),Color("b9a17f"),.08)
	for step in 4:
		_stone(Vector3(0,-.67-step*.29,.45+step*.27),Vector3(1.64,.25,.46),Color("a39079").darkened(step*.025),.07)
	for side in [-1,1]:
		_cylinder(Vector3(side*.96,-.40,.15),Vector3(.18,.56,.18),WOOD,1)
		_cylinder(Vector3(side*.96,-.24,.15),Vector3(.31,.12,.31),GOLD,3)
		if index!=1:
			for k in 3:_arc(Vector3(side*.96,-.21+k*.045,.15),.15,.025,0,TAU,Color("bca47d"),10,1)

func _hill_channel(index:int)->void:
	# Curved earth shelves and a visibly hollow stone water chute, below the path.
	for tier in 3:
		var width:float=2.40-tier*.24
		_stone(Vector3(0,-.39-tier*.48,.1+tier*.19),Vector3(width,.32,.78),Color("839071").darkened(tier*.03),.18)
		for side in [-1,1]:_stone(Vector3(side*.30,-.19-tier*.48,.12+tier*.19),Vector3(.15,.18,.67),Color("a8a68a"),.045)
		_stone(Vector3(0,-.21-tier*.48,.15+tier*.19),Vector3(.42,.035,.63),Color("5d9494"),.025)
	if index==1:
		for side in [-1,1]:
			_beam(Vector3(side*.46,-1.65,.73),Vector3(side*.46,-.34,.18),.065,WOOD)

func _old_aqueduct(index:int)->void:
	for side in [-1,1]:
		_stone(Vector3(side*.88,-.77,.11),Vector3(.44,1.22,.61),Color("81918a"),.14)
		_stone(Vector3(side*.92,-.16,.13),Vector3(.64,.18,.74),Color("a1ad99"),.09)
	_arch(Vector3(0,-.95,.18),.78,.23,.47,.12,PI-(.43 if index==2 else .12),Color("939f8e"),10)
	for i in 5:
		var p:=Vector3(-1.15+i*.23,-.3-i*.23,.44)
		_sphere(p,Vector3(.35,.14,.22),Color("6b897b"))
	_stone(Vector3(.1,-1.75,.36),Vector3(1.80,.13,.65),Color("6e8c86"),.21)

func _inner_infrastructure(d:Dictionary)->void:
	var kind:String=["market_loading_apron","mill_irrigation_garden","ruin_reliquary_ring"][int(d.id)]
	var site:Dictionary=_safe_inner(d,1.10,.78)
	_inner_sites.append(site)
	if not bool(site.found):return
	_matrix=Transform3D(Basis.IDENTITY,site.position)
	match int(d.id):
		0:
			# Inset timber wheel turntable and a curved stone unloading apron.
			_cylinder(Vector3(0,.05,0),Vector3(1.84,.09,1.56),Color("a89476"))
			for i in 7:
				var z:float=-.61+i*.20;var length:float=sqrt(maxf(.1,.80*.80-z*z))*2
				_stone(Vector3(0,.105,z),Vector3(length,.075,.16),WOOD.lightened(.08),.025,Vector3.ZERO,1)
			_arc(Vector3(0,.15,0),.79,.035,0,TAU,GOLD,16)
			_cylinder(Vector3(0,.18,0),Vector3(.29,.12,.29),GOLD,3)
			for side in [-1,1]:
				_cylinder(Vector3(side*.63,.35,-.23),Vector3(.31,.40,.31),WOOD,1)
				_arc(Vector3(side*.63,.57,-.23),.16,.03,0,TAU,GOLD,12)
		1:
			_stone(Vector3(0,.09,0),Vector3(1.83,.17,1.50),Color("7d8b62"),.22)
			for row in 3:
				var z:float=-.43+row*.41
				for j in 8:
					var x:float=-.67+j*.19
					_beam(Vector3(x,.19,z),Vector3(x+.04,.58,z-.02),.025,Color("ab9c61"))
					_sphere(Vector3(x+.04,.59,z-.02),Vector3(.13,.20,.11),Color("c9b477"),6)
			for side in [-1,1]:_stone(Vector3(side*.93,.15,0),Vector3(.13,.23,1.71),Color("a6a78a"),.04)
			_stone(Vector3(0,.14,.91),Vector3(1.83,.05,.21),Color("588b88"),.05)
		2:
			# Broken annular plinth with radial paving and roots reaching its edge.
			for j in 9:
				if j==5:continue
				var a:float=j*TAU/9
				_stone(Vector3(cos(a)*.72,.13,sin(a)*.72),Vector3(.48,.25,.37),Color("8c9d8e"),.08,Vector3(0,-a,0))
			_cylinder(Vector3(0,.10,0),Vector3(1.19,.18,1.19),Color("6b877b"))
			_cylinder(Vector3(0,.26,0),Vector3(.60,.19,.60),Color("a1aa92"))
			for i in 4:
				var a:float=i*TAU/4+.23
				_beam(Vector3(cos(a)*.28,.18,sin(a)*.28),Vector3(cos(a)*.95,.08,sin(a)*.95),.055,WOOD.darkened(.08))
	_inner_sites[-1].kind=kind
	_matrix=Transform3D.IDENTITY

func _safe_inner(d:Dictionary,radius:float,height:float)->Dictionary:
	var best:Dictionary={"district":int(d.id),"found":false,"radius":radius,"height":height}
	var merit:float=-INF
	for x in range(-6,7):
		for z in range(-4,5):
			var p:Vector3=d.center+Vector3(x*.80,-.23,z*.80)
			var road:float=_route_distance(p)
			if road<radius+1.2:continue
			var occupied:bool=false
			for old:Dictionary in _painter.placements:
				if int(old.district)!=int(d.id):continue
				if Vector2(p.x-old.pos.x,p.z-old.pos.z).length()<float(old.requested_clearance)-.65+radius+.30:occupied=true;break
			if occupied or not _projection_clear(p,radius,height):continue
			var score:float=road-.13*Vector2(x,z).length()
			if score>merit:
				merit=score;best={"district":int(d.id),"found":true,"position":p,"radius":radius,"height":height,"road_clearance":road,"projection_clear":true}
	return best

func _ruin_fragments(d:Dictionary)->void:
	# Replace the three already reserved column groups, without adding props or
	# draw objects. High stone stays within the old envelope. Roots remain low,
	# connected to those columns, and stop well before every playable route.
	for index in _painter.ruin_fragments.size():
		var source:Dictionary=_painter.ruin_fragments[index]
		var p:Vector3=source.position
		var height:float=[1.34,1.02,.81][index]
		var start:int=_triangles*3
		_matrix=Transform3D(Basis.IDENTITY,p);_feature_max_y=-INF
		_stone(Vector3(0,.05,0),Vector3(.90,.14,.82),Color("839185"),.14,Vector3(0,.10*index,0))
		_stone(Vector3(-.08,.15,-.035),Vector3(.61,.12,.58),Color("a0a993"),.10)
		_arc(Vector3(-.08,.24,-.035),.245,.052,0,TAU,Color("a4ac99"),16)
		_broken_shaft(Vector3(-.08,.26,-.035),.245,height-.26,index,Color("9da992"))
		# A fallen drum with exposed dark fracture, aligned differently at each site.
		var saved:Transform3D=_matrix
		_matrix=saved*Transform3D(Basis.from_euler(Vector3(0,.27-index*.31,-1.40)),Vector3(.34,.20,.22))
		_broken_shaft(Vector3(0,-.22,0),.16,.48,index+2,Color("909d88"))
		_matrix=saved
		# A broad vine climbs the visible side of the shaft. Leaves are thick,
		# simple toy shapes rather than alpha cards or a spray of tiny spheres.
		var vine:Array[Vector3]=[]
		for i in 9:
			var t:float=float(i)/8;var a:float=.30+t*3.35+index*.7
			vine.append(Vector3(-.08+cos(a)*.275,.17+t*(height-.27),-.035+sin(a)*.275))
		_tube_path(vine,.031,Color("647e61"))
		for i in [1,3,5,7]:
			var outward:Vector3=Vector3(vine[i].x+.08,.17,vine[i].z+.035).normalized()
			_leaf(vine[i],outward,.22,.095,Color("789367"))
		var high_end:int=_triangles*3
		var high_max:float=_feature_max_y
		_ruin_roots(p,index,float(d.height)-.24)
		_ruin_sites.append({"position":p,"variant":index,"old_height":source.old_height,"maximum_height":high_max-p.y,"high_radius_limit":.73,"high_start_vertex":start,"high_end_vertex":high_end,"end_vertex":_triangles*3,"route_margin":1.20,"projection_clear":_projection_clear(p,.73,height)})
	_matrix=Transform3D.IDENTITY

func _broken_shaft(p:Vector3,radius:float,height:float,variant:int,colour:Color)->void:
	# Twelve broad flutes, a slightly bulging stone profile and an uneven broken
	# face. A missing wedge changes the silhouette, not only its surface colour.
	var rings:Array[PackedVector3Array]=[]
	for row in 5:
		var ring:=PackedVector3Array();var t:float=float(row)/4
		for j in 36:
			var angle:float=j*TAU/36
			var r:float=radius*(1.0+.055*sin(t*PI))*(.952+.048*cos(angle*12))
			var chip:float=maxf(0.0,cos(angle-variant*.81-.5))
			var y:float=height*t
			if row==4:
				y-=height*(.08+.23*pow(chip,5))+.025*sin(angle*5+variant)
				r*=1.0-.14*pow(chip,6)
			ring.append(p+Vector3(cos(angle)*r,y,sin(angle)*r))
		rings.append(ring)
	for row in 4:
		for j in 36:
			var k:int=(j+1)%36;var outward:Vector3=(rings[row][j]+rings[row][k])*.5-p
			outward.y=0
			_facing_quad(rings[row][j],rings[row][k],rings[row+1][k],rings[row+1][j],colour.darkened(.018 if j%3==1 else 0),outward)
	var core:Vector3=p+Vector3(.015,height*.77,-.012)
	for j in 36:
		var a:Vector3=rings[4][j];var b:Vector3=rings[4][(j+1)%36]
		if (b-core).cross(a-core).y>=0:_triangle(core,a,b,colour.darkened(.13+.035*sin(j*.71)))
		else:_triangle(core,b,a,colour.darkened(.13+.035*sin(j*.71)))
		_triangle(p,rings[0][(j+1)%36],rings[0][j],colour.darkened(.12))

func _ruin_roots(p:Vector3,index:int,ground_y:float)->void:
	# Low, irregular connected moss/root aprons give each fragment a context.
	# These have neither round landing pads nor stripes that resemble a route.
	var ground:float=ground_y-p.y+.018
	var ring:Array[Vector3]=[]
	for i in 18:
		var a:float=i*TAU/18
		var radius:float=1.05+.15*sin(a*3+index)+.11*cos(a*5-index)
		var q:=Vector3(cos(a)*radius,ground,sin(a)*radius)
		while radius>.50 and _route_distance(p+q)<1.20:
			radius-=.06;q=Vector3(cos(a)*radius,ground,sin(a)*radius)
		ring.append(q)
	for i in 18:
		_triangle(Vector3(0,ground,0),ring[i],ring[(i+1)%18],Color("6f8874").lightened(.014*sin(i*1.7)),7)
	for branch in 5:
		var angle:float=branch*TAU/5+index*.43
		var path:Array[Vector3]=[]
		for step in 7:
			var t:float=float(step)/6;var distance:float=.24+t*.92
			var a:float=angle+sin(t*PI)*.22
			var q:=Vector3(cos(a)*distance,ground+.032+sin(t*PI)*.015,sin(a)*distance)
			if _route_distance(p+q)<1.25:break
			path.append(q)
		if path.size()<2:continue
		_tube_path(path,.027,Color("788164"))
		if path.size()>4:
			var direction:Vector3=Vector3(-sin(angle),.25,cos(angle)).normalized()
			_leaf(path[3],direction,.25,.115,Color("809573"))

func _tube_path(points:Array[Vector3],radius:float,colour:Color)->void:
	if points.size()<2:return
	var rings:Array[PackedVector3Array]=[]
	for i in points.size():
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var x:Vector3=tangent.cross(Vector3.UP).normalized()
		if x.length_squared()<.01:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:Vector3=tangent.cross(x).normalized();var ring:=PackedVector3Array()
		for j in 6:ring.append(points[i]+(x*cos(j*TAU/6)+z*sin(j*TAU/6))*radius*(1.0-.30*float(i)/points.size()))
		rings.append(ring)
	for i in points.size()-1:
		for j in 6:
			var k:int=(j+1)%6
			var normal:Vector3=(rings[i][j]+rings[i][k]-points[i]*2).normalized()
			_facing_quad(rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j],colour,normal,5)

func _leaf(p:Vector3,direction:Vector3,length:float,width:float,colour:Color)->void:
	var across:Vector3=direction.cross(Vector3.UP).normalized()
	var tip:Vector3=p+direction*length
	var left:Vector3=p+direction*length*.43+across*width
	var right:Vector3=p+direction*length*.43-across*width
	var ridge:Vector3=p+direction*length*.42+Vector3.UP*.043
	_facing_quad(p,left,tip,ridge,colour,Vector3.UP,5)
	_facing_quad(p,ridge,tip,right,colour.lightened(.06),Vector3.UP,5)
	_facing_quad(p,right,tip,left,colour.darkened(.10),Vector3.DOWN,5)

func _route_distance(p:Vector3)->float:
	var best:float=INF
	for edge:Variant in _edges:
		if FurPartyMap.is_ferry_edge(int(edge[0]),int(edge[1])):continue
		var first:Vector3=_tiles[int(edge[0])].pos;var last:Vector3=_tiles[int(edge[1])].pos
		var a:=Vector2(first.x,first.z);var b:=Vector2(last.x,last.z);var q:=Vector2(p.x,p.z);var delta:Vector2=b-a
		best=minf(best,q.distance_to(a+delta*clampf((q-a).dot(delta)/maxf(delta.length_squared(),.001),0,1)))
	return best

func _projection_clear(p:Vector3,radius:float,height:float)->bool:
	for tile:Dictionary in _tiles:
		var q:Vector3=tile.pos
		if (p.y+height)*.644+(p.z+radius)*.765<q.y*.644+q.z*.765-.15:continue
		var low:float=p.y*.765-p.z*.644-radius*.644
		var high:float=(p.y+height)*.765-p.z*.644+radius*.644
		var at:float=q.y*.765-q.z*.644
		if absf(p.x-q.x)<radius+.85 and at+2.3>low and at-.7<high:return false
	return true

func _triangle(a:Vector3,b:Vector3,c:Vector3,colour:Color,family:int=0)->void:
	var normal:Vector3=(c-a).cross(b-a).normalized()
	_st.set_color(colour);_st.set_normal(_matrix.basis*normal);_st.set_uv2(Vector2(family,0))
	for p:Vector3 in [a,b,c]:
		var world:Vector3=_matrix*p;_st.add_vertex(world);_feature_max_y=maxf(_feature_max_y,world.y)
	_triangles+=1

func _quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,colour:Color,family:int=0)->void:
	_triangle(a,b,c,colour,family);_triangle(a,c,d,colour,family)

func _facing_quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,colour:Color,normal:Vector3,family:int=0)->void:
	if (c-a).cross(b-a).dot(normal)>=0:_quad(a,b,c,d,colour,family)
	else:_quad(a,d,c,b,colour,family)

func _stone(p:Vector3,size:Vector3,colour:Color,cut:float,rotation:Vector3=Vector3.ZERO,family:int=0)->void:
	var half:Vector2=Vector2(size.x,size.z)*.5;cut=minf(cut,minf(half.x,half.y)*.55)
	var outline:Array[Vector2]=[Vector2(-half.x+cut,-half.y),Vector2(half.x-cut,-half.y),Vector2(half.x,-half.y+cut),Vector2(half.x,half.y-cut),Vector2(half.x-cut,half.y),Vector2(-half.x+cut,half.y),Vector2(-half.x,half.y-cut),Vector2(-half.x,-half.y+cut)]
	var basis:=Basis.from_euler(rotation)
	for i in 8:
		var a:Vector3=p+basis*Vector3(outline[i].x,size.y*.5,outline[i].y)
		var b:Vector3=p+basis*Vector3(outline[(i+1)%8].x,size.y*.5,outline[(i+1)%8].y)
		_triangle(p+basis*Vector3(0,size.y*.5,0),a,b,colour,family)
		var outward:Vector3=((a+b)*.5-p);outward-=basis*Vector3.UP*size.y*.5
		_facing_quad(a,b,b-basis*Vector3.UP*size.y,a-basis*Vector3.UP*size.y,colour.darkened(.07),outward,family)

func _arch(p:Vector3,radius:float,width:float,depth:float,from:float,to:float,colour:Color,segments:int)->void:
	for i in segments:
		var a:float=lerpf(from,to,float(i)/segments)+.012
		var b:float=lerpf(from,to,float(i+1)/segments)-.012
		var inside_a:=Vector3(cos(a)*radius,sin(a)*radius,0)
		var inside_b:=Vector3(cos(b)*radius,sin(b)*radius,0)
		var outside_a:=Vector3(cos(a)*(radius+width),sin(a)*(radius+width),0)
		var outside_b:=Vector3(cos(b)*(radius+width),sin(b)*(radius+width),0)
		var back:=Vector3(0,0,-depth*.5);var front:Vector3=-back
		_facing_quad(p+inside_a+front,p+outside_a+front,p+outside_b+front,p+inside_b+front,colour,Vector3.BACK)
		_facing_quad(p+inside_b+back,p+outside_b+back,p+outside_a+back,p+inside_a+back,colour.darkened(.07),Vector3.FORWARD)
		_facing_quad(p+inside_a+back,p+outside_a+back,p+outside_a+front,p+inside_a+front,colour.darkened(.04),Vector3(sin(a),-cos(a),0))
		_facing_quad(p+inside_b+back,p+outside_b+back,p+outside_b+front,p+inside_b+front,colour.darkened(.04),Vector3(-sin(b),cos(b),0))
		_facing_quad(p+outside_a+back,p+outside_b+back,p+outside_b+front,p+outside_a+front,colour,(outside_a+outside_b).normalized())
		_facing_quad(p+inside_b+back,p+inside_a+back,p+inside_a+front,p+inside_b+front,colour.darkened(.14),-(inside_a+inside_b).normalized())

func _arc(p:Vector3,radius:float,thick:float,from:float,to:float,colour:Color,count:int,family:int=3)->void:
	for i in count:
		var a:float=lerpf(from,to,float(i)/count);var b:float=lerpf(from,to,float(i+1)/count)
		var radial_a:=Vector3(cos(a),0,sin(a));var radial_b:=Vector3(cos(b),0,sin(b))
		for side in 6:
			var c:float=side*TAU/6;var d:float=(side+1)*TAU/6
			var va:Vector3=p+radial_a*(radius+cos(c)*thick)+Vector3.UP*sin(c)*thick
			var vb:Vector3=p+radial_b*(radius+cos(c)*thick)+Vector3.UP*sin(c)*thick
			var vc:Vector3=p+radial_b*(radius+cos(d)*thick)+Vector3.UP*sin(d)*thick
			var vd:Vector3=p+radial_a*(radius+cos(d)*thick)+Vector3.UP*sin(d)*thick
			var normal:Vector3=(radial_a+radial_b)*cos((c+d)*.5)*.5+Vector3.UP*sin((c+d)*.5)
			_facing_quad(va,vb,vc,vd,colour,normal,family)

func _shape(kind:String,p:Vector3,size:Vector3,colour:Color,basis:Basis=Basis.IDENTITY,family:int=0)->void:
	if not _cache.has(kind):
		var mesh:PrimitiveMesh
		if kind=="sphere":
			var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=5;mesh=sphere
		else:
			var cylinder:=CylinderMesh.new();cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.height=1;cylinder.radial_segments=12;cylinder.rings=1;mesh=cylinder
		_cache[kind]=mesh
	var arrays:Array=_cache[kind].get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var transform:=Transform3D(basis.scaled(size),p);var normal_basis:Basis=transform.basis.inverse().transposed()
	_st.set_color(colour);_st.set_uv2(Vector2(family,0))
	for i in indices:
		_st.set_normal((_matrix.basis*normal_basis*normals[i]).normalized())
		var world:Vector3=_matrix*(transform*vertices[i]);_st.add_vertex(world);_feature_max_y=maxf(_feature_max_y,world.y)
	_triangles+=indices.size()/3

func _sphere(p:Vector3,size:Vector3,colour:Color,family:int=5)->void:_shape("sphere",p,size,colour,Basis.IDENTITY,family)
func _cylinder(p:Vector3,size:Vector3,colour:Color,family:int=0)->void:_shape("cylinder",p,size,colour,Basis.IDENTITY,family)
func _beam(a:Vector3,b:Vector3,radius:float,colour:Color,family:int=1)->void:
	var delta:Vector3=b-a
	if delta.length()<.0001:return
	var y:Vector3=delta.normalized();var x:Vector3=y.cross(Vector3.FORWARD).normalized()
	if x.length_squared()<.01:x=y.cross(Vector3.RIGHT).normalized()
	_shape("cylinder",(a+b)*.5,Vector3(radius*2,delta.length(),radius*2),colour,Basis(x,y,x.cross(y)),family)
