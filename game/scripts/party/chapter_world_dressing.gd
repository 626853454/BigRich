class_name FurChapterWorldDressing
extends Node3D
## Self-owned visual scenery. Authoritative board positions are read-only.
## The parent chooses the active camera and applies environment_profile().
const Map=preload("res://scripts/party/party_map.gd")
const ChapterMap=preload("res://scripts/party/adventure_map.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const SurfaceNoise=preload("res://scripts/party/party_surface_noise.gd")
const CloudGeometry=preload("res://scripts/party/party_cloud_geometry.gd")
const CLOUD_SHADER=preload("res://assets/party/environment_v2/cloud_sea.gdshader")
const WOOD:=Color("8c654e")
const DARK:=Color("5d4c55")
const CREAM:=Color("eee3c7")
const BRASS:=Color("b39359")
var chapter:int=-1
var placement_report:Array[Dictionary]=[]
var geometry_report:Dictionary={}
var interior_report:Array[Dictionary]=[]
var ground_report:Array[Dictionary]=[]
var _ground_samples:Array[Dictionary]=[]
var _occupied:Array[Dictionary]=[]
var _host:Node3D
var _visual:Node3D
var _tiles:Array=[]
var _edges:Array=[]
var _segments:Array[PackedVector2Array]=[]
var _ground_values:Dictionary={}
var _cache:Dictionary={}
var _surface:SurfaceTool
var _triangles:int=0
var _parts:int=0
var _material:ShaderMaterial
var _family:int=0
var _model_origin:=Vector3.ZERO
var _model_scale:float=1.0

func build(board_root:Node3D,tiles:Array,edges:Array)->void:
	clear();_host=board_root;_tiles=tiles.duplicate(true);_edges=edges.duplicate(true)
	_segments.clear()
	for edge:Variant in _edges:
		if Map.is_ferry_edge(int(edge[0]),int(edge[1])):continue
		var a:Vector3=_tiles[int(edge[0])].pos;var b:Vector3=_tiles[int(edge[1])].pos
		_segments.append(PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z)]))
	name="ChapterWorldDressingController"
	if _material==null:
		_material=Crafted.material(-1)
	set_chapter(0)

func clear()->void:
	if is_instance_valid(_visual):
		if _visual.get_parent()!=null:_visual.get_parent().remove_child(_visual)
		_visual.free()
	_visual=null;chapter=-1;placement_report.clear();geometry_report.clear();interior_report.clear();ground_report.clear();_ground_samples.clear()

func _exit_tree()->void:
	# The host may itself be freeing its children. Never remove a sibling
	# synchronously from that busy parent during controller teardown.
	if is_instance_valid(_visual):_visual.queue_free()
	_visual=null

func set_chapter(index:int)->void:
	var requested:int=clampi(index,0,2)
	if not is_instance_valid(_host):return
	if chapter==requested and is_instance_valid(_visual):return
	clear();chapter=requested
	_visual=Node3D.new();_visual.name="ChapterDressingRoot";_host.add_child(_visual)
	_triangles=0;_parts=0
	for district:Dictionary in ChapterMap.districts(chapter):
		var site:Dictionary=_safe_anchor(district)
		placement_report.append(site)
		if not bool(site.found):continue
		var center:Vector3=site.position
		_begin()
		if chapter==0:_harbor_scene(center,int(district.id))
		elif chapter==1:_tea_scene(center,int(district.id))
		else:_clock_scene(center,int(district.id))
		_finish("ChapterLandmark_%d"%int(district.id))
		if chapter>0:
			_begin();_interior_scene(district);_finish("ChapterInterior_%d"%int(district.id))
	if chapter>0:
		_cloud_sea()
		_begin()
		for district:Dictionary in ChapterMap.districts(chapter):
			for i in 9:
				var angle:float=float(i)*TAU/9+.12*sin(float(i)*2.3)
				var radius:Vector2=Vector2(district.get("size",Vector2(27.6,21.4)))*.5
				var offset:float=.6+.8*sin(float(i)*1.7)
				var p:Vector3=district.center+Vector3(cos(angle)*(radius.x+offset),-float(district.height)-1.35+.26*sin(float(i)*2.1),sin(angle)*(radius.y+offset))
				_shape("cloud",p,Vector3(4.5+.55*sin(i),1.7+.20*cos(i),3.1+.3*sin(i*2)),Color("e0e9e6") if chapter==1 else Color("dedfe9"),Vector3(0,angle*.23,0))
		_finish("ChapterCloudBanks")
		var cloud_material:=ShaderMaterial.new();cloud_material.shader=preload("res://assets/art/sevenhour_v1/cloud_porcelain_soft.gdshader")
		var cloud_mesh:=_visual.get_node("ChapterCloudBanks") as MeshInstance3D
		cloud_mesh.material_override=cloud_material;cloud_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_report={"chapter":chapter,"triangles":_triangles,"primitive_parts":_parts,"draw_objects":_visual.get_child_count(),"placements":placement_report.duplicate(true),"interiors":interior_report.duplicate(true),"ground_layer":ground_report.duplicate(true)}

func environment_profile()->Dictionary:
	var profiles:Array[Dictionary]=[
		{"name":"糖风海岛","background":Color("b8d4d8"),"ambient_color":Color("e2d9d0"),"ambient_energy":.48,"sun_color":Color("ffe9cc"),"sun_energy":.84},
		{"name":"云顶茶城","background":Color("d4d5e5"),"ambient_color":Color("dddceb"),"ambient_energy":.5,"sun_color":Color("fff0db"),"sun_energy":.78},
		{"name":"时序空港","background":Color("a9abc7"),"ambient_color":Color("d7d5ea"),"ambient_energy":.48,"sun_color":Color("f7dfbd"),"sun_energy":.82}]
	return profiles[clampi(chapter,0,2)].duplicate(true)

func _safe_anchor(d:Dictionary)->Dictionary:
	var preferred:float=[PI+.22,-PI/2,-.22][int(d.id)]
	var best:Dictionary={"district":int(d.id),"found":false,"position":Vector3.ZERO,"road_clearance":0.0,"projection_clear":false}
	for extra:float in [0.0,1.4,2.8]:
		for shift:float in [0.0,-.22,.22,-.45,.45]:
			var angle:float=preferred+shift
			var point:Vector3=d.center+Vector3(cos(angle)*(15.2+extra),-.24,sin(angle)*(12.5+extra))
			var road:float=_route_distance(point)
			if road<4.5:continue
			var safe:bool=true
			# Bounds include widest wind-wing and full clock/tea roof. Projection
			# uses the board's 32/38 pitch and a whole animal standing on each tile.
			var low:float=point.y*.765-point.z*.644-2.3*.644
			var high:float=point.y*.765-point.z*.644+4.8*.765+2.3*.644
			for tile:Dictionary in _tiles:
				var p:Vector3=tile.pos;var vertical:float=p.y*.765-p.z*.644
				if absf(point.x-p.x)<3.4 and vertical+2.4>low and vertical-.75<high:safe=false;break
			if not safe:continue
			return {"district":int(d.id),"found":true,"position":point,"road_clearance":road,"projection_clear":true,"width_bound":5.2,"height_bound":4.8}
	return best

func _route_distance(point:Vector3)->float:
	var result:float=INF;var q:=Vector2(point.x,point.z)
	for segment:PackedVector2Array in _segments:
		var a:Vector2=segment[0];var b:Vector2=segment[1];var line:Vector2=b-a
		var t:float=clampf((q-a).dot(line)/maxf(line.length_squared(),.001),0,1)
		result=minf(result,q.distance_to(a+line*t))
	return result

func _interior_scene(d:Dictionary)->void:
	_occupied.clear()
	var specs:Array[Dictionary]=[
		{"role":"tea_house" if chapter==1 else "clock_tower","radius":1.96,"height":2.55,"preferred":Vector2(2,1)},
		{"role":"tea_pool" if chapter==1 else "rail_workshop","radius":1.35,"height":1.28,"preferred":Vector2(-3,-1)},
		{"role":"jade_garden" if chapter==1 else "capacitors","radius":1.02,"height":1.50,"preferred":Vector2(3,-3)}]
	for spec:Dictionary in specs:
		# The north tea court is narrower and its shortcut cuts across the
		# buildable pocket. A smaller real building preserves the same kit.
		var scale:float=.80 if chapter==1 and int(d.id)==1 and str(spec.role)=="tea_house" else 1.0
		spec.radius=float(spec.radius)*scale;spec.height=float(spec.height)*scale
		var site:Dictionary=_find_inner(d,spec)
		interior_report.append(site)
		if not bool(site.found):continue
		var p:Vector3=site.position
		_courtyard(p,float(spec.radius),chapter)
		_model_origin=p;_model_scale=scale
		match str(spec.role):
			"tea_house":_tea_house(p,int(d.id))
			"clock_tower":_clock_tower(p,int(d.id))
			"tea_pool":_tea_pool(p)
			"rail_workshop":_rail_workshop(p)
			"jade_garden":_jade_garden(p,int(d.id))
			"capacitors":_capacitors(p)
		_model_scale=1.0
	_ground_layer(d)
	_crafted_garden_pockets(d)

func _crafted_garden_pockets(d:Dictionary)->void:
	if chapter!=1:return
	var chosen:Array[Vector3]=[]
	var extent:Vector2=Vector2(d.size)*.5-Vector2.ONE*.8
	for offset:Vector2 in [Vector2(-6.1,-5.0),Vector2(-3.9,-4.0),Vector2(2.8,4.1),Vector2(5.7,3.8),Vector2(-5.9,2.8),Vector2(4.9,-3.8),Vector2(0,-5.5),Vector2(5.9,.6),Vector2(-3.1,3.5)]:
		if chosen.size()>=5:break
		if absf(offset.x)>extent.x or absf(offset.y)>extent.y:continue
		var p:Vector3=d.center+Vector3(offset.x,0,offset.y)
		if _route_distance(p)<1.65:continue
		var blocked:=false
		for site:Dictionary in _occupied:
			if Vector2(p.x-site.position.x,p.z-site.position.z).length()<float(site.radius)+.85:blocked=true;break
		if blocked:continue
		for prior:Vector3 in chosen:
			if p.distance_to(prior)<1.8:blocked=true;break
		if blocked:continue
		var bamboo:=FurHarborCraftedAssets.prop("bamboo_crafted");bamboo.position=p;bamboo.rotation.y=float(chosen.size())*2.399;bamboo.scale=Vector3.ONE*.78;_visual.add_child(bamboo);chosen.append(p)

func _ground_layer(d:Dictionary)->void:
	_family=0
	_ground_values.clear()
	var start_triangles:int=_triangles
	var sample_start:int=_ground_samples.size()
	var center:Vector3=d.center;var count:int=0
	# Clip a union of broad planted/workshop pockets against route clearance.
	# These are nearly flat irregular material islands, never new walk edges.
	for x in range(-12,12):
		for z in range(-12,12):
			var a:=center+Vector3(x*.65,.019,z*.65)
			var b:=a+Vector3(.65,0,0);var c:=a+Vector3(.65,0,.65);var e:=a+Vector3(0,0,.65)
			_clip_ground([a,b,c],d);_clip_ground([a,c,e],d)
	for pair in [[0,1],[0,2],[1,2]]:
		if pair[0]>=_occupied.size() or pair[1]>=_occupied.size():continue
		var first:Dictionary=_occupied[pair[0]];var second:Dictionary=_occupied[pair[1]]
		var a:Vector3=first.position;var b:Vector3=second.position
		var delta:Vector3=b-a;var side:=Vector3(-delta.z,0,delta.x).normalized()
		var steps:int=maxi(5,int(ceil(delta.length()/.40)))
		for i in range(1,steps):
			var t:float=float(i)/float(steps);var q:Vector3=a.lerp(b,t)+side*sin(t*PI)*.35
			q.y=float(d.height)+.055
			if Vector2(q.x-a.x,q.z-a.z).length()<float(first.radius)*.83 or Vector2(q.x-b.x,q.z-b.z).length()<float(second.radius)*.83:continue
			if not _ground_safe(q,.22,.11,"stepping_stone" if chapter==1 else "copper_conduit"):continue
			if chapter==1:
				var yaw:float=atan2(delta.x,delta.z)+.16*sin(float(i)*1.9)
				_box(q,Vector3(.30,.055,.24),Color("98a291") if i%2==0 else Color("a9ad98"),Vector3(0,yaw,0))
			else:
				var after:Vector3=q+delta.normalized()*.28
				_beam(q,after,.035,Color("9b8264"))
				if i%3==0:_cylinder(q+Vector3(0,.035,0),Vector3(.13,.09,.13),Color("ad9c77"))
	# Fixed small clusters skirt the group, not every road or every tile.
	for site:Dictionary in _occupied:
		for i in 8:
			if count>=12:break
			var angle:float=float(i)*TAU/8+.3*float(d.id)
			var radius:float=float(site.radius)+.55
			var q:Vector3=site.position+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			if _near_other_cluster(q,site,.7):continue
			if not _ground_safe(q,.46,.56,"low_hedge" if chapter==1 else "cargo_fixture"):continue
			if chapter==1:
				_authored_ground("chapter_leafy_edging_atelier",q,angle,.82)
			elif count%3==0:
				_authored_ground("clockwork_courier_crate_atelier",q,angle,1.0)
			else:
				_authored_ground("clockwork_reel_atelier",q,angle,1.0)
			count+=1
	var minimum:float=INF
	for i in range(sample_start,_ground_samples.size()):minimum=minf(minimum,float(_ground_samples[i].road_clearance)-float(_ground_samples[i].radius))
	ground_report.append({"district":int(d.id),"added_triangles":_triangles-start_triangles,"low_clusters":count,"checked_features":_ground_samples.size()-sample_start,"minimum_free_margin":minimum,"merged_into_existing_interior":true})

func _ground_value(p:Vector3,d:Dictionary)->float:
	var key:=Vector2i(roundi(p.x*100),roundi(p.z*100))
	if _ground_values.has(key):return float(_ground_values[key])
	var field:float=INF
	for site:Dictionary in _occupied:
		var delta:=Vector2(p.x-site.position.x,p.z-site.position.z)
		field=minf(field,delta.length()-float(site.radius)-1.02)
	var center:Vector3=d.center;var extent:Vector2=Vector2(d.size)*.5
	var boundary:float=maxf(absf(p.x-center.x)-extent.x+1.8,absf(p.z-center.z)-extent.y+1.8)
	var value:float=maxf(field,maxf(1.29-_route_distance(p),boundary))
	_ground_values[key]=value
	return value

func _authored_ground(asset:String,position:Vector3,yaw:float,scale_value:float)->void:
	# Consume the sculpted edging in the existing regional draw surface.
	var mesh:ArrayMesh=FurFeedbackMeshes.mesh(asset);var a:Array=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var colours:PackedColorArray=a[Mesh.ARRAY_COLOR];var tags:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2]
	var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		for i in vertices.size():indices.append(i)
	var basis:=Basis(Vector3.UP,yaw)
	for i:int in indices:
		_surface.set_color(colours[i].linear_to_srgb() if colours.size()>i else Color("678978"))
		_surface.set_uv2(tags[i] if tags.size()>i else Vector2(6,0))
		_surface.set_normal(basis*normals[i]);_surface.add_vertex(position+basis*vertices[i]*scale_value)
	_triangles+=indices.size()/3;_parts+=1

func _clip_ground(points:Array,d:Dictionary)->void:
	var clipped:Array[Vector3]=[]
	for i in points.size():
		var a:Vector3=points[i];var b:Vector3=points[(i+1)%points.size()]
		var fa:float=_ground_value(a,d);var fb:float=_ground_value(b,d)
		if fa<=0:clipped.append(a)
		if (fa<=0)!=(fb<=0):clipped.append(a.lerp(b,fa/(fa-fb)))
	if clipped.size()<3:return
	var tint:Color=Color("829881") if chapter==1 else Color("867d8f")
	for i in range(1,clipped.size()-1):
		var a:Vector3=clipped[0];var b:Vector3=clipped[i];var c:Vector3=clipped[i+1]
		if (b-a).cross(c-a).length_squared()<.000001:continue
		# Last check on the emitted triangle protects clipped segment corners.
		var safe:bool=true
		for q:Vector3 in [a,b,c,(a+b+c)/3.0]:
			if _route_distance(q)<1.21:safe=false;break
		if not safe:continue
		_triangle(a,b,c,tint)

func _ground_safe(q:Vector3,radius:float,height:float,kind:String)->bool:
	var distance:float=_route_distance(q)
	if distance<radius+1.10 or not _projection_clear(q,radius,height):return false
	_ground_samples.append({"position":q,"radius":radius,"height":height,"kind":kind,"road_clearance":distance,"projection_clear":true})
	return true

func _near_other_cluster(q:Vector3,owner:Dictionary,margin:float)->bool:
	for old:Dictionary in _occupied:
		if old.position==owner.position:continue
		if Vector2(q.x-old.position.x,q.z-old.position.z).length()<float(old.radius)+margin:return true
	return false

func _find_inner(d:Dictionary,spec:Dictionary)->Dictionary:
	var radius:float=spec.radius;var height:float=spec.height
	var center:Vector3=d.center;var extent:Vector2=Vector2(d.size)*.5
	var best:Dictionary={"district":int(d.id),"role":str(spec.role),"found":false,"radius":radius,"height":height}
	var score:float=-INF
	for x in range(-8,9):
		for z in range(-8,9):
			var local:=Vector2(x*.65,z*.65)
			if absf(local.x)+radius>extent.x-1.3 or absf(local.y)+radius>extent.y-1.3:continue
			var p:=center+Vector3(local.x,.025,local.y)
			var road:float=_route_distance(p)
			if road<radius+1.10:continue
			var crowded:bool=false
			for old:Dictionary in _occupied:
				if Vector2(p.x,p.z).distance_to(Vector2(old.position.x,old.position.z))<radius+float(old.radius)+.32:crowded=true;break
			if crowded or not _projection_clear(p,radius,height):continue
			var merit:float=-local.distance_to(Vector2(spec.preferred))+.20*minf(road,4.0)
			if merit>score:
				score=merit;best={"district":int(d.id),"role":str(spec.role),"found":true,"position":p,"radius":radius,"height":height,"road_clearance":road,"projection_clear":true}
	if bool(best.found):_occupied.append(best)
	return best

func _projection_clear(p:Vector3,radius:float,height:float)->bool:
	var low:float=p.y*.765-p.z*.644-radius*.644
	var high:float=p.y*.765-p.z*.644+height*.765+radius*.644
	var front_depth:float=(p.y+height)*.644+(p.z+radius)*.765
	for tile:Dictionary in _tiles:
		var q:Vector3=tile.pos
		# A foreground standing animal may overlap a background roof without
		# being hidden by it. Only closer scenery can occlude a landing.
		if front_depth<q.y*.644+q.z*.765-.15:continue
		var vertical:float=q.y*.765-q.z*.644
		if absf(p.x-q.x)<radius+.85 and vertical+2.30>low and vertical-.70<high:return false
	return true

func _courtyard(p:Vector3,radius:float,theme:int)->void:
	_family=0
	_cylinder(p+Vector3(0,.02,0),Vector3(radius*2,.055,radius*1.85),Color("aaab8c") if theme==1 else Color("8e8597"))
	for i in 8:
		var a:float=i*TAU/8
		_box(p+Vector3(cos(a)*radius*.87,.055,sin(a)*radius*.78),Vector3(.3,.055,.18),Color("bfc2a5") if theme==1 else Color("baab8b"),Vector3(0,-a,0))

func _tea_house(p:Vector3,_id:int)->void:
	var pavilion:=FurHarborCraftedAssets.prop("tea_pavilion_crafted");pavilion.position=p;pavilion.scale=Vector3.ONE*.69*_model_scale;_visual.add_child(pavilion)

func _tea_pool(p:Vector3)->void:
	var prop:=FurTravelArtAssets.instance("cloud_koi_basin_atelier");prop.position=p;_visual.add_child(prop)

func _jade_garden(p:Vector3,_id:int)->void:
	var prop:=FurTravelArtAssets.instance("mahjong_garden_shrine_atelier");prop.position=p;_visual.add_child(prop)

func _clock_tower(p:Vector3,id:int)->void:
	var tower:=FurHarborCraftedAssets.prop("clock_pavilion_crafted");tower.position=p;tower.scale=Vector3.ONE*.90;tower.rotation.y=.06*(id-1);_visual.add_child(tower)

func _rail_workshop(p:Vector3)->void:
	var prop:=FurTravelArtAssets.instance("clockwork_rail_workshop_atelier");prop.position=p;_visual.add_child(prop)

func _capacitors(p:Vector3)->void:
	var prop:=FurTravelArtAssets.instance("porcelain_capacitor_station_atelier");prop.position=p;_visual.add_child(prop)

func _harbor_scene(p:Vector3,id:int)->void:
	_family=1
	var dock:=FurTravelArtAssets.instance("harbor_dock_module");dock.position=p;dock.rotation.y=PI*.5;dock.scale=Vector3(1.22,1,1.08);_visual.add_child(dock)
	for x:float in [-1.5,1.5]:
		for z:float in [-.82,.82]:
			var leg:float=maxf(p.y+3.10,.4);_cylinder(Vector3(p.x+x,p.y-leg*.5,p.z+z),Vector3(.17,leg,.17),WOOD)
	var center:Vector3=ChapterMap.districts(0)[id].center
	var outward:Vector3=p-center;outward.y=0;outward=outward.normalized()
	var berth:Vector3=p+outward*2.55;berth.y=-2.97
	var boat:=FurHarborCraftedAssets.prop("harbor_sailboat_crafted");boat.position=berth;boat.rotation.y=atan2(-outward.x,-outward.z)+PI*.5;boat.scale=Vector3.ONE*.88;_visual.add_child(boat)
	# Mooring lines now connect the pier to an actual water-level boat.
	for side in [-1,1]:
		var from:Vector3=p+Vector3(side*.55,.24,0);var to:Vector3=berth+Vector3(side*.50,.58,0)
		_beam(from,from.lerp(to,.5)-Vector3.UP*.13,.019,CREAM);_beam(from.lerp(to,.5)-Vector3.UP*.13,to,.019,CREAM)
	var lantern:=FurTravelArtAssets.instance("street_lantern_atelier");lantern.position=p+Vector3(-1.4,0,-.56);lantern.scale=Vector3.ONE*.78;_visual.add_child(lantern)

func _tea_scene(p:Vector3,_id:int)->void:
	_family=1;_platform(p,Color("a2ada6"),true)
	var pavilion:=FurHarborCraftedAssets.prop("tea_pavilion_crafted");pavilion.position=p;pavilion.scale=Vector3.ONE*1.09;_visual.add_child(pavilion)

func _clock_scene(p:Vector3,_id:int)->void:
	_family=1;_platform(p,Color("8d8593"),true)
	var clock:=FurHarborCraftedAssets.prop("clock_pavilion_crafted");clock.position=p;clock.scale=Vector3.ONE*1.50;_visual.add_child(clock)

func _platform(p:Vector3,colour:Color,sky:bool)->void:
	# Separate decorative off-route piers are physically supported. Chapter 2/3
	# replace lower stilts with sculpted levitating cloud/balloon foundations.
	_cylinder(p+Vector3(0,-.12,0),Vector3(4.5,.42,3.4),colour)
	if sky:
		_sphere(p+Vector3(0,-.67,0),Vector3(3.8,1.1,2.7),Color("b5c4c3") if chapter==1 else Color("928ba9"))
		for x:float in [-1.1,1.1]:_sphere(p+Vector3(x,-.37,.62),Vector3(1.5,.72,1.3),Color("d0dbd4") if chapter==1 else Color("b3aac7"))
	else:
		var leg:float=maxf(p.y+3.1,.4)
		for x:float in [-1.5,1.5]:
			for z:float in [-1.0,1.0]:_cylinder(Vector3(p.x+x,p.y-leg*.5,p.z+z),Vector3(.25,leg,.25),WOOD)

func _roof(p:Vector3,width:float,depth:float,height:float,colour:Color)->void:
	var previous:int=_family;_family=1
	# Real continuous lifted eaves with thickness replace two paper-thin pitches.
	for side:int in [-1,1]:
		for row in 8:
			var u:float=row/8.0;var next_u:float=(row+1)/8.0
			for column in 6:
				var v:float=-1.0+column/3.0;var next_v:float=v+1.0/3
				_quad(_roof_point(p,width,depth,height,side,u,v),_roof_point(p,width,depth,height,side,u,next_v),_roof_point(p,width,depth,height,side,next_u,next_v),_roof_point(p,width,depth,height,side,next_u,v),colour.lightened(float(row%2)*.018))
			for v:float in [-1.0,1.0]:
				var a:Vector3=_roof_point(p,width,depth,height,side,u,v);var b:Vector3=_roof_point(p,width,depth,height,side,next_u,v)
				_quad(a,b,b-Vector3.UP*.085,a-Vector3.UP*.085,WOOD)
			# Raised narrow tile ribs follow the curvature, without dozens of cylinders.
			for column in 7:
				var v:float=-.94+column*.31333
				var a:Vector3=_roof_point(p,width,depth,height,side,u,v)+Vector3.UP*.018;var b:Vector3=_roof_point(p,width,depth,height,side,next_u,v)+Vector3.UP*.018
				_quad(a-Vector3(0,0,.018),a+Vector3(0,0,.018),b+Vector3(0,0,.018),b-Vector3(0,0,.018),colour.lightened(.075))
		var a:Vector3=_roof_point(p,width,depth,height,side,1,-1);var b:Vector3=_roof_point(p,width,depth,height,side,1,1)
		_quad(a,b,b-Vector3.UP*.10,a-Vector3.UP*.10,WOOD)
		_family=3;_beam(a-Vector3.UP*.025,b-Vector3.UP*.025,.042,BRASS);_family=1
	_family=3;_beam(p+Vector3(0,height+.012,-depth*.52),p+Vector3(0,height+.012,depth*.52),.065,BRASS);_family=previous

func _roof_point(p:Vector3,width:float,depth:float,height:float,side:int,u:float,v:float)->Vector3:
	var lift:float=height*pow(maxf(0.0,1.0-u),1.58)+.10*u+.085*pow(absf(v),3)*u*u*u
	return p+Vector3(side*width*.5*u,lift,v*depth*.53)

func _cloud_sea()->void:
	var plane:=PlaneMesh.new();plane.size=Vector2(154,130)
	var node:=MeshInstance3D.new();node.name="ChapterCloudOcean";node.mesh=plane;node.position=Vector3(0,-2.94,-5)
	var material:=ShaderMaterial.new();material.shader=CLOUD_SHADER;material.set_shader_parameter("surface_noise",SurfaceNoise.texture());material.set_shader_parameter("low_tint",Color("a3b8c4") if chapter==1 else Color("858da9"));material.set_shader_parameter("high_tint",Color("d0dedb") if chapter==1 else Color("b9bfd1"));node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_visual.add_child(node)

func _begin()->void:
	_surface=SurfaceTool.new();_surface.begin(Mesh.PRIMITIVE_TRIANGLES);_surface.set_uv2(Vector2.ZERO)

func _finish(title:String)->void:
	var node:=MeshInstance3D.new();node.name=title;node.mesh=_surface.commit();node.material_override=_material;_visual.add_child(node);_surface=null

func _shape(kind:String,position:Vector3,dimensions:Vector3,colour:Color,rotation:Vector3=Vector3.ZERO)->void:
	position=_model_origin+(position-_model_origin)*_model_scale;dimensions*=_model_scale
	if not _cache.has(kind):
		var mesh:Mesh
		if kind=="cloud":mesh=CloudGeometry.mesh()
		elif kind=="box":mesh=BoxMesh.new()
		elif kind=="sphere":
			var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=14;sphere.rings=7;mesh=sphere
		else:
			var cylinder:=CylinderMesh.new();cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.height=1;cylinder.radial_segments=14;cylinder.rings=1;mesh=cylinder
		_cache[kind]=mesh
	var source:Mesh=_cache[kind];var arrays:Array=source.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var basis:Basis=Basis.from_euler(rotation)*Basis.from_scale(dimensions);var normal_basis:Basis=basis.inverse().transposed()
	_surface.set_color(colour);_surface.set_uv2(Vector2(_family,0))
	for id:int in indices:
		_surface.set_normal((normal_basis*normals[id]).normalized());_surface.add_vertex(basis*vertices[id]+position)
	_triangles+=int(indices.size()/3.0);_parts+=1

func _box(p:Vector3,s:Vector3,c:Color,r:Vector3=Vector3.ZERO)->void:_shape("box",p,s,c,r)
func _sphere(p:Vector3,s:Vector3,c:Color)->void:_shape("sphere",p,s,c)
func _cylinder(p:Vector3,s:Vector3,c:Color,r:Vector3=Vector3.ZERO)->void:_shape("cylinder",p,s,c,r)

func _beam(a:Vector3,b:Vector3,radius:float,colour:Color)->void:
	var delta:Vector3=b-a
	if delta.length()<.001:return
	var rotation:Vector3=Basis(Quaternion(Vector3.UP,delta.normalized())).get_euler()
	_cylinder((a+b)*.5,Vector3(radius*2,delta.length(),radius*2),colour,rotation)

func _ring(p:Vector3,radius:float,width:float,colour:Color,rotation:Vector3=Vector3.ZERO)->void:
	# One real torus replaces 24 overlapping capped cylinders per ornamental ring.
	var mesh:=TorusMesh.new();mesh.inner_radius=maxf(.001,radius-width);mesh.outer_radius=radius+width;mesh.rings=24;mesh.ring_segments=6
	var arrays:Array=mesh.get_mesh_arrays();var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var center:Vector3=_model_origin+(p-_model_origin)*_model_scale;var basis:=Basis.from_euler(rotation)
	_surface.set_color(colour);_surface.set_uv2(Vector2(3,0))
	for index:int in indices:_surface.set_normal(basis*normals[index]);_surface.add_vertex(center+basis*points[index]*_model_scale)
	_triangles+=indices.size()/3;_parts+=1

func _leaf(base:Vector3,tip:Vector3,width:float,colour:Color)->void:
	base=_model_origin+(base-_model_origin)*_model_scale;tip=_model_origin+(tip-_model_origin)*_model_scale
	Foliage.leaf_piece(_surface,base,tip,width*_model_scale,colour,5);_triangles+=32;_parts+=1

func _triangle(a:Vector3,b:Vector3,c:Vector3,colour:Color)->void:
	a=_model_origin+(a-_model_origin)*_model_scale;b=_model_origin+(b-_model_origin)*_model_scale;c=_model_origin+(c-_model_origin)*_model_scale
	var normal:Vector3=(b-a).cross(c-a).normalized();_surface.set_color(colour);_surface.set_uv2(Vector2(_family,0))
	_surface.set_normal(normal)
	for vertex:Vector3 in [a,c,b]:_surface.add_vertex(vertex)
	_surface.set_normal(-normal)
	for vertex:Vector3 in [a,b,c]:_surface.add_vertex(vertex)
	_triangles+=2;_parts+=1

func _quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,colour:Color)->void:
	_triangle(a,b,c,colour);_triangle(a,c,d,colour)
