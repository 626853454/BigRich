class_name FurAdventureSession
extends "res://scripts/party/party_session.gd"

const Adventure=preload("res://scripts/party/adventure_model.gd")
const AdventureMap=preload("res://scripts/party/adventure_map.gd")
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const PanelArt=preload("res://scripts/party/chapter_panel_art.gd")
const Card=preload("res://scripts/party/chapter_card.gd")
const Backdrop=preload("res://scripts/party/chapter_menu_backdrop.gd")
const Dressing=preload("res://scripts/party/chapter_world_dressing.gd")
const ChapterWorld=preload("res://scripts/party/chapter_board_world.gd")
const Echo=preload("res://scripts/party/chapter_echo.gd")
const PuzzleBoard=preload("res://scripts/party/chapter_puzzle_board.gd")
const RealMahjong=preload("res://scripts/party/chapter_mahjong_table.gd")
const TablePresenter=preload("res://scripts/party/mahjong_teahouse_presenter.gd")
const BoardHUD=preload("res://scripts/party/chapter_board_hud.gd")
const Feedback=preload("res://scripts/party/chapter_feedback.gd")
const TITLES:=["海岛远征","云顶雀馆","时光空港"]
const DESCRIPTIONS:=["选路经营、承接地区委托，挑战站才合作割草。\n用路线积累，让下一场构筑不同。","坐到真实立体麻将桌，摸打吃碰杠胡。\n门清、刻子、连序流派，挑战不同残局。","记录上一轮的行动，留下回声。\n让过去的自己帮现在送达能量。"]
var adventure:=Adventure.new()
var echo:=Echo.new()
var dressing:Node3D
var overlay:Control
var overlay_kind:=""
var overlay_options:Array[Button]=[]
var activity_kind:=""
var activity_actor:=0
var station_token:=0
var station_return:="board"
var activity_wait:=0.0
var visual_chapter:=-1
var markers:Node3D
var last_activity_result:Dictionary={}
var selected_practice:=-1
var overlay_generation:=0
var pending_entry_chapter:=-1
var resetting_journey:=false
var table_mahjong:=RealMahjong.new()
var table_presenter:FurMahjongTeahousePresenter
var echo_presenter:FurUIEchoPresenter
var board_hud:FurChapterBoardHUD
var feedback:FurChapterFeedback
var _hud_dirty:=false
var _hud_clock:=0.0
var premium_player_badges:Array[FurUIPlayerBadge]=[]
var premium_faces:Array[Texture2D]=[]
var journey_badge:FurUIJourneyBadge
var settings_button:Button
var atlas_button:Button
var combat_hud:FurUICombatHUD
var settings_arena:Node
var settings_arena_running:bool=false
var settings_return_menu:bool=false

func _setup_camera()->void:
	super._setup_camera()
	FurArtLighting.apply(environment.environment,0)
	for child in board_root.get_children():
		if child is DirectionalLight3D and child.shadow_enabled:FurArtLighting.key(child)
	camera.keep_aspect=Camera3D.KEEP_WIDTH

func _ready()->void:
	model=adventure;board_tiles=AdventureMap.nodes(0);board_districts=AdventureMap.districts(0)
	super._ready()
	dressing=Dressing.new();board_root.add_child(dressing);dressing.build(board_root,board_tiles,Map.edges())
	_set_chapter_visuals();_show_menu()

func start_party(use_ai:bool,seed_value:int)->void:
	_close_overlay();activity_kind="";last_activity_result.clear();selected_practice=-1
	resetting_journey=true
	super.start_party(use_ai,seed_value)
	if pending_entry_chapter>=0:
		adventure.start_chapter(seed_value,use_ai,pending_entry_chapter);selected_practice=pending_entry_chapter
	pending_entry_chapter=-1;resetting_journey=false
	table_mahjong.start(seed_value,use_ai)
	visual_chapter=-1;_set_chapter_visuals();_refresh()

func _begin_journey(chapter:int)->void:
	var use_ai:bool=mode_picker.selected==0
	var seed_value:int=randi_range(1,2147483647)
	pending_entry_chapter=chapter
	start_party(use_ai,seed_value)
	presentation="idle";last_result="普通格继续探索；挑战站才开启本章玩法。";_refresh()

func _style(_fill:Color,_border:Color,_radius:int)->StyleBoxFlat:
	return Palette.panel_style()

func _label(text:String,font_size:int)->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size);label.add_theme_font_override("font",FurChapterUITheme.font(font_size>=22));label.add_theme_color_override("font_color",Palette.INK);return label

func _button(text:String,callback:Callable)->Button:
	var button:=Button.new();button.theme=Palette.create();button.text=text;button.custom_minimum_size=Vector2(150,43);button.focus_mode=Control.FOCUS_ALL;button.add_theme_font_size_override("font_size",16)
	button.pressed.connect(_show_menu if text=="新的一局" else callback)
	Palette.apply_button(button,"ivory")
	return button

func _make_ui()->void:
	super._make_ui();hud.theme=Palette.create()
	for i in player_panels.size():
		var old_row:Control=player_labels[i].get_parent();old_row.hide()
		var textures:Array=old_row.find_children("*","TextureRect",true,false)
		premium_faces.append(textures[0].texture)
		player_panels[i].position=Vector2(24+i*278,24);player_panels[i].size=Vector2(260,102)
		player_panels[i].add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		var badge:=FurUIPlayerBadge.new();player_panels[i].add_child(badge);premium_player_badges.append(badge)
	var old_heading:Control=round_label.get_parent().get_parent();old_heading.hide()
	journey_badge=FurUIJourneyBadge.new();journey_badge.position=Vector2(596,24);journey_badge.size=Vector2(390,102);hud.add_child(journey_badge)
	for child in hud.get_children():
		if child is ColorRect:child.color=Color("e7dfd1")
		if child is Button and child.text=="新的一局":child.hide()
	phase_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	roll_button.offset_top=-166;roll_button.offset_bottom=-36;roll_button.offset_left=-187
	Palette.apply_button(roll_button,"primary");roll_button.text=""
	var die_icon:=FurUIIcons.view("dice",Vector2(63,63));die_icon.position=Vector2(48,3);roll_button.add_child(die_icon)
	var roll_title:=_label("掷骰",25);roll_title.position=Vector2(0,63);roll_title.size=Vector2(159,31);roll_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;roll_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;roll_title.add_theme_color_override("font_color",Color("fff6df"));roll_button.add_child(roll_title)
	var keycap:=_label("SPACE",13);keycap.position=Vector2(0,102);keycap.size=Vector2(159,20);keycap.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;keycap.mouse_filter=Control.MOUSE_FILTER_IGNORE;keycap.add_theme_color_override("font_color",Color("d6c9ad"));roll_button.add_child(keycap)
	mode_picker.hide();sound_button.hide()
	overview_button.text="群岛总览";overview_button.position=Vector2(1008,24);overview_button.size=Vector2(168,45)
	notebook_button.text="冒险手册";notebook_button.position=Vector2(1192,81);notebook_button.size=Vector2(177,45)
	loadout_button.text="搭配流派";loadout_button.position=Vector2(1008,81);loadout_button.size=Vector2(168,45)
	toast_backplate.position=Vector2(1385,81);toast_backplate.size=Vector2(190,45);toast.add_theme_font_size_override("font_size",15);toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var toast_style:=Palette.panel_style();toast_style.content_margin_top=9;toast_style.content_margin_bottom=8;toast_style.shadow_size=5;toast_backplate.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(toast_style,true))
	var chapters:=_button("冒险图册",_show_menu);atlas_button=chapters;chapters.position=Vector2(1192,24);chapters.size=Vector2(177,45);hud.add_child(chapters)
	settings_button=_button("设置",_show_settings);settings_button.position=Vector2(1385,24);settings_button.size=Vector2(190,45);hud.add_child(settings_button)
	for pair in [[overview_button,"compass"],[notebook_button,"book"],[loadout_button,"bag"],[chapters,"route"],[settings_button,"settings"]]:Palette.apply_button(pair[0],"quiet",pair[1])
	board_hud=BoardHUD.new();hud.add_child(board_hud)
	combat_hud=FurUICombatHUD.new();combat_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.add_child(combat_hud);combat_hud.hide()
	camera_rig.board_view_bias=Vector3(0,-2.1,2.5);camera_rig.follow_offset=Vector3(5,28,43);camera_rig.overview_offset=Vector3(0,38,45)
	feedback=Feedback.new();feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.add_child(feedback)
	phase_title.hide();phase_detail.hide();phase_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	option_row.add_theme_constant_override("separation",18);option_row.alignment=BoxContainer.ALIGNMENT_CENTER

func _close_overlay()->void:
	if is_instance_valid(instruction):instruction.show()
	if overlay_kind in ["mahjong_table","menu","activity"] and is_instance_valid(board_root):board_root.show()
	table_presenter=null;echo_presenter=null
	overlay_generation+=1
	if is_instance_valid(overlay):hud.remove_child(overlay);overlay.queue_free()
	overlay=null;overlay_kind="";overlay_options.clear()
	if is_instance_valid(camera_rig):camera_rig.enabled=arena==null

func _overlay_base(kind:String,title:String,subtitle:String,illustrated:bool=false)->VBoxContainer:
	_close_overlay();overlay_kind=kind
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;hud.add_child(overlay)
	if illustrated:overlay.add_child(Backdrop.create())
	else:
		var veil:=ColorRect.new();veil.color=Color(.045,.105,.13,.77);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(veil)
	var chapter:int=int(adventure.state.get("chapter",0))
	var panel:=PanelContainer.new();panel.position=Vector2(170,68);panel.size=Vector2(1260,764)
	var plate:=Palette.panel_style();plate.bg_color=Color("f6f0e3");plate.set_corner_radius_all(30);plate.content_margin_left=32;plate.content_margin_right=32;plate.content_margin_top=27;plate.content_margin_bottom=27;plate.shadow_size=24;plate.shadow_color=Color(.02,.06,.07,.25)
	panel.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate));overlay.add_child(panel)
	if kind in ["table_mode","style_station"]:panel.position=Vector2(170,120);panel.size=Vector2(1260,660)
	if kind=="activity":panel.position=Vector2(56,25);panel.size=Vector2(1488,850)
	if kind=="mahjong_table":panel.position=Vector2.ZERO;panel.size=Vector2(1600,900);panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",18);panel.add_child(column)
	if kind!="mahjong_table":
		var header:=HBoxContainer.new();header.add_theme_constant_override("separation",18);column.add_child(header)
		var icon:String={"upgrade":"forge","loadout":"bag","help":"book","settings":"settings","activity":"clock","activity_result":"star","combat_recap":"star","table_mode":"mahjong","style_station":"mahjong"}.get(kind,"compass")
		header.add_child(FurUIIcons.view(icon,Vector2(72,72)))
		var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",7);header.add_child(words)
		var heading:=_label(title,32);heading.add_theme_color_override("font_color",Palette.INK);words.add_child(heading)
		var sub:=_label(subtitle,17);sub.add_theme_color_override("font_color",Palette.MUTED);sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;sub.custom_minimum_size.y=42;words.add_child(sub)
		var line:=HSeparator.new();var rule:=StyleBoxLine.new();rule.color=Color("d7c7a8");rule.thickness=1;line.add_theme_stylebox_override("separator",rule);column.add_child(line)
	camera_rig.enabled=false;return column

func _card(row:HBoxContainer,title:String,detail:String,callback:Callable,badge:String="",cost:String="",chapter:int=-1,compact:bool=false,expanded:bool=false,showcase:bool=false,hero:String="",icon:String="")->Button:
	var card:=Card.new();card.configure({"chapter":int(adventure.state.get("chapter",0)) if chapter<0 else chapter,"heading":title,"detail":detail,"badge":badge,"cost":cost,"compact":compact,"expanded":expanded,"showcase":showcase,"hero":hero,"icon":icon if not icon.is_empty() else ["compass","mahjong","clock"][int(adventure.state.get("chapter",0))]});card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.pressed.connect(_guard_overlay(callback));row.add_child(card);overlay_options.append(card);return card

func _guard_overlay(callback:Callable)->Callable:
	var expected:int=overlay_generation
	return func():
		if expected==overlay_generation and is_instance_valid(overlay):callback.call()

func _show_menu()->void:
	if not is_instance_valid(hud):return
	if arena!=null or presentation in ["loading","result","puzzle","walk","dice"]:return
	_close_overlay();overlay_kind="menu"
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.add_child(overlay)
	var menu:=FurAdventureMenu.new();menu.mode=mode_picker.selected
	menu.chapter_chosen.connect(_begin_journey)
	menu.full_journey.connect(_begin_journey.bind(-1))
	menu.resume_journey.connect(_resume_board)
	menu.mode_chosen.connect(func(index:int):mode_picker.selected=index)
	menu.settings_requested.connect(_show_settings)
	overlay.add_child(menu);overlay_options=menu.chapter_buttons
	var tea_entry:=Button.new();tea_entry.text="百番夜宴 · 3D 麻将肉鸽";tea_entry.position=Vector2(104,748);tea_entry.size=Vector2(452,60);Palette.apply_button(tea_entry,"primary","mahjong");overlay.add_child(tea_entry)
	tea_entry.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/party/mahjong_night.tscn"))
	board_root.hide();camera_rig.enabled=false

func _resume_board()->void:_close_overlay();_refresh()

func _toggle_notebook()->void:
	if presentation=="puzzle":return
	if not overlay_kind.is_empty():_close_overlay();return
	if arena!=null or presentation in ["walk","dice","loading","result"]:return
	var column:=_overlay_base("help","冒险手册","三个章节，各有一套与伙伴配合的方法。")
	var guide:=FurUIFieldGuide.new();guide.configure(int(adventure.state.chapter));column.add_child(guide)
	var back:=_button("知道了 · 返回旅程",_resume_board);Palette.apply_button(back,"primary","check");back.custom_minimum_size=Vector2(280,52);back.size_flags_horizontal=Control.SIZE_SHRINK_END;column.add_child(back)

func _set_chapter_visuals()->void:
	if not is_instance_valid(board_root) or adventure.state.is_empty():return
	var chapter:int=adventure.state.chapter
	if visual_chapter==chapter:return
	visual_chapter=chapter;board_tiles=AdventureMap.nodes(chapter);board_districts=AdventureMap.districts(chapter)
	if chapter>0 or world.get_script().resource_path!="res://scripts/party/world_builder.gd":
		board_root.remove_child(world);world.free()
		world=World.new() if chapter==0 else ChapterWorld.new();board_root.add_child(world)
		if chapter==0:world.build(board_tiles,Map.edges())
		else:world.build(board_tiles,Map.edges(),chapter)
	if is_instance_valid(dressing):dressing.build(board_root,board_tiles,Map.edges());dressing.set_chapter(chapter)
	if is_instance_valid(markers):board_root.remove_child(markers);markers.queue_free()
	markers=Node3D.new();markers.name="ActivityMarkers";board_root.add_child(markers)
	for tile in board_tiles:
		var activity:String=tile.get("activity","");var station:String=tile.get("station","")
		if activity.is_empty() and station.is_empty():continue
		var label:=Label3D.new();label.text=("挑战" if activity=="challenge" else ("出口" if activity=="chapter_exit" else {"item_shop":"道具","commission":"委托","forge":"工坊"}.get(station,"工坊")));label.font=preload("res://assets/art/sevenhour_v1/NotoSansSC-Bold-Outline.ttf");label.font_size=48;label.pixel_size=.011;label.outline_size=0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("714d3c") if activity=="challenge" else Color("315458");label.outline_modulate=Color("36585b");label.position=tile.pos+Vector3(0,1.28,0);label.no_depth_test=false;markers.add_child(label)
	for i in pawns.size():pawns[i].position=_pawn_position(adventure.state.players[i].node,i)
	if is_instance_valid(camera_rig):
		var active_node:int=adventure.state.players[adventure.state.active].node
		camera_rig.set_focus(board_tiles[active_node].pos,board_districts[board_tiles[active_node].district].center,true)
	_restore_environment()

func _restore_environment()->void:
	super._restore_environment()
	if is_instance_valid(dressing):
		var profile:Dictionary=dressing.environment_profile()
		if profile.has("background"):environment.environment.background_color=profile.background
		if profile.has("ambient_color"):environment.environment.ambient_light_color=profile.ambient_color
		if profile.has("ambient_energy"):environment.environment.ambient_light_energy=profile.ambient_energy
		for child in board_root.get_children():
			if child is DirectionalLight3D and child.shadow_enabled:
				child.light_color=profile.get("sun_color",Color("ffdfb0"));child.light_energy=profile.get("sun_energy",.85)
				child.shadow_blur=2.2;child.shadow_normal_bias=1.2
	FurArtLighting.apply(environment.environment,int(adventure.state.get("chapter",0)))
	for child in board_root.get_children():
		if child is DirectionalLight3D and child.shadow_enabled:FurArtLighting.key(child)
	if FurIslandComposition.enabled and int(adventure.state.get("chapter",0))==0:FurAtelierLighting.island(environment.environment,board_root)

func _process(delta:float)->void:
	_hud_clock+=delta
	if _hud_dirty or (arena!=null and _hud_clock>.12):_sync_board_hud();_hud_dirty=false;_hud_clock=0
	if overlay_kind=="mahjong_table":
		activity_wait+=delta
		var current:Dictionary=table_mahjong.state()
		if ai_enabled and current.get("actor",0)==1 and activity_wait>.95 and not table_presenter.table_view.is_animating():
			if current.get("phase","")=="discard":
				var choice:int=table_mahjong.ai_choice()
				if choice>=0:_real_table_action(choice,1,current.revision)
				else:
					var exchange:Array=table_mahjong.ai_exchange()
					if not exchange.is_empty():_real_table_tea("exchange",Vector2i(exchange[0],exchange[1]),1,current.revision)
					else:_real_table_discard(table_mahjong.ai_discard(),1,current.revision)
			else:
				var choice:int=table_mahjong.ai_choice()
				if choice>=0:_real_table_action(choice,1,current.revision)
		return
	if overlay_kind=="style_station":
		activity_wait+=delta
		if ai_enabled and activity_actor==1 and activity_wait>.8:
			var district:int=board_tiles[adventure.state.players[1].node].district
			_choose_table_style(["sequence","triplet","closed"][district])
		return
	if overlay_kind in ["menu","help","loadout","chapter_intro","activity_result","table_mode","settings"]:return
	if overlay_kind=="activity":
		activity_wait+=delta
		var current:Dictionary=echo.state()
		if ai_enabled and int(current.get("actor",0))==1 and activity_wait>.85:
			var choice:int=echo.ai_choice()
			if choice>=0:_activity_choice(choice)
		return
	super._process(delta)
	if arena!=null and presentation=="arena":
		var battle=arena.model
		round_label.text="海岛挑战 %d · Lv%d · %d/%d经验"%[adventure.state.chapter_cleared.size()+1,battle.players[0].build.level,battle.experience,battle.next_level_experience]

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F10:_toggle_sound();get_viewport().set_input_as_handled();return
	if event.physical_keycode==KEY_F11:super._unhandled_key_input(event);return
	if not overlay_kind.is_empty():
		if event.physical_keycode==KEY_ESCAPE and overlay_kind=="settings":_leave_settings()
		elif event.physical_keycode==KEY_ESCAPE and overlay_kind in ["menu","help"]:_resume_board()
		elif event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9]:
			var index:int=event.physical_keycode-KEY_1
			if index<overlay_options.size() and not overlay_options[index].disabled:overlay_options[index].pressed.emit()
		get_viewport().set_input_as_handled();return
	super._unhandled_key_input(event)

func _refresh()->void:
	_hud_dirty=true
	if resetting_journey:return
	if not is_instance_valid(hud) or adventure.state.is_empty():return
	if presentation in ["loading","result"]:return
	if overlay_kind=="upgrade" and presentation!="upgrade":_close_overlay()
	var state:Dictionary=adventure.state;var chapter:int=state.chapter;serial_seen=state.serial
	_set_chapter_visuals()
	world.set_star(state.star_node);world.set_active_tile(state.players[state.active].node);world.set_path(state.path)
	if world.has_method("set_properties"):world.set_properties(state.properties)
	for i in 2:
		player_labels[i].text="%s · %s\n金币 %d  星铃 %d"%[Map.PLAYER_NAMES[i],"泡泡熊AI" if state.players[i].ai else "P%d"%(i+1),state.players[i].coins,state.players[i].stars]
		if chapter>0:
			var res:Dictionary=state.chapter_resources[i]
			player_labels[i].text+="\n"+("窥牌%d · 换牌%d"%[res.wilds,res.redraws] if chapter==1 else "旋转%d · 余辉%d"%[res.rotate_tokens,res.echo_bonus])
		else:
			var supply:Dictionary=state.provisions[i]
			player_labels[i].text+="\n血+%.0f · 攻+%.0f%%"%[supply.health_bonus+(12 if state.players[i].preparation==0 else 0),100*(supply.damage_bonus+(.12 if state.players[i].preparation==1 else 0))]
		if presentation!="walk" or i!=move_actor:pawns[i].position=_pawn_position(state.players[i].node,i)
		player_panels[i].modulate=Color.WHITE
	round_label.text="第%d章 · %s · 印章%d/2"%[chapter+1,TITLES[chapter],state.chapter_cleared.size()]
	toast.text=("试玩" if state.practice else "旅程")+" · 第%d手"%state.turn
	joint_panel.hide();mission_panel.hide();loadout_button.visible=chapter==0 and state.phase=="prepare" and state.activity_index==0 and presentation=="idle";notebook_button.disabled=presentation in ["dice","walk","landing_pause"]
	overview_button.show();toast_backplate.show();notebook_button.show();phase_panel.offset_top=-185;phase_panel.offset_right=-24
	phase_title.add_theme_font_size_override("font_size",24);phase_detail.add_theme_font_size_override("font_size",17)
	instruction.text="Space 掷骰     1–4 选择     Tab 总览     F1 手册     F10 静音                         挑战站才开启活动 · 收集两枚印章再出发"
	_clear_options();roll_button.visible=state.phase=="roll" and presentation=="idle";roll_button.disabled=state.players[state.active].ai
	if roll_button.visible:phase_panel.offset_right=-215
	phase_detail.text=last_result
	if presentation=="recap":
		if overlay_kind!="combat_recap":_show_combat_recap()
		return
	if presentation=="upgrade":
		_show_upgrade();return
	if presentation=="dice":phase_title.text=Map.PLAYER_NAMES[state.active]+" · 骰子正在旋转";return
	if presentation=="walk" or state.phase=="moving":phase_title.text="%s · %s剩%d步"%[Map.PLAYER_NAMES[state.active],"风艇航行，" if sailing else "",state.remaining];return
	if presentation=="landing_pause":phase_title.text="落点已兑现 · 继续探索";return
	match str(state.phase):
		"prepare":
			phase_title.text="%s · 下一场挑战怎样配合？"%Map.PLAYER_NAMES[state.active];phase_detail.text="选择免费战备，随后自由走棋；只有进入挑战站才开战。"
			for item in adventure.prepare_options(state.active):
				var heading:String="暖心补给" if item.choice==0 else "热力口粮"
				_decision_card(heading,"下一次实际挑战：生命 +12" if item.choice==0 else "下一次实际挑战：伤害 +12%",_prepare.bind(item.choice),"免费战备","heart" if item.choice==0 else "forge",not state.players[state.active].ai,"等待伙伴选择" if state.players[state.active].ai else "")
		"roll":
			phase_title.text="%s 的探索回合"%Map.PLAYER_NAMES[state.active];phase_detail.text="挑战站 06 / 20 / 34 · 出口 11 / 25 / 39。每章取得两处不同印章。"
			var order:String=_commission_hint(state.active)
			if not order.is_empty():phase_detail.text=order
			for item in state.players[state.active].items:
				var b:=_button("使用 "+{"boost":"加骰+2","shield":"保钱","swap":"换位"}[item],_use_item.bind(item,1-state.active if item=="swap" else state.active));b.disabled=state.item_used or state.players[state.active].ai;option_row.add_child(b)
		"branch":
			phase_panel.offset_top=-258;phase_title.text="岔路选择 · 看清停靠站再出发";phase_detail.text="经过挑战/出口会停步并放弃剩余步数；可选择进入或离开。风艇2金币。"
			var order:String=_commission_hint(state.active)
			if not order.is_empty():phase_detail.text=order+" · 风艇2金；挑战可不进入。"
			for target in adventure.branch_options(state.active):
				var p:Dictionary=branch_preview(target);var preview:Dictionary=adventure.preview_branch(state.active,target)
				var lines:PackedStringArray=str(p.caption).split("\n")
				_decision_card(lines[0]," · ".join(lines.slice(1)),_advance.bind(target),"船票 %d 金币"%preview.get("ferry_cost",0) if int(preview.get("ferry_cost",0))>0 else "步行 · 不收船票","route",not state.players[state.active].ai,"等待伙伴选择" if state.players[state.active].ai else "")
		"landing":
			var tile:Dictionary=board_tiles[state.players[state.active].node];var activity:String=tile.get("activity","")
			phase_title.text="%s · %s"%[Map.PLAYER_NAMES[state.active],"挑战站" if activity=="challenge" else ("章节出口" if activity=="chapter_exit" else ("配方工坊" if tile.get("station","")=="forge" else ("旅途道具店" if tile.get("station","")=="item_shop" else Map.LABELS.get(tile.kind,tile.kind))))]
			phase_detail.text=DESCRIPTIONS[chapter].replace("\n"," ") if activity=="challenge" else ("取得两处不同挑战印章后离开当前章节。" if activity=="chapter_exit" else "选择会立刻改变金币、路线或本章实际可用的构筑资源。")
			if tile.get("station","")=="commission":
				phase_panel.offset_top=-254;phase_title.text=Map.PLAYER_NAMES[state.active]+" · 地区委托站"
				phase_detail.text="至少走4个真实步数并到目标落地；两人轮换计时，逾期押金不返。每人每章每站每种仅接一次。"+_commission_hint(state.active)
			for item in adventure.landing_options(state.active):
				var face:Dictionary=_offer_face(item,tile)
				var reason:String="等待伙伴选择" if state.players[state.active].ai else _offer_reason(item)
				_decision_card(face.heading,face.detail,_land.bind(item.choice),face.cost,face.icon,bool(item.enabled) and not state.players[state.active].ai,reason,tile.get("station","")=="commission")
		"challenge":
			phase_title.text="%s · 即将进入%s"%[Map.PLAYER_NAMES[state.active],TITLES[chapter]];phase_detail.text=DESCRIPTIONS[chapter].replace("\n"," ")
			option_row.add_child(_button("一起进入挑战",_start_arena))
		"activity_retry":
			phase_title.text="这次未完成 · 伙伴共同决定";phase_detail.text="失败不发印章。由玩家确认原地重试，或先回棋盘补充资源；无需代替AI掷骰。";_retry_buttons()
		"finished":
			phase_title.text="章节试玩完成！" if state.practice else "三章冒险完成！"
			phase_detail.text="伙伴们以不同玩法完成了实际挑战。星铃与金币记录这一程的个人收获。"
			option_row.add_child(_button("打开冒险图册",_show_menu))

func _retry_buttons()->void:
	option_row.add_child(_button("原地重试",_retry_activity));option_row.add_child(_button("先回棋盘",_leave_activity))
func _retry_activity()->void:
	if adventure.retry_activity(adventure.state.active).ok:presentation="idle";_refresh()
func _leave_activity()->void:
	if adventure.leave_activity(adventure.state.active).ok:presentation="idle";_refresh()

func _prepare(choice:int)->void:
	if presentation!="idle":return
	if adventure.choose_preparation(adventure.state.active,choice).ok:wait_clock=0;last_result="免费战备已准备，去棋盘挑选挑战。";_refresh()

func _roll(forced:int=0)->Dictionary:
	var result:Dictionary=super._roll(forced)
	if not result.ok:return result
	# Keep the real roll and its animation, but give the whole visible arc a
	# screen-space margin from both animals instead of covering the partner.
	var origin:Vector3=pawns[adventure.state.active].position
	var best:Vector3=origin+Vector3(-2.6,.9,.3);var best_score:=-INF
	for offset in [Vector3(-2.6,.9,.3),Vector3(2.6,.9,.3),Vector3(-2.2,.9,1.4),Vector3(2.2,.9,1.4)]:
		var candidate:Vector3=origin+offset;var score:=INF
		for height in [0.0,1.2,2.4]:
			var screen:Vector2=camera.unproject_position(candidate+Vector3.UP*height)
			for pawn in pawns:
				for body_height in [.5,1.5,2.4]:score=minf(score,screen.distance_to(camera.unproject_position(pawn.position+Vector3.UP*body_height)))
			if screen.x<100 or screen.x>1500 or screen.y<210 or screen.y>650:score-=100
		if score>best_score:best_score=score;best=candidate
	dice.position=best
	return result

func _land(choice:int)->void:
	if presentation!="idle":return
	var previous:int=adventure.state.chapter
	var result:Dictionary=adventure.resolve_landing(adventure.state.active,choice)
	if not result.ok:last_result=result.reason;_refresh();return
	_landing_feedback(result.facts)
	if adventure.state.chapter!=previous:
		visual_chapter=-1;_set_chapter_visuals();last_result="抵达新的章节，准备一套新的玩法！";_refresh();return
	if adventure.state.phase in ["challenge","finished"]:wait_clock=0;_refresh();return
	if result.facts.get("station_kind","")=="mahjong_workshop":
		station_token=result.facts.station_token;activity_actor=result.facts.station_actor;station_return="board";_station_menu();return
	var facts:Dictionary=result.facts
	last_result="选择已兑现：金币 %+d"%int(facts.get("coin_delta",0))
	if facts.has("commission_action"):
		var action:String=facts.commission_action.get("action","")
		last_result={"accepted":"委托已接下，沿实际路线前往目标。","supported":"已支援伙伴，后续由你亲自送达也可兑现。","cancelled":"委托已取消，实际退款见钱包。"}.get(action,"保留现金，继续探索。")
	for receipt in facts.get("commission_receipts",[]):
		last_result+=" · 委托%s：小柯%+d / 泡泡%+d金"%["完成" if receipt.action=="completed" else receipt.action,receipt.actual_coins[0],receipt.actual_coins[1]]
	if not str(facts.get("item","")).is_empty():last_result+=" · 获得"+{"boost":"加骰+2","shield":"保钱护符","swap":"位置互换"}.get(facts.item,facts.item)
	elif facts.has("supply_when"):last_result+=" · 本区新挑战首试供给"+{"wilds":"窥牌券","rotate_tokens":"旋转券"}.get(facts.estate_supply_kind,"")
	elif facts.has("resources_after") and adventure.state.chapter>0:last_result+=" · 本章资源已记入伙伴卡"
	elif facts.has("provisions_after"):last_result+=" · 这份战备将在下次挑战兑现"
	presentation="landing_pause";wait_clock=0;_refresh()

func branch_preview(target:int)->Dictionary:
	var p:Dictionary=adventure.preview_branch(adventure.state.active,target)
	if not p.ok:return {"caption":"路线不可用","path":[]}
	var tile:Dictionary=board_tiles[p.node];var caption:String=board_districts[tile.district].name+"\n"
	caption+=("挑战停靠" if tile.get("activity","")=="challenge" else ("出口停靠" if tile.get("activity","")=="chapter_exit" else ("继续选岔路" if not p.landing else {"commission":"地区委托站","forge":"配方工坊","item_shop":"道具补给站"}.get(tile.get("station",""),Map.LABELS.get(tile.kind,tile.kind)))))
	caption+=" · %02d格"%p.node
	if p.ferry_cost>0:caption+="\n渡船 2金币"
	if p.interrupted_steps>0:caption+="\n停靠放弃剩%d步，可选择不进入"%p.interrupted_steps
	return {"caption":caption,"path":p.path}

func _commission_hint(actor:int)->String:
	var status:Dictionary=adventure.commission_status();var record:Dictionary=status.active[actor]
	var traveler:int=actor;var prefix:String=""
	if record.is_empty():
		var partner:Dictionary=status.active[1-actor]
		if not partner.is_empty():
			record=partner
			if partner.helper!=actor:traveler=1-actor;prefix="伙伴"+Map.PLAYER_NAMES[1-actor]+" · "
			else:prefix="支援伙伴 · "
	if record.is_empty():return ""
	var target:int=record.via if record.kind=="survey" and not record.via_seen[traveler] else record.target
	var text:String=prefix+"%s→%s%02d格 · 走%d/4步 · 剩%d手"%["配送" if record.kind=="delivery" else "勘探",board_districts[board_tiles[target].district].name,target,record.steps[traveler],maxi(0,record.expires_turn-adventure.state.turn)]
	return text+" · 持单奖%d金"%record.reward+(" / 支援2金" if record.helper>=0 else "")

func _start_arena()->void:
	if adventure.state.phase!="challenge" or presentation!="idle":return
	if adventure.state.chapter==0:super._start_arena();return
	battle_plan=adventure.battle_context();challenge_token=battle_plan.token;activity_wait=0;activity_actor=battle_plan.leader
	if adventure.state.chapter==1:
		presentation="puzzle";_show_table_mode();return
	else:
		if not echo.start(challenge_token,battle_plan.district,ai_enabled).ok:return
		activity_kind="echo"
	presentation="puzzle";music.set_mode("battle");_show_activity()

func _show_table_mode()->void:
	var column:=_overlay_base("table_mode","云顶雀馆 · 怎样开这一桌？","双人合作麻将：万筒索与字牌共136张；任一伙伴合法胡牌便共同过站。两种模式使用同一套摸打规则。")
	var row:=HBoxContainer.new();column.add_child(row)
	_card(row,"公开残局","13张起手和墙首条件公开，练习顺子、刻子或七对。吃碰杠和窥牌顺序会改变实际摸牌时机。",_choose_table_mode.bind(true),"读牌 · 练技艺","预设起手，其余真洗牌",1)
	_card(row,"自由洗牌","全副136张真正洗牌后发13张，没有预设赢家。利用棋盘攒来的券与流派技艺，决定留牌、叫牌与门清。",_choose_table_mode.bind(false),"随机 · 考验构筑","无预设起手或墙首",1)
	column.add_child(_label("基础胜利奖励相同；合法胡牌达成流派目标，胜者额外3金。64次弃牌或牌墙耗尽即流局，可回棋盘补券再试。",20))
	column.add_child(_label("两人合作简化规则：真实吃碰杠与四面子一将 / 门清七对，伙伴间弃牌可以互相配合。",17))

func _choose_table_mode(endgame:bool)->void:
	if overlay_kind!="table_mode" or adventure.state.phase!="challenge":return
	if not table_mahjong.begin_challenge(activity_actor,challenge_token,battle_plan.district,endgame).ok:return
	activity_kind="real_mahjong";presentation="puzzle";music.set_mode("battle");_show_real_table()

func _station_menu()->void:
	activity_wait=0
	var column:=_overlay_base("style_station",Map.PLAYER_NAMES[activity_actor]+" · 雀馆修行","只有一个流派槽。每人每场一次技艺；真实胡牌规则不变，达成流派目标的胜者额外得3金币。")
	var row:=HBoxContainer.new();column.add_child(row)
	var current:String=table_mahjong.state().styles[activity_actor]
	_card(row,"门清修行","技艺：无明副露时窥真实墙顶3牌一次。\n胡牌目标：保持门清。",_choose_table_style.bind("closed"),"当前装备" if current=="closed" else "隐忍","单槽 · 取代当前流派",1).set_selected(current=="closed")
	_card(row,"刻子派","技艺：实际碰杠后，换本次摸入牌一次。\n胡牌目标：至少3个刻子或杠。",_choose_table_style.bind("triplet"),"当前装备" if current=="triplet" else "进攻","单槽 · 取代当前流派",1).set_selected(current=="triplet")
	_card(row,"连序派","技艺：实际吃牌后窥真实墙顶3牌一次。\n胡牌目标：至少3组顺子。",_choose_table_style.bind("sequence"),"当前装备" if current=="sequence" else "谋划","单槽 · 取代当前流派",1).set_selected(current=="sequence")
	column.add_child(_button("保留当前流派，继续探索",_finish_station))

func _choose_table_style(style:String)->void:
	var changed:Dictionary=table_mahjong.set_style_station(activity_actor,style,station_token)
	if not changed.ok:return
	board_audio.play("purchase");_finish_station()

func _finish_station()->void:
	_close_overlay();activity_kind=""
	if station_return=="market":
		if not adventure.finish_market(activity_actor).ok:return
		if adventure.state.phase=="market":
			activity_actor=adventure.state.market_actor;station_token=adventure.state.serial;_station_menu();return
		presentation="idle"
	else:presentation="landing_pause"
	wait_clock=0;last_result="麻将流派已保留，下一场使用真实牌墙与当前构筑。";_refresh()

func _show_real_table()->void:
	if overlay_kind!="mahjong_table" or not is_instance_valid(table_presenter):
		var column:=_overlay_base("mahjong_table","","")
		table_presenter=TablePresenter.new();table_presenter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(table_presenter)
		table_presenter.discard_requested.connect(_real_table_discard)
		table_presenter.action_requested.connect(_real_table_action)
		table_presenter.resource_requested.connect(_real_table_resource)
		table_presenter.retreat_requested.connect(_real_table_retreat)
		table_presenter.tea_requested.connect(_real_table_tea)
	board_root.hide()
	instruction.hide()
	var current:Dictionary=table_mahjong.state();var actor:int=current.actor
	var counts:Dictionary=adventure.state.chapter_resources[actor]
	var allowed:Dictionary={}
	for key in ["wilds","redraws"]:allowed[key]=table_mahjong.can_resource(key,actor,current.revision)
	table_presenter.configure(current,ai_enabled,table_mahjong.choices(),counts,allowed)
	overlay_options=table_presenter.buttons

func _real_table_discard(index:int,actor:int,revision:int)->void:
	if table_presenter.table_view.is_animating():return
	var committed:Dictionary=table_mahjong.discard(index,actor,revision)
	if committed.ok:board_audio.play("step");_real_table_changed()

func _real_table_action(choice:int,actor:int,revision:int)->void:
	if table_presenter.table_view.is_animating():return
	var committed:Dictionary=table_mahjong.apply(choice,actor,revision)
	if committed.ok:board_audio.play("purchase");_real_table_changed()

func _real_table_resource(key:String,actor:int,revision:int)->void:
	if table_presenter.table_view.is_animating():return
	if not table_mahjong.can_resource(key,actor,revision):return
	if not adventure.consume_activity_resource(actor,key,challenge_token).ok:return
	var committed:Dictionary=table_mahjong.apply_resource(key,actor,revision)
	if not committed.ok:push_error("Validated real Mahjong resource failed synchronous commit");return
	_refresh();_real_table_changed()

func _real_table_retreat(actor:int,revision:int)->void:
	if table_mahjong.retreat(actor,revision).ok:_real_table_changed()

func _real_table_tea(kind:String,value:Variant,actor:int,revision:int)->void:
	if table_presenter.table_view.is_animating():return
	var reply:Dictionary=table_mahjong.choose_tea(str(value),actor,revision) if kind=="recipe" else table_mahjong.exchange_tea(value.x,value.y,actor,revision)
	if reply.ok:board_audio.play("purchase");_real_table_changed()

func _real_table_changed()->void:
	activity_wait=0
	var result:Dictionary=table_mahjong.result()
	if not result.is_empty():
		_show_real_table()
		await get_tree().create_timer(1.45).timeout
		if overlay_kind=="mahjong_table":_settle_puzzle(result)
	else:_show_real_table()

func _show_activity()->void:
	var state:Dictionary=echo.state();var actor:int=state.actor
	if overlay_kind!="activity" or not is_instance_valid(echo_presenter):
		var column:=_overlay_base("activity","时光回声 · 双人接力","录下上一轮的自己，让过去的行动替现在开路。")
		echo_presenter=FurUIEchoPresenter.new();column.add_child(echo_presenter)
		echo_presenter.choice_requested.connect(func(choice:int,who:int,revision:int):
			if _echo_input_current(who,revision):_activity_choice(choice))
		echo_presenter.resource_requested.connect(func(key:String,who:int,revision:int):
			if _echo_input_current(who,revision):_activity_resource(key))
		echo_presenter.seal_requested.connect(func(who:int,revision:int):
			if _echo_input_current(who,revision):_seal_recording())
		echo_presenter.retreat_requested.connect(func(who:int,revision:int):
			if _echo_input_current(who,revision):_retreat_echo())
	board_root.hide();instruction.hide()
	echo_presenter.configure(state,echo,ai_enabled,adventure.state.chapter_resources[actor]);overlay_options=echo_presenter.buttons

func _echo_input_current(actor:int,revision:int)->bool:
	if overlay_kind!="activity" or activity_kind!="echo":return false
	var current:Dictionary=echo.state()
	return int(current.actor)==actor and int(current.revision)==revision and not (ai_enabled and actor==1)

func _activity_choice(choice:int)->void:
	if activity_kind!="echo":return
	var state:Dictionary=echo.state();var committed:Dictionary=echo.apply(choice,state.actor,state.revision)
	if not committed.ok:return
	board_audio.play("step");activity_wait=0
	var outcome:Dictionary=echo.result()
	if not outcome.is_empty():_settle_puzzle(outcome)
	else:_show_activity()

func _activity_resource(key:String)->void:
	if activity_kind!="echo":return
	var state:Dictionary=echo.state()
	if not echo.can_resource(key,state.actor,state.revision):return
	if not adventure.consume_activity_resource(state.actor,key,challenge_token).ok:return
	var committed:Dictionary=echo.apply_resource(key,state.actor,state.revision)
	if not committed.ok:push_error("Validated Echo resource failed synchronous commit");return
	activity_wait=0;_refresh();_show_activity()

func _seal_recording()->void:
	var state:Dictionary=echo.state()
	if echo.seal_recording(state.actor,state.revision).ok:activity_wait=0;board_audio.play("embark");_show_activity()
func _retreat_echo()->void:
	var state:Dictionary=echo.state()
	if echo.retreat(state.actor,state.revision).ok:_settle_puzzle(echo.result())

func _settle_puzzle(outcome:Dictionary)->void:
	if outcome.token!=challenge_token or adventure.state.phase!="challenge":return
	var proof:Dictionary={"token":outcome.token}
	if activity_kind=="real_mahjong":proof={"token":outcome.token,"mahjong":outcome.duplicate(true)}
	var settled:Dictionary=adventure.settle_challenge(outcome.scores,challenge_token,proof)
	if not settled.ok:return
	if outcome.success:board_audio.play("star")
	last_activity_result=outcome.duplicate(true);music.set_mode("board")
	_refresh()
	var column:=_overlay_base("activity_result","挑战完成，印章点亮！" if outcome.success else "保留构筑，换个解法","这一站的收益已入账 · 下一站还能继续搭配")
	var receipt:Dictionary=settled.facts.receipt;var players:Array=[]
	for i in 2:
		players.append({"coins":receipt.coin_rewards[i],"wallet":adventure.state.players[i].coins,"detail":"携手完成本站挑战" if outcome.success else "本次未取得印章"})
	var retained:String="金币和剩余券保留；新挑战重新录制回声。"
	var headline:String="双人送达 · 与过去完成接力" if outcome.success else "重新安排路线，再试一次"
	var detail:String="下一步：前往另一处挑战站" if outcome.success else "可原地重试，也可回棋盘准备"
	if activity_kind=="real_mahjong":
		retained="麻将流派和剩余券保留；新场重新使用完整136张牌。"
		headline=("%s · 合作胡牌"%{"ron":"荣和","tsumo":"自摸","rob_kong":"抢杠胡"}.get(outcome.get("win_kind",""),"合法胡牌")) if outcome.success else "流局 / 撤回 · 留住下一次机会"
		detail="本次牌型 %d 积分"%int(outcome.get("points",0)) if outcome.success else "未取得印章，可选择原地重试"
		if receipt.has("mahjong_result"):
			var bonus:int=receipt.mahjong_result.get("actual_bonus",0)
			detail+=" · 流派目标%s · 胜者额外 %d 金"%["达成" if outcome.get("style_qualified",false) else "未达成",bonus]
			var winner:int=int(receipt.mahjong_result.get("winner",-1))
			if winner>=0 and winner<2:players[winner].coins+=bonus;players[winner].detail="基础 +%d  ·  流派奖励 +%d"%[receipt.coin_rewards[winner],bonus]
	var summary:=FurUIResultSummary.new();summary.configure({"success":outcome.success,"headline":headline,"detail":detail,"players":players,"stamps":adventure.state.chapter_cleared.size(),"retained":retained},premium_faces);column.add_child(summary)
	var next:=_button("带着收获继续" if outcome.success else "重新制定计划",_close_activity_result);Palette.apply_button(next,"primary","compass");next.custom_minimum_size=Vector2(310,56);next.size_flags_horizontal=Control.SIZE_SHRINK_END;column.add_child(next);overlay_options.append(next)
	if outcome.success:_confirmed_feedback("stamp","挑战印章 +1",Vector2(800,756))

func _show_combat_recap()->void:
	var state:Dictionary=adventure.state;var success:bool=battle_recap.get("won",false)
	var column:=_overlay_base("combat_recap","守住了，这座岛记住了你们" if success else "先撤回来，再换一种搭配",str(battle_recap.get("district","海岛"))+" · 挑战结算")
	var players:Array=[];var actual_rows:Array=battle_recap.get("player_rows",[])
	for i in 2:
		var row:Dictionary=actual_rows[i] if i<actual_rows.size() else {}
		players.append({"coins":row.get("coins",0),"wallet":state.players[i].coins,"detail":"击退 %d  ·  造成伤害 %.0f"%[row.get("kills",0),row.get("damage",0)]})
	var growth:Dictionary=battle_recap.get("growth",{});var retained:String="伙伴成长  Lv%d → Lv%d  ·  经验 %d / %d
武器、改装与经验带到下一处挑战。"%[battle_recap.get("old_level",1),battle_recap.get("level",1),growth.get("experience",0),growth.get("next_level_experience",1)]
	var summary:=FurUIResultSummary.new();summary.configure({"success":success,"headline":"地区任务已兑现" if battle_recap.get("objective",false) else "地区任务尚未完成","detail":"两处不同印章后，就能从出口前往下一章。" if success else "战斗中的成长仍然保留，可以原地重试。","players":players,"stamps":state.chapter_cleared.size(),"retained":retained},premium_faces);column.add_child(summary)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_END;column.add_child(row)
	if state.phase=="market":
		var next:=_button("挑选免费改装",func():_close_overlay();_open_workshop());Palette.apply_button(next,"primary","forge");next.custom_minimum_size=Vector2(310,56);row.add_child(next);overlay_options.append(next)
	else:
		var leave:=_button("先回棋盘",func():_close_overlay();_leave_activity());Palette.apply_button(leave,"quiet","compass");leave.custom_minimum_size=Vector2(240,56);row.add_child(leave);overlay_options.append(leave)
		var retry:=_button("伙伴一起重试",func():_close_overlay();_retry_activity());Palette.apply_button(retry,"primary","shield");retry.custom_minimum_size=Vector2(300,56);row.add_child(retry);overlay_options.append(retry)

func _sync_board_hud()->void:
	if not is_instance_valid(board_hud) or adventure.state.is_empty():return
	combat_hud.visible=arena!=null and overlay_kind.is_empty() and presentation=="arena"
	if combat_hud.visible:
		_sync_player_badges();_sync_combat_ui();board_hud.hide();phase_panel.hide();mission_panel.hide();return
	board_hud.visible=overlay_kind.is_empty() and presentation not in ["loading","result","puzzle","upgrade"]
	phase_panel.visible=board_hud.visible
	if not board_hud.visible:return
	var state:Dictionary=adventure.state;var actor:int=state.active
	_sync_player_badges()
	var button_height:float=0
	for button in option_row.get_children():
		button_height=maxf(button_height,button.custom_minimum_size.y)
		if button is FurChapterCard:
			button.size_flags_horizontal=Control.SIZE_FILL if option_row.get_child_count()<3 else Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.x=575 if option_row.get_child_count()==2 else (650 if option_row.get_child_count()==1 else 320)
	var footer:float=maxf(52,button_height+8) if option_row.get_child_count()>0 else 14.0
	phase_panel.offset_top=-footer-27;phase_panel.offset_bottom=-27;phase_panel.offset_right=-215 if roll_button.visible else -24
	board_hud.position=Vector2(24,900-footer-27-85);board_hud.size=Vector2(1335 if roll_button.visible else 1552,74)
	var current:Dictionary=builds[actor]
	var build_text:String="%s · %d把武器\n火力 ×%.2f · Lv%d"%[FurBuildCatalog.NAMES[current.style],current.weapons,current.damage,current.get("level",1)]
	var objective:String="两处不同挑战后离岛 · %s"%board_districts[board_tiles[state.players[actor].node].district].name
	var hint:String="地区委托让探索转化为下一场战备"
	if state.chapter==1:
		var style:String=table_mahjong.state().styles[actor]
		build_text={"closed":"门清 · 观潮","triplet":"刻派 · 换骨","sequence":"连序 · 接龙"}.get(style,style)+"\n本场一次真实流派技艺"
		hint="窥牌%d · 换牌%d"%[state.chapter_resources[actor].wilds,state.chapter_resources[actor].redraws]
	elif state.chapter==2:build_text="时间回声 · 双人接力";hint="旋转%d · 余辉%d"%[state.chapter_resources[actor].rotate_tokens,state.chapter_resources[actor].echo_bonus]
	var commission:String=_commission_hint(actor)
	if not commission.is_empty():objective=commission
	if state.phase=="landing" and not state.landing_resolved and commission.is_empty():objective=phase_detail.text
	if not commission.is_empty():hint="期限按两人轮换 · 留意停步与渡船费"
	if arena!=null:
		current=arena.model.players[0].build;actor=0
		var caption:Dictionary=FurCombatBuildCaption.describe(arena.model.players[0])
		build_text="%s · %d把武器\n%s · 火力 ×%.2f"%[FurBuildCatalog.NAMES[current.style],current.weapons,caption.name,current.damage]
		objective="%s · 地区任务%.0f/%.0f"%[battle_plan.district_name,arena.model.rule_state.progress,arena.model.rule_state.target]
		hint=caption.hint
	board_hud.configure({"chapter":state.chapter,"mode":"combat" if arena!=null else "board","actor":Map.PLAYER_NAMES[actor],"action":phase_title.text,"objective":objective,"coins":state.players[actor].coins,"stamps":"%d / 2"%state.chapter_cleared.size(),"build":build_text,"hint":hint,"compact":true})

func _confirmed_feedback(kind:String,text:String,origin:Vector2)->void:
	if not is_instance_valid(feedback):return
	hud.move_child(feedback,hud.get_child_count()-1);feedback.play(kind,adventure.state.chapter,origin,text)

func _landing_feedback(facts:Dictionary)->void:
	var text:="";var kind:="success"
	var delta:int=facts.get("coin_delta",0)
	if delta!=0:text="金币 %+d"%delta;kind="coin" if delta>0 else "blocked"
	for receipt in facts.get("commission_receipts",[]):
		if receipt.action=="completed":text="委托完成 · 小柯%+d / 泡泡%+d金"%[receipt.actual_coins[0],receipt.actual_coins[1]];kind="success"
	if facts.get("commission_action",{}).get("action","")=="accepted":text="路线委托已接 · 押金已付";kind="success"
	if text.is_empty():return
	var origin:Vector2=camera.unproject_position(pawns[adventure.state.active].position+Vector3.UP*2.3)
	origin.x=clampf(origin.x,190,1400);origin.y=clampf(origin.y,250,580);_confirmed_feedback(kind,text,origin)

func _close_activity_result()->void:
	_close_overlay();presentation="idle";activity_kind=""
	if adventure.state.phase=="market":
		if adventure.state.chapter==1:
			station_return="market";station_token=adventure.state.serial;activity_actor=0;_station_menu();return
		adventure.finish_market(0);adventure.finish_market(1)
	_refresh()

func _open_loadout()->void:
	if adventure.state.phase!="prepare" or adventure.state.chapter!=0:return
	var column:=_overlay_base("loadout","选择你的冒险流派","不同自动武器、技能与专属改装，共同成长。")
	var row:=HBoxContainer.new();column.add_child(row)
	var descriptions:=["挥锅迎敌，回收锅能，给伙伴减伤。","站定蓄能、迈步齐射，把时机变成爆发。","放置诱饵聚怪，让饼阵连环炸开。"]
	for i in 3:
		var card:=_card(row,FurBuildCatalog.NAMES[i],descriptions[i],_choose_style.bind(i),["守护 · 近身","爆发 · 走停","陷阱 · 聚怪"][i],"本局持续成长",0,false,false,false,"weapon_"+["pan","blaster","cookie"][i]);card.set_selected(i==int(builds[adventure.state.active].style))
	var detail:=_label("选择后立即装备。伙伴可选择另一个流派，在同一场挑战中配合。",18);detail.add_theme_color_override("font_color",Palette.MUTED);column.add_child(detail)
	var back:=_button("保留当前流派",_resume_board);Palette.apply_button(back,"quiet","check");column.add_child(back)
	back.custom_minimum_size=Vector2(280,48);back.size_flags_horizontal=Control.SIZE_SHRINK_END
func _choose_style(style:int)->void:
	builds[adventure.state.active]=FurBuildCatalog.create(style);_close_overlay();last_result="选好了 "+FurBuildCatalog.NAMES[style];_refresh()

func _show_upgrade()->void:
	var state:Dictionary=adventure.state;var current:Dictionary=builds[upgrade_actor]
	var column:=_overlay_base("upgrade",Map.PLAYER_NAMES[upgrade_actor]+" · 构筑工坊","追加一件需要6金币，或保留金币继续探索。" if upgrade_free_done else "选择一件免费永久改装；两件核心只能选其一。" if current.masterwork.is_empty() and not state.chapter_cleared.is_empty() else "选择一件免费永久改装，让下一处挑战打法不同。")
	var status:=HBoxContainer.new();status.add_theme_constant_override("separation",14);column.add_child(status);status.add_child(FurUIIcons.view("coin",Vector2(29,29)))
	var wallet:=_label("%d 金币"%state.players[upgrade_actor].coins,21);wallet.custom_minimum_size.x=150;status.add_child(wallet)
	var build_text:=_label("%s    ·    %d把武器    火力 ×%.2f    生命 %.0f"%[FurBuildCatalog.NAMES[current.style],current.weapons,current.damage,current.health],18);build_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.add_child(build_text)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",19);column.add_child(row)
	for i in upgrade_options.size():
		var reason:String="等待泡泡选择" if ai_enabled and upgrade_actor==1 else ("金币不足 · 需要6金币" if upgrade_free_done and state.players[upgrade_actor].coins<6 else "")
		var card:=FurUIUpgradeCard.new();card.configure(upgrade_options[i],current,i,upgrade_free_done,reason);card.pressed.connect(_guard_overlay(_choose_upgrade.bind(i)));row.add_child(card);overlay_options.append(card)
	if upgrade_free_done:
		var leave:=_button("4  留钱，继续探索",_guard_overlay(_finish_upgrade_actor));Palette.apply_button(leave,"primary","compass");leave.disabled=ai_enabled and upgrade_actor==1;leave.custom_minimum_size=Vector2(310,52);leave.size_flags_horizontal=Control.SIZE_SHRINK_END;column.add_child(leave);overlay_options.append(leave)
	else:
		var hint:=_label("绿色数值为收益，陶土色为代价；更改后的属性按当前构筑计算。",15);hint.add_theme_color_override("font_color",Palette.MUTED);column.add_child(hint)

func _prepare_upgrade()->void:
	var seed_value:int=adventure.state.seed+adventure.state.round*177+upgrade_actor+(7919 if upgrade_free_done else 0)
	# Two required victories per chapter: the first genuine win must already
	# offer a behavior-changing core, rather than waiting for obsolete wave4.
	var core_offer:bool=adventure.state.chapter==0 and not adventure.state.chapter_cleared.is_empty() and not upgrade_free_done
	upgrade_options=Workshop.draft(builds[upgrade_actor],int(builds[1-upgrade_actor].style),seed_value,core_offer,upgrade_free_done,int(battle_plan.get("district",0)))
	_refresh()

func _sync_player_badges()->void:
	var state:Dictionary=adventure.state
	var journey:Dictionary={"chapter":state.chapter,"practice":state.practice,"stamps":state.chapter_cleared.size()}
	if arena!=null:
		journey.merge({"combat":true,"remaining":arena.model.remaining,"challenge":state.chapter_cleared.size()+1,"level":arena.model.players[0].build.level,"xp":arena.model.experience,"xp_cap":arena.model.next_level_experience})
	journey_badge.configure(journey)
	for i in mini(2,premium_player_badges.size()):
		var snap:Dictionary=state.players[i].duplicate(true);snap.active=i==state.active
		if arena!=null:
			var fighter:Dictionary=arena.model.players[i];snap.combat=true;snap.hp=fighter.hp;snap.max_hp=fighter.build.health;snap.skill_cd=fighter.skill_cd;snap.skill_key="Q" if i==0 else "/";snap.down=fighter.down;snap.revive=fighter.revive
		else:
			var lines:PackedStringArray=player_labels[i].text.split("\n");snap.summary=lines[2] if lines.size()>2 else ""
		premium_player_badges[i].configure(i,premium_faces[i],snap)
	settings_button.disabled=presentation in ["dice","walk","loading","result","landing_pause"]
	atlas_button.disabled=arena!=null or settings_button.disabled

func _decision_card(title:String,detail:String,callback:Callable,cost:String,icon:String,enabled:bool=true,reason:String="",roomy:bool=false)->FurChapterCard:
	var card:=Card.new();card.configure({"chapter":adventure.state.chapter,"heading":"%d  %s"%[option_row.get_child_count()+1,title],"detail":detail,"cost":cost,"icon":icon,"horizontal":true,"roomy":roomy,"enabled":enabled,"reason":reason})
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.pressed.connect(callback);option_row.add_child(card);return card

func _offer_reason(item:Dictionary)->String:
	if item.get("enabled",true):return ""
	var reasons:Dictionary={"insufficient_coins":"金币不足","already_taken_this_chapter":"本章已领取","already_cleared":"本站已有印章","two_distinct_challenges_required":"还需两处不同挑战印章","no_contract":"伙伴还未接取委托","inventory_full":"道具袋已满","resource_cap":"此资源已达到上限","commission_active":"已有进行中的委托","already_used":"本章已使用"}
	if item.has("cost") and int(adventure.state.players[adventure.state.active].coins)<int(item.cost):return "金币不足"
	if item.has("item") and adventure.state.players[adventure.state.active].items.size()>=2:return "道具袋已满 · 最多2件"
	return reasons.get(str(item.get("reason","")),"当前条件未满足")

func _offer_face(item:Dictionary,tile:Dictionary)->Dictionary:
	var label:String=str(item.label);var parts:PackedStringArray=label.split("：",true,1)
	var title:String=parts[0] if parts.size()>1 else label
	var detail:String=parts[1] if parts.size()>1 else ""
	var cost:String=("%d 金币"%int(item.cost) if int(item.get("cost",0))>0 else "不消耗金币") if item.has("cost") else "确认此项"
	var icon:String="compass";var station:String=tile.get("station","")
	if station=="item_shop":icon="bag"
	elif station=="forge":icon="forge"
	elif station=="commission":icon="route"
	elif tile.get("activity","")=="challenge":icon=["shield","mahjong","clock"][adventure.state.chapter]
	elif tile.get("activity","")=="chapter_exit":icon="star"
	elif tile.kind=="property":icon="shop"
	if title.length()>12:
		detail=label;title={"commission":"路线委托","forge":"选择补给","item_shop":"旅途道具"}.get(station,"旅途选择")
	if item.get("choice",-1)==3 or label.begins_with("离开") or label.begins_with("继续"):
		title="继续旅程";detail=label;icon="compass"
	if station=="commission":
		if item.has("commission_quote"):
			var q:Dictionary=item.commission_quote;var delivery:bool=int(item.choice)==0
			title="配送委托" if delivery else "勘探委托"
			detail=("送至 %02d 格"%int(q.target) if delivery else "经 %02d 格，再到 %02d 格"%[q.via,q.target])+"\n完成到账 %d 金 · 截止第%d手"%[q.reward,q.expires_turn]
			cost=("押金 " if delivery else "投入 ")+"%d 金币"%int(item.cost)
		elif item.choice==3:title="交货 / 离开";detail="兑现已完成的路线，或保留现金离开"
		elif item.choice==2:title="取消委托" if label.begins_with("取消") else "支援伙伴";detail=label
	elif station=="item_shop" and item.has("item"):
		title={"boost":"加骰券","shield":"护财符","swap":"换位铃"}.get(item.item,"旅途道具")
		detail={"boost":"下一次投骰 +2 步","shield":"抵消下一次破财格损失","swap":"投骰前交换双方位置"}.get(item.item,label)
		if int(item.get("discount",0))>0:detail+="\n本区经营优惠已减 %d 金"%item.discount
	elif tile.get("activity","")=="challenge":
		title="一起挑战" if int(item.choice)==0 else "继续探索"
		detail=["合作割草 · 用构筑守住海岛","实体麻将 · 同桌合力胡牌","时间回声 · 与过去协作"][adventure.state.chapter] if int(item.choice)==0 else "保留当前构筑，寻找下一处落点"
		if int(item.choice)!=0:icon="compass"
	elif station=="forge" and adventure.state.chapter==1 and int(item.choice)==2:
		title="更换麻将流派";detail="门清 / 刻子 / 连序，选择一项单槽技艺";icon="mahjong"
	return {"heading":title,"detail":detail,"cost":cost,"icon":icon}

func _show_settings()->void:
	if presentation in ["dice","walk","loading","result","landing_pause"]:return
	settings_return_menu=overlay_kind=="menu"
	settings_arena=arena;settings_arena_running=arena.running if arena!=null else false
	if arena!=null:arena.running=false
	var column:=_overlay_base("settings","把旅程调成你喜欢的样子","声音与界面偏好 · 即时生效")
	var settings:=FurUISettings.new();column.add_child(settings);settings.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var back:=_button("保存并返回",_leave_settings);Palette.apply_button(back,"primary","check");column.add_child(back)
	back.custom_minimum_size=Vector2(280,52);back.size_flags_horizontal=Control.SIZE_SHRINK_END

func _leave_settings()->void:
	FurUIPreferences.save();sound_muted=AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	if is_instance_valid(settings_arena) and settings_arena==arena:arena.running=settings_arena_running
	settings_arena=null
	if settings_return_menu:_show_menu()
	else:_resume_board()

func _sync_combat_ui()->void:
	if arena==null:return
	var battle=arena.model;var task:Dictionary=FurRouteCatalog.entry(battle.route);var fighters:Array=[]
	for i in 2:
		var fighter:Dictionary=battle.players[i].duplicate(true);var count:=0
		for bait in battle.baits:
			if bait.owner==i:count+=1
		fighter.baits=count;fighters.append(fighter)
	combat_hud.configure({"players":fighters,"ai":ai_enabled,"goal":task.goal,"rule":task.rule,"reward":task.reward,"progress":battle.rule_state.progress,"target":battle.rule_state.target,"rewarded":battle.rule_state.rewarded})

func _toggle_sound()->void:
	super._toggle_sound();FurUIPreferences.ensure_loaded();FurUIPreferences.muted=sound_muted;FurUIPreferences.save()
