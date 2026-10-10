class_name FurPawnGeometry
extends RefCounted
## Rounded toy parts share geometry/material resources across board, arena and portraits.
static var _meshes:Dictionary={}
static var _materials:Dictionary={}

static func sphere()->SphereMesh:
	if not _meshes.has("sphere"):
		var shape:=SphereMesh.new();shape.radius=1.0;shape.height=2.0;shape.radial_segments=32;shape.rings=16
		_meshes.sphere=shape
	return _meshes.sphere

static func material(colour:Color,kind:String="fur")->StandardMaterial3D:
	var key:String=colour.to_html()+kind
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new();mat.albedo_color=colour
		mat.roughness=0.84 if kind=="cloth" else 0.72
		if kind=="eye":mat.roughness=0.18;mat.clearcoat_enabled=true;mat.clearcoat=0.32;mat.clearcoat_roughness=0.16
		if kind=="nose":mat.roughness=0.32
		if kind=="metal":mat.roughness=0.33;mat.metallic=0.5
		_materials[key]=mat
	return _materials[key]

static func rounded_box()->ArrayMesh:
	if _meshes.has("rounded_box"):return _meshes.rounded_box
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var values:Array[float]=[-1.0,-0.978,-0.916,-0.822,-0.70,0.70,0.822,0.916,0.978,1.0]
	for face in 6:
		var axis:int=face/2
		var sign_value:float=-1.0 if face%2==0 else 1.0
		for y in values.size()-1:
			for x in values.size()-1:
				var raw:Array[Vector3]=[]
				for uv:Vector2 in [Vector2(values[x],values[y]),Vector2(values[x+1],values[y]),Vector2(values[x+1],values[y+1]),Vector2(values[x],values[y+1])]:
					var point:=Vector3(sign_value,uv.x,uv.y) if axis==0 else (Vector3(uv.y,sign_value,uv.x) if axis==1 else Vector3(uv.x,uv.y,sign_value))
					var inside:=Vector3(clampf(point.x,-0.7,0.7),clampf(point.y,-0.7,0.7),clampf(point.z,-0.7,0.7))
					raw.append(inside+(point-inside).normalized()*0.30)
				var order:Array=[0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]
				for idx:int in order:tool.add_vertex(raw[idx])
	tool.generate_normals()
	var result:ArrayMesh=tool.commit();_meshes.rounded_box=result
	return result

static func soft_ear()->ArrayMesh:
	if _meshes.has("ear"):return _meshes.ear
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile:Array[Vector3]=[Vector3(0.19,0,0.14),Vector3(0.25,0.18,0.16),Vector3(0.23,0.36,0.135),Vector3(0.155,0.55,0.10),Vector3(0.060,0.70,0.045),Vector3(0.007,0.765,0.007)]
	for row in profile.size()-1:
		for i in 20:
			var a:float=i*TAU/20.0;var b:float=(i+1)*TAU/20.0
			var points:Array[Vector3]=[]
			for data:Vector3 in [Vector3(row,a,0),Vector3(row,b,0),Vector3(row+1,b,0),Vector3(row+1,a,0)]:
				var p:Vector3=profile[int(data.x)]
				points.append(Vector3(cos(data.y)*p.x+p.y*0.05,p.y,sin(data.y)*p.z))
			for idx:int in [0,1,2,0,2,3]:tool.add_vertex(points[idx])
	tool.generate_normals()
	var result:ArrayMesh=tool.commit();_meshes.ear=result
	return result

static func scarf_tail()->ArrayMesh:
	if _meshes.has("scarf_tail"):return _meshes.scarf_tail
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 7:
		for col in 5:
			var points:Array[Vector3]=[]
			for uv:Vector2 in [Vector2(col,row),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
				var u:float=uv.x/5.0;var v:float=uv.y/7.0
				points.append(Vector3((u-0.5)*(0.27+v*0.08),-v*0.55,0.024*sin(u*TAU*1.5)+0.08*sin(v*PI)))
			for depth:float in [-0.022,0.022]:
				var order:Array=[0,2,1,0,3,2] if depth<0 else [0,1,2,0,2,3]
				for idx:int in order:tool.add_vertex(points[idx]+Vector3(0,0,depth))
	tool.generate_normals()
	var result:ArrayMesh=tool.commit();_meshes.scarf_tail=result
	return result

static func forehead_blaze()->ArrayMesh:
	if _meshes.has("blaze"):return _meshes.blaze
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 12:
		for col in 8:
			var points:Array[Vector3]=[]
			for uv:Vector2 in [Vector2(col,row),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
				var t:float=uv.y/12.0;var y:float=lerpf(1.63,2.30,t)
				var width:float=lerpf(.18,.047,t)*(1.0+.12*sin(t*PI))
				var x:float=(uv.x/8.0*2.0-1.0)*width
				var z:float=.015+.57*sqrt(maxf(.001,1.0-x*x/(.715*.715)-(y-1.82)*(y-1.82)/(.61*.61)))+.008
				points.append(Vector3(x,y,z))
			for idx:int in [0,2,1,0,3,2]:tool.add_vertex(points[idx])
	tool.generate_normals()
	var result:ArrayMesh=tool.commit();_meshes.blaze=result
	return result

