class_name FurPartyFerryView
extends Node3D
## Curved hull, bevelled deck, sewn balloon. Batches share materials, not 200 draws.
## No transport-domain changes: follow still consumes authoritative path position.
const Geometry=preload("res://scripts/party/pawn_geometry.gd")
var clock:=0.0
var boat:Node3D
var materials:Dictionary={}
var batches:Dictionary={}
func _ready()->void:
	boat=Node3D.new();add_child(boat)
	var timber:=_mat(Color("8d6042"));var edge:=_mat(Color("335a63"));var brass:=_mat(Color("c6a56a"),.38,.65)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array[Vector3]=[Vector3(.05,-.58,.08),Vector3(.44,-.5,.82),Vector3(.72,-.29,1.17),Vector3(.85,-.06,1.30),Vector3(.81,.07,1.27)]
	for row in rings.size()-1:
		for i in 32:
			var points:Array[Vector3]=[]
			for uv:Vector2 in [Vector2(i,row),Vector2(i+1,row),Vector2(i+1,row+1),Vector2(i,row+1)]:
				var r:Vector3=rings[int(uv.y)];var a:float=uv.x*TAU/32.0;points.append(Vector3(cos(a)*r.x,r.y,sin(a)*r.z))
			for j in [0,1,2,0,2,3]:st.add_vertex(points[j])
	st.generate_normals();_part(st.commit(),Vector3.ZERO,Vector3.ONE,timber)
	for i in 9:
		var z:float=-1.08+i*.27;var width:float=1.48*sqrt(maxf(.1,1.0-pow(z/1.29,2)))
		_part(Geometry.rounded_box(),Vector3(0,.055,z),Vector3(width*.5,.042,.127),_mat(Color("cda773") if i%2==0 else Color("d5b281")))
	for z in [-.67,.61]:_part(Geometry.rounded_box(),Vector3(0,.22,z),Vector3(.72,.075,.115),timber)
	for i in 32:
		var a:float=i*TAU/32.0;var b:float=(i+1)*TAU/32.0
		_rope(Vector3(cos(a)*.84,.14,sin(a)*1.28),Vector3(cos(b)*.84,.14,sin(b)*1.28),.045,edge)
	var fabric:=SurfaceTool.new();fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 12:
		for col in 32:
			var colour:=Color("e7cf99") if (col/4)%2==0 else Color("648b88")
			for uv:Vector2 in [Vector2(col,row),Vector2(col+1,row+1),Vector2(col+1,row),Vector2(col,row),Vector2(col,row+1),Vector2(col+1,row+1)]:
				var az:float=uv.x*TAU/32;var el:float=uv.y*PI/12
				fabric.set_color(colour);fabric.add_vertex(Vector3(sin(el)*cos(az)*1.1,cos(el)*.72+3.35,sin(el)*sin(az)*1.55-.18))
	fabric.generate_normals();var cloth:=_mat(Color.WHITE);cloth.vertex_color_use_as_albedo=true;_part(fabric.commit(),Vector3.ZERO,Vector3.ONE,cloth)
	for x in [-.72,.72]:
		for z in [-.7,.7]:
			_rope(Vector3(x,.15,z),Vector3(x*.94,3.06,z-.18),.022,timber)
			_part(Geometry.rounded_box(),Vector3(x,.19,z),Vector3(.063,.085,.063),brass)
	for k in 16:
		var a:float=k*TAU/16.0
		for j in 12:
			var e1:float=j*PI/12;var e2:float=(j+1)*PI/12
			_rope(Vector3(sin(e1)*cos(a)*1.106,cos(e1)*.726+3.35,sin(e1)*sin(a)*1.556-.18),Vector3(sin(e2)*cos(a)*1.106,cos(e2)*.726+3.35,sin(e2)*sin(a)*1.556-.18),.006,_mat(Color("baa478")))
	for material in batches:
		var instance:=MeshInstance3D.new();instance.mesh=batches[material].commit();instance.material_override=material;boat.add_child(instance)
	batches.clear();visible=false
func _mat(colour:Color,roughness:float=.8,metallic:float=0)->StandardMaterial3D:
	var key:String=colour.to_html()+str(roughness)+str(metallic)
	if materials.has(key):return materials[key]
	var m:=StandardMaterial3D.new();m.albedo_color=colour;m.roughness=roughness;m.metallic=metallic;materials[key]=m;return m
func _part(shape:Mesh,pos:Vector3,scale3:Vector3,material:Material,orientation:Basis=Basis.IDENTITY)->void:
	if not batches.has(material):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[material]=st
	# Mixing indexed primitives with non-indexed authored hulls otherwise leaves
	# the hull vertices out of the final index buffer. Normalize every input.
	var expanded:=SurfaceTool.new();expanded.create_from(shape,0);expanded.deindex()
	batches[material].append_from(expanded.commit(),0,Transform3D(orientation.scaled(scale3),pos))
func _rope(a:Vector3,b:Vector3,radius:float,material:Material)->void:
	if a.distance_to(b)<.001:return
	var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=6;shape.rings=1
	_part(shape,(a+b)*.5,Vector3.ONE,material,Basis(Quaternion(Vector3.UP,(b-a).normalized())))
func follow(pos:Vector3,yaw:float,delta:float)->void:
	clock+=delta;position=pos-Vector3.UP*.05;rotation.y=yaw;boat.rotation.z=sin(clock*3)*.025;visible=true
