class_name FurMahjongTableView
extends SubViewportContainer
## An actual isolated 3D tabletop, shared physical meshes, and ray-picked hands.
signal tile_selected(index:int,actor:int,revision:int)
signal tray_selected(slot:int,actor:int,revision:int)
signal tray_hovered(slot:int)
signal meld_selected(index:int,actor:int,revision:int)
signal table_sound(kind:String)
const Geometry=preload("res://scripts/party/mahjong_tile_geometry.gd")
const Toy=preload("res://scripts/party/pawn_geometry.gd")
const Room=preload("res://scripts/party/mahjong_room_geometry.gd")
const Surfaces=preload("res://scripts/party/mahjong_surface_materials.gd")
const Lighting=preload("res://scripts/art/art_lighting.gd")
const NightTileMotion=preload("res://scripts/party/mahjong_night_tile_motion.gd")
var viewport_3d:SubViewport
var stage:Node3D
var camera_3d:Camera3D
var bodies:MultiMeshInstance3D
var backs:MultiMeshInstance3D
var back_trim:MultiMeshInstance3D
var face_groups:Dictionary={}
var pick_root:Node3D
var state_data:Dictionary={}
var transforms:Dictionary={}
var shown_faces:Dictionary={}
var selected_index:=-1
var viewer_actor:=0
var ai_enabled:=true
var _motion:Tween
var _built:=false
var _materials:Dictionary={}
var draw_marker:MeshInstance3D
var table_title:Label3D
var hand_fill:DirectionalLight3D
var _pawns:Array[FurPartyPawn]=[]
var _wall_slots:Dictionary={}
var _busy:=false
var _callout:Label3D
var _kettle:Node3D
var _last_revision:=-1
var selected_indices:Array=[]
var night_relics:FurMahjongNightRelics
var night_fixtures:FurMahjongNightFixtures
var night_feedback:FurMahjongNightFeedback
var night_stagecraft:FurMahjongNightStagecraft
var _stamp_groups:Dictionary={}
var _stamp_pulse_ids:Array=[]
var _stamp_pulse_value:float=0.0
var _stamp_pulse_motion:Tween
var table_rigs:Array[FurMahjongTableContactRig]=[]
var _night_light_ready:bool=false
var _score_highlight:MultiMeshInstance3D
var _highlighted_tiles:Array=[]
var _reshape_highlight:MultiMeshInstance3D
var _reshape_give_ids:Array=[]
var presentation_speed:float=1.0
var _hover_slot:int=-1
var _delivery_markers:Array[Node3D]=[]
var _score_pose:Tween
var _idle_phase:float=0.0
var _tea_objects:Node3D
var night_tea_service:FurMahjongNightTeaService
var mute_presentation:bool=false
var _score_echo:Tween
var _echo_rest:Dictionary={}
var night_encore_stage:FurMahjongNightEncoreStage

func _sound(kind:String)->void:
	if not mute_presentation:table_sound.emit(kind)

func _process(delta:float)->void:
	_idle_phase+=delta
	if _busy or table_rigs.size()!=2 or (is_instance_valid(_score_pose) and _score_pose.is_running()):return
	for actor in 2:table_rigs[actor].attend(_idle_phase+float(actor)*1.7,actor==int(state_data.get("actor",0)))

func _ready()->void:
	stretch=true;mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func():_set_hover_slot(-1))
	viewport_3d=SubViewport.new();viewport_3d.size=Vector2i(1380,600);viewport_3d.own_world_3d=true;viewport_3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport_3d.msaa_3d=Viewport.MSAA_4X;add_child(viewport_3d)
	stage=Node3D.new();viewport_3d.add_child(stage)
	var world:=WorldEnvironment.new();var environment:=Environment.new();Lighting.apply(environment,1);FurAtelierLighting.studio(environment);environment.sky.sky_material.energy_multiplier=.36;environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("b2d3d9");environment.tonemap_exposure=1.0;world.environment=environment;stage.add_child(world)
	var light:=DirectionalLight3D.new();Lighting.key(light);light.rotation_degrees=Vector3(-43,-38,0);light.light_energy=1.55;light.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;light.directional_shadow_max_distance=45.0;stage.add_child(light)
	hand_fill=DirectionalLight3D.new();hand_fill.rotation_degrees=Vector3(-45,0,0);hand_fill.light_color=Color("eff8f2");hand_fill.light_energy=.22;hand_fill.shadow_enabled=false;stage.add_child(hand_fill)
	camera_3d=Camera3D.new();camera_3d.projection=Camera3D.PROJECTION_PERSPECTIVE;camera_3d.fov=40;camera_3d.position=Vector3(1.8,13.8,22.8);stage.add_child(camera_3d);camera_3d.look_at(Vector3(0,.45,1.0));camera_3d.current=true
	_table()
	if state_data.has("night"):
		night_relics=FurMahjongNightRelics.new();stage.add_child(night_relics)
		night_feedback=FurMahjongNightFeedback.new();stage.add_child(night_feedback)
	stage.add_child(FurTravelArtAssets.instance("mahjong_veranda_sculpted_v3",true))
	FurTeaRoomVista.build(stage)
	bodies=_multimesh(Geometry.body(),Surfaces.surface("ceramic",Color("faf4e4")));backs=_multimesh(Geometry.body(),Surfaces.surface("ceramic",Color("25645a")));back_trim=_multimesh(Geometry.back(),Geometry.material());pick_root=Node3D.new();stage.add_child(pick_root)
	# The ceramic body casts tile shadows; sub-millimetre back inlay does not.
	back_trim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw_marker=MeshInstance3D.new();draw_marker.mesh=Toy.rounded_box();draw_marker.material_override=_surface_material(Color("d3a24d"),.55);draw_marker.scale=Vector3(.53,.035,.27);stage.add_child(draw_marker)
	_callout=Label3D.new();_callout.font=FurChapterUITheme.font(true);_callout.font_size=96;_callout.pixel_size=.014;_callout.modulate=Color("f9d897");_callout.outline_size=8;_callout.outline_modulate=Color("25443e");_callout.billboard=BaseMaterial3D.BILLBOARD_ENABLED;_callout.position=Vector3(0,3.5,0);stage.add_child(_callout)
	var tea_scene:PackedScene=load("res://assets/mahjong_teahouse/tea_tableware.glb")
	if tea_scene!=null:
		var objects:Node3D=tea_scene.instantiate();stage.add_child(objects);_kettle=objects.get_node_or_null("Teapot");_tea_objects=objects
	_built=true
	if not state_data.is_empty():_sync_tiles(true)

func configure(data:Dictionary,use_ai:bool,selected:int=-1)->void:
	var changed:bool=int(data.get("revision",-1))!=_last_revision
	_hover_slot=-1
	state_data=data.duplicate(true);ai_enabled=use_ai;selected_index=selected;_last_revision=int(data.get("revision",-1))
	if _built and changed:_sync_tiles(true)

func is_animating()->bool:return _busy or (is_instance_valid(night_encore_stage) and night_encore_stage.is_animating())


func select_tile(index:int)->void:
	if _busy:return
	_hover_slot=-1
	selected_index=index
	if _built:_sync_tiles(false)

func select_opening_tiles(indices:Array)->void:
	if _busy:return
	selected_indices=indices.duplicate()
	if _built:_sync_tiles(false)

func diagnostics()->Dictionary:
	return {"physical_tile_count":transforms.size(),"visible_face_types":face_groups.size(),"viewer_actor":viewer_actor,"ray_pick_areas":pick_root.get_child_count() if is_instance_valid(pick_root) else 0,"viewport_size":viewport_3d.size if is_instance_valid(viewport_3d) else Vector2i.ZERO}

func _table()->void:
	stage.add_child(FurHarborCraftedAssets.prop("mahjong_table_crafted"))
	table_title=Label3D.new();table_title.font=FurChapterUITheme.font(true);table_title.outline_size=0;table_title.text="";table_title.font_size=36;table_title.pixel_size=.008;table_title.modulate=Color("85a798");table_title.rotation_degrees.x=-90;table_title.position=Vector3(0,.13,0);stage.add_child(table_title)
	for actor in 2:
		var pawn:=FurPartyPawn.new();pawn.build(actor);FurApprovedCharacter.use_table_undercoat(pawn._character,actor);pawn.set_seated();pawn.scale=Vector3.ONE*2.35;pawn.position=Vector3(-10.6,-.88,4.7) if actor==0 else Vector3(10.6,-.88,-4.7);pawn.rotation.y=2.02 if actor==0 else -1.12159;stage.add_child(pawn);_pawns.append(pawn)
		var chair:=FurTravelArtAssets.instance("mahjong_chair_sculpted_v2",true);chair.scale=Vector3.ONE*2.0;chair.position=Vector3(pawn.position.x,.40,pawn.position.z);chair.rotation.y=pawn.rotation.y+PI;stage.add_child(chair)

func _part(position3:Vector3,dimensions:Vector3,color:Color,kind:String="wood")->void:
	var mesh:=MeshInstance3D.new();mesh.mesh=Toy.rounded_box();mesh.material_override=Surfaces.surface(kind,color);mesh.position=position3;mesh.scale=dimensions*.5;stage.add_child(mesh)

func _surface_material(color:Color,roughness:float)->StandardMaterial3D:
	var key:String=color.to_html()+str(roughness)
	if not _materials.has(key):
		var material:=StandardMaterial3D.new();material.albedo_color=color.srgb_to_linear();material.roughness=roughness;_materials[key]=material
	return _materials[key]

func _multimesh(mesh:Mesh,material:Material)->MultiMeshInstance3D:
	var instance:=MultiMeshInstance3D.new();instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D;instance.multimesh.mesh=mesh;instance.material_override=material;stage.add_child(instance);return instance

func _place(id:int,position3:Vector3,basis:Basis,show_face:bool)->void:
	transforms[id]=Transform3D(basis,position3)
	if show_face:shown_faces[id]=true

func _sync_tiles(animate:bool)->void:
	reset_score_echo()
	reset_score_stamp()
	if is_instance_valid(_motion):_motion.kill()
	reset_score_pose()
	var previous:Dictionary=transforms.duplicate();transforms.clear();shown_faces.clear()
	if state_data.has("night") and not is_instance_valid(night_relics):night_relics=FurMahjongNightRelics.new();stage.add_child(night_relics)
	if state_data.has("night") and is_instance_valid(night_relics):night_relics.configure(state_data.night)
	if state_data.has("night") and not is_instance_valid(night_fixtures):night_fixtures=FurMahjongNightFixtures.new();stage.add_child(night_fixtures)
	if state_data.has("night") and is_instance_valid(night_fixtures):night_fixtures.configure(state_data.night)
	if state_data.has("night") and not is_instance_valid(night_feedback):night_feedback=FurMahjongNightFeedback.new();stage.add_child(night_feedback)
	if is_instance_valid(night_feedback):night_feedback.camera=camera_3d
	if state_data.has("night") and not is_instance_valid(night_stagecraft):night_stagecraft=FurMahjongNightStagecraft.new();stage.add_child(night_stagecraft)
	if is_instance_valid(night_stagecraft):
		night_stagecraft.configure(state_data.night,0 if ai_enabled else int(state_data.actor))
		night_stagecraft.visible=not state_data.night.has("welcome")
		night_stagecraft.process_mode=Node.PROCESS_MODE_INHERIT if night_stagecraft.visible else Node.PROCESS_MODE_DISABLED
	if state_data.has("night") and not is_instance_valid(night_encore_stage):
		night_encore_stage=FurMahjongNightEncoreStage.new();stage.add_child(night_encore_stage);night_encore_stage.seal_landed.connect(func():_sound("encore_accept"))
	if is_instance_valid(night_encore_stage):night_encore_stage.configure(state_data,0 if ai_enabled else int(state_data.actor),presentation_speed,not ai_enabled)
	if state_data.has("night") and not is_instance_valid(night_tea_service) and is_instance_valid(_tea_objects):
		night_tea_service=FurMahjongNightTeaService.new();stage.add_child(night_tea_service);night_tea_service.install(_tea_objects);night_tea_service.sound.connect(_sound)
	var fill_tea_at_landing:bool=is_instance_valid(night_tea_service) and animate and not previous.is_empty() and state_data.tea.charge>night_tea_service._last
	if is_instance_valid(night_tea_service) and not fill_tea_at_landing:night_tea_service.configure(state_data.tea.charge,presentation_speed,previous.is_empty())
	if state_data.has("night") and not _night_light_ready:_night_lighting()
	if state_data.has("night") and table_rigs.is_empty():
		for actor in _pawns.size():
			var rig:=FurMahjongTableContactRig.new();stage.add_child(rig)
			if rig.install(_pawns[actor]._character,actor):table_rigs.append(rig)
	if state_data.get("table_event",{}).get("kind","")=="deal":_wall_slots.clear()

	var requested_viewer:int=0 if ai_enabled else int(state_data.get("actor",0))
	var defer_turn:bool=state_data.has("night") and not ai_enabled and animate and not previous.is_empty() and requested_viewer!=viewer_actor and state_data.get("table_event",{}).get("kind","") in ["discard","added_kong"]
	if not defer_turn:viewer_actor=requested_viewer
	table_title.rotation.y=PI if viewer_actor==1 else 0.0
	hand_fill.rotation_degrees.y=180 if viewer_actor==1 else 0
	var wall:Array=state_data.get("wall",[])
	for i in wall.size():
		var id:int=wall[i]
		if not _wall_slots.has(id):_wall_slots[id]=136-wall.size()+i
		var physical_slot:int=_wall_slots[id]
		var side:int=physical_slot/34;var slot:int=(physical_slot%34)/2;var layer:int=physical_slot%2
		var along:float=(slot-8)*.93;var point:Vector3
		if side==0:point=Vector3(along,.36+layer*.37,4.30)
		elif side==1:point=Vector3(8.05,.36+layer*.37,-along*.56)
		elif side==2:point=Vector3(-along,.36+layer*.37,-4.30)
		else:point=Vector3(-8.05,.36+layer*.37,along*.56)
		_place(int(wall[i]),point,Basis(Vector3.RIGHT,PI/2).rotated(Vector3.UP,side*PI/2),false)
	var tea_tray:Array=state_data.get("tea",{}).get("tray",[])
	var river_visible:int=state_data.get("night",{}).get("revealed",tea_tray.size())
	for i in tea_tray.size():
		var face:bool=i<river_visible or state_data.get("phase","")=="finished"
		var basis:Basis=Basis(Vector3.RIGHT,-.30 if face else PI/2).rotated(Vector3.UP,PI if viewer_actor==1 else 0)
		_place(int(tea_tray[i]),Vector3((i-(tea_tray.size()-1)*.5)*1.12,.70,-.12),basis,face)
	var hands:Array=state_data.get("hands",[[],[]])
	var discards:Array=state_data.get("discards",[[],[]])
	var melds:Array=state_data.get("melds",[[],[]])
	for actor in 2:
		var visible:bool=actor==viewer_actor or state_data.get("phase","")=="finished"
		var sign_value:float=1.0 if actor==0 else -1.0
		for index in hands[actor].size():
			var point:=Vector3((index-(hands[actor].size()-1)*.5)*.98,.84,sign_value*6.05)
			if actor==1:point.x=-point.x
			if actor==int(state_data.get("actor",0)) and (index==selected_index or index in selected_indices):point.y+=.23;point.z+=sign_value*.18
			var lesson:Dictionary=state_data.get("night",{}).get("welcome",{})
			if actor==0 and lesson.get("kind","")=="tutorial" and lesson.get("number",0)==1 and int(hands[actor][index]) in [0,4,8]:point.y+=.25
			var hand_basis:=Basis(Vector3.UP,PI if actor==1 else 0).scaled(Vector3.ONE*1.10)
			if state_data.get("phase","")=="finished":hand_basis=Basis(Vector3.RIGHT,-PI/2).rotated(Vector3.UP,PI if actor==1 else 0).scaled(Vector3.ONE*1.10);point.y=.48
			_place(int(hands[actor][index]),point,hand_basis,visible)
		for index in discards[actor].size():
			var point:=Vector3((index%9-4)*.64,.34,sign_value*(.95+float(index/9)*.87))
			_place(int(discards[actor][index]),point,Basis(Vector3.RIGHT,-PI/2).rotated(Vector3.UP,PI if actor==1 else 0).scaled(Vector3.ONE*.68),true)
		var meld_index:=0
		for meld in melds[actor]:
			var tiles:Array=meld.get("tiles",[])
			for index in tiles.size():
				var point:=Vector3(-6.5+float(index%3)*.69,.37+(.26 if index==3 else 0),sign_value*(2.0+float(meld_index)*1.02))
				var concealed:bool=meld.get("concealed",false) and actor!=viewer_actor and index in [0,2]
				var tile_basis:=Basis(Vector3.RIGHT,PI/2 if concealed else -PI/2).rotated(Vector3.UP,PI if actor==1 else 0).scaled(Vector3.ONE*.72)
				_place(int(tiles[index]),point,tile_basis,not concealed)
			meld_index+=1
	_update_meshes()
	var drawn:int=state_data.get("drawn_tile",-1)
	draw_marker.visible=drawn in hands[viewer_actor] and viewer_actor==int(state_data.get("actor",0))
	if draw_marker.visible:draw_marker.position=transforms[drawn].origin+Vector3(0,-.69,.01)
	for child in pick_root.get_children():pick_root.remove_child(child);child.queue_free()
	var active:int=int(state_data.get("actor",0))
	var opening:bool=state_data.get("phase","")=="night_offer" and state_data.get("night",{}).get("stage",-1)==0
	if (str(state_data.get("phase",""))=="discard" or opening) and not (ai_enabled and active==1):
		for index in hands[active].size():
			var area:=Area3D.new();area.transform=transforms[int(hands[active][index])];area.set_meta("hand_index",index);area.collision_layer=1;area.collision_mask=0
			var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.85,1.24,.39);collision.shape=shape;area.add_child(collision);pick_root.add_child(area)
	if str(state_data.get("phase",""))=="discard" and not (ai_enabled and active==1):
		if state_data.has("night"):
			for index in melds[active].size():
				var meld:Dictionary=melds[active][index]
				if meld.tiles.size()!=3 or meld.get("concealed",false):continue
				for id:int in meld.tiles:
					var area:=Area3D.new();area.transform=transforms[id];area.set_meta("meld_index",index);area.collision_layer=1;area.collision_mask=0
					var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.85,1.24,.39);collision.shape=shape;area.add_child(collision);pick_root.add_child(area)
		for slot in tea_tray.size():
			if slot>=river_visible:continue
			var area:=Area3D.new();area.transform=transforms[int(tea_tray[slot])];area.set_meta("tray_slot",slot);area.collision_layer=1;area.collision_mask=0
			var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.85,1.24,.39);collision.shape=shape;area.add_child(collision);pick_root.add_child(area)
	var sign_view:float=1.0 if viewer_actor==0 else -1.0
	var desired:=Vector3(1.8*sign_view,13.8,22.8*sign_view)
	var look_point:=Vector3(0,.45,sign_view)
	var welcome_camera:Dictionary=state_data.get("night",{}).get("welcome",{})
	if welcome_camera.get("kind","")=="tutorial" and welcome_camera.get("number",0)<3:
		desired=Vector3(-1.4,10.8,19.4);look_point=Vector3(-1.4,.6,3.0)
	if state_data.has("night") and viewer_actor==1:desired=Vector3(-1.8,14.8,-20.0)
	var camera_start:Vector3=camera_3d.position
	var relic_start:float=night_relics.rotation.y if is_instance_valid(night_relics) else 0.0
	var relic_target:float=PI if viewer_actor==1 else 0.0
	var event:Dictionary=state_data.get("table_event",{})
	var kind:String=event.get("kind","")
	if not animate:
		if is_instance_valid(night_relics):night_relics.rotation.y=relic_target
		camera_3d.position=desired;camera_3d.look_at(look_point);_update_meshes();return
	var target:Dictionary=transforms.duplicate();var starts:Dictionary={};var changed_ids:Array=[]
	var flight_ids:Array=event.get("tiles",[]).duplicate()
	var drawn_id:int=state_data.get("drawn_tile",-1)
	# Only a genuine drawing event animates the drawn marker's tile. Keeping the
	# marker from a past draw must not make an unrelated hand tile hop on self-meld.
	if drawn_id>=0 and drawn_id not in flight_ids and kind in ["pass","kong","closed_kong","skill","deal","reveal"]:flight_ids.append(drawn_id)
	var second_group:Array=event.get("tiles",[]).duplicate() if event.get("reshape_chain",false) or event.get("continuation",false) else []
	for id in target:
		starts[id]=previous.get(id,target[id])
		if previous.is_empty() and id not in wall:
			starts[id]=Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(6,.70,-3))
		if starts[id].origin.distance_to(target[id].origin)>.05:changed_ids.append(id)
	var duration:float=1.65 if previous.is_empty() else (.92 if kind in ["chi","pon","kong","closed_kong","exchange","win"] else .65)
	var winning_ids:Array=flight_ids.duplicate() if kind=="win" and state_data.has("night") else []
	var reshape_give:Array=event.get("give",[]) if kind=="reshape" else []
	var reshape_take:Array=event.get("take",[]) if kind=="reshape" else []
	if kind=="reshape":duration=1.30
	winning_ids.sort()
	if not winning_ids.is_empty():duration=1.10
	var contact_id:int=-1
	if not table_rigs.is_empty() and not previous.is_empty():
		if kind in ["discard","exchange","trick_recall","trick_relay","chi","pon","self_chi","self_pon"] and not flight_ids.is_empty():contact_id=flight_ids[0]
		elif drawn_id>=0 and kind in ["pass","closed_kong","kong"]:contact_id=drawn_id
	if contact_id>=0:duration=1.15
	if not second_group.is_empty():duration=1.48
	if kind in ["recipe","offer"]:duration=.20
	if camera_start.distance_to(desired)>4.0:duration=maxf(duration,.80)
	var release_position:=Vector3.ZERO
	if contact_id>=0 and table_rigs.size()==2:
		var contact_actor:int=event.get("actor",0);var contact_sign:float=1 if contact_actor==0 else -1
		table_rigs[contact_actor].seat()
		release_position=table_rigs[contact_actor].reach(Vector3(-8.70*contact_sign,1.35,5.27*contact_sign),1.0)+Vector3(.12*contact_sign,.13,0)
		table_rigs[contact_actor].seat()
	_busy=true
	if contact_id>=0:_sound("tile_pick")
	elif kind=="reveal":_sound("reveal")
	elif kind=="deal":_sound("reveal")
	elif kind=="reshape":_sound("reshape_open")
	elif not winning_ids.is_empty():_sound("charge")
	_callout.text={"trick_recall":"回 手 · 改写这一手","trick_relay":"递 彩 · 接力留牌","trick_boost":"催 演 · 下一组 ×1.8","chi":"吃 · 茶气上升","pon":"碰 · 茶气上升","self_chi":"亮 顺","self_pon":"亮 刻","kong":"杠！补牌","closed_kong":"暗杠！补牌","exchange":"茶盘换牌","win":"胡  牌","deal":"开 席"}.get(kind,"")
	if kind=="trick_boost":_callout.text="催 演 · ×%.1f"%float(event.get("factor",1.8))
	_callout.font_size=72 if kind=="encore" else 96
	if kind=="encore":_callout.text="加 演 开 场 · 共追新目标"
	if kind=="reshape":_callout.text="借 形 改 组 · 旧牌新生";_callout.font_size=68
	if event.get("reshape_chain",false):_callout.text="借 形 连 响 · 再亮一组";_callout.font_size=74
	if event.get("continuation",false):_callout.text="续 奏 · 第 二 响";_callout.font_size=78
	_callout.modulate.a=1.0
	_motion=create_tween()
	_motion.set_speed_scale(presentation_speed)
	var landed:Array=[false]
	var fan_sounds:Array=[0]
	_motion.tween_method(func(t:float):
		# Physical winning tiles turn over in a readable wave. Five capped porcelain
		# landings follow real tween time, so fast/skip cannot enqueue an audio pile.
		if not winning_ids.is_empty() and fan_sounds[0]<5 and t>=.65+float(fan_sounds[0])*.054:
			fan_sounds[0]+=1;_sound("tile_land")
		if not landed[0] and t>=.91:
			landed[0]=true
			if kind in ["self_chi","self_pon","chi","pon","kong","closed_kong"]:_sound("group_land")
			elif kind in ["discard","exchange","trick_recall","trick_relay"]:_sound("tile_land")
			elif kind=="reshape":_sound("reshape_land")
			if event.get("reshape_chain",false) or event.get("continuation",false):_sound("chain_land")
			if fill_tea_at_landing:night_tea_service.configure(state_data.tea.charge,presentation_speed)
		var eased:float=smoothstep(0.0,1.0,t)
		var actor:int=event.get("actor",0)
		var actual_contact:Vector3=Vector3.ZERO
		if table_rigs.size()==2:
			for rig:FurMahjongTableContactRig in table_rigs:rig.seat()
			if kind=="win":
				table_rigs[actor].celebrate(sin(t*PI)*.7)
				table_rigs[1-actor].celebrate(sin(clampf((t-.18)/.82,0,1)*PI)*.35)
			elif kind=="reshape":
				table_rigs[actor].weave(t)
			elif contact_id>=0:
				var sign_value:float=1 if actor==0 else -1
				var station:=Vector3(-8.95*sign_value,1.25,5.45*sign_value)
				var reach_weight:float=smoothstep(0.0,.30,t)*(1.0-smoothstep(.67,1.0,t))
				var hand_slide:float=smoothstep(.36,.62,t)
				if not second_group.is_empty():
					reach_weight=smoothstep(0.0,.22,t)*(1.0-smoothstep(.38,.70,t));hand_slide=smoothstep(.18,.38,t)
				station+=Vector3(.25*sign_value,.10,-.18*sign_value)*hand_slide
				actual_contact=table_rigs[actor].reach(station,reach_weight)
		for id in target:
			var u:float=eased
			if previous.is_empty() and id in changed_ids:u=smoothstep(0.0,1.0,clampf((t-float(changed_ids.find(id))*.009)/.68,0,1))
			if id in winning_ids:u=smoothstep(0.0,1.0,clampf((t-.10-float(winning_ids.find(id))*.018)/.55,0,1))
			var pose:Transform3D=starts[id].interpolate_with(target[id],u)
			if id in reshape_take or id in reshape_give:
				# Real physical IDs cross in separate lanes. Lift / exchange / seat:
				# no duplicated proxy tiles and no client-side rule mutation.
				var take:bool=id in reshape_take
				var travel:float=smoothstep(.20 if take else .30,.82 if take else .90,t)
				pose=starts[id].interpolate_with(target[id],travel)
				var rise:float=smoothstep(0,.20,t)*(1.0-smoothstep(.80,1.0,t))
				pose.origin.y+=rise*(1.12 if take else .68)
				pose.origin.x+=sin(travel*PI)*(.62 if take else -.38)
				if t>.90:pose.origin.y+=sin((t-.90)*10*PI)*.035
			if id in winning_ids:pose.origin.y+=sin(u*PI)*.38
			if id in changed_ids and (previous.is_empty() or id in flight_ids):pose.origin.y+=sin(u*PI)*(1.65 if kind in ["discard","exchange"] else .75)
			if id==contact_id and table_rigs.size()==2:
				var sign_value:float=1 if actor==0 else -1
				var contact_offset:=Vector3(.12*sign_value,.13,0)
				if t<.30:pose.origin=starts[id].origin.lerp(actual_contact+contact_offset,smoothstep(0.0,.30,t))
				elif t<=.62:pose.origin=actual_contact+contact_offset
				else:
					var flight:float=smoothstep(.62,.91,t)
					pose.origin=release_position.lerp(target[id].origin,flight);pose.origin.y+=sin(flight*PI)*.16
					if t>.91:pose.origin.y+=sin(clampf((t-.91)/.09,0,1)*PI)*.035
			if id in second_group and (id!=contact_id or t>.38):
				pose=NightTileMotion.second_chime(starts[id],target[id],release_position,second_group.find(id),actor,t,id==contact_id,viewer_actor)
			transforms[id]=pose
		if camera_start.distance_to(desired)>.1:
			var azimuth:float=lerp_angle(atan2(camera_start.x,camera_start.z),atan2(desired.x,desired.z),eased)
			var radius:float=lerpf(Vector2(camera_start.x,camera_start.z).length(),Vector2(desired.x,desired.z).length(),eased)
			camera_3d.position=Vector3(sin(azimuth)*radius,lerpf(camera_start.y,desired.y,eased),cos(azimuth)*radius);camera_3d.look_at(look_point)
		if is_instance_valid(night_relics):night_relics.rotation.y=lerp_angle(relic_start,relic_target,eased)
		for i in _pawns.size():
			var gesture:float=sin(t*PI)*(.75 if kind in ["chi","pon","kong","win"] else .45) if i==actor else 0.0
			if not _pawns[i]._character.get_meta("night_skeletal_rig",false):
				for material:ShaderMaterial in _pawns[i]._character.get_meta("approved_coat_materials",[]):material.set_shader_parameter("table_gesture",gesture)
		_callout.position.y=(4.9 if not second_group.is_empty() else 3.2)+eased*.8;_callout.modulate.a=1.0-smoothstep(.55,1.0,t)
		if is_instance_valid(_kettle) and not state_data.has("night"):_kettle.rotation.z=sin(t*PI)*.12
		_update_meshes(),0.0,1.0,duration)
	_motion.tween_callback(func():
		if is_instance_valid(night_relics):night_relics.rotation.y=relic_target
		transforms=target;camera_3d.position=desired;camera_3d.look_at(look_point);_busy=false;_callout.text="";_update_meshes()
		if defer_turn:
			state_data.table_event={"kind":"camera_turn","actor":requested_viewer,"tiles":[]};_sync_tiles(true))

func _update_meshes()->void:
	_update_score_highlights()
	var ids:Array=transforms.keys();bodies.multimesh.instance_count=ids.size()
	var visible_back_transforms:Array[Transform3D]=[]
	var all_back_transforms:Array[Transform3D]=[]
	var groups:Dictionary={}
	for i in ids.size():
		var id:int=ids[i];var transform:Transform3D=transforms[id]
		bodies.multimesh.set_instance_transform(i,transform*Transform3D(Basis().scaled(Vector3(.42,.60,.18)),Vector3.ZERO))
		all_back_transforms.append(transform*Transform3D(Basis().scaled(Vector3(.40,.57,.09)),Vector3(0,0,-.13)))
		# The relief on a back facing away from the current camera cannot contribute.
		var to_camera:Vector3=(camera_3d.position-transform.origin).normalized()
		if (-transform.basis.z.normalized()).dot(to_camera)>.025:
			visible_back_transforms.append(transform*Transform3D(Basis().scaled(Vector3(.40,.57,.09)),Vector3(0,0,-.13)))
		if shown_faces.has(id):
			var type:int=id/4
			if not groups.has(type):groups[type]=[]
			groups[type].append(transform)
	back_trim.multimesh.instance_count=visible_back_transforms.size()
	for index in visible_back_transforms.size():
		back_trim.multimesh.set_instance_transform(index,visible_back_transforms[index])
	var back_bodies:Array=visible_back_transforms if state_data.has("night") else all_back_transforms
	backs.multimesh.instance_count=back_bodies.size()
	for index in back_bodies.size():backs.multimesh.set_instance_transform(index,back_bodies[index])
	for type in face_groups:
		if not groups.has(type):face_groups[type].multimesh.instance_count=0
	for type in groups:
		if not face_groups.has(type):face_groups[type]=_multimesh(Geometry.face(type),Geometry.material());face_groups[type].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var instances:MultiMeshInstance3D=face_groups[type];instances.multimesh.instance_count=groups[type].size()
		for i in groups[type].size():instances.multimesh.set_instance_transform(i,groups[type][i])
	_update_stamps()
	_update_deliveries()

func reset_score_pose()->void:
	if is_instance_valid(_score_pose):
		_score_pose.kill()
		for rig:FurMahjongTableContactRig in table_rigs:rig.seat()

func echo_score_tiles(ids:Array,strength:float=1.0)->void:
	# Move the existing physical IDs, then return exactly to their resting poses.
	# No duplicate cards, collider movement or scoring mutation is involved.
	reset_score_echo()
	if _busy:return
	strength=clampf(strength,1.0,1.8)
	if is_instance_valid(night_feedback) and night_feedback.reduced_motion:strength=1.0
	for id:int in ids:
		if transforms.has(id) and shown_faces.has(id):_echo_rest[id]=transforms[id]
	if _echo_rest.is_empty():return
	var order:Array=_echo_rest.keys()
	_score_echo=create_tween();_score_echo.set_speed_scale(presentation_speed)
	_score_echo.tween_method(func(t:float):
		for i in order.size():
			var id:int=order[i];var rest:Transform3D=_echo_rest[id]
			var phase:float=clampf((t-float(i)*.035)/.82,0,1)
			var lift:float=sin(phase*PI)
			var pose:Transform3D=rest;pose.origin.y+=lift*.24*strength
			pose.basis=rest.basis.rotated(Vector3.RIGHT,sin(phase*TAU)*.045)
			transforms[id]=pose
		_update_meshes(),0.0,1.0,.29*sqrt(strength))
	_score_echo.tween_callback(reset_score_echo)

func flourish_score_tiles(ids:Array)->void:
	# Wind payoff: a travelling lift of the SAME three physical tiles. No extra
	# models, particles or scoring calls. Skip/reset restores every exact pose.
	reset_score_echo()
	if _busy:return
	if is_instance_valid(night_feedback) and night_feedback.reduced_motion:
		highlight_score_tiles(ids);return
	for id:int in ids:
		if transforms.has(id) and shown_faces.has(id):_echo_rest[id]=transforms[id]
	if _echo_rest.is_empty():return
	var order:Array=_echo_rest.keys();order.sort()
	_score_echo=create_tween();_score_echo.set_speed_scale(presentation_speed)
	_score_echo.tween_method(func(t:float):
		for i in order.size():
			var id:int=order[i];var rest:Transform3D=_echo_rest[id]
			transforms[id]=NightTileMotion.wind_flourish(rest,i,order.size(),t,viewer_actor)
		_update_meshes(),0.0,1.0,.90)
	_score_echo.tween_callback(reset_score_echo)

func reset_score_echo()->void:
	if is_instance_valid(_score_echo):_score_echo.kill()
	if _echo_rest.is_empty():return
	for id:int in _echo_rest:
		if transforms.has(id):transforms[id]=_echo_rest[id]
	_echo_rest.clear()
	if _built:_update_meshes()

func celebrate_score(actor:int,strength:float=1.0)->void:
	if _busy or table_rigs.size()!=2:return
	reset_score_pose();_score_pose=create_tween();_score_pose.set_speed_scale(presentation_speed)
	_score_pose.tween_method(func(t:float):
		var hero:float=sin(clampf(t/.70,0,1)*PI)*.88+sin(clampf((t-.60)/.40,0,1)*PI)*.20
		table_rigs[actor].celebrate(hero*strength)
		table_rigs[1-actor].celebrate(sin(clampf((t-.14)/.86,0,1)*PI)*.42*strength),0.0,1.0,.92 if strength>=.99 else .42)
	_score_pose.tween_callback(func():
		for rig:FurMahjongTableContactRig in table_rigs:rig.seat())

func _update_deliveries()->void:
	if not state_data.has("night"):return
	if _delivery_markers.is_empty():
		for actor in 2:
			var anchor:=Node3D.new();stage.add_child(anchor);_delivery_markers.append(anchor)
			var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=.49;mesh.outer_radius=.55;mesh.rings=20;mesh.ring_segments=6;ring.mesh=mesh
			var material:=StandardMaterial3D.new();material.albedo_color=Color("edb07c") if actor==0 else Color("8ddac8");material.metallic=.45;material.roughness=.35;ring.material_override=material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;anchor.add_child(ring)
			var label:=Label3D.new();label.text="给"+["小柯","泡泡"][actor];label.position.y=1.46;label.font=FurChapterUITheme.font(true);label.font_size=42;label.pixel_size=.008;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=material.albedo_color;label.outline_size=6;label.outline_modulate=Color("153c38");anchor.add_child(label)
	for actor in 2:
		var id:int=state_data.night.get("deliveries",[-1,-1])[actor]
		var visible:bool=id>=0 and id in state_data.tea.tray and transforms.has(id) and state_data.phase!="finished"
		var donor:int=1-actor;var promise:int=state_data.night.get("promised_tiles",[-1,-1])[donor]
		var agreed:bool=promise>=0 and promise in state_data.hands[donor] and state_data.night.requests[actor]==int(promise/4) and state_data.phase!="finished"
		var anchor:Node3D=_delivery_markers[actor];var ring:MeshInstance3D=anchor.get_child(0);var sign:Label3D=anchor.get_child(1)
		anchor.visible=visible or agreed;ring.visible=visible
		if visible:
			anchor.position=transforms[id].origin+Vector3(0,-.50,0);sign.position.y=1.46;sign.text="给"+["小柯","泡泡"][actor];sign.font_size=42
		elif agreed:
			# This face was voluntarily promised in the shop and is already public.
			anchor.position=Vector3(-9.6,4.9,4.7) if donor==0 else Vector3(9.6,4.9,-4.7)
			sign.position.y=0;sign.text=ChapterMahjongTable.tile_name(promise)+" · 给你留着";sign.font_size=52

func _update_stamps()->void:
	if not state_data.has("night"):return
	for kind:String in ["red","gold"]:
		if not _stamp_groups.has(kind):
			var mesh:=CylinderMesh.new();mesh.top_radius=.095;mesh.bottom_radius=.10;mesh.height=.025;mesh.radial_segments=16
			var mat:=ShaderMaterial.new();mat.shader=load("res://assets/mahjong_night/show/stamp_wax.gdshader");mat.set_shader_parameter("wax_color",Color("ba5547") if kind=="red" else Color("d9b866"))
			_stamp_groups[kind]=_multimesh(mesh,mat);_stamp_groups[kind].multimesh.use_custom_data=true
		var selected:Array=[]
		for id:int in transforms:
			if state_data.night.build.stamps.get(str(id),"")==kind and shown_faces.has(id):selected.append(id)
		var group:MultiMeshInstance3D=_stamp_groups[kind];group.multimesh.instance_count=selected.size()
		for i in selected.size():
			var pulse:float=_stamp_pulse_value if selected[i] in _stamp_pulse_ids else 0.0
			group.multimesh.set_instance_transform(i,transforms[selected[i]]*Transform3D(Basis(Vector3.RIGHT,PI/2).scaled(Vector3.ONE*(1.0+pulse*.60)),Vector3(.275,-.43,.202+pulse*.06)))
			group.multimesh.set_instance_custom_data(i,Color(pulse,0,0,1))

func pulse_score_stamp(ids:Array)->void:
	reset_score_stamp();_stamp_pulse_ids=ids.duplicate()
	_stamp_pulse_motion=create_tween();_stamp_pulse_motion.set_speed_scale(presentation_speed)
	_stamp_pulse_motion.tween_method(func(t:float):_stamp_pulse_value=sin(t*PI);_update_stamps(),0.0,1.0,.30)
	_stamp_pulse_motion.tween_callback(reset_score_stamp)

func reset_score_stamp()->void:
	if is_instance_valid(_stamp_pulse_motion):_stamp_pulse_motion.kill()
	_stamp_pulse_ids.clear();_stamp_pulse_value=0.0
	if _built:_update_stamps()

func _set_hover_slot(slot:int)->void:
	if _hover_slot==slot:return
	_hover_slot=slot;tray_hovered.emit(slot)

func _pick_at(point:Vector2)->Dictionary:
	var screen:Vector2=point*Vector2(viewport_3d.size)/size
	var origin:Vector3=camera_3d.project_ray_origin(screen);var end:Vector3=origin+camera_3d.project_ray_normal(screen)*100
	var query:=PhysicsRayQueryParameters3D.create(origin,end,1);query.collide_with_areas=true;query.collide_with_bodies=false
	var world:World3D=stage.get_world_3d()
	return {} if world==null else world.direct_space_state.intersect_ray(query)

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseMotion:
		if not _built or _busy or not state_data.has("night") or state_data.get("phase","")!="discard" or selected_index<0:return
		var hover:Dictionary=_pick_at(event.position)
		_set_hover_slot(int(hover.collider.get_meta("tray_slot",-1)) if not hover.is_empty() else -1)
		return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return
	var opening:bool=state_data.get("phase","")=="night_offer" and state_data.get("night",{}).get("stage",-1)==0
	if not _built or _busy or (state_data.get("phase","")!="discard" and not opening):return
	var hit:Dictionary=_pick_at(event.position)
	if hit.is_empty():return
	if hit.collider.has_meta("meld_index"):
		meld_selected.emit(int(hit.collider.get_meta("meld_index")),int(state_data.actor),int(state_data.revision));accept_event();return
	if hit.collider.has_meta("tray_slot"):
		tray_selected.emit(int(hit.collider.get_meta("tray_slot")),int(state_data.actor),int(state_data.revision));accept_event();return
	var index:int=hit.collider.get_meta("hand_index",-1)
	if index>=0:tile_selected.emit(index,int(state_data.actor),int(state_data.revision));accept_event()

func _night_lighting()->void:
	_night_light_ready=true
	# Same authored full mesh plus offline-generated distant LODs; pick shapes unchanged.
	bodies.multimesh.mesh=load("res://assets/mahjong_night/batched/tile_body.res")
	backs.multimesh.mesh=bodies.multimesh.mesh
	back_trim.multimesh.mesh=load("res://assets/mahjong_night/batched/tile_back.res")
	for node in stage.get_children():
		if node is WorldEnvironment:
			var environment:Environment=node.environment
			environment.background_color=Color("132c46")
			environment.sky.sky_material.energy_multiplier=.20
			environment.ambient_light_energy=.64
		if node is DirectionalLight3D and node!=hand_fill:
			node.light_color=Color("ffe3bd");node.light_energy=1.15
	hand_fill.light_color=Color("d5e9ef");hand_fill.light_energy=.26
	# Far terrace shadows fall outside the playable tea table; foreground contacts stay.
	for terrace:Node3D in stage.find_children("chapter_terrace_1_*","Node3D",true,false):
		for mesh:MeshInstance3D in terrace.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.lod_bias=.08
	for mesh:MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh is PlaneMesh and mesh.mesh.size.x>200:
			var material:StandardMaterial3D=mesh.material_override.duplicate()
			var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color("112b46"),Color("304e64")])
			var wash:=GradientTexture2D.new();wash.gradient=gradient;wash.width=8;wash.height=128;wash.fill_from=Vector2(.5,0);wash.fill_to=Vector2(.5,1)
			material.albedo_texture=wash;mesh.material_override=material
	for side in [-1,1]:
		var lantern:Node3D=FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/fixtures/river_lantern.glb");lantern.position=Vector3(side*8.0,1.55,-10.4);lantern.scale=Vector3.ONE*1.3;stage.add_child(lantern)
		var glow:=OmniLight3D.new();glow.position=lantern.position+Vector3(0,1.1,0);glow.light_color=Color("ffc981");glow.light_energy=1.1;glow.omni_range=4.5;glow.shadow_enabled=false;stage.add_child(glow)
	FurMahjongNightScenography.apply(stage,hand_fill)

func highlight_score_tiles(ids:Array)->void:
	_highlighted_tiles=ids.duplicate()
	if not is_instance_valid(_score_highlight):
		var box:=BoxMesh.new();box.size=Vector3.ONE
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("f7d48a");material.emission_enabled=true;material.emission=Color("f7ce74");material.emission_energy_multiplier=.45
		_score_highlight=_multimesh(box,material);_score_highlight.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_score_highlights()

func _update_score_highlights()->void:
	if not is_instance_valid(_score_highlight):return
	var list:Array[Transform3D]=[]
	var guided:bool=state_data.get("night",{}).has("welcome")
	for id:int in _highlighted_tiles:
		if not transforms.has(id):continue
		for edge in [Vector4(-.447,0,.027,1.28),Vector4(.447,0,.027,1.28),Vector4(0,.635,.90,.027),Vector4(0,-.635,.90,.027)]:
			if guided:
				if edge.z<.1:edge.z=.05
				else:edge.w=.05
			list.append(transforms[id]*Transform3D(Basis().scaled(Vector3(edge.z,edge.w,.023)),Vector3(edge.x,edge.y,.196)))
	_score_highlight.multimesh.instance_count=list.size()
	for i in list.size():_score_highlight.multimesh.set_instance_transform(i,list[i])
	if is_instance_valid(_reshape_highlight):
		var inserted:Array[Transform3D]=[]
		for id:int in _reshape_give_ids:
			if not transforms.has(id):continue
			for edge in [Vector4(-.447,0,.027,1.28),Vector4(.447,0,.027,1.28),Vector4(0,.635,.90,.027),Vector4(0,-.635,.90,.027)]:
				inserted.append(transforms[id]*Transform3D(Basis().scaled(Vector3(edge.z,edge.w,.023)),Vector3(edge.x,edge.y,.196)))
		_reshape_highlight.multimesh.instance_count=inserted.size()
		for i in inserted.size():_reshape_highlight.multimesh.set_instance_transform(i,inserted[i])

func highlight_reshape(give:Array,take:Array)->void:
	_reshape_give_ids=give.duplicate()
	if not give.is_empty() and not is_instance_valid(_reshape_highlight):
		var box:=BoxMesh.new();box.size=Vector3.ONE
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("64e4d6");material.emission_enabled=true;material.emission=Color("64e4d6");material.emission_energy_multiplier=.45
		_reshape_highlight=_multimesh(box,material);_reshape_highlight.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight_score_tiles(take)
