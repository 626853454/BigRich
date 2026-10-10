class_name FurPartyRuinGeometry
extends RefCounted
## Real radial wedge stones, recessed joints and climbing foliage; one cached mesh.
const Bridge=preload("res://scripts/party/party_bridge_geometry.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
static var _mesh:ArrayMesh

static func mesh()->ArrayMesh:
	if _mesh!=null:return _mesh
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP);st.set_uv2(Vector2.ZERO)
	var stone:=Color("8d9e92")
	for side:float in [-1.0,1.0]:
		for row in 5:
			var basis:=Basis(Vector3.UP,.015*sin(row*1.8+side))
			Bridge.plank(st,Transform3D(basis,Vector3(side*1.18,.28+row*.42,0)),Vector3(.52,.38,.73),stone.lightened(float(row%2)*.035),0)
		Bridge.plank(st,Transform3D(Basis.IDENTITY,Vector3(side*1.18,.08,0)),Vector3(.78,.16,.91),stone.darkened(.065),0)
	for i in 9:
		if i==2:continue
		var middle:float=PI-i*PI/8
		var half_width:float=.177 if i!=3 else .156
		_wedge(st,middle-half_width,middle+half_width,stone.lightened(float(i%3)*.022))
	for i in 5:
		var point:=Vector3(-1.8+i*.8,.12,.65+sin(i)*.30)
		Bridge.plank(st,Transform3D(Basis(Vector3.UP,.19*sin(i)),point),Vector3(.50,.22,.40),stone.darkened(.025),0)
	# A climbing woody vine replaces evenly spaced moss spheres.
	for branch in 2:
		var points:Array[Vector3]=[]
		for i in 12:points.append(Vector3(-1.18+sin(i*.53+branch)*(.13+branch*.035),.26+i*.21,.39+branch*.03))
		st.set_uv2(Vector2(1,0));Bridge.tube(st,points,.027,Color("6e7956"),6)
		for i in 6:
			var p:Vector3=points[1+i*2];var side:float=-1 if i%2==0 else 1
			Foliage.leaf_piece(st,p,p+Vector3(side*.21,.105,.07),.20,Color("668963").lightened(branch*.04),5)
	_mesh=st.commit();_mesh.surface_set_material(0,Crafted.material(-1));return _mesh

static func _wedge(st:SurfaceTool,a:float,b:float,color:Color)->void:
	var points:Array[Vector3]=[Vector3(cos(a)*.96,1.90+sin(a)*.86,0),Vector3(cos(b)*.96,1.90+sin(b)*.86,0),Vector3(cos(b)*1.42,1.90+sin(b)*1.30,0),Vector3(cos(a)*1.42,1.90+sin(a)*1.30,0)]
	var center:Vector3=(points[0]+points[1]+points[2]+points[3])*.25
	st.set_uv2(Vector2.ZERO)
	for sign_z:float in [-1.0,1.0]:
		var normal:=Vector3(0,0,sign_z)
		var inset:Array[Vector3]=[]
		for p:Vector3 in points:inset.append(p.lerp(center,.105)+Vector3(0,0,sign_z*.365))
		Foliage._quad(st,inset[0],inset[1],inset[2],inset[3],normal,color)
		for i in 4:
			var next:int=(i+1)%4
			var p:Vector3=points[i]+Vector3(0,0,sign_z*.325);var q:Vector3=points[next]+Vector3(0,0,sign_z*.325)
			Foliage._quad(st,inset[i],inset[next],q,p,(normal+(points[i]-center).normalized()).normalized(),color.lightened(.025))
	for i in 4:
		var next:int=(i+1)%4
		var outward:Vector3=((points[i]+points[next])*.5-center).normalized()
		Foliage._quad(st,points[i]+Vector3(0,0,.325),points[next]+Vector3(0,0,.325),points[next]-Vector3(0,0,.325),points[i]-Vector3(0,0,.325),outward,color.darkened(.055))
