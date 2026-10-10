class_name FurMahjongTileGeometry
extends RefCounted
## Real numbered suits and honor faces. Geometry is shared by physical tile IDs.
const Toy=preload("res://scripts/party/pawn_geometry.gd")
const FontStyle=preload("res://scripts/furball/visual_style.gd")
static var _faces:Dictionary={}
static var _ink:StandardMaterial3D
static var _body:ArrayMesh
static var _back:ArrayMesh

static func body()->ArrayMesh:
	if _body!=null:return _body
	# A Mahjong tile needs a silhouette bevel, not the animal mesh's fine grid.
	# 300 triangles versus 972 per body; ray bounds/physical IDs stay unchanged.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var values:Array[float]=[-1.0,-.966,-.76,.76,.966,1.0]
	for side in 6:
		var axis:int=side/2;var sign_value:float=-1.0 if side%2==0 else 1.0
		for y in values.size()-1:
			for x in values.size()-1:
				var raw:Array[Vector3]=[]
				for uv:Vector2 in [Vector2(values[x],values[y]),Vector2(values[x+1],values[y]),Vector2(values[x+1],values[y+1]),Vector2(values[x],values[y+1])]:
					var point:=Vector3(sign_value,uv.x,uv.y) if axis==0 else (Vector3(uv.y,sign_value,uv.x) if axis==1 else Vector3(uv.x,uv.y,sign_value))
					var inside:=Vector3(clampf(point.x,-.76,.76),clampf(point.y,-.76,.76),clampf(point.z,-.76,.76))
					var bevelled:Vector3=inside+(point-inside).normalized()*.24
					# The front glaze well is physically shallower than its rounded rim.
					# Existing physical extents / ray boxes and 300-triangle budget remain.
					if axis==2 and sign_value>0 and absf(uv.x)<=.76 and absf(uv.y)<=.76:bevelled.z=.925
					raw.append(bevelled)
				for index:int in ([0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]):st.add_vertex(raw[index])
	st.generate_normals();_body=st.commit();return _body

static func back()->ArrayMesh:
	if _back!=null:return _back
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rounded celadon border and one shared paw seal. No tile identity is revealed.
	var contour:PackedVector3Array=[]
	for corner in 4:
		var center:Vector2=[Vector2(.47,.56),Vector2(-.47,.56),Vector2(-.47,-.56),Vector2(.47,-.56)][corner]
		for step in 5:
			var angle:float=(corner*PI*.5)+float(step)*PI/8
			contour.append(Vector3(center.x+cos(angle)*.15,center.y+sin(angle)*.15,-1.016))
	# Continuous four-sided bead: no overlapping capped tubes at every corner.
	# The small bevel remains real geometry and keeps the rounded silhouette.
	for i in contour.size():
		var next:int=(i+1)%contour.size()
		for side in 4:
			var points:Array[Vector3]=[]
			for pair:Vector2i in [Vector2i(i,side),Vector2i(next,side),Vector2i(next,(side+1)%4),Vector2i(i,(side+1)%4)]:
				var tangent:Vector3=(contour[(pair.x+1)%contour.size()]-contour[(pair.x-1+contour.size())%contour.size()]).normalized()
				var normal:=Vector3(tangent.y,-tangent.x,0)
				var angle:float=float(pair.y)*TAU/4.0
				points.append(contour[pair.x]+normal*cos(angle)*.021+Vector3(0,0,sin(angle)*.021))
			for id:int in [0,2,1,0,3,2]:st.set_color(Color("a0c7ae"));st.add_vertex(points[id])
	var pad:=SphereMesh.new();pad.radius=.18;pad.height=.28;pad.radial_segments=10;pad.rings=3
	_append(st,pad,Transform3D(Basis().scaled(Vector3(1,1,.10)),Vector3(0,-.13,-1.021)),Color("91bca4"))
	for i in 4:
		var toe:=SphereMesh.new();toe.radius=.074;toe.height=.19;toe.radial_segments=8;toe.rings=2
		var x:float=(float(i)-1.5)*.145;var y:float=.12+(.052 if i in [1,2] else 0.0)
		_append(st,toe,Transform3D(Basis(Vector3.FORWARD,(float(i)-1.5)*-.16).scaled(Vector3(1,1,.12)),Vector3(x,y,-1.019)),Color("91bca4"))
	st.generate_normals();_back=st.commit();_back.surface_set_material(0,material());return _back

static func face_name(type:int)->String:
	if type<0 or type>=34:return "未知牌"
	if type<27:return str(type%9+1)+["万","筒","索"][type/9]
	return ["东风","南风","西风","北风","红中","发财","白板"][type-27]

static func material()->StandardMaterial3D:
	if _ink==null:
		_ink=StandardMaterial3D.new();_ink.vertex_color_use_as_albedo=true;_ink.vertex_color_is_srgb=true;_ink.roughness=.58;_ink.metallic_specular=.18
	return _ink

static func face(type:int)->ArrayMesh:
	if _faces.has(type):return _faces[type]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red:=Color("a6303a");var green:=Color("17654c");var navy:=Color("1b3e59")
	if type<9:
		_text(st,["一","二","三","四","五","六","七","八","九"][type],Vector3(0,.28,.191),navy,.0055)
		_text(st,"萬",Vector3(0,-.28,.191),red,.0051)
	elif type<18:
		var rank:int=type%9+1
		for i in rank:
			var point:Vector2=_pip_position(rank,i)
			var disk:=CylinderMesh.new();disk.top_radius=.088 if rank>1 else .235;disk.bottom_radius=disk.top_radius;disk.height=.018;disk.radial_segments=14;disk.rings=1
			_append(st,disk,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(point.x,point.y,.19)),[navy,green,red][i%3])
			var center:=CylinderMesh.new();center.top_radius=.038 if rank>1 else .14;center.bottom_radius=center.top_radius;center.height=.02;center.radial_segments=12;center.rings=1
			_append(st,center,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(point.x,point.y,.204)),Color("f5efd7"))
	elif type<27:
		var rank:int=type%9+1
		if rank==1:
			var bird:=SphereMesh.new();bird.radius=.20;bird.height=.51;bird.radial_segments=14;bird.rings=7
			_append(st,bird,Transform3D(Basis().scaled(Vector3(1,1,.15)),Vector3(0,-.07,.21)),green)
			var head:=SphereMesh.new();head.radius=.09;head.height=.18;head.radial_segments=12;head.rings=5
			_append(st,head,Transform3D(Basis().scaled(Vector3(1,1,.2)),Vector3(.07,.23,.21)),green)
			_stick(st,Vector3(.15,.24,.212),Vector3(.26,.19,.212),.027,red)
			_stick(st,Vector3(-.11,-.19,.212),Vector3(-.21,-.40,.212),.044,navy)
			_stick(st,Vector3(.02,-.15,.215),Vector3(.14,-.35,.215),.04,red)
		else:
			for i in rank:
				var point:Vector2=_pip_position(rank,i)
				_stick(st,Vector3(point.x,point.y-.10,.205),Vector3(point.x,point.y+.10,.205),.025,red if i==rank-1 and rank==7 else green)
				_stick(st,Vector3(point.x-.045,point.y,.21),Vector3(point.x+.045,point.y,.21),.018,green)
	else:
		var word:String=["東","南","西","北","中","發",""][type-27]
		if type==33:
			for side in 4:
				var a:Vector3=[Vector3(-.23,-.35,.20),Vector3(.23,-.35,.20),Vector3(.23,.35,.20),Vector3(-.23,.35,.20)][side]
				var b:Vector3=[Vector3(.23,-.35,.20),Vector3(.23,.35,.20),Vector3(-.23,.35,.20),Vector3(-.23,-.35,.20)][side]
				_stick(st,a,b,.026,navy)
		else:_text(st,word,Vector3(0,0,.191),green if type==32 else (red if type==31 else navy),.0075)
	st.generate_normals();var mesh:ArrayMesh=st.commit();mesh.surface_set_material(0,material());_faces[type]=mesh;return mesh

static func _pip_position(count:int,index:int)->Vector2:
	if count==1:return Vector2.ZERO
	if count==2:return Vector2(0,.23 if index==0 else -.23)
	if count==3:return Vector2(-.18+index*.18,.29-index*.29)
	if count==4:return Vector2(-.18 if index%2==0 else .18,.27 if index<2 else -.27)
	if count==5:
		if index==4:return Vector2.ZERO
		return _pip_position(4,index)
	if count==6:return Vector2(-.18 if index%2==0 else .18,.30-(index/2)*.30)
	if count==7:
		if index==6:return Vector2(0,.40)
		return Vector2(-.18 if index%2==0 else .18,.17-(index/2)*.28)
	if count==8:return Vector2(-.18 if index%2==0 else .18,.39-(index/2)*.26)
	return Vector2(-.22+(index%3)*.22,.32-(index/3)*.32)

static func _text(st:SurfaceTool,word:String,position:Vector3,color:Color,pixel:float)->void:
	var text:=TextMesh.new();text.font=FontStyle.font();text.text=word;text.font_size=80;text.pixel_size=pixel;text.depth=.008;text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_append(st,text,Transform3D(Basis(),position),color)

static func _stick(st:SurfaceTool,a:Vector3,b:Vector3,radius:float,color:Color)->void:
	var tube:=CylinderMesh.new();tube.top_radius=radius;tube.bottom_radius=radius;tube.height=a.distance_to(b);tube.radial_segments=8;tube.rings=1
	var normal:Vector3=(b-a).normalized();var x:Vector3=normal.cross(Vector3.FORWARD).normalized();var z:Vector3=x.cross(normal).normalized()
	_append(st,tube,Transform3D(Basis(x,normal,z),(a+b)*.5),color)

static func _append(st:SurfaceTool,mesh:Mesh,transform:Transform3D,color:Color)->void:
	var arrays:Array=mesh.surface_get_arrays(0)
	var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for vertex in points:
			var p:Vector3=transform*vertex
			# Thin coloured inlay rests in the ceramic face well, rather than floating.
			if p.z>0:p.z=.167+(p.z-.19)*.22
			st.set_color(color);st.add_vertex(p)
	else:
		for index in indices:
			var p:Vector3=transform*points[index]
			if p.z>0:p.z=.167+(p.z-.19)*.22
			st.set_color(color);st.add_vertex(p)
