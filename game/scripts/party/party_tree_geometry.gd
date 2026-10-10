class_name FurPartyTreeGeometry
extends RefCounted
## Cached toy trees. One surface/material per tree, no textures, nodes or animation.
## Local origin is the original tree root. Keep caller transforms unchanged.
static var _cache:Dictionary={}
const Crafted=preload("res://scripts/party/party_environment_material.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")

static func mesh(theme:String,variant:int=0)->ArrayMesh:
	var forest:bool=theme=="ruins"
	var type_id:int=posmod(variant,3)
	var key:String=("ruins" if forest else "orchard")+str(type_id)
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_uv2(Vector2(1,0))
	var height_scale:float=1.0 if forest else .884
	var wood:=Color("775943");var bark:=Color("82694f")
	var leaf:=Color("53805e") if forest else Color("7b9c56")
	var lean:float=[-.12,.10,.025][type_id]
	# Thick curves and rounded forks are visible beneath the crown instead of a pole.
	_tube(st,[Vector3(0,.04,0),Vector3(-lean*.35,.38,.015),Vector3(lean,.85,.025),Vector3(lean*.8,1.28,-.055),Vector3(lean*.3,1.76,-.02)],[.16,.12,.10,.078,.035],wood,height_scale,8)
	for branch in 3:
		var angle:float=branch*TAU/3.0+type_id*.57
		var end:=Vector3(cos(angle)*.51,1.48+branch*.10,sin(angle)*.40)
		_tube(st,[Vector3(lean*.7,.87+branch*.1,.02),Vector3(end.x*.59,1.22+branch*.06,end.z*.56),end],[.074,.057,.019],bark,height_scale,7)
	# Four low buttress roots stay within the former tree footprint.
	for root in 4:
		var angle:float=root*TAU/4.0+type_id*.46
		_tube(st,[Vector3(0,.20,0),Vector3(cos(angle)*.23,.10,sin(angle)*.23),Vector3(cos(angle)*.43,.035,sin(angle)*.43)],[.085,.065,.012],wood,height_scale,6)
	st.set_uv2(Vector2(5,0))
	# Closed curved leaf cushions build one rounded crown. The former thin
	# three-layer sprays read as exposed poles at the ordinary overview camera.
	# These are original elongated leaf volumes, never hidden sphere stacks.
	var flip:float=-1.0 if type_id==1 else 1.0
	for layer in 3:
		var count:int=[5,5,3][layer]
		for leaf_id in count:
			var angle:float=leaf_id*TAU/count+layer*.62+type_id*.43
			var origin:=Vector3(cos(angle)*-.10,[1.34,1.55,1.83][layer],sin(angle)*-.08)
			var reach:float=[.82,.62,.29][layer]
			var end:=Vector3(cos(angle)*reach*flip,[1.38,1.89,2.32][layer]+.065*sin(leaf_id*2.4+type_id),sin(angle)*reach*.93)
			origin.y*=height_scale;end.y*=height_scale
			_cushion_leaf(st,origin,end,[.77,.85,.61][layer],[.19,.24,.21][layer]*height_scale,leaf.lightened(layer*.040+.019*sin(leaf_id*1.8)))
	if not forest:
		st.set_uv2(Vector2(6,0))
		for fruit in 3:
			var p:Vector3=[Vector3(-.48,1.27,.35),Vector3(.46,1.44,.32),Vector3(.07,1.91,.39)][fruit]
			p.x*=flip
			_crown(st,p,Vector3(.083,.09,.083),Color("bd7d58"),0,height_scale,8,4,false)
	var result:ArrayMesh=st.commit();result.surface_set_material(0,material());_cache[key]=result
	return result

static func _cushion_leaf(st:SurfaceTool,base:Vector3,tip:Vector3,width:float,thickness:float,colour:Color)->void:
	var axis:Vector3=(tip-base).normalized();var side:=Vector3(-axis.z,0,axis.x).normalized()
	if side.length_squared()<.01:side=Vector3.RIGHT
	var up:Vector3=axis.cross(side).normalized()
	if up.y<0:up=-up
	var rings:Array=[];var normals:Array=[];var centers:Array[Vector3]=[]
	for row in 5:
		var t:float=row/4.0
		var center:Vector3=base.lerp(tip,t)+Vector3.UP*sin(t*PI)*.12
		var profile:float=[.055,.77,1.0,.67,.025][row]
		var ring:Array[Vector3]=[];var ring_normals:Array[Vector3]=[]
		for j in 6:
			var a:float=j*TAU/6
			var point:Vector3=center+side*cos(a)*width*.50*profile+up*sin(a)*thickness*profile
			# Preserve the existing tree envelope and tile clearance guarantees.
			point.x=clampf(point.x,-.90,.90);point.z=clampf(point.z,-.86,.86);point.y=minf(point.y,2.47)
			ring.append(point);ring_normals.append((side*cos(a)/maxf(width*.50,.01)+up*sin(a)/maxf(thickness,.01)).normalized())
		rings.append(ring);normals.append(ring_normals);centers.append(center)
	st.set_uv2(Vector2(5,0))
	for row in 4:
		for j in 6:
			var k:int=(j+1)%6
			var pairs:Array[Vector2i]=[Vector2i(row,j),Vector2i(row+1,k),Vector2i(row,k),Vector2i(row,j),Vector2i(row+1,j),Vector2i(row+1,k)]
			var a:Vector3=rings[row][j];var b:Vector3=rings[row+1][k];var c:Vector3=rings[row][k]
			if (b-a).cross(c-a).dot(normals[row][j])>0:pairs.reverse()
			for pair:Vector2i in pairs:
				var normal:Vector3=normals[pair.x][pair.y]
				st.set_normal(normal);st.set_color(colour.lightened(normal.y*.025));st.add_vertex(rings[pair.x][pair.y])
	for row:int in [0,4]:
		var normal:Vector3=-axis if row==0 else axis
		for j in 6:Foliage._triangle(st,centers[row],rings[row][j],rings[row][(j+1)%6],normal,colour)

static func material()->ShaderMaterial:
	return Crafted.material(-1)

static func _tube(st:SurfaceTool,points:Array[Vector3],radii:Array[float],colour:Color,height_scale:float,sides:int)->void:
	var rings:Array[PackedVector3Array]=[]
	for row in points.size():
		var tangent:Vector3=(points[mini(row+1,points.size()-1)]-points[maxi(row-1,0)]).normalized()
		var right:Vector3=tangent.cross(Vector3.FORWARD).normalized()
		if right.length_squared()<.1:right=Vector3.RIGHT
		var forward:Vector3=right.cross(tangent).normalized();var ring:=PackedVector3Array()
		for column in sides:
			var a:float=column*TAU/sides
			ring.append(points[row]+(right*cos(a)+forward*sin(a))*radii[row])
		rings.append(ring)
	for row in points.size()-1:
		for column in sides:
			var next:int=(column+1)%sides
			for pair:Vector2i in [Vector2i(row,column),Vector2i(row,next),Vector2i(row+1,next),Vector2i(row,column),Vector2i(row+1,next),Vector2i(row+1,column)]:
				var vertex:Vector3=rings[pair.x][pair.y];var normal:Vector3=(vertex-points[pair.x]).normalized()
				st.set_normal(Vector3(normal.x,normal.y/height_scale,normal.z).normalized());st.set_color(colour.lightened(.022*cos(pair.y*TAU/sides)))
				vertex.y*=height_scale;st.add_vertex(vertex)
	# Branch tips are covered by foliage. Root bases remain sealed at ground level.
	for row:int in [0,points.size()-1]:
		var normal:Vector3=(points[0]-points[1]).normalized() if row==0 else (points[row]-points[row-1]).normalized()
		normal=Vector3(normal.x,normal.y/height_scale,normal.z).normalized()
		for column in sides:
			var a:Vector3=rings[row][column];var b:Vector3=rings[row][(column+1)%sides]
			var triangle:Array=[points[row],b,a] if row==0 else [points[row],a,b]
			for vertex:Vector3 in triangle:
				st.set_normal(normal);st.set_color(colour);vertex.y*=height_scale;st.add_vertex(vertex)

static func _crown(st:SurfaceTool,center:Vector3,scale3:Vector3,colour:Color,phase:float,height_scale:float,segments:int,rings:int,sculpted:bool=true)->void:
	var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=segments;sphere.rings=rings
	var data:Array=sphere.get_mesh_arrays();var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=data[Mesh.ARRAY_INDEX]
	for index:int in indices:
		var unit:Vector3=vertices[index]
		var angle:float=atan2(unit.z,unit.x)
		var wave:float=1.0+(.065*sin(angle*3+phase)+.025*cos(angle*5-phase))*(1.0-unit.y*unit.y) if sculpted else 1.0
		var p:Vector3=center+Vector3(unit.x*wave,unit.y,unit.z*wave)*scale3
		p.x=clampf(p.x,-.9,.9);p.z=clampf(p.z,-.86,.86);p.y*=height_scale
		var normal:Vector3=(unit/Vector3(scale3.x,scale3.y*height_scale,scale3.z)).normalized()
		st.set_normal(normal);st.set_color(colour.lightened(.023*unit.y));st.add_vertex(p)
