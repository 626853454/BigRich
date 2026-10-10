class_name FurPartyCoastalRockGeometry
extends RefCounted
## One weathered, genuinely open sea arch. A continuous bevelled section follows
## the curved vault and reaches the water; no ellipsoid plugs fill its opening.
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
static var _cache:Dictionary={}

static func sea_arch(colour:Color)->ArrayMesh:
	var key:String=colour.to_html()
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP);st.set_uv2(Vector2.ZERO)
	var rings:Array=[];var centers:Array[Vector3]=[]
	for step in 21:
		var angle:float=clampf((step-2)*PI/16.0,0,PI)
		var drop:float=-1.92 if step in [0,20] else (-.78 if step in [1,19] else 0.0)
		var radial:=Vector3(cos(angle),sin(angle),0)
		var center:=Vector3(radial.x*.92,.12+radial.y*.835+drop,.36);centers.append(center)
		var section:Array[Vector3]=[]
		for cross in 8:
			var inside:bool=cross in [0,1,6,7]
			var bevel:float=.055 if cross in [1,2,5,6] else 0.0
			var radius_x:float=(.63+bevel) if inside else (1.16-bevel)
			var radius_y:float=(.61+bevel) if inside else (1.06-bevel)
			var rough:float=(.013*sin(angle*5.0)+.009*cos(angle*9.0))*(1.0 if not inside else .35)
			var front:bool=cross<=3;var z:float=(.945 if front else -.225) if bevel>0 else (.89 if front else -.17)
			section.append(Vector3(radial.x*(radius_x+rough),.12+radial.y*(radius_y+rough)+drop,z+.014*sin(angle*3)))
		rings.append(section)
	for row in rings.size()-1:
		for j in 8:
			var k:int=(j+1)%8
			var a:Vector3=rings[row][j];var b:Vector3=rings[row][k];var c:Vector3=rings[row+1][k];var d:Vector3=rings[row+1][j]
			var expected:Vector3=(a+b+c+d)*.25-(centers[row]+centers[row+1])*.5
			var shade:Color=colour.lightened(.026*sin(row*.74)-(.10 if j==7 else 0.0))
			Foliage._quad(st,a,b,c,d,expected.normalized(),shade)
	for end:int in [0,20]:
		for j in 8:Foliage._triangle(st,centers[end],rings[end][j],rings[end][(j+1)%8],Vector3.DOWN,colour.darkened(.15))
	# Two low, non-uniform toe stones continue the vault into its wet footing.
	for side:float in [-1.0,1.0]:
		var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=10;sphere.rings=4
		var arrays:Array=sphere.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var size:=Vector3(.70,.43,.80);var point:=Vector3(side*1.39,-1.58,.48)
		for i:int in arrays[Mesh.ARRAY_INDEX]:
			var v:Vector3=vertices[i];var factor:float=1.0+.055*sin(v.x*9+v.z*5+side)
			st.set_normal((normals[i]/size).normalized());st.set_color(colour.darkened(.12));st.add_vertex(point+v*size*factor)
	var mesh:ArrayMesh=st.commit();mesh.surface_set_material(0,Crafted.material(0,-2.96));_cache[key]=mesh;return mesh
