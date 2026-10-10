class_name FurPartyArenaStage
extends Node3D
## Visual scenery only. The authoritative x ±13, z ±8.7 play rectangle stays flat.
const World=preload("res://scripts/party/world_builder.gd")
const Assets=preload("res://scripts/party/party_world_archipelago.gd")
const Landmarks=preload("res://scripts/party/party_landmark_factory.gd")
const Palette=preload("res://scripts/party/party_world_palette.gd")
const Water=preload("res://scripts/party/party_water_surface.gd")
const Crafted=preload("res://scripts/party/party_environment_material.gd")
const Foliage=preload("res://scripts/party/party_foliage_geometry.gd")
const Harbor=preload("res://scripts/party/party_harbor_geometry.gd")
var palette:int=0
var scenery:Node3D
var painter:RefCounted
var obstacle_footprints:Array[Rect2]=[]
var static_draw_objects:int=0
var _plants:SurfaceTool
var plant_vertices:int=0

func build(district:int)->void:
	for child:Node in get_children():remove_child(child);child.queue_free()
	palette=clampi(district,0,2);obstacle_footprints.clear()
	_plants=SurfaceTool.new();_plants.begin(Mesh.PRIMITIVE_TRIANGLES);_plants.set_normal(Vector3.UP);_plants.set_uv2(Vector2.ZERO);plant_vertices=0
	scenery=World.new();scenery.name="ArenaScenery";add_child(scenery)
	painter=Assets.new();painter.w=scenery;scenery._archipelago=painter
	_sea();_shore();_floor()
	match palette:
		0:_harbor()
		1:_hill()
		2:_ruins()
	_boundary();_nearby_islets();_frame_gardens()
	if plant_vertices>0:
		var foliage:=MeshInstance3D.new();foliage.name="ArenaSculptedLeafGroups";foliage.mesh=_plants.commit();foliage.material_override=Crafted.material(-1);scenery.add_child(foliage)
	_plants=null
	scenery._flush_batches();scenery._combine_static_geometry()
	static_draw_objects=find_children("*","MeshInstance3D",true,false).size()+find_children("*","MultiMeshInstance3D",true,false).size()

func _hash(x:int,z:int,salt:int=0)->float:
	return fposmod(sin(float(x*127+z*311+salt*73))*43758.5453,1.0)

func _vertex_mesh(builder:SurfaceTool,label:String)->MeshInstance3D:
	builder.generate_normals()
	var result:=MeshInstance3D.new();result.name=label;result.mesh=builder.commit()
	result.material_override=Crafted.material(-1 if label=="LayeredArenaShore" else 0,-2.0 if label=="LayeredArenaShore" else -100.0);scenery.add_child(result);return result

func _sea()->void:
	FurCoastalDepthWater.create(scenery,[{"center":Vector3.ZERO,"radius":Vector2(18.2,14.4)}],true)

func _shore()->void:
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_smooth_group(-1);builder.set_uv2(Vector2.ZERO);builder.set_normal(Vector3.UP)
	var ground:Color=Palette.GROUND[palette]
	var stone:Color=[Color("a18f80"),Color("948c74"),Color("87948b")][palette]
	for i in 88:
		var angle:float=i*TAU/88.0;var next:float=(i+1)*TAU/88.0
		var a:Vector3=_coast_point(angle);var b:Vector3=_coast_point(next)
		builder.set_color(ground);builder.set_uv2(Vector2(0 if palette==0 else 7,0))
		for v:Vector3 in [Vector3(0,-.075,0),a,b]:builder.add_vertex(v)
		builder.set_uv2(Vector2.ZERO)
		# Broad faulted planes replace three equidistant ledges and 44 round
		# pebbles. The entire playable top remains bit-for-bit unchanged.
		for row in 2:
			var top:float=0.0 if row==0 else .40
			var bottom:float=.40 if row==0 else 1.0
			builder.set_color(stone.darkened(.06+row*.13).lightened(.027*sin(i*.39+palette)))
			scenery._quad(builder,_shore_wall(angle,top),_shore_wall(next,top),_shore_wall(next,bottom),_shore_wall(angle,bottom))
	var rim:=FurCoastalSculptAssets.instance("arena_fracture_rim_%d"%palette);scenery.add_child(rim)
	var shore:MeshInstance3D=_vertex_mesh(builder,"LayeredArenaShore")
	shore.set_meta("coast_sculpt",{"merged_rock_feet":12,"removed_round_stones":44,"preserved_top_samples":88,"no_new_draw_objects":true})
	var foam_points:=PackedVector3Array()
	for i in 88:
		var point:Vector3=_shore_wall(i*TAU/88,.94866);point.y=-2.01;foam_points.append(point)
	var foam:=Water.shore_foam(scenery,foam_points,Vector3.ZERO,.68,"ArenaShoreFoamV2")
	var foam_material:=ShaderMaterial.new();foam_material.shader=load("res://assets/art/eighthour_v1/contact_foam.gdshader");foam_material.set_shader_parameter("surface_noise",FurPartySurfaceNoise.texture());foam_material.render_priority=1;foam.material_override=foam_material

func _shore_wall(angle:float,depth:float)->Vector3:
	var top:Vector3=_coast_point(angle)
	var fault:float=(.15*sin(angle*3.0+palette)+.07*cos(angle*7.0))*sin(depth*PI)
	var t:float=clampf(depth+fault,0.0,1.0)
	var spread:float=1.0+.065*depth+(.033*sin(angle*5.0+palette)+.022*cos(angle*9.0))*sin(depth*PI)
	return Vector3(top.x*spread,lerpf(-.075,-2.12,t),top.z*spread)

func _shore_rock(st:SurfaceTool,index:int,stone:Color)->void:
	var angle:float=(float(index)+.18*sin(index*1.7))*TAU/12
	var radial:=Vector3(cos(angle),0,sin(angle));var side:=Vector3(-radial.z,0,radial.x)
	var origin:Vector3=_coast_point(angle)
	var width:float=1.25+float(index%4)*.30
	var rings:Array=[];var centers:Array[Vector3]=[]
	for row in 3:
		var center:Vector3=origin+radial*(.15+row*.23)+side*(.07*sin(index+row))
		center.y=[-.22,-1.05,-2.12][row];centers.append(center)
		var ring:Array[Vector3]=[]
		for j in 7:
			var a:float=j*TAU/7+.16;var scale:float=(.82+row*.13)*(1.0+.06*sin(index+j*2))
			ring.append(center+side*cos(a)*width*.5*scale+radial*sin(a)*(.44+row*.12))
		rings.append(ring)
	st.set_uv2(Vector2.ZERO)
	for row in 2:
		for j in 7:
			var next:int=(j+1)%7
			Foliage._quad(st,rings[row][j],rings[row][next],rings[row+1][next],rings[row+1][j],(rings[row][j]+rings[row][next])*.5-centers[row],stone.darkened(row*.13).lightened(.04*sin(index)))
	var turf:bool=index%3==1
	for j in 7:
		var next:int=(j+1)%7
		Foliage._triangle(st,centers[0],rings[0][j],rings[0][next],Vector3.UP,stone.lightened(.07))
		if turf:
			var green:Color=[Color("758b61"),Color("82945b"),Color("5e806b")][palette];var lift:=Vector3.UP*.014
			st.set_uv2(Vector2(7,0));Foliage._triangle(st,centers[0]+lift,centers[0].lerp(rings[0][j],.54)+lift,centers[0].lerp(rings[0][next],.54)+lift,Vector3.UP,green.lerp(stone,.23))
			st.set_uv2(Vector2.ZERO)

func _coast_point(angle:float)->Vector3:
	var x:float=cos(angle);var z:float=sin(angle)
	var irregular:float=1.0+.025*sin(angle*5.0+palette)+.016*cos(angle*9.0)
	return Vector3(signf(x)*pow(absf(x),.40)*17.0*irregular,-.075,signf(z)*pow(absf(z),.40)*13.0*irregular)

func _floor()->void:
	var floor:=MeshInstance3D.new();floor.name="UnobstructedPlaySurface"
	var plane:=PlaneMesh.new();plane.size=Vector2(30.4,21.4);floor.mesh=plane;floor.position.y=-.032
	var shader:=Shader.new();shader.code="""shader_type spatial;
uniform vec4 base:source_color;uniform vec4 patch:source_color;varying vec2 p;
void vertex(){p=VERTEX.xz;}
void fragment(){float broad=sin(p.x*.47+sin(p.y*.39))*sin(p.y*.61-p.x*.17);float grain=sin(p.x*1.7+sin(p.y*1.2))*sin(p.y*2.3)*.006;ALBEDO=mix(base.rgb,patch.rgb,smoothstep(-.55,.65,broad)*.34)+grain;ROUGHNESS=.97;}
"""
	var material:=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("base",Palette.FLOOR[palette])
	material.set_shader_parameter("patch",Palette.PATCH[palette]);floor.material_override=material;scenery.add_child(floor)
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_smooth_group(-1)
	if palette==0:
		var paving:=FurTravelArtAssets.instance("harbor_arena_paving_atelier");paving.name="AuthoredHarborPlaza";scenery.add_child(paving);_paving_detail(paving);return
	else:
		for row in range(-12,13):
			for col in range(-16,17):
				var pos:=Vector2(col*.93+float(posmod(row,2))*.465,row*.84)
				pos+=Vector2(_hash(col,row,2)-.5,_hash(col,row,5)-.5)*.09
				if absf(pos.x)>14.1 or absf(pos.y)>9.95:continue
				if palette==1:
					if absf(pos.y-sin(pos.x*.23)*1.9)>2.50 and absf(pos.x+sin(pos.y*.28)*2.1)>1.80:continue
				var shade:Color=Palette.PAVING[palette]
				shade=shade.darkened(_hash(col,row,1)*.055).lightened(_hash(col,row,3)*.026)
				_paver(builder,pos,Vector2(.885,.795),shade,_hash(col,row)*.035-.0175)
	var paving:MeshInstance3D=_vertex_mesh(builder,"ShallowDressedPaving");paving.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if palette==0:_compass_inlay()
	if palette==2:
		for radius:float in [2.8,3.35]:
			var ring:MeshInstance3D=scenery._ring(Vector3(0,.016,0),radius,radius+.075,.014,Color("b4bca4"));ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _paver(builder:SurfaceTool,point:Vector2,size2:Vector2,colour:Color,angle:float)->void:
	var corners:Array[Vector3]=[]
	for corner:Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var v:Vector2=(corner*size2*.5).rotated(angle)+point;corners.append(Vector3(v.x,-.001,v.y))
	builder.set_color(colour);scenery._quad(builder,corners[0],corners[3],corners[2],corners[1])
	for i in 4:
		var a:Vector3=corners[i];var b:Vector3=corners[(i+1)%4]
		builder.set_color(colour.darkened(.085));scenery._quad(builder,a,b,b-Vector3(0,.026,0),a-Vector3(0,.026,0))

func _compass_inlay()->void:
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var angle:float=i*TAU/8.0
		var a:=Vector3(cos(angle)*2.45,.012,sin(angle)*2.45);var b:=Vector3(cos(angle-.23)*.52,.012,sin(angle-.23)*.52);var c:=Vector3(cos(angle+.23)*.52,.012,sin(angle+.23)*.52)
		builder.set_color(Color("ab9b84") if i%2==0 else Color("bcad93"))
		for v:Vector3 in [a,b,c]:builder.add_vertex(v)
	_vertex_mesh(builder,"HarborCompassInlay");scenery._ring(Vector3(0,.011,0),2.60,2.65,.012,Color("b7a283"))

func _landmark(district:int,point:Vector3,max_height:float=3.3)->void:
	var landmark:Node3D=Landmarks.build(district,max_height);scenery.add_child(landmark);landmark.position=point

func _reserve(point:Vector3,radius:Vector2)->void:
	obstacle_footprints.append(Rect2(Vector2(point.x,point.z)-radius,radius*2))

func _harbor()->void:
	_landmark(0,Vector3(-7.4,0,-11.65),3.25);_reserve(Vector3(-7.4,0,-11.65),Vector2(1.9,1.6))
	_landmark(0,Vector3(8.8,0,-11.7),2.65);_reserve(Vector3(8.8,0,-11.7),Vector2(1.8,1.45))
	painter._shelf(Vector3(-3.9,0,-11.1));painter._cargo_cluster(Vector3(12.4,0,-11.0))
	painter._cargo_cluster(Vector3(-14.45,0,3.1));painter._barrel(Vector3(14.35,0,2.4));painter._bench(Vector3(3.5,0,-11.15))
	for x:float in [-15.1,15.1]:
		for i in 34:
			scenery._batch("box",Vector3(x,-.02,-9.8+i*.59),Vector3(2.1,.17,.55),[Color("a58962"),Color("aa8f68"),Color("9b805d")][i%3])
		for z:float in [-9.4,-5.0,0,5.0,9.4]:
			scenery._cylinder(Vector3(x+signf(x)*.78,-.74,z),2.12,.13,Color("77644e"))
			scenery._ring(Vector3(x+signf(x)*.78,.25,z),.13,.19,.09,Color("b7a282"))
	for x in range(-13,14):
		for row in 2:scenery._batch("box",Vector3(x+.5*float(row%2),-.18-row*.37,10.55),Vector3(.95,.33,.54),Color("ab9982").lightened(float(posmod(x,3))*.03))
	for i in 11:scenery._batch("box",Vector3(17.0,-.11,-5.1+i*.38),Vector3(3.4,.16,.35),Color("a18864"))
	var boat:=Node3D.new();boat.name="HarborMooredRowboat";boat.position=Vector3(19.6,-1.75,-3.2);boat.rotation.y=.24;scenery.add_child(boat)
	var hull:=MeshInstance3D.new();hull.name="HollowClinkerRowboat";hull.mesh=Harbor.rowboat();hull.material_override=Crafted.material(-1);boat.add_child(hull)

	scenery._beam(Vector3(18.35,-.1,-4.25),Vector3(19.7,-1.1,-4.1),.035,Color("c6b795"))
	for x:float in [-12.0,-.4,5.3]:_planter(Vector3(x,0,-11.25))

func _hill()->void:
	_landmark(1,Vector3(-8.6,0,-11.8),3.25);_reserve(Vector3(-8.6,0,-11.8),Vector2(1.95,1.55))
	_landmark(0,Vector3(10.2,0,-11.8),2.7);_reserve(Vector3(10.2,0,-11.8),Vector2(1.8,1.55))
	for i in 3:
		var point:=Vector3(-2.5+i*3.2,.04,-11.6);painter._terraced_garden(point);_reserve(point,Vector2(1.85,1.50))
	for side:float in [-1.0,1.0]:
		for i in 5:
			var point:=Vector3(side*15.4,-.12,-8.6+i*4.1)
			scenery._sphere(point,Vector3(3.0,1.25,3.25),Color("879867"))
			for shrub in 3:
				var offset:=Vector3(side*.25,.47,-.52+shrub*.49)
				_plant(point+offset-Vector3.UP*.20,"windmill",i+shrub,.84)
		for z:float in [-7.0,1.5,7.3]:_small_tree(Vector3(side*16.1,.10,z),"windmill",int(z))
	painter._barrel(Vector3(-12.0,0,-10.8));painter._bench(Vector3(13.9,.05,-4.5))
	for i in 3:scenery._sphere(Vector3(-14.2,.17,4.0+i*.48),Vector3(.57,.46,.46),Color("c2b08a"))
	for side:float in [-1.0,1.0]:
		for z:float in [-7.8,-2.4,3.3,8.1]:_fence(Vector3(side*14.45,0,z),PI/2,2.6)
	scenery._box(Vector3(13.95,.16,6.7),Vector3(.8,.4,1.9),Color("a5987b"))
	scenery._box(Vector3(13.95,.37,6.7),Vector3(.59,.015,1.63),Color("78a29a"))

func _ruins()->void:
	_landmark(2,Vector3(-7.7,.02,-11.5),3.25);_reserve(Vector3(-7.7,0,-11.5),Vector2(2.15,1.50))
	_landmark(2,Vector3(8.1,.02,-11.9),2.5);_reserve(Vector3(8.1,0,-11.9),Vector2(1.75,1.35))
	for i in 4:painter._broken_column(Vector3(-2.4+i*1.3,0,-11.9),i)
	for side:float in [-1.0,1.0]:
		for i in 6:
			var p:=Vector3(side*(14.4+.35*sin(i*1.4)),0,-8.5+i*3.2)
			scenery._batch("box",p+Vector3(0,.15,0),Vector3(.83,.30,1.5),Color("96a293"),Vector3(0,.20*sin(i),0))
			if i%2==0:painter._broken_column(p+Vector3(side*.45,.15,.45),i)
			for moss in 3:scenery._batch("sphere",p+Vector3(.22*sin(moss),.33,.4*cos(moss*1.8)),Vector3(.40,.08,.26),Color("7e956e"))
		for i in 4:_small_tree(Vector3(side*16.2,0,-8.5+i*5.0),"ruins",i+2)
	for i in 7:_small_tree(Vector3(-13.2+i*4.4,-.04,-11.9-.06*sin(i)),"ruins",i+10)
	for i in 18:
		var side:float=-1.0 if i%2==0 else 1.0;var p:=Vector3(side*(14.5+_hash(i,4)*1.0),.24,-8.5+float(i/2)*1.9)
		scenery._cylinder(p,.21,.035,Color("b8b797"));scenery._sphere(p+Vector3(0,.17,0),Vector3(.31,.13,.30),Color("b0b7ba"))
		if i%3==0:scenery._sphere(p+Vector3(.17,.48,.18),Vector3(.064,.064,.064),Color("c4dcb4"),null,true)
	for side:float in [-1.0,1.0]:
		for z:float in [-7.6,7.8]:
			var p:=Vector3(side*14.0,0,z);scenery._cylinder(p+Vector3(0,.19,0),.38,.34,Color("94a18f"))
			scenery._sphere(p+Vector3(0,.57,0),Vector3(.21,.44,.21),Color("a9cbb2"),null,true)

func _boundary()->void:
	var colour:Color=[Color("bda88c"),Color("a6ab85"),Color("97a594")][palette]
	for side:float in [-1.0,1.0]:
		for i in 28:scenery._batch("box",Vector3(side*13.55,.045,-8.8+i*.65),Vector3(.25,.11,.61),colour)
		for i in 40:scenery._batch("box",Vector3(-13.05+i*.67,.045,side*9.25),Vector3(.62,.11,.25),colour)
	if palette!=2:
		for x:float in [-12.6,-5.0,4.8,12.6]:scenery._lantern(Vector3(x,0,-10.10),.84)
	if palette==0:
		for side:float in [-1.0,1.0]:
			for z:float in [-7.8,0,7.8]:scenery._lantern(Vector3(side*14.4,0,z),.94)

func _planter(p:Vector3)->void:
	scenery._box(p+Vector3(0,.16,0),Vector3(1.30,.32,.54),Color("a18b67"))
	for i in 3:_plant(p+Vector3(-.40+i*.40,.29,0),"harbor",i,.54)

func _plant(p:Vector3,_theme:String,variant:int,size:float=1.0)->void:
	var plant:=FurCoastalSculptAssets.instance("coastal_leaf_shrub");plant.position=p;plant.scale=Vector3.ONE*size;plant.rotation.y=variant*2.399;scenery.add_child(plant)

func _fence(p:Vector3,yaw:float,length:float)->void:
	var root:=Node3D.new();root.position=p;root.rotation.y=yaw;scenery.add_child(root)
	for side:float in [-1.0,1.0]:scenery._box(Vector3(side*length*.5,.35,0),Vector3(.11,.7,.11),Color("998263"),root)
	for y:float in [.26,.55]:scenery._box(Vector3(0,y,0),Vector3(length,.095,.07),Color("ad9775"),root)

func _small_tree(p:Vector3,theme:String,index:int)->void:
	var tree:=FurCoastalSculptAssets.instance("island_tree_recessed_canopy");tree.position=p;tree.scale=Vector3.ONE*.66;tree.rotation.y=index*2.399;scenery.add_child(tree);_reserve(p,Vector2(1.25,1.25))

func _nearby_islets()->void:
	for i in 4:
		var p:=Vector3(-27.0+float(i%2)*53.0,-2.4,-23.0+float(i/2)*45.0)
		var rocks:=FurCoastalSculptAssets.instance("coast_land_rocks_02");rocks.position=p;rocks.scale=Vector3(.55,.53,.55);scenery.add_child(rocks)
		var tree:=FurCoastalSculptAssets.instance("island_tree_recessed_canopy");tree.position=p+Vector3(0,1.8,0);tree.scale=Vector3.ONE*.88;tree.rotation.y=i*2.1;scenery.add_child(tree)

func _frame_gardens()->void:
	for i in 4:
		var p:=Vector3([-15.5,15.5,-12.8,13.0][i],0,[-9.8,-10.0,-12.9,-13.1][i])
		var tree:=FurCoastalSculptAssets.instance("island_tree_recessed_canopy");tree.position=p;tree.scale=Vector3.ONE*(.82 if i<2 else .68);tree.rotation.y=i*2.399;scenery.add_child(tree)
		for j in 3:_plant(p+Vector3(-.8+j*.7,0,.5+.4*sin(j*2.3)),"harbor",i+j,.90)

func _paving_detail(node:Node)->void:
	if node is MeshInstance3D:
		var material:=ShaderMaterial.new();material.shader=load("res://assets/art/eighthour_v1/plaza_stone.gdshader")
		material.set_shader_parameter("stone_detail",load("res://assets/art/eighthour_v1/coast/rock_moss_set_01_rock01_rock_moss_set_01_nor_gl_1k.jpg"));material.set_shader_parameter("stone_color",load("res://assets/art/eighthour_v1/coast/rock_moss_set_01_rock01_rock_moss_set_01_diff_1k.jpg"));node.material_override=material
	for child in node.get_children():_paving_detail(child)
