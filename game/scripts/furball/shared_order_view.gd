class_name FurSharedOrderView
extends Node3D

# Presentation only; the combat view projects the authoritative shared order.
# Seven fixed scene nodes including this root; no player/domain writes or ticks.
const Catalog=preload("res://scripts/furball/district_catalog.gd")
const Style=preload("res://scripts/furball/visual_style.gd")
const Paths=preload("res://scripts/furball/shared_order_paths.gd")
const NODE_BUDGET:=7
const GROUND_TEXT:="近箱 E直送 / R外圈"
const DUO_GROUND_TEXT:="近箱选线 · P1 E/R\nP2 逗号/句号"
const ROUTE_GROUND_TEXT:=["直送配送箱 · E拾原线路","外圈配送箱 · E拾原线路"]
const DUO_ROUTE_GROUND_TEXT:=["直送配送箱 · 拾原线路\nP1 E / P2 逗号","外圈配送箱 · 拾原线路\nP1 E / P2 逗号"]
const CARRY_TEXT:=["P1载货 · 直送 · 冲刺放箱","P2载货 · 直送 · 冲刺放箱","P1载货 · 外圈 · 冲刺放箱","P2载货 · 外圈 · 冲刺放箱"]
const SOLO_TEXT:=["P1载货（单人）· 直送 · 冲刺放箱","P1载货（单人）· 外圈 · 冲刺放箱"]
const ORDER_TEXT:=["1 · 下一站","2 · 后一站","2 · 下一站"]
const OPTION_TEXT:=["E · 直送入口","R · 外圈入口"]
var crate:MeshInstance3D
var carrier_label:Label3D
var markers:Array[MeshInstance3D]=[]
var ordinals:Array[Label3D]=[]
var active_targets:=0
var active_carrier:=-1
var path_cache_builds:=0
var _cached_options:Dictionary={}
var _cached_run:=0
var _cached_wave:=0
var _cached_cargo:=0
var _cached_origin:=Vector2.INF
var _cached_seed:=0
var _cached_district:=-1
var _cached_battle_seed:=0
var _cached_charges:Array=[]

func _ready()->void:
	crate=MeshInstance3D.new();crate.name="DeliveryCrate";crate.mesh=_crate_mesh()
	crate.material_override=_material(Color.WHITE,true);crate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crate)
	carrier_label=_label("CargoActor");add_child(carrier_label)
	var marker_mesh:=CylinderMesh.new();marker_mesh.top_radius=.72;marker_mesh.bottom_radius=.72
	marker_mesh.height=.045;marker_mesh.radial_segments=16
	for index in 2:
		var marker:=MeshInstance3D.new();marker.name="DeliveryTarget%d"%(index+1);marker.mesh=marker_mesh
		marker.material_override=_material(Color("cb9fff"));marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker);markers.append(marker)
		var label:=_label("DeliveryOrder%d"%(index+1));add_child(label);ordinals.append(label)
	clear()

func _material(color:Color,vertex_color:bool=false)->StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color;material.vertex_color_use_as_albedo=vertex_color
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

func _label(label_name:String)->Label3D:
	var label:=Label3D.new();label.name=label_name;label.font=Style.font();label.font_size=40;label.pixel_size=.012
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true
	label.modulate=Color("fff0d5");label.outline_modulate=Color("251939");label.outline_size=8
	return label

func _crate_mesh()->ArrayMesh:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	# Paper-colored box with a broad purple cross-seal; logistics parcels are mint.
	_append_box(vertices,colors,Vector3.ZERO,Vector3(1.2,.75,.82),Color("f6cf89"))
	_append_box(vertices,colors,Vector3(0,.383,0),Vector3(1.22,.03,.16),Color("994fe3"))
	_append_box(vertices,colors,Vector3(0,.402,0),Vector3(.16,.03,.84),Color("994fe3"))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func _append_box(vertices:PackedVector3Array,colors:PackedColorArray,origin:Vector3,size:Vector3,color:Color)->void:
	var h:=size*.5
	var corners:=[Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)]
	for face in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]:
		for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
			vertices.append(origin+corners[index]);colors.append(color)

func clear()->void:
	_hide()
	_cached_options={};_cached_run=0;_cached_wave=0;_cached_cargo=0
	_cached_origin=Vector2.INF;_cached_seed=0;_cached_district=-1;_cached_battle_seed=0;_cached_charges=[]

func _hide()->void:
	if crate!=null:crate.visible=false
	if carrier_label!=null:carrier_label.visible=false
	for marker in markers:marker.visible=false
	for label in ordinals:label.visible=false
	active_targets=0;active_carrier=-1

func render(state:Variant,low_fx:bool=false,local_duo:bool=false,carrier_projection:Variant=null)->Dictionary:
	_hide()
	if not _valid(state):
		clear();return {"visible":false,"targets":0,"carrier":-1,"rejected":1}
	if _cached_run!=0 and state.has("run_token") and _cached_run!=state.run_token:clear()
	if state.run_closed or state.fulfilled or state.battle.is_empty() or state.cargo.is_empty():return _hidden()
	var cargo:Dictionary=state.cargo
	if cargo.phase=="delivered" or cargo.checkpoint==2:return _hidden()
	var pending:bool=int(cargo.route_choice)==-1
	var choices:Dictionary={}
	if pending:
		choices=_options(state)
		if not _options_valid(choices):clear();return {"visible":false,"targets":0,"carrier":-1,"rejected":1}
	crate.visible=true;carrier_label.visible=true
	var carried:bool=cargo.phase=="carrying"
	var shown:Vector2=cargo.point
	if carried and _point(carrier_projection):shown=carrier_projection
	crate.position=Vector3(shown.x,1.05 if carried else .42,shown.y)
	carrier_label.position=Vector3(shown.x,2.03 if carried else 1.38,shown.y)
	active_carrier=int(cargo.carrier) if carried else -1
	var duo:bool=local_duo and state.players==2
	var route:int=int(cargo.route_choice)
	var text:String=DUO_GROUND_TEXT if pending and duo else GROUND_TEXT if pending else SOLO_TEXT[route] if carried and state.players==1 else CARRY_TEXT[route*2+active_carrier] if carried else DUO_ROUTE_GROUND_TEXT[route] if duo else ROUTE_GROUND_TEXT[route]
	if carrier_label.text!=text:carrier_label.text=text
	for index in 2:
		if index<int(cargo.checkpoint):continue
		var target:Vector2=choices.direct[0] if pending and index==0 else choices.outer[0] if pending else cargo.nodes[index]
		var current:bool=not pending and index==int(cargo.checkpoint)
		markers[index].visible=true;ordinals[index].visible=true;active_targets+=1
		markers[index].position=Vector3(target.x,.08,target.y)
		markers[index].scale=Vector3.ONE if current or pending else Vector3(.75,1,.75)
		markers[index].material_override.albedo_color=Color("f4d17b") if current or pending and index==0 else Color("b885ef")
		ordinals[index].position=Vector3(target.x,1.35,target.y)
		var label_text:String=OPTION_TEXT[index] if pending else ORDER_TEXT[0] if index==0 else ORDER_TEXT[2] if current else ORDER_TEXT[1]
		if ordinals[index].text!=label_text:ordinals[index].text=label_text
	# low_fx intentionally preserves every critical box/actor/order cue.
	return {"visible":true,"targets":active_targets,"carrier":active_carrier,"rejected":0,"choice_pending":pending,"low_fx_preserved":low_fx}

func _hidden()->Dictionary:
	clear();return {"visible":false,"targets":0,"carrier":-1,"rejected":0}

func _options(state:Dictionary)->Dictionary:
	var cargo:Dictionary=state.cargo;var battle:Dictionary=state.battle
	if _cached_run==state.run_token and _cached_wave==battle.wave and _cached_cargo==cargo.id and _cached_origin==cargo.origin and _cached_seed==state.seed and _cached_district==battle.district_id and _cached_battle_seed==battle.seed and _cached_charges==cargo.source_charges:return _cached_options
	_cached_run=state.run_token;_cached_wave=battle.wave;_cached_cargo=cargo.id;_cached_origin=cargo.origin;_cached_seed=state.seed
	_cached_district=battle.district_id;_cached_battle_seed=battle.seed;_cached_charges=cargo.source_charges.duplicate()
	_cached_options=Paths.options(battle,cargo.origin,cargo.source_charges,state.seed)
	path_cache_builds+=1
	return _cached_options

func _options_valid(options:Dictionary)->bool:
	if not options.has_all(["direct","outer","direct_length","outer_length"]):return false
	for route in ["direct","outer"]:
		if not options[route] is Array or options[route].size()!=2 or not _point(options[route][0]) or not _point(options[route][1]):return false
	for length in ["direct_length","outer_length"]:
		if not _finite(options[length]) or float(options[length])<=0:return false
	return true

func _valid(state:Variant)->bool:
	if not state is Dictionary or state.size()>20 or not state.has_all(["players","fulfilled","run_closed","battle","cargo"]):return false
	if not state.players is int or state.players not in [1,2] or not state.fulfilled is bool or not state.run_closed is bool or not state.battle is Dictionary or not state.cargo is Dictionary:return false
	if state.battle.size()>12:return false
	if state.cargo.is_empty():return true
	if not state.has_all(["seed","run_token"]) or not state.seed is int or state.seed<1 or state.seed>2147483647 or not state.run_token is int or state.run_token<1 or state.run_token>2147483647:return false
	if state.battle.is_empty() or not state.battle.has_all(["wave","district_id","elapsed"]):return false
	if not state.battle.wave is int or state.battle.wave<1 or state.battle.wave>6 or not state.battle.district_id is int or state.battle.district_id not in [0,1,2] or not _finite(state.battle.elapsed) or float(state.battle.elapsed)<0:return false
	var cargo:Dictionary=state.cargo
	if cargo.size()!=13 or not cargo.has_all(["id","phase","point","origin","source_charges","spawn_kind","carrier","last_carrier","regrab_until","checkpoint","nodes","route_choice","pickup_revision"]):return false
	for field in ["id","carrier","last_carrier","checkpoint","route_choice","pickup_revision"]:
		if not cargo[field] is int:return false
	if cargo.id<1 or cargo.id>6 or cargo.carrier<-1 or cargo.carrier>=state.players or cargo.last_carrier<-1 or cargo.last_carrier>=state.players or cargo.checkpoint<0 or cargo.checkpoint>2:return false
	if not cargo.phase is String or cargo.phase not in ["ground","carrying","delivered"] or not _point(cargo.point):return false
	# The parent domain owns canonical provenance and wall validation. Here only
	# bound pure-data fields before accepting its formal thirteen-field snapshot.
	if not _point(cargo.origin) or not cargo.spawn_kind is String or cargo.spawn_kind not in ["completion","retry"] or not cargo.source_charges is Array:return false
	if cargo.source_charges.size()!=(3 if cargo.spawn_kind=="completion" else 0):return false
	for charge in cargo.source_charges:
		if not _finite(charge) or float(charge)<0 or float(charge)>1.2:return false
	if (cargo.phase=="carrying" and cargo.carrier<0) or (cargo.phase!="carrying" and cargo.carrier!=-1):return false
	if (cargo.phase=="delivered" and cargo.checkpoint!=2) or (cargo.phase!="delivered" and cargo.checkpoint==2):return false
	if cargo.route_choice not in [-1,0,1] or cargo.pickup_revision<0 or cargo.pickup_revision>256 or not cargo.nodes is Array:return false
	if cargo.route_choice==-1:
		if cargo.phase!="ground" or cargo.checkpoint!=0 or cargo.pickup_revision!=0 or not cargo.nodes.is_empty() or not _geometry_valid(state.battle):return false
	elif cargo.nodes.size()!=2 or not _point(cargo.nodes[0]) or not _point(cargo.nodes[1]) or cargo.nodes[0].distance_squared_to(cargo.nodes[1])<.0001:return false
	if not cargo.regrab_until is Array or cargo.regrab_until.size()!=state.players:return false
	for cooldown in cargo.regrab_until:
		if not _finite(cooldown) or float(cooldown)<0:return false
	return true

func _geometry_valid(battle:Dictionary)->bool:
	if not battle.has_all(["seed","points","obstacles","routes"]) or not battle.seed is int or battle.seed<1:return false
	if not battle.points is Array or battle.points.size()!=3 or not battle.obstacles is Array or battle.obstacles.size()>2 or not battle.routes is Array or battle.routes.size()!=3:return false
	for point in battle.points:
		if not _point(point):return false
	for obstacle in battle.obstacles:
		if not obstacle is Rect2 or not obstacle.position.is_finite() or not obstacle.size.is_finite() or obstacle.size.x<=0 or obstacle.size.y<=0:return false
	for route in battle.routes:
		if not route is Dictionary or route.size()!=2 or not route.has_all(["from","to"]) or not _point(route.from) or not _point(route.to):return false
	return true

func _point(value:Variant)->bool:return value is Vector2 and value.is_finite() and Catalog.BOUNDS.has_point(value)
func _finite(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
