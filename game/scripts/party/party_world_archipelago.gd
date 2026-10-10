class_name FurPartyArchipelago
extends RefCounted
const Palette=preload("res://scripts/party/party_world_palette.gd")
const TreeGeometry=preload("res://scripts/party/party_tree_geometry.gd")
const Water=preload("res://scripts/party/party_water_surface.gd")
const HeroHouse=preload("res://scripts/party/party_harbor_house_geometry.gd")
const Windmill=preload("res://scripts/party/party_windmill_geometry.gd")
const CoastalRock=preload("res://scripts/party/party_coastal_rock_geometry.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const BridgeGeometry=preload("res://scripts/party/party_bridge_geometry.gd")
const RuinGeometry=preload("res://scripts/party/party_ruin_geometry.gd")

var w
var tiles:Array[Dictionary]=[]
var links:Array=[]
var regions:Array[Dictionary]=[]
var rotors:Array[Node3D]=[]
var elapsed:float=0.0
var placements:Array[Dictionary]=[]
var ruin_fragments:Array[Dictionary]=[]
var garden_mounds:Array[Dictionary]=[]
var coast_vegetation:Array[Dictionary]=[]
var _occupied:Array[Dictionary]=[]
var _ground_surfaces:Array[SurfaceTool]=[]
var _ground_vertices:Array[int]=[]
var _ground_district:int=0
const WOOD=Color("775943")
const STONE=Palette.STONE
const CREAM=Palette.CREAM

func build(world:Node3D,nodes:Array[Dictionary],edges:Array,districts:Array[Dictionary])->void:
	w=world;tiles=nodes;links=edges;regions=districts
	rotors.clear()
	placements.clear()
	ruin_fragments.clear();garden_mounds.clear();coast_vegetation.clear()
	_ground_surfaces.clear();_ground_vertices.clear()
	for i in 3:
		var detail:=SurfaceTool.new();detail.begin(Mesh.PRIMITIVE_TRIANGLES);detail.set_smooth_group(-1);detail.set_normal(Vector3.UP);detail.set_uv2(Vector2.ZERO);_ground_surfaces.append(detail);_ground_vertices.append(0)
	_sea()
	for district:Dictionary in regions:
		_ground_district=int(district.id)
		_landmass(district)
		_island_scenery(district)
	_routes()
	_docks()
	_distant_rocks()
	_finish_ground_details()

func animate(delta:float)->void:
	elapsed=fmod(elapsed+delta,3600.0)
	for rotor:Node3D in rotors:
		if is_instance_valid(rotor):rotor.rotation.z=-elapsed*.18

func _sea()->void:
	if FurIslandComposition.enabled:FurCoastalDepthWater.create(w,regions)
	else:Water.sea(w,Vector2(154,130),-3.0,regions)

func _landmass(d:Dictionary)->void:
	if FurIslandComposition.enabled:
		var sculpt:=FurCoastalSculptAssets.instance("sculpted_island_%d"%int(d.id));sculpt.name="SculptedCoast_%s"%d.theme;sculpt.position=d.center;w.add_child(sculpt)
		var rows:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/eighthour_v1/coast/coast_contact_%d.json"%int(d.id)))
		var points:=PackedVector3Array()
		for p:Array in rows:points.append(d.center+Vector3(float(p[0]),float(p[1]),float(p[2])))
		var foam:MeshInstance3D=Water.shore_foam(w,points,d.center,.46,"ContactFoam_%d"%int(d.id))
		var material:=ShaderMaterial.new();material.shader=preload("res://assets/art/eighthour_v1/contact_foam.gdshader");material.set_shader_parameter("surface_noise",FurPartySurfaceNoise.texture());material.render_priority=1;foam.material_override=material
		return
	var coast:Node3D=FurHarborCraftedAssets.coast(int(d.id));coast.name="SculptedCoast_%s"%d.theme;coast.position=d.center;w.add_child(coast)
	var source:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/sevenhour_v1/coast_atelier_%d_shore.json"%int(d.id)))
	var points:=PackedVector3Array()
	for p:Array in source:points.append(d.center+Vector3(float(p[0]),float(p[1])+.035,float(p[2])))
	Water.shore_foam(w,points,d.center,.44,"SculptedShoreFoam_%d"%int(d.id))

func _cliff_point(d:Dictionary,angle:float,depth:float,factor:float)->Vector3:
	var center:Vector3=d.center;var radius:Vector2=d.radius
	var outline:float=1.075+.062*sin(angle*3+float(d.id)*1.7)+.041*cos(angle*5+float(d.id))
	# Angular faults have different heights, so intermediate rows never form a
	# continuous horizontal band. The actual playable upper outline is untouched.
	var fault:float=(.105*sin(angle*3+float(d.id)*1.7)+.060*cos(angle*7-float(d.id)))*sin(depth*PI)
	var depth_at:float=clampf(depth+fault,0,1)
	var erosion:float=(.063*sin(angle*5+float(d.id))+.041*cos(angle*9-depth*2.7))*sin(depth*PI)
	var foot:float=pow(depth,2.7)*(.087*pow(maxf(0,cos(angle*4+float(d.id)*2.1)),3)-.047*pow(maxf(0,cos(angle*7-.8)),2))
	var height:float=lerpf(float(d.height)-.24,-3.15,depth_at)
	return Vector3(center.x+cos(angle)*radius.x*outline*(factor+erosion+foot),height,center.z+sin(angle)*radius.y*outline*(factor+erosion+foot))

func _rock_outcrops(st:SurfaceTool,d:Dictionary,colour:Color)->void:
	# Broad buttresses are merged into the same land surface. Each has a distinct
	# width, height and lean, with turf only where the whole cap clears the route.
	var angles:Array[float]=[-.32,.44,1.10,1.83,2.42,3.09,3.94,4.77,5.53]
	for index in angles.size():
		var angle:float=angles[index]+float(d.id)*.16
		var origin:Vector3=_cliff_point(d,angle,0,1)
		var radial:=Vector3(cos(angle),0,sin(angle));var tangent:=Vector3(-sin(angle),0,cos(angle))
		var width:float=[1.55,2.20,1.80,2.65,1.68,2.32,1.72,2.08,1.95][index]
		var front:float=.68+float(index%3)*.13
		var levels:Array[float]=[origin.y-.10,lerpf(origin.y,-3.15,.43+.09*sin(index)), -3.15]
		var rings:Array=[];var center_points:Array[Vector3]=[]
		for row in 3:
			var center:Vector3=origin+radial*(.06+row*.21)+tangent*(.10*sin(index*1.7+row));center.y=levels[row];center_points.append(center)
			var ring:Array[Vector3]=[]
			for j in 8:
				var a:float=j*TAU/8+.16
				var span:float=(.80+row*.12)*(1.0+.075*sin(j*2+index))
				ring.append(center+tangent*cos(a)*width*.5*span+radial*sin(a)*front*(.67+row*.13))
			rings.append(ring)
		st.set_uv2(Vector2.ZERO)
		for row in 2:
			for j in 8:
				var k:int=(j+1)%8;var outward:Vector3=(rings[row][j]+rings[row][k])*.5-center_points[row]
				Foliage._quad(st,rings[row][j],rings[row][k],rings[row+1][k],rings[row+1][j],outward,colour.darkened(row*.09).lightened(.028*sin(index*1.8)))
		for j in 8:
			var k:int=(j+1)%8
			Foliage._triangle(st,center_points[0],rings[0][j],rings[0][k],Vector3.UP,colour.lightened(.075))
		# A whole bright cap made each rock look like a green-topped pedestal.
		# Restrained inset moss and a small rooted spray leave the stone exposed.
		if index%3==2:
			var rooted:Vector3=center_points[0]-radial*.16+Vector3.UP*.017
			var clearance:float=_route_distance(rooted,int(d.id))
			if clearance>=1.92:
				var green:Color=[Color("758b61"),Color("82945b"),Color("5e806b")][int(d.id)]
				var patch:Array[Vector3]=[]
				for j in 9:
					var angle2:float=j*TAU/9+.24
					patch.append(rooted+tangent*cos(angle2)*(.48+.06*sin(j*2.3+index))+radial*sin(angle2)*(.28+.035*cos(j*1.9)))
				st.set_uv2(Vector2(7,0));st.set_normal(Vector3.UP)
				for j in 9:
					var k:int=(j+1)%9
					var points:Array[Vector3]=[rooted,patch[j],patch[k]]
					if (points[1]-points[0]).cross(points[2]-points[0]).y>0:points=[rooted,patch[k],patch[j]]
					st.set_color(green);st.add_vertex(points[0])
					st.set_color(colour.lightened(.075).lerp(green,.22));st.add_vertex(points[1]);st.add_vertex(points[2])
				for leaf_id in 5:
					var angle2:float=leaf_id*TAU/5+index*.73
					var end:Vector3=rooted+Vector3(cos(angle2)*.33,.17+.06*sin(leaf_id*2),sin(angle2)*.26)
					Foliage.leaf_piece(st,rooted+Vector3.UP*.025,end,.18,green.lightened(.035),5)
				coast_vegetation.append({"district":d.id,"position":rooted,"maximum_radius":.62,"maximum_height":.31,"road_clearance":clearance})
				st.set_uv2(Vector2.ZERO)

func _route_distance(point:Vector3,region:int=-1)->float:
	var distance:float=INF
	var q:=Vector2(point.x,point.z)
	for edge:Variant in links:
		var a:Dictionary=tiles[int(edge[0])];var b:Dictionary=tiles[int(edge[1])]
		if FurPartyMap.is_ferry_edge(int(a.id),int(b.id)):continue
		if region>=0 and int(a.district)!=region and int(b.district)!=region:continue
		var start:=Vector2(a.pos.x,a.pos.z);var end:=Vector2(b.pos.x,b.pos.z)
		var segment:Vector2=end-start
		var t:float=clampf((q-start).dot(segment)/maxf(segment.length_squared(),.0001),0,1)
		distance=minf(distance,q.distance_to(start+segment*t))
	return distance

func _safe_site(d:Dictionary,preferred:Vector2,clearance:float,height_bound:float=0.0,roof_back:float=-1.0)->Vector3:
	var center:Vector3=d.center;var best:=center+Vector3(preferred.x,0,preferred.y);var score:float=-INF
	for x in range(-5,6):
		for z in range(-4,7):
			var p:=center+Vector3(float(x),-.24,float(z))
			var road:float=_route_distance(p,int(d.id))
			if road<clearance:continue
			var blocked:bool=false
			for prior:Dictionary in _occupied:
				if Vector2(p.x,p.z).distance_to(Vector2(prior.pos.x,prior.pos.z))<float(prior.radius)+clearance-.65:blocked=true;break
			if blocked:continue
			if height_bound>0:
				var footprint:float=clearance-.55
				var bottom:float=p.y*.79-p.z*.61-footprint*.61
				var top:float=p.y*.79-p.z*.61+height_bound*.79+(footprint if roof_back<0 else roof_back)*.61
				for tile:Dictionary in tiles:
					if int(tile.district)!=int(d.id):continue
					var point:Vector3=tile.pos;var vertical:float=point.y*.79-point.z*.61
					if absf(point.x-p.x)<footprint+.78 and vertical>bottom-.60 and vertical<top+.60:blocked=true;break
			if blocked:continue
			var candidate:float=-Vector2(x,z).distance_to(preferred)+minf(road,4.0)*.1
			if candidate>score:score=candidate;best=p
	_occupied.append({"pos":best,"radius":clearance-.65})
	placements.append({"district":int(d.id),"pos":best,"road_clearance":_route_distance(best,int(d.id)),"requested_clearance":clearance,"height_bound":height_bound,"placement_found":score>-INF})
	return best

func _island_scenery(d:Dictionary)->void:
	var center:Vector3=d.center;var theme:String=d.theme
	_occupied.clear()
	if theme=="harbor":
		var main_site:Vector3=_safe_site(d,Vector2(2.0,1.8),2.6,3.75)
		_detailed_house(main_site,Vector3(3.5,2.0,2.7),Color("c8a27b"),Color("557b87"),.03,true)
		var market:Vector3=_safe_site(d,Vector2(-5,1),1.8,2.4)
		w._stall(market,-.15)
		var fountain:Vector3=_safe_site(d,Vector2(5,-1.5),1.8,2.7)
		w._fountain(fountain)
		var bakery:Vector3=center+Vector3(-4.2,-.19,-10.15)
		_promontory(center+Vector3(-4.2,-.22,-9.25),Vector2(3.0,3.15),Color("b6a087"))
		_detailed_house(bakery,Vector3(2.35,1.6,2.0),Color("c6a58b"),Color("a66c5d"),-.12)
		placements.append({"district":0,"pos":bakery,"road_clearance":_route_distance(bakery,0),"requested_clearance":1.9,"height_bound":3.0,"placement_found":_route_distance(bakery,0)>1.9,"type":"back_headland"})
		for p:Vector3 in [main_site,market,fountain]:_courtyard(p,2.8)
		_lighthouse(center+Vector3(-10.1,-.20,-5.0))
	elif theme=="windmill":
		var windmill:Vector3=_safe_site(d,Vector2(1,5.0),2.7,4.85,0.0)
		_windmill(windmill)
		var cottage:Vector3=_safe_site(d,Vector2(-4.0,2.7),1.9,3.3)
		_detailed_house(cottage,Vector3(2.5,1.6,2.0),Color("d0ba8c"),Color("8f7554"),.12)
		for p:Vector3 in [windmill,cottage]:_courtyard(p,2.35)
		var field:Vector3=_safe_site(d,Vector2(4,-2),1.7)
		_wheat_patch(field)
	else:
		var ruin:Vector3=center+Vector3(-3,-.19,-10.1)
		_promontory(center+Vector3(-3,-.22,-9.2),Vector2(3.25,3.20),Color("87948a"))
		placements.append({"district":2,"pos":ruin,"road_clearance":_route_distance(ruin,2),"requested_clearance":2.25,"height_bound":3.2,"placement_found":_route_distance(ruin,2)>2.25,"type":"back_headland"})
		_ruin(ruin)
		var shrine:Vector3=_safe_site(d,Vector2(3,-1.8),1.9,2.0)
		_shrine(shrine)
		_courtyard(ruin,2.4,true)
		var camp:Vector3=_safe_site(d,Vector2(-3,2.4),1.7,1.65)
		_tent(camp)
	_extra_scenery(d)
	_planting(d)
	_crafted_coastal_gardens(d)
	_ground_cover(d)
	_garden_mounds(d)
	# Sparse boundary rails frame viewpoints while leaving most of the coast open.
	var radius:Vector2=d.radius
	for i in 22:
		var angle:float=i*TAU/22.0
		var p:=center+Vector3(cos(angle)*(radius.x-.4),-.24,sin(angle)*(radius.y-.4))
		if _route_distance(p,int(d.id))<1.38:continue
		if i%3==0:w._lantern(p,1.15)
		if theme=="ruins":continue
		if i%2==0:
			for shift:float in [-.48,.48]:w._batch("cylinder",p+Vector3(shift,.39,0),Vector3(.12,.78,.12),WOOD)
			w._batch("box",p+Vector3(0,.55,0),Vector3(1.02,.07,.08),WOOD)

func _courtyard(p:Vector3,radius:float,moss:bool=false)->void:
	# Cut-corner, shallow stones replace a grid of full rounded-box instances.
	# A single surface per district supports future island culling without extra props.
	var theme:String=str(regions[_ground_district].theme)
	var spacing:float=.46 if theme=="harbor" else .55
	for x in range(-6,7):
		for z in range(-6,7):
			var offset:=Vector3(x*spacing+float(posmod(z,2))*.18,.022,z*spacing)
			if Vector2(offset.x,offset.z).length()>radius or _route_distance(p+offset,_ground_district)<1.48:continue
			if moss and posmod(x*3+z*5,7)<2:continue
			var size2:=Vector2(.57,.25) if theme=="harbor" else Vector2(.48,.40)
			var angle:float=(PI/4 if posmod(x+z,2)==0 else -PI/4) if theme=="harbor" else .11*sin(float(x*3+z))
			var colour:Color=Palette.PAVING[_ground_district].darkened(.07).lightened(float(posmod(x*3+z,4))*.012)
			_inlaid_stone(p+offset,size2,angle,colour)

func _inlaid_stone(p:Vector3,size2:Vector2,angle:float,colour:Color)->void:
	var cut:float=minf(size2.x,size2.y)*.19;var half:Vector2=size2*.5
	var outline:Array[Vector2]=[Vector2(-half.x+cut,-half.y),Vector2(half.x-cut,-half.y),Vector2(half.x,-half.y+cut),Vector2(half.x,half.y-cut),Vector2(half.x-cut,half.y),Vector2(-half.x+cut,half.y),Vector2(-half.x,half.y-cut),Vector2(-half.x,-half.y+cut)]
	var surface:SurfaceTool=_ground_surfaces[_ground_district]
	for i in 8:
		var a2:Vector2=outline[i].rotated(angle);var b2:Vector2=outline[(i+1)%8].rotated(angle)
		var a:=p+Vector3(a2.x,.021,a2.y);var b:=p+Vector3(b2.x,.021,b2.y)
		surface.set_color(colour)
		for vertex:Vector3 in [p+Vector3.UP*.021,a,b]:surface.add_vertex(vertex)
		surface.set_color(colour.darkened(.07));w._quad(surface,a,b,b-Vector3.UP*.029,a-Vector3.UP*.029)
		_ground_vertices[_ground_district]+=9

func _ground_patch(p:Vector3,size2:Vector2,colour:Color,phase:float)->void:
	var surface:SurfaceTool=_ground_surfaces[_ground_district]
	for i in 18:
		var a:float=i*TAU/18.0;var b:float=(i+1)*TAU/18.0
		var ra:float=.91+.08*sin(a*3+phase)+.04*cos(a*5);var rb:float=.91+.08*sin(b*3+phase)+.04*cos(b*5)
		var pa:=p+Vector3(cos(a)*size2.x*ra,0,sin(a)*size2.y*ra);var pb:=p+Vector3(cos(b)*size2.x*rb,0,sin(b)*size2.y*rb)
		surface.set_color(colour.lightened(.018*sin(a*2+phase)))
		for vertex:Vector3 in [p,pa,pb]:surface.add_vertex(vertex)
		_ground_vertices[_ground_district]+=3

func _ground_cover(d:Dictionary)->void:
	var center:Vector3=d.center;var count:int=0
	for row in 3:
		for col in 5:
			if count>=6:return
			var p:Vector3=center+Vector3(-6.4+col*3.2,-.222,-3.9+row*3.9)
			if _route_distance(p,int(d.id))<2.25:continue
			var clear:bool=true
			for prior:Dictionary in _occupied:
				if Vector2(p.x-prior.pos.x,p.z-prior.pos.z).length()<float(prior.radius)+.55:clear=false;break
			if not clear:continue
			var tint:Color=Palette.GROUND[int(d.id)].darkened(.055) if int(d.id)!=0 else Palette.PAVING[0].darkened(.13)
			_ground_patch(p,Vector2(1.12,.74),tint,col+row*2.7)
			for chip in 6:
				var angle:float=chip*2.399+float(row);var point:Vector3=p+Vector3(cos(angle)*(.22+chip*.11),.003,sin(angle)*(.18+chip*.07))
				var size2:=Vector2(.29,.21) if int(d.id)!=1 else Vector2(.18,.11)
				_inlaid_stone(point,size2,angle,Palette.PAVING[int(d.id)].darkened(.13))
			var garden:=FurTravelArtAssets.instance("living_garden_atelier");garden.position=p+Vector3(0,.015,0);garden.scale=Vector3.ONE*.78;garden.rotation.y=col*.7+row*.3;w.add_child(garden)
			count+=1

func _garden_mounds(d:Dictionary)->void:
	var wanted:int=2 if int(d.id)==0 else 1
	var center:Vector3=d.center
	for slot in wanted:
		var radius:=Vector2(1.28,.97) if slot==0 else Vector2(1.04,.83)
		var best:=Vector3.ZERO;var score:float=-INF;var found:bool=false
		var preferred:Vector2=Vector2(-4.2,2.7) if slot==0 else Vector2(4.3,2.6)
		for row in 9:
			for column in 11:
				var local:=Vector2(-7.0+column*1.4,-5.6+row*1.4)
				var p:Vector3=center+Vector3(local.x,-.235,local.y)
				if _route_distance(p,int(d.id))<radius.x*1.038+1.4:continue
				var safe:bool=true
				for prior:Dictionary in _occupied:
					if Vector2(p.x-prior.pos.x,p.z-prior.pos.z).length()<float(prior.radius)+radius.x+.15:safe=false;break
				if not safe:continue
				var value:float=-local.distance_to(preferred)+minf(_route_distance(p,int(d.id)),3.5)*.25
				if value>score:score=value;best=p;found=true
		if not found:continue
		var height:float=.32 if int(d.id)==0 else .38
		var surface:SurfaceTool=_ground_surfaces[int(d.id)];surface.set_uv2(Vector2(7,0));surface.set_smooth_group(1)
		var grass:Color=[Color("72954e"),Color("829e55"),Color("598776")][int(d.id)]
		for row in 5:
			var inner:float=row/5.0;var outer:float=(row+1)/5.0
			for i in 24:
				var a:float=i*TAU/24;var b:float=(i+1)*TAU/24
				var vertices:Array[Vector3]=[]
				for corner:Vector2 in [Vector2(a,inner),Vector2(b,inner),Vector2(b,outer),Vector2(a,outer)]:
					var factor:float=1.0+.038*sin(corner.x*3+float(slot))
					vertices.append(best+Vector3(cos(corner.x)*radius.x*corner.y*factor,height*pow(maxf(0.0,1.0-corner.y*corner.y),1.55),sin(corner.x)*radius.y*corner.y*factor))
				surface.set_color(grass.lightened(.018*sin(a*3)+.025*inner));w._quad(surface,vertices[0],vertices[1],vertices[2],vertices[3]);_ground_vertices[int(d.id)]+=6
		# Existing foliage template rests physically on the mound's crown.
		surface.set_smooth_group(-1);surface.set_uv2(Vector2.ZERO)
		_bush(best+Vector3(.12,height-.025,.025),str(d.theme),slot,.94)
		_occupied.append({"pos":best,"radius":radius.x+.12})
		garden_mounds.append({"district":int(d.id),"position":best,"radius":radius,"height":height,"road_clearance":_route_distance(best,int(d.id)),"maximum_radius":radius.x*1.038,"merged_draw_objects":0})

func _finish_ground_details()->void:
	for district in 3:
		if _ground_vertices[district]==0:continue
		var surface:SurfaceTool=_ground_surfaces[district];surface.generate_normals()
		var mesh:=MeshInstance3D.new();mesh.name="DistrictGroundInlays_%d"%district;mesh.mesh=surface.commit()
		mesh.material_override=Crafted.material(-1)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;w.add_child(mesh)
	_ground_surfaces.clear();_ground_vertices.clear()

func _routes()->void:
	for edge:Variant in links:
		var origin:int=edge[0];var destination:int=edge[1]
		if FurPartyMap.is_ferry_edge(origin,destination):continue
		var from:Vector3=tiles[origin].pos;var to:Vector3=tiles[destination].pos
		var bridge:bool=FurPartyMap.is_bridge_edge(origin,destination)
		var vector:Vector3=to-from;var length:float=vector.length();var direction:Vector3=vector.normalized()
		var side:=Vector3(-direction.z,0,direction.x).normalized();var yaw:float=-atan2(direction.z,direction.x)+PI/2
		if not bridge:
			var steps:int=maxi(2,ceili(length/.52))
			for i in steps:
				var p:Vector3=from.lerp(to,(float(i)+.5)/steps)
				var shade:Color=Palette.PAVING[int(tiles[origin].district)].lightened(float(i%3)*.016)
				for column in 3:
					var offset:float=(float(column)+.5)/3*2.12-1.06
					if FurIslandComposition.enabled:
						var region:int=int(tiles[origin].district)
						_ground_vertices[region]+=FurRaisedPathStones.append(_ground_surfaces[region],p+side*offset+Vector3(0,-.095,0),side,direction,2.12/3-.021,length/steps*.985,shade.lightened(float((i+column)%2)*.025))
					else:w._batch("box",p+side*offset+Vector3(0,-.20,0),Vector3(2.12/3-.035,.21,length/steps*.94),shade.lightened(float((i+column)%2)*.025),Vector3(0,yaw,0))
			continue
		var district:int=int(tiles[origin].district)
		_ground_vertices[district]+=Foliage.append(_ground_surfaces[district],FurAuthoredBridgeMesh.bridge(from,to),Transform3D.IDENTITY)
		var mid:Vector3=(from+to)*.5
		for shift:float in [-.65,.65]:
			var foot:Vector3=mid+side*shift
			w._cylinder(Vector3(foot.x,(-2.9+mid.y-.3)*.5,foot.z),mid.y+2.6,.20,Color("8e9190"))

func _docks()->void:
	for edge:Variant in links:
		var from:int=edge[0];var to:int=edge[1]
		if not FurPartyMap.is_ferry_edge(from,to):continue
		for node_id:int in [from,to]:
			var node:Dictionary=tiles[node_id];var center:Vector3=regions[int(node.district)].center
			var radial:Vector3=(Vector3(node.pos)-center);radial.y=0;radial=radial.normalized()
			var side:=Vector3(-radial.z,0,radial.x)
			var root:Vector3=node.pos+radial*1.32
			var district:int=int(node.district)
			_ground_vertices[district]+=Foliage.append(_ground_surfaces[district],BridgeGeometry.dock(root,radial),Transform3D.IDENTITY)
			for factor:float in [-1.0,1.0]:
				var p:Vector3=root+radial*1.8+side*.85*factor
				w._cylinder(p+Vector3(0,-1.3,0),3.25,.09,WOOD)
				w._cylinder(p+Vector3(0,.31,0),.16,.16,CREAM)
			w._lantern(root+side*.94,.88)
			# Real mooring rings distinguish the fare option from a normal tile.
			var ring:MeshInstance3D=w._ring(root+radial*1.0+side*.6+Vector3(0,.05,0),.12,.18,.07,Color("bbaa78"))
			ring.rotation.x=.18

func _detailed_house(p:Vector3,size:Vector3,_wall:Color,roof:Color,yaw:float,refined_roof:bool=false)->void:
	var crafted:Node3D=FurHarborCraftedAssets.house(size,Color.WHITE if refined_roof else roof)
	crafted.position=p;crafted.rotation.y=yaw;w.add_child(crafted)

func _lighthouse(p:Vector3)->void:
	var lighthouse:=FurHarborCraftedAssets.prop("lighthouse_crafted");lighthouse.position=p;w.add_child(lighthouse)

func _windmill(p:Vector3)->void:
	var body:=FurHarborCraftedAssets.prop("windmill_crafted");body.name="CraftedWindmillMasonry";body.position=p;w.add_child(body)
	var rotor:=Node3D.new();rotor.name="WindmillSails";rotor.position=p+Vector3(0,2.48,1.08);rotor.set_meta("keep_animated",true);w.add_child(rotor);rotors.append(rotor)
	var sails:=FurHarborCraftedAssets.prop("windmill_sails_crafted");sails.set_meta("keep_animated",true);rotor.add_child(sails)

func _wheat_patch(p:Vector3)->void:
	var bed:=FurTravelArtAssets.instance("wheat_garden_atelier");bed.position=p;w.add_child(bed)

func _ruin(p:Vector3)->void:
	var arch:=FurHarborCraftedAssets.prop("ruin_arch_crafted");arch.position=p;w.add_child(arch)

func _shrine(p:Vector3)->void:
	var shrine:=FurTravelArtAssets.instance("star_shrine_atelier");shrine.position=p;w.add_child(shrine)

func _tent(p:Vector3)->void:
	var tent:=FurTravelArtAssets.instance("explorer_tent_atelier");tent.position=p;w.add_child(tent)

func _planting(d:Dictionary)->void:
	var center:Vector3=d.center;var radius:Vector2=d.radius;var theme:String=d.theme
	for i in 36:
		var angle:float=(i+.18)*TAU/36.0
		var p:=center+Vector3(cos(angle)*(radius.x-1.7),-.22,sin(angle)*(radius.y-1.1))
		if _route_distance(p,int(d.id))<1.6:continue
		var tall:bool=i%4==0 and p.z<center.z+4.0 and _route_distance(p,int(d.id))>2.6
		if tall:_tree(p,theme,i)
		else:
			_bush(p,theme,i)
	# Place interior orchard/forest clusters only where the route-clearance test allows.
	for i in 9:
		var p:=center+Vector3(-5.5+float(i%3)*5.5,-.22,-3.7+float(i/3)*3.7)
		if _route_distance(p,int(d.id))<2.05:continue
		var occupied:bool=false
		for prior:Dictionary in _occupied:
			if Vector2(p.x,p.z).distance_to(Vector2(prior.pos.x,prior.pos.z))<float(prior.radius)+1.1:occupied=true;break
		if occupied:continue
		if theme=="ruins":_tree(p,theme,i+7)
		elif i%2==0:
			for j in 3:_bush(p+Vector3(sin(j*2.1)*.4,0,cos(j*2.1)*.35),theme,i+j,.86)
	for i in 11:
		var angle:float=i*TAU/11.0+.37
		var p:=center+Vector3(cos(angle)*(radius.x-.95),-.18,sin(angle)*(radius.y-.85))
		if _route_distance(p,int(d.id))<1.3:continue
		w._batch("sphere",p+Vector3(0,.11,0),Vector3(.63,.34,.47),Color("a3a08d"))
		if theme=="ruins":
			w._cylinder(p+Vector3(.27,.25,0),.26,.045,Color("bbbc9e"))
			w._sphere(p+Vector3(.27,.39,0),Vector3(.30,.18,.29),Color("b2b9c9"))
			w._sphere(p+Vector3(.31,.76,.16),Vector3(.05,.05,.05),Color("c1ddb0"),null,true)

func _bush(p:Vector3,_theme:String,variant:int,scale:float=1.0)->void:
	var shrub:Node3D=FurHarborCraftedAssets.plant();shrub.position=p;shrub.scale=Vector3(.90+.055*(variant%4),.84+.055*(variant%5),.91+.035*((variant+2)%4))*scale;shrub.rotation.y=variant*2.399;w.add_child(shrub)


func _tree(p:Vector3,theme:String,index:int)->void:
	var tree:Node3D=FurHarborCraftedAssets.plant(true);tree.name="CraftedTree_%s_%d"%[theme,index]
	tree.position=p;tree.rotation.y=index*2.399;tree.scale=Vector3.ONE*(.78 if theme=="harbor" else 1.0)
	w.add_child(tree)

func _crafted_coastal_gardens(d:Dictionary)->void:
	# Coastal pockets outside the ring road were absent from the old planting
	# pass, whose sample radius coincided with the road itself.
	for i in 23:
		var angle:float=i*TAU/23.0+.17
		var edge:Vector3=_cliff_point(d,angle,0,1)
		var p:Vector3=d.center+(edge-d.center)*.97;p.y=float(d.height)-.23
		if _route_distance(p,int(d.id))<1.75:continue
		var near_building:bool=false
		for prior:Dictionary in _occupied:
			if Vector2(p.x-prior.pos.x,p.z-prior.pos.z).length()<float(prior.radius)+.65:near_building=true;break
		if near_building:continue
		_bush(p,str(d.theme),i,.90 if i%3 else 1.12)
		if i%5==0 and p.z<d.center.z-1.5 and _route_distance(p,int(d.id))>2.5:_tree(p,str(d.theme),i)

func _distant_rocks()->void:
	var positions:Array[Vector3]=[Vector3(-41,-.5,-18),Vector3(37,-.8,-14),Vector3(-38,-1.0,27),Vector3(35,-1.2,28),Vector3(1,-.4,-33)]
	for index in positions.size():
		var p:Vector3=positions[index]
		_promontory(p,Vector2(2.5+float(index%2)*.7,1.8+float(index%3)*.35),Color("738a87"))
		for i in 2:
			var point:Vector3=p+Vector3(sin(i*2.1)*.80,0,cos(i*2.1)*.60)
			var tree:=FurHarborCraftedAssets.plant(true);tree.position=point;tree.scale=Vector3.ONE*.60;tree.rotation.y=i*1.3;w.add_child(tree)
		if index==4:
			var beacon:=FurTravelArtAssets.instance("lighthouse_atelier");beacon.position=p+Vector3(1.0,0,0);beacon.scale=Vector3.ONE*.46;w.add_child(beacon)

func _promontory(p:Vector3,radius:Vector2,colour:Color)->void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(-1)
	# Existing flat tops keep buildings supported. The rock beneath grows shelves
	# and an irregular wider foot so far islands no longer repeat a cup silhouette.
	var levels:Array[Vector2]=[Vector2(0,1),Vector2(.15,.98),Vector2(.15,1.045),Vector2(.38,1.015),Vector2(.61,.93),Vector2(.72,1.055),Vector2(1,1.16)]
	var phase:float=p.x*.11+p.z*.13
	for i in 36:
		var a:float=i*TAU/36.0;var b:float=(i+1)*TAU/36.0
		var pa:=p+Vector3(cos(a)*radius.x,0,sin(a)*radius.y)
		var pb:=p+Vector3(cos(b)*radius.x,0,sin(b)*radius.y)
		st.set_color(colour)
		for v:Vector3 in [p,pa,pb]:st.add_vertex(v)
		for tier in levels.size()-1:
			var corners:Array[Vector3]=[]
			for data:Vector3 in [Vector3(a,levels[tier].x,levels[tier].y),Vector3(b,levels[tier].x,levels[tier].y),Vector3(b,levels[tier+1].x,levels[tier+1].y),Vector3(a,levels[tier+1].x,levels[tier+1].y)]:
				var factor:float=data.z+.047*sin(data.x*3+phase+data.y)*sin(data.y*PI)
				var height:float=lerpf(p.y,-3.10,data.y)+.08*sin(data.x*4+phase)*sin(data.y*PI)
				corners.append(Vector3(p.x+cos(data.x)*radius.x*factor,height,p.z+sin(data.x)*radius.y*factor))
			st.set_color(colour.darkened(.09+levels[tier+1].x*.20+.021*sin(i*.73)))
			w._quad(st,corners[0],corners[1],corners[2],corners[3])
	st.generate_normals()
	var mesh:=MeshInstance3D.new();mesh.name="ErodedHeadland";mesh.mesh=st.commit()
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.roughness=.96;mesh.material_override=material;w.add_child(mesh)
	for i in 5:
		var angle:float=PI+i*PI/4.0+.08*sin(i*2+phase)
		w._batch("sphere",p+Vector3(cos(angle)*radius.x*.98,-.30,sin(angle)*radius.y*.98),Vector3(.9,.8,.75),colour.darkened(.17),Vector3(0,angle,0))

func _detail_site(d:Dictionary,preferred:Vector2,radius:float)->Vector3:
	var center:Vector3=d.center;var result:=Vector3.INF;var score:float=-INF
	for x in range(-8,9):
		for z in range(-6,7):
			var p:=center+Vector3(x,-.22,z)
			if float(x*x)/90.0+float(z*z)/45.0>.96:continue
			if _route_distance(p,int(d.id))<radius+1.15:continue
			var free:bool=true
			for item:Dictionary in _occupied:
				if Vector2(p.x,p.z).distance_to(Vector2(item.pos.x,item.pos.z))<float(item.radius)+radius+.15:free=false;break
			if not free:continue
			var rank:float=-Vector2(x,z).distance_to(preferred)
			if rank>score:result=p;score=rank
	if result.is_finite():_occupied.append({"pos":result,"radius":radius})
	return result

func _extra_scenery(d:Dictionary)->void:
	var center:Vector3=d.center;var theme:String=d.theme
	if theme=="harbor":
		for preferred:Vector2 in [Vector2(-6,1),Vector2(5,-3),Vector2(0,-4)]:
			var p:Vector3=_detail_site(d,preferred,.83)
			if p.is_finite():_cargo_cluster(p)
		var shelf:Vector3=_detail_site(d,Vector2(6,2),.74)
		if shelf.is_finite():_shelf(shelf)
		var bench:Vector3=_detail_site(d,Vector2(-2,-3),.65)
		if bench.is_finite():_bench(bench)
		var sign_site:Vector3=_detail_site(d,Vector2(-5,-3),.5)
		if sign_site.is_finite():
			var sign_model:=FurTravelArtAssets.instance("travel_sign_atelier");sign_model.position=sign_site;sign_model.scale=Vector3.ONE*.78;w.add_child(sign_model)
		# The warehouse headland has its own loading apron and short stone stairs.
		var apron:Vector3=center+Vector3(-4.2,-.18,-8.48)
		_courtyard(apron,1.65)
		for i in 4:w._box(apron+Vector3(1.0,.05-i*.04,.56+i*.27),Vector3(.86,.14,.42),STONE)
		_cargo_cluster(center+Vector3(-6.0,-.15,-9.3))
	elif theme=="windmill":
		var terrace:Vector3=_detail_site(d,Vector2(-1,0),1.55)
		if terrace.is_finite():_terraced_garden(terrace)
		var millstones:Vector3=_detail_site(d,Vector2(5,1),.79)
		if millstones.is_finite():
			var mill:=FurTravelArtAssets.instance("hand_mill_atelier");mill.position=millstones;w.add_child(mill)
		_waterfall(d)
	else:
		# A wooded spur sits behind the northern road, keeping the route in front.
		var forest:Vector3=center+Vector3(4,-.20,-9.2)
		_promontory(forest,Vector2(4.0,2.6),Color("788b75"))
		for i in 5:_tree(center+Vector3(1.0+i*1.15,-.18,-9.1+.55*sin(i*1.7)),"ruins",i+20)
		for preferred:Vector2 in [Vector2(-5,0),Vector2(4,0),Vector2(0,-4)]:
			var p:Vector3=_detail_site(d,preferred,.73)
			if p.is_finite():_broken_column(p,int(absf(preferred.x)+absf(preferred.y)))
		var pool:Vector3=_detail_site(d,Vector2(-2,-1),.95)
		if pool.is_finite():
			w._cylinder(pool+Vector3(0,.03,0),.045,1.01,Color("649088"))
			w._ring(pool+Vector3(0,.055,0),.92,1.09,.10,Color("99a698"))
			for i in 7:
				var angle:float=i*TAU/7
				w._sphere(pool+Vector3(cos(angle)*.66,.16,sin(angle)*.65),Vector3(.19,.10,.16),Color("9aab83"))
		for i in 10:
			var angle:float=i*TAU/10.0
			var p:=center+Vector3(cos(angle)*4.5,.76+.25*sin(i*1.3),sin(angle)*3.3)
			if _route_distance(p,int(d.id))<1.3:continue
			w._sphere(p,Vector3(.075,.075,.075),Color("c6dab2"),null,true)
	_shore_arch(d)

func _cargo_cluster(p:Vector3)->void:
	for item in 3:
		var crate:=FurTravelArtAssets.instance("oak_crate_atelier");crate.position=p+Vector3(-.44+float(item%2)*.83,float(item/2)*.70,.12-float(item/2)*.12);crate.rotation.y=.04*sin(item*1.7+p.x);w.add_child(crate)
	_barrel(p+Vector3(.99,0,.07))

func _barrel(p:Vector3)->void:
	var barrel:=FurTravelArtAssets.instance("oak_barrel_atelier");barrel.position=p;w.add_child(barrel)

func _shelf(p:Vector3)->void:
	var shelf:=FurTravelArtAssets.instance("apothecary_shelf_atelier");shelf.position=p;w.add_child(shelf)

func _bench(p:Vector3)->void:
	var bench:=FurTravelArtAssets.instance("harbor_bench_atelier");bench.position=p;w.add_child(bench)

func _terraced_garden(p:Vector3)->void:
	for tier in 3:
		var level:float=.12+tier*.27;var depth:float=2.65-tier*.47
		w._box(p+Vector3(0,level,-tier*.23),Vector3(3.5-tier*.29,.30,depth),Color("9b9476"))
		w._box(p+Vector3(0,level+.17,-tier*.23),Vector3(3.38-tier*.29,.06,depth-.11),Color("83935f"))
		for plant in 6:
			var point:Vector3=p+Vector3(-1.35+plant*.52,level+.29,-tier*.23+depth*.32)
			w._batch("sphere",point,Vector3(.21,.24,.20),Color("9eae6e"))
			w._batch("sphere",point+Vector3(.02,.14,0),Vector3(.08,.08,.08),Color("ccb77d"))
	for i in 5:w._box(p+Vector3(1.80,.06+i*.14,.63-i*.31),Vector3(.37,.16,.44),STONE)

func _broken_column(p:Vector3,variant:int)->void:
	# Keep the original reserved sites. The dressing pass creates three distinct
	# eroded shafts and connected roots inside its existing district mesh.
	ruin_fragments.append({"position":p,"variant":variant,"old_height":.68+float(variant%3)*.26+.325,"reserved_radius":.73})

func _shore_arch(d:Dictionary)->void:
	var center:Vector3=d.center;var radius:Vector2=d.radius
	var angle:float=1.54 if int(d.id)!=1 else .35
	var radial:float=1.075+.062*sin(angle*3+float(d.id)*1.7)+.041*cos(angle*5+float(d.id))
	var p:=center+Vector3(cos(angle)*radius.x*radial,0,sin(angle)*radius.y*radial)
	p.y=-1.22
	var parent:=Node3D.new();parent.name="SeaCaveRockArch";parent.position=p;parent.rotation.y=-angle+PI/2;w.add_child(parent)
	var colour:=Color("86908b") if int(d.id)==2 else Color("9f9588")
	var arch:=MeshInstance3D.new();arch.name="CarvedSeaArchWithWetFooting"
	arch.mesh=CoastalRock.sea_arch(colour);arch.material_override=Crafted.material(0,-2.96);parent.add_child(arch)

func _waterfall(d:Dictionary)->void:
	var center:Vector3=d.center;var radius:Vector2=d.radius
	var angle:float=1.18;var radial:float=1.075+.062*sin(angle*3+float(d.id)*1.7)+.041*cos(angle*5+float(d.id))
	var p:=center+Vector3(cos(angle)*radius.x*radial,-.16,sin(angle)*radius.y*radial)
	var tangent:=Vector3(-sin(angle),0,cos(angle));var outward:=Vector3(cos(angle),0,sin(angle))
	var section:PackedVector3Array=PackedVector3Array()
	var rows:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/sevenhour_v1/coast_atelier_1_cascade_profile.json"))
	for row:Array in rows:section.append(center+Vector3(float(row[0]),float(row[1]),float(row[2])))
	Water.waterfall(w,p,tangent,outward,-3.0,section)
