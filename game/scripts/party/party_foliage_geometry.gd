class_name FurPartyFoliageGeometry
extends RefCounted
## Thick toy leaves with a center fold and rounded shoulders, never alpha cards.
## Appended into the existing district mesh: no extra bush draw objects.
static var _cache:Dictionary={}

static func bush(theme:String,variant:int=0)->ArrayMesh:
	var key:String=theme+str(posmod(variant,2))
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_uv2(Vector2(5,0))
	var leaf:Color=Color("638d6c") if theme=="ruins" else (Color("92a86c") if theme=="windmill" else Color("7da06c"))
	for ring in 2:
		var count:int=7 if ring==0 else 5
		for i in count:
			var a:float=i*TAU/count+ring*.44+posmod(variant,2)*.31
			var origin:=Vector3(cos(a)*.06,.10+ring*.13,sin(a)*.045)
			var end:=Vector3(cos(a)*(.40-ring*.13),.10+ring*.10+sin(a*3)*.02,sin(a)*(.33-ring*.10))
			leaf_piece(st,origin,end,.20-ring*.025,leaf.lightened(.035*float(i%3)),5)
	# Three real five-petal flowers replace the old three unarticulated spheres.
	for flower in 3:
		var a:float=flower*TAU/3+.52+variant*.21
		var p:=Vector3(cos(a)*.21,.31+float(flower%2)*.035,sin(a)*.15)
		var blossom:Color=[Color("d9b280"),Color("d596a3"),Color("cbbb72")][posmod(variant+flower,3)]
		for petal in 5:
			var angle:float=petal*TAU/5
			leaf_piece(st,p,p+Vector3(cos(angle)*.108,.035,sin(angle)*.108),.09,blossom,6)
		leaf_piece(st,p+Vector3(-.033,.03,0),p+Vector3(.033,.052,0),.07,Color("b58a43"),6)
	var result:ArrayMesh=st.commit();_cache[key]=result;return result

static func append(st:SurfaceTool,mesh:Mesh,transform:Transform3D)->int:
	var data:Array=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=data[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=data[Mesh.ARRAY_COLOR];var tags:PackedVector2Array=data[Mesh.ARRAY_TEX_UV2]
	var normal_basis:Basis=transform.basis.inverse().transposed()
	for i in vertices.size():
		st.set_normal((normal_basis*normals[i]).normalized());st.set_color(colors[i]);st.set_uv2(tags[i]);st.add_vertex(transform*vertices[i])
	st.set_uv2(Vector2.ZERO);return vertices.size()

static func leaf_piece(st:SurfaceTool,base:Vector3,tip:Vector3,width:float,color:Color,family:int=5)->void:
	var axis:Vector3=(tip-base).normalized();var side:=Vector3(-axis.z,0,axis.x).normalized()
	if side.length_squared()<.01:side=Vector3.RIGHT
	var mid:Vector3=base.lerp(tip,.47);var ridge:Vector3=mid+Vector3.UP*width*.24
	var outline:Array[Vector3]=[base,base.lerp(tip,.19)+side*width*.40,mid+side*width*.52,base.lerp(tip,.77)+side*width*.35,tip,base.lerp(tip,.77)-side*width*.35,mid-side*width*.52,base.lerp(tip,.19)-side*width*.40]
	st.set_uv2(Vector2(family,0))
	for i in 8:
		var a:Vector3=outline[i];var b:Vector3=outline[(i+1)%8]
		_triangle(st,ridge,a,b,Vector3.UP,color.lightened(.025 if i<4 else -.025))
		_triangle(st,mid-Vector3.UP*.017,b-Vector3.UP*.012,a-Vector3.UP*.012,Vector3.DOWN,color.darkened(.10))
		_quad(st,a,b,b-Vector3.UP*.012,a-Vector3.UP*.012,(a+b-mid*2).normalized(),color.darkened(.08))

static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,outward:Vector3,color:Color)->void:
	var points:Array[Vector3]=[a,b,c];var normal:Vector3=(b-a).cross(c-a).normalized()
	if normal.dot(outward)<0:normal=-normal
	if (b-a).cross(c-a).dot(normal)>0:points=[a,c,b]
	for p:Vector3 in points:st.set_color(color);st.set_normal(normal);st.add_vertex(p)

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,outward:Vector3,color:Color)->void:
	_triangle(st,a,b,c,outward,color);_triangle(st,a,c,d,outward,color)
