class_name FurChapterBoardWorld
extends Node3D
## Independent chapter 1/2 board geometry. The original island builder is never run.
## Only its reusable tile/icon primitives are shared for consistent landing symbols.
const Map=preload("res://scripts/party/adventure_map.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
const MeshKit=preload("res://scripts/party/world_builder.gd")
var chapter:int=1
var tiles:Array=[]
var districts:Array[Dictionary]=[]
var geometry_report:Dictionary={}
var _kit:Node3D
var _star:Node3D
var _active:Node3D
var _path:Array[Node3D]=[]
var _outlines:Array[PackedVector2Array]=[]
var _surfaces:Array[MeshInstance3D]=[]
var _links:Array=[]

func build(nodes:Array,edges:Array,index:int)->void:
	for child in get_children():
		remove_child(child);child.free()
	_path.clear();_outlines.clear();_surfaces.clear();geometry_report.clear()
	chapter=clampi(index,1,2);tiles=nodes.duplicate(true);_links=edges.duplicate(true);districts=Map.districts(chapter)
	_kit=MeshKit.new();_kit.name="ChapterGeometryKit";add_child(_kit);_kit.set_process(false)
	for district:Dictionary in districts:
		var outline:PackedVector2Array=_outline(district);_outlines.append(outline)
		_platform(district,outline)
	_routes()
	for tile:Dictionary in tiles:
		_kit._tile(tile)
		if bool(tile.get("elevated",false)):_elevated_support(tile)
		if str(tile.get("activity",""))=="challenge":_station_mark(tile)
	_kit._flush_batches();_kit._combine_static_geometry()
	_active=Node3D.new();_active.name="ChapterActiveTile";add_child(_active);_kit._ring(Vector3(0,.12,0),1.035,1.12,.045,Color("ffe7aa"),_active,true);_active.hide()
	_star=Node3D.new();_star.name="ChapterStarDestination";add_child(_star)
	_kit._cylinder(Vector3(0,.10,0),.2,.36,Color("bd955c"),_star)
	_kit._cylinder(Vector3(0,.62,0),.9,.055,Color("9e8055"),_star)
	_kit._mesh(_kit._star_mesh(),Vector3(0,1.32,0),Vector3(.68,.68,.68),Color("f4ce79"),_star,true);_star.hide()
	geometry_report={"chapter":chapter,"tile_count":tiles.size(),"platforms":districts.size(),"non_ferry_edges":_non_ferry_count(),"static_draw_objects":_kit.static_draw_objects,"original_archipelago_created":false,"surface_triangles":_terrain_triangles(),"has_process":false}

func set_active_tile(index:int)->void:
	if not is_instance_valid(_active):return
	_active.visible=index>=0 and index<tiles.size()
	if _active.visible:_active.position=tiles[index].pos

func set_star(index:int)->void:
	if not is_instance_valid(_star):return
	_star.visible=index>=0 and index<tiles.size()
	if not _star.visible:return
	var point:Vector3=tiles[index].pos
	var d:Dictionary=districts[int(tiles[index].district)]
	var outward:Vector3=point-Vector3(d.center);outward.y=0
	if outward.length_squared()<.01:outward=Vector3.RIGHT
	_star.position=point+outward.normalized()*1.46

func set_path(ids:Array)->void:
	for marker:Node3D in _path:marker.hide()
	var used:int=0
	for value:Variant in ids:
		if typeof(value)!=TYPE_INT or int(value)<0 or int(value)>=tiles.size():continue
		if used>=tiles.size():break
		if used>=_path.size():
			var mark:=Node3D.new();mark.name="ChapterPath_%d"%used;add_child(mark);_kit._ring(Vector3(0,.12,0),1.045,1.10,.025,Color("f8d796"),mark,true);_path.append(mark)
		_path[used].position=tiles[int(value)].pos;_path[used].show();used+=1

func set_properties(_properties:Array)->void:
	# Later-chapter stations are run by AdventureModel, not the legacy property economy.
	pass

func set_contract(_contract:Dictionary)->void:
	pass

func _outline(d:Dictionary)->PackedVector2Array:
	var extent:Vector2=Vector2(d.get("size",Vector2(22,18)))*.5
	var result:=PackedVector2Array()
	if str(d.get("shape","square"))=="gear":
		# Broad clockwork teeth keep the whole playable footprint filled: the
		# inner gear radius is 92% of the full bounds, not a thin decorative ring.
		for tooth in 12:
			for corner in 4:
				var angle:float=(float(tooth)+float(corner)/4.0)*TAU/12.0
				var ratio:float=.92 if corner in [0,3] else 1.0
				# The straight-run route has broad corners. A full-bodied rounded
				# gear keeps each complete disc supported within the same bounds.
				var cx:float=cos(angle);var sz:float=sin(angle)
				result.append(Vector2(signf(cx)*pow(absf(cx),.6)*extent.x*ratio,signf(sz)*pow(absf(sz),.6)*extent.y*ratio))
	else:
		var bevel:float=1.15
		result=PackedVector2Array([Vector2(-extent.x+bevel,-extent.y),Vector2(extent.x-bevel,-extent.y),Vector2(extent.x,-extent.y+bevel),Vector2(extent.x,extent.y-bevel),Vector2(extent.x-bevel,extent.y),Vector2(-extent.x+bevel,extent.y),Vector2(-extent.x,extent.y-bevel),Vector2(-extent.x,-extent.y+bevel)])
	return result

func _platform(d:Dictionary,outline:PackedVector2Array)->void:
	var center:Vector3=d.center;var height:float=float(d.height)
	var terrace:=FurHarborCraftedAssets.terrace(chapter,int(d.id));terrace.position=Vector3(center.x,height,center.z);_kit.add_child(terrace)
	for mesh:Node in terrace.find_children("*","MeshInstance3D",true,false):_surfaces.append(mesh)
	var extent:Vector2=Vector2(d.get("size",Vector2(22,18)))*.5
	if chapter==1:
		for i in 12:
			var angle:float=float(i)*TAU/12
			# Billows support the lower court edge; their tops must not poke
			# through the upper stone fascia as disconnected white pinholes.
			_kit._batch("cloud",Vector3(center.x+cos(angle)*extent.x*.97,height-2.25,center.z+sin(angle)*extent.y*.97),Vector3(3.4,1.55,2.8),Color("d3dfd7"),Vector3(0,angle*.17,0))
		# Interior dressing supplies local paved courtyards. No board-wide
		# raised grid: thin shadow-casting bars looked like a spreadsheet.
	# The authored clock terrace now includes its real open-spoke underside.

func _routes()->void:
	var visited:Dictionary={}
	for edge:Variant in _links:
		var a_id:int=int(edge[0]);var b_id:int=int(edge[1])
		if Map.is_ferry_edge(a_id,b_id):continue
		var key:=Vector2i(mini(a_id,b_id),maxi(a_id,b_id))
		if visited.has(key):continue
		visited[key]=true
		var a:Vector3=tiles[a_id].pos;var b:Vector3=tiles[b_id].pos;var delta:Vector3=b-a
		var span:float=delta.length();var middle:Vector3=(a+b)*.5
		var bridge:bool=bool(tiles[a_id].get("bridge",false)) or bool(tiles[b_id].get("bridge",false)) or bool(tiles[a_id].get("elevated",false)) or bool(tiles[b_id].get("elevated",false)) or int(tiles[a_id].district)!=int(tiles[b_id].district)
		var rotation:Vector3=Basis.looking_at(delta,Vector3.UP).get_euler()
		var tint:Color=Color("ded5ba") if chapter==1 else Color("c4b49b")
		if not bridge:_kit._batch("box",middle-Vector3(0,.19,0),Vector3(1.40,.11,span+.05),tint,rotation)
		if not bridge:
			var lateral:=Vector3(-delta.z,0,delta.x).normalized()
			var count:int=maxi(2,int(ceil(span/.72)))
			for part in count:
				var at:Vector3=a.lerp(b,(part+.5)/float(count))-Vector3(0,.12,0)
				for side in [-1,1]:_kit._batch("box",at+lateral*side*.35,Vector3(.665,.055,span/float(count)*.90),tint.lightened(.025 if (part+side)%3==0 else .0),rotation)
			continue
		var crossing:=MeshInstance3D.new();crossing.name="AuthoredStoneCrossing";crossing.mesh=FurAuthoredBridgeMesh.bridge(a,b);crossing.material_override=FurPartyEnvironmentMaterial.material(0);_kit.add_child(crossing)

func _station_mark(tile:Dictionary)->void:
	# Ground-level three-dot inlay marks an activity; it cannot cover an animal face.
	var point:Vector3=tile.pos
	for i in 3:
		_kit._batch("sphere",point+Vector3(-.24+i*.24,.185,.5),Vector3(.095,.045,.095),Color("fff4c9"))

func _elevated_support(tile:Dictionary)->void:
	var point:Vector3=tile.pos
	var ground:float=float(districts[int(tile.district)].height)
	var leg:float=maxf(point.y-ground-.25,.1)
	# Narrow twin supports straddle the overhead landing, leaving the
	# lower route visually open instead of filling it with a solid wall.
	for x:float in [-.76,.76]:
		_kit._batch("cylinder",Vector3(point.x+x,ground+leg*.5,point.z),Vector3(.15,leg,.15),Color("a09073"))
	_kit._batch("cylinder",point-Vector3(0,.24,0),Vector3(2.16,.15,2.16),Color("9b927e"))

func _face(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3,colour:Color)->void:
	st.set_color(colour);st.set_normal(normal)
	# Enforce clockwise front faces relative to the explicit outward normal.
	var order:Array=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
	for p:Vector3 in order:st.add_vertex(p)

func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3,colour:Color)->void:
	_face(st,a,b,c,normal,colour);_face(st,a,c,d,normal,colour)

func _terrain_triangles()->int:
	var total:int=0
	for item:MeshInstance3D in _surfaces:
		if is_instance_valid(item):total+=item.mesh.get_faces().size()/3
	return total

func _non_ferry_count()->int:
	var count:int=0
	for edge:Variant in _links:
		if not Map.is_ferry_edge(int(edge[0]),int(edge[1])):count+=1
	return count
