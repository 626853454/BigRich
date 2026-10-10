class_name FurballSession
extends Node3D
const Evaluation=preload("res://scripts/furball/campaign_evaluation.gd")
const CampaignSummary=preload("res://scripts/furball/campaign_summary.gd")
const BoardView=preload("res://scripts/furball/board_view.gd")
const SnapshotDomains=preload("res://scripts/furball/snapshot_domains.gd")
const Supplies=preload("res://scripts/furball/team_supplies.gd")
const OrderPaths=preload("res://scripts/furball/shared_order_paths.gd")
const GMBoard = preload("res://scripts/furball/gm_board_commands.gd")

var model:=FurCombatModel.new()
var view: FurCombatView
var bridge: FurNetBridge
var mode: String="solo"
var hud: Control
var top_labels: Array[Label]=[]
var wave_label: Label
var footer: Label
var modal: PanelContainer
var modal_box: VBoxContainer
var address: LineEdit
var displayed_phase: String=""
var displayed_drafts: String=""
var status: String=""
var ui_clock:=0.0
var net_clock:=0.0
var input_clock:=0.0
var pending_dash:=false
var pending_skill:=false
var last_network_event:=0
var rule_label: Label
var rule_progress: Label
var order_progress:Label
var challenge_progress:Label
var order_route_hint_key:=""
var order_route_hint:Dictionary={}
var show_rules:=false
var station_header: Panel
var last_snapshot_elapsed := -1.0
var network_styles: Array[int] = [0,1]
var host_kit: OptionButton
var boss_panel: PanelContainer
var boss_label: Label
var boss_bar: ProgressBar
var muted:=false
var seed_text:=""
var stored_address:="127.0.0.1"
var network_kit_selection:=0
var host_seed:=0
var client_ready_for_frames:=false
var last_snapshot_msec:=0
var synchronization_panel:PanelContainer
var synchronization_label:Label
var board_view:BoardView
var gm_router:FurballGMCommands
var gm_console:FurballGMConsole
var gm_board:GMBoard
var last_remote_input_msec:=0
var rejected_snapshots:=0
const REMOTE_INPUT_TIMEOUT_MSEC:=600
const SETTINGS_PATH="user://furball-settings.cfg"

func _ready() -> void:
	view=FurCombatView.new();view.name="CombatView";add_child(view)
	bridge=FurNetBridge.new();bridge.name="NetBridge";add_child(bridge)
	bridge.guest_connected.connect(_guest_connected)
	bridge.begin_received.connect(_begin_received)
	bridge.frame_received.connect(_frame_received)
	bridge.input_received.connect(_receive_remote_input)
	bridge.choice_received.connect(func(kind,choice):_choose(kind,choice,1))
	bridge.event_choice_received.connect(func(choice,serial):_choose_board_event(choice,serial,1))
	bridge.route_suggestion_received.connect(func(request):_receive_route_suggestion(request,1))
	bridge.draft_choice_received.connect(func(choice,token,wave,revision):_receive_draft_choice(choice,token,wave,revision,1))
	bridge.order_pickup_received.connect(func(choice,token,wave,cargoid,revision):_receive_order_pickup(choice,token,wave,cargoid,revision,1))
	bridge.connection_problem.connect(_connection_problem)
	_load_preferences()
	_create_ui()
	gm_board=GMBoard.new();gm_board.configure(model)
	gm_router=FurballGMCommands.new();gm_router.configure(model,func():return mode,FurballGMCommands.development_requested(),gm_board.execute)
	gm_router.command_recorded.connect(_record_gm)
	gm_console=FurballGMConsole.new();gm_console.configure(gm_router);hud.add_child(gm_console)
	board_view=BoardView.new();hud.add_child(board_view);board_view.action_requested.connect(_choose);board_view.suggestion_requested.connect(_submit_route_suggestion);board_view.hide()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if gm_console!=null and gm_console.blocks_gameplay_input():return
	if model.phase=="battle" and event.physical_keycode in [KEY_E,KEY_R,KEY_COMMA,KEY_PERIOD]:
		var second:bool=event.physical_keycode in [KEY_COMMA,KEY_PERIOD]
		if second and (mode!="local" or model.players.size()!=2):return
		var actor:int=1 if second or mode=="client" else 0
		_submit_order_pickup(1 if event.physical_keycode in [KEY_R,KEY_PERIOD] else 0,actor);return
	if event.physical_keycode==KEY_F8:_toggle_effects()
	if event.physical_keycode==KEY_F9:_toggle_sound()
	if event.physical_keycode==KEY_F11:
		_toggle_fullscreen()
	if event.physical_keycode==KEY_F1:show_rules=not show_rules;_refresh_ui()
	if model.phase=="board" and event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_SPACE]:
		if board_view!=null and board_view.busy():return
		var actor:=1 if mode=="client" else (int(model.board.state.active) if mode=="local" else 0)
		var choice:int=event.physical_keycode-KEY_1
		if model.board.state.stage=="move" and model.players.size()==2 and choice in [0,1,2]:
			if mode=="local" and event.shift_pressed:
				_submit_route_suggestion(choice-1,1-int(model.board.state.active));return
			if mode in ["host","client"] and actor!=int(model.board.state.active):
				_submit_route_suggestion(choice-1,actor);return
		if mode=="local" and event.shift_pressed:return
		match str(model.board.state.stage):
			"roll":
				if event.physical_keycode in [KEY_SPACE,KEY_1]:_choose("board_roll",board_view.roll_order_choice() if board_view!=null else 0,actor)
			"move":
				if choice in [0,1,2]:_choose("board_move",choice,actor)
			"business":
				if choice in [0,1,2] and board_view!=null:board_view._act(choice)
			"event_choice":
				if choice in [0,1,2] and board_view!=null:board_view._act(choice)
	if event.physical_keycode in [KEY_1,KEY_2,KEY_3] and model.phase in ["draft","route"]:
		var player_index:=1 if mode=="client" else 0
		if mode=="local" and model.phase=="draft" and model.draft_done[0]:player_index=1
		var choice:int=event.physical_keycode-KEY_1
		if model.phase=="draft" or choice<2:_choose(model.phase,choice,player_index)
	if event.physical_keycode==KEY_ESCAPE:
		_return_to_camp()

func _return_to_camp() -> void:
	if mode!="client":model.cancel_shared_order()
	model.payoff.clear_pending();model.payoff_state={}
	model.cart_impact.reset();model.district.cart_sweeps.clear()
	client_ready_for_frames=false;pending_dash=false;pending_skill=false
	input_clock=0;net_clock=0;mode="solo";model.phase="camp";view.local_duo=false
	last_remote_input_msec=0
	bridge.close();status="已返回营地";displayed_phase="";_refresh_ui()

func _load_preferences() -> void:
	var config:=ConfigFile.new()
	if config.load(SETTINGS_PATH)!=OK:return
	view.low_fx=config.get_value("presentation","low_fx",false)==true
	muted=config.get_value("presentation","muted",false)==true
	view.set_music(config.get_value("presentation","music",true)==true)
	AudioServer.set_bus_mute(0,muted)

func _save_preferences() -> void:
	var config:=ConfigFile.new();config.set_value("presentation","low_fx",view.low_fx)
	config.set_value("presentation","muted",muted)
	config.set_value("presentation","music",view.music_enabled);config.save(SETTINGS_PATH)

func _toggle_effects() -> void:
	view.low_fx=not view.low_fx;_save_preferences();displayed_phase="";_refresh_ui()

func _toggle_sound() -> void:
	muted=not muted;AudioServer.set_bus_mute(0,muted);_save_preferences();displayed_phase="";_refresh_ui()

func _toggle_music() -> void:
	view.set_music(not view.music_enabled);_save_preferences();displayed_phase="";_refresh_ui()

func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	displayed_phase="";_refresh_ui()

func _physics_process(delta: float) -> void:
	if model.phase!="battle":return
	var direction:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	# Camera looks down from +Z, so W moves up the displayed field.
	var dash:=Input.is_action_just_pressed("fur_dash")
	var skill:=Input.is_action_just_pressed("fur_skill")
	var blocked:=gm_console!=null and gm_console.blocks_gameplay_input()
	if blocked:direction=Vector2.ZERO;dash=false;skill=false;pending_dash=false;pending_skill=false
	if mode=="client":
		pending_dash=pending_dash or dash;pending_skill=pending_skill or skill
		input_clock+=delta
		if input_clock>=.05:
			input_clock=0;bridge.send_input(direction,pending_dash,pending_skill)
			pending_dash=false;pending_skill=false
		return
	model.set_input(0,direction,dash,skill)
	_expire_remote_input(Time.get_ticks_msec())
	if mode=="local":
		var second:=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		model.set_input(1,Vector2.ZERO if blocked else second,not blocked and Input.is_action_just_pressed("fur_dash_p2"),not blocked and Input.is_action_just_pressed("fur_skill_p2"))
	model.tick(delta)

func _receive_remote_input(direction:Vector2,dash:bool,skill:bool) -> void:
	if mode!="host" or model.phase!="battle":return
	last_remote_input_msec=Time.get_ticks_msec()
	model.set_input(1,direction,dash,skill)

func _expire_remote_input(now:int) -> void:
	# Keep brief packet gaps tolerable, but never hold a direction indefinitely.
	if mode=="host" and model.phase=="battle" and model.players.size()==2 and now-last_remote_input_msec>=REMOTE_INPUT_TIMEOUT_MSEC:
		model.set_input(1,Vector2.ZERO,false,false)

func _process(delta: float) -> void:
	ui_clock+=delta
	if ui_clock>.12:ui_clock=0;_refresh_ui()
	# Choices and routes must keep synchronizing while combat simulation is paused.
	if mode=="host":
		net_clock+=delta
		if net_clock>=.083:
			net_clock=0;bridge.publish(_pack_frame())

func start_game(styles: Array[int], selected_mode: String="solo", run_seed: int=0, skip_board:bool=false,run_token:int=0) -> void:
	if run_seed == 0: run_seed = randi_range(1,2147483647)
	mode=selected_mode;model.start(styles,run_seed,skip_board,run_token);view.local_duo=selected_mode=="local";view.bind(model)
	bridge.run_token=int(model.board.state.run_token)
	model.enemy_behaviors.authority=selected_mode!="client"
	client_ready_for_frames=selected_mode=="client"
	last_snapshot_msec=Time.get_ticks_msec()
	last_remote_input_msec=last_snapshot_msec
	pending_dash=false;pending_skill=false;input_clock=0;net_clock=0
	show_rules=false
	last_network_event=0
	last_snapshot_elapsed=-1.0;rejected_snapshots=0
	displayed_phase="";displayed_drafts="";status="";_refresh_ui()

func _host(styles: Array[int] = [0,1]) -> void:
	client_ready_for_frames=false
	host_seed=_requested_seed()
	if host_seed<0:return
	var error:=bridge.host()
	if error!=OK:status="创建房间失败：%s" % error_string(error);displayed_phase="";return
	network_styles.assign(styles)
	mode="host";model.phase="waiting";status="等待队友加入。端口 27842；目前支持直接地址连接。"
	displayed_phase="";_refresh_ui()

func _join() -> void:
	client_ready_for_frames=false
	var ip:=address.text.strip_edges()
	if ip.is_empty():return
	var error:=bridge.join(ip)
	if error!=OK:status="无法连接：%s" % error_string(error);displayed_phase="";return
	mode="client";model.phase="waiting";status="正在连接队友…";displayed_phase="";_refresh_ui()

func _guest_connected(_peer: int) -> void:
	if mode!="host":return
	start_game(network_styles,"host",host_seed);bridge.begin(model.seed_value,network_styles)

func _begin_received(run_seed: int, styles: Array[int],run_token:int) -> void:
	if mode!="client":return
	network_styles.assign(styles)
	start_game(styles,"client",run_seed,false,run_token)

func _connection_problem(message: String) -> void:
	if mode!="client":model.cancel_shared_order()
	client_ready_for_frames=false
	status=message;mode="solo";model.phase="camp";view.local_duo=false;displayed_phase=""
	# Peer-disconnection signals can arrive inside ENet's polling callback.
	# Replacing / closing that peer must happen after the callback returns.
	bridge.call_deferred("close_if_current",bridge.multiplayer.multiplayer_peer);_refresh_ui()

func _pack_pool(pool: FurEntityPool) -> Array:
	var packed: Array=[]
	for slot in pool.active:
		packed.append([pool.pos[slot],pool.velocity[slot],pool.hp[slot],pool.max_hp[slot],pool.kind[slot],pool.owner[slot],pool.marked[slot],pool.life[slot],pool.identity[slot]])
	return packed

func _pack_frame() -> Dictionary:
	return {"phase":model.phase,"wave":model.wave,"remaining":model.remaining,"elapsed":model.elapsed,"seed_value":model.seed_value,"shared_order":model.shared_order.snapshot(),"patrol":model.patrol.snapshot(),"challenge_contract":model.challenge_contract.snapshot(),"legacy_diagnostic":model.skip_board_for_checks,"task_formation_preview":model.task_formation_preview.duplicate(true),
		"players":model.players.duplicate(true),"enemies":_pack_pool(model.enemies),"shots":_pack_pool(model.shots),
		"pickups":_pack_pool(model.pickups),"baits":model.baits.duplicate(true),"events":model.network_fx.duplicate(true),"key_events":model.network_events.duplicate(true),
		"experience":model.experience,"next_xp":model.next_level_experience,"draft":model.draft_options.duplicate(true),"order_draft_pending":model.order_draft_pending.duplicate(),"draft_is_order":model.draft_is_order.duplicate(),"draft_revisions":model.draft_revisions.duplicate(),"done":model.draft_done.duplicate(),"dice":model.dice,
		"round_results":_round_results_snapshot(),"board":model.board.snapshot(),"district":model.district.snapshot(),"estate":model.estate.state.duplicate(true),"enemy_behavior_state":model.enemy_behaviors.presentation(),"payoff":model.payoff.presentation(),"debug_run":model.debug_run,"debug_history":model.debug_history.duplicate(true),"district_cash":model.district_cash,
		"route":model.route,"rule":model.rule_state.duplicate(true),"hazards":model.hazards.duplicate(true),"route_history":model.route_history.duplicate(),"rule_rewards":model.rule_rewards,"boss_pattern":model.boss_pattern,"boss_cycles":model.boss_cycles}

func _unpack_pool(pool: FurEntityPool, packed: Array) -> void:
	pool.clear()
	for entry in packed:
		var slot:=pool.acquire(entry[0],entry[2],entry[4])
		if slot<0:break
		pool.velocity[slot]=entry[1];pool.max_hp[slot]=entry[3];pool.owner[slot]=entry[5];pool.marked[slot]=entry[6]
		if entry.size() > 7: pool.life[slot]=entry[7]
		if entry.size() > 8: pool.identity[slot]=entry[8]

func _frame_received(frame: Dictionary) -> void:
	# Reliable begin and unreliable snapshots use different ENet channels.
	# A snapshot may arrive first; wait for begin to bind this run's view.
	if mode!="client" or not client_ready_for_frames:return
	if not SnapshotDomains.validate(frame):
		rejected_snapshots=mini(1000000000,rejected_snapshots+1);return
	if not frame.get("board") is Dictionary or frame.board.run_token!=model.board.state.run_token or frame.get("seed_value")!=model.seed_value:
		rejected_snapshots=mini(1000000000,rejected_snapshots+1);return
	var previous_wave := model.wave
	var interval: float = float(frame.elapsed)-last_snapshot_elapsed if last_snapshot_elapsed>=0 else .083
	model.shared_order.apply_state(frame.shared_order,model.seed_value,frame.players.size(),model.board.state.run_token)
	model.patrol.apply_state(frame.patrol,model.seed_value,model.board.state.run_token);model.skip_board_for_checks=frame.legacy_diagnostic
	model.challenge_contract.apply_state(frame.challenge_contract,model.seed_value,model.board.state.run_token,frame.challenge_contract.wave,frame.challenge_contract.district,frame.elapsed)
	model.task_formation_preview=frame.task_formation_preview.duplicate(true)
	if frame.has("round_results"):_apply_round_results(frame.round_results)
	if frame.has("board"):model.board.apply_state(frame.board)
	if frame.has("district"):model.district.apply_state(frame.district)
	if frame.has("estate"):_apply_estate_state(frame.estate)
	if frame.has("enemy_behavior_state"):_apply_enemy_behavior_state(frame.enemy_behavior_state)
	model.payoff_state=frame.get("payoff",{});model.debug_run=frame.get("debug_run",false);model.debug_history.assign(frame.get("debug_history",[]));model.district_cash=frame.get("district_cash",0)
	model.phase=frame.phase;model.wave=frame.wave;model.remaining=frame.remaining;model.elapsed=frame.elapsed
	model.order_draft_pending.assign(frame.order_draft_pending);model.draft_is_order.assign(frame.draft_is_order);model.draft_revisions.assign(frame.draft_revisions)
	model.players.assign(frame.players);model.draft_options=frame.draft;model.draft_done.assign(frame.done);model.dice=frame.dice
	model.route=frame.get("route",0);model.rule_state=frame.get("rule",{});model.hazards.assign(frame.get("hazards",[]))
	model.route_history.assign(frame.get("route_history",[]));model.rule_rewards=frame.get("rule_rewards",0)
	model.boss_pattern=frame.get("boss_pattern",0);model.boss_cycles=frame.get("boss_cycles",0)
	_apply_baits(frame.baits);model.experience=frame.experience;model.next_level_experience=frame.next_xp
	# Merge by authority sequence so retransmitted warning history does not flash
	# twice, while a render frame consuming events cannot erase unsent warnings.
	var received: Array = frame.events.duplicate()
	received.append_array(frame.get("key_events", []))
	received.sort_custom(func(a, b): return a.get("sequence", 0) < b.get("sequence", 0))
	for event in received:
		var sequence: int = event.get("sequence", 0)
		if sequence <= last_network_event: continue
		last_network_event = sequence
		if event.get("wave", model.wave) != model.wave or model.elapsed - event.get("time", model.elapsed) > 1.0: continue
		if model.events.size() < 96: model.events.append(event)
	_unpack_pool(model.enemies,frame.enemies);_unpack_pool(model.shots,frame.shots);_unpack_pool(model.pickups,frame.pickups)
	model.grid.rebuild(model.enemies)
	if previous_wave!=model.wave: view.clear_network_motion()
	view.receive_network_motion(interval)
	last_snapshot_elapsed=float(frame.elapsed)
	last_snapshot_msec=Time.get_ticks_msec()

func _choose(kind: String, choice: int, player_index: int) -> void:
	if kind=="draft":
		_choose_draft(choice,player_index);return
	if kind=="board_event":
		_choose_board_event(choice,int(model.board.state.get("event_serial",0)),player_index);return
	if mode=="client":bridge.send_choice(kind,choice);return
	if kind.begins_with("board_"):model.board_choose(kind,choice,player_index)
	if kind=="route":
		var leader: int=model.wave%2 if mode=="host" else player_index
		if mode!="host" or player_index==leader:model.choose_route(choice)
	displayed_phase="";_refresh_ui()

func _choose_board_event(choice:int,event_serial:int,player_index:int)->void:
	if mode=="client":bridge.send_board_event(choice,event_serial);return
	model.board_choose("board_event",choice,player_index,event_serial)
	displayed_phase="";_refresh_ui()

func _submit_route_suggestion(adjustment:int,actor:int)->void:
	var current:Dictionary=model.board.state.get("suggestion",{})
	var request:Dictionary={"run_token":int(model.board.state.run_token),"round_token":int(model.board.state.round),"adjustment":adjustment,"expected_revision":int(current.get("revision",0))}
	if mode=="client":bridge.send_route_suggestion(request);return
	_receive_route_suggestion(request,actor)

func _receive_route_suggestion(request:Dictionary,actor:int)->void:
	if mode=="client":return
	if model.board_suggest(request,actor,Time.get_ticks_msec()):_refresh_ui()

func _style() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color(.07,.095,.17,.94)
	box.border_color=Color("637b95");box.set_border_width_all(1);box.set_corner_radius_all(12)
	box.content_margin_left=20;box.content_margin_right=20;box.content_margin_top=14;box.content_margin_bottom=14
	return box

func _label(text: String, size: int=18) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label

func _button(text: String, action: Callable, parent: Node=null) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(220,46)
	button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(action)
	var normal:=_style();normal.bg_color=Color("344866");button.add_theme_stylebox_override("normal",normal)
	var hover:=normal.duplicate() as StyleBoxFlat;hover.bg_color=Color("526c84")
	button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("pressed",hover)
	(parent if parent!=null else modal_box).add_child(button);return button

func _create_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer);hud=Control.new();layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.size=get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func():hud.size=get_viewport().get_visible_rect().size)
	var theme:=Theme.new();var font:=FurVisualStyle.font()
	theme.default_font=font;theme.default_font_size=18;theme.set_color("font_color","Label",Color("f4efd8"));hud.theme=theme
	for index in 2:
		var panel:=PanelContainer.new();hud.add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if index==0 else Control.PRESET_TOP_RIGHT)
		panel.offset_left=20 if index==0 else -480;panel.offset_right=480 if index==0 else -20
		panel.offset_top=16;panel.offset_bottom=112
		panel.custom_minimum_size=Vector2(460,96);panel.add_theme_stylebox_override("panel",_style())
		var text:=_label("",17);panel.add_child(text);top_labels.append(text)
	station_header=Panel.new();hud.add_child(station_header)
	station_header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	station_header.offset_left=-170;station_header.offset_right=170;station_header.offset_top=16;station_header.offset_bottom=110
	station_header.add_theme_stylebox_override("panel",_style());station_header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	wave_label=_label("",22);hud.add_child(wave_label)
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);wave_label.offset_left=-120;wave_label.offset_right=120;wave_label.offset_top=20;wave_label.offset_bottom=95
	wave_label.custom_minimum_size=Vector2(240,75);wave_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	rule_progress=_label("",14);hud.add_child(rule_progress)
	rule_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	rule_progress.offset_left=-160;rule_progress.offset_right=160;rule_progress.offset_top=84;rule_progress.offset_bottom=108
	rule_progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	order_progress=_label("",15);hud.add_child(order_progress);order_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	order_progress.offset_left=-310;order_progress.offset_right=310;order_progress.offset_top=232;order_progress.offset_bottom=260
	order_progress.autowrap_mode=TextServer.AUTOWRAP_OFF;order_progress.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	order_progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	order_progress.add_theme_color_override("font_shadow_color",Color.BLACK);order_progress.add_theme_constant_override("shadow_offset_x",1);order_progress.add_theme_constant_override("shadow_offset_y",1)
	challenge_progress=_label("",15);hud.add_child(challenge_progress);challenge_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	challenge_progress.offset_left=-310;challenge_progress.offset_right=310;challenge_progress.offset_top=268;challenge_progress.offset_bottom=296
	challenge_progress.autowrap_mode=TextServer.AUTOWRAP_OFF;challenge_progress.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	challenge_progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;challenge_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	challenge_progress.add_theme_color_override("font_color",Color("fbe69a"));challenge_progress.add_theme_color_override("font_shadow_color",Color.BLACK)
	challenge_progress.add_theme_constant_override("shadow_offset_x",1);challenge_progress.add_theme_constant_override("shadow_offset_y",1)
	var footer_panel := PanelContainer.new();hud.add_child(footer_panel)
	footer_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer_panel.offset_left=20;footer_panel.offset_top=-58;footer_panel.offset_right=-20;footer_panel.offset_bottom=-12
	footer_panel.add_theme_stylebox_override("panel",_style());footer_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	footer=_label("",15);footer_panel.add_child(footer)
	boss_panel=PanelContainer.new();hud.add_child(boss_panel)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boss_panel.offset_left=-230;boss_panel.offset_right=230;boss_panel.offset_top=-116;boss_panel.offset_bottom=-66
	boss_panel.add_theme_stylebox_override("panel",_style());boss_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var boss_box:=VBoxContainer.new();boss_panel.add_child(boss_box)
	boss_label=_label("",14);boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;boss_box.add_child(boss_label)
	boss_bar=ProgressBar.new();boss_bar.show_percentage=false;boss_bar.custom_minimum_size=Vector2(420,8);boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var boss_fill:=StyleBoxFlat.new();boss_fill.bg_color=Color("cca9ff");boss_fill.set_corner_radius_all(4)
	var boss_back:=StyleBoxFlat.new();boss_back.bg_color=Color("403c56");boss_back.set_corner_radius_all(4)
	boss_bar.add_theme_stylebox_override("fill",boss_fill);boss_bar.add_theme_stylebox_override("background",boss_back);boss_box.add_child(boss_bar)
	var rule_panel := PanelContainer.new();hud.add_child(rule_panel)
	rule_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	rule_panel.offset_left=20;rule_panel.offset_right=620;rule_panel.offset_top=130;rule_panel.offset_bottom=220
	var rule_style:=_style();rule_style.content_margin_top=8;rule_style.content_margin_bottom=8
	rule_panel.add_theme_stylebox_override("panel",rule_style);rule_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rule_label=_label("",16);rule_panel.add_child(rule_label)
	rule_panel.resized.connect(_position_order_hud)
	synchronization_panel=PanelContainer.new();hud.add_child(synchronization_panel)
	synchronization_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	synchronization_panel.offset_left=-300;synchronization_panel.offset_right=300
	synchronization_panel.offset_top=-195;synchronization_panel.offset_bottom=-126
	synchronization_panel.add_theme_stylebox_override("panel",_style());synchronization_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	synchronization_label=_label("",16);synchronization_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	synchronization_label.add_theme_color_override("font_color",Color("ffd587"));synchronization_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	synchronization_panel.add_child(synchronization_label);synchronization_panel.visible=false
	modal=PanelContainer.new();hud.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left=-430;modal.offset_right=430;modal.offset_top=-235;modal.offset_bottom=235;modal.custom_minimum_size=Vector2(860,0)
	modal.grow_vertical=Control.GROW_DIRECTION_END;modal.add_theme_stylebox_override("panel",_style())
	modal_box=VBoxContainer.new();modal_box.add_theme_constant_override("separation",12);modal.add_child(modal_box)

func _clear_modal() -> void:
	for child in modal_box.get_children():modal_box.remove_child(child);child.queue_free()

func _refresh_ui() -> void:
	var snapshot_age:=float(Time.get_ticks_msec()-last_snapshot_msec)/1000.0
	synchronization_panel.visible=mode=="client" and client_ready_for_frames and model.phase in ["battle","draft","route","board"] and snapshot_age>=.75
	if synchronization_panel.visible:synchronization_label.text="等待房主更新 · %.1f 秒\n收到更新会自动恢复；Esc 可返回营地" % snapshot_age
	for i in 2:
		top_labels[i].get_parent().visible=i<model.players.size() and model.phase not in ["camp","waiting"]
		if i>=model.players.size():continue
		var p: Dictionary=model.players[i];var build: Dictionary=p.build
		var resource := "锅能 %d%%" % int(p.pot/float(build.get("pot_cap",50))*100) if build.style==0 else ("蓄能 %d%%" % int(p.charge/2.5*100) if build.style==1 else "场上诱饵 %d / 12" % model.baits.size())
		var skill_key := "/" if i==1 and mode=="local" else "Q"
		var skill_status := "%s 就绪" % skill_key if p.skill_cd<=0 else "%s %.1f 秒" % [skill_key,p.skill_cd]
		var down_status := "救援 %.1f / 2.5 秒" % p.revive if model.players.size()>1 else "倒下 · 本局结束"
		var provider:=model.protecting_guard(i)
		var action_status := _personal_payoff_text(build)
		if provider>=0 and provider!=i:action_status+=" · 护盾 %d%%" % int(model.players[provider].build.shield_reduction*100)
		top_labels[i].text="P%d  %s   Lv.%d\n生命 %d / %d   武器 %d / 6   %s\n%s · %s · 击败 %d" % [i+1,FurBuildCatalog.NAMES[build.style],build.level,int(ceil(p.hp)),int(build.health),build.weapons,down_status if p.down else resource,skill_status,action_status,build.kills]
	boss_panel.visible=false
	if model.phase=="battle":
		for slot in model.enemies.active:
			if model.enemies.kind[slot]!=2:continue
			boss_panel.visible=true;boss_bar.max_value=model.enemies.max_hp[slot];boss_bar.value=maxf(0,model.enemies.hp[slot])
			var boss_attack:=FurBossCatalog.attack(model.wave,model.boss_pattern)
			boss_label.text="%s · %d / %d · %s" % [FurBossCatalog.name_for_wave(model.wave),int(ceil(model.enemies.hp[slot])),int(ceil(model.enemies.max_hp[slot])),"落点通知" if boss_attack.id=="notice" else "近身收账"]
			break
	wave_label.visible=model.phase not in ["camp","waiting"]
	station_header.visible=wave_label.visible
	wave_label.text="第 %d / 6 站\n%02d:%02d" % [model.wave,int(maxf(0,model.remaining))/60,int(maxf(0,model.remaining))%60]
	if model.phase=="board":wave_label.text="第 %d / 6 轮\n棋盘经营" % int(model.board.state.round)
	if model.phase=="battle" and model.remaining<=0: wave_label.text="第 %d / 6 站\n清场 · 击败收账员" % model.wave
	rule_label.get_parent().visible=model.phase=="battle" and (show_rules or model.elapsed-model.rule_state.get("started_at",0)<2.5)
	rule_progress.visible=model.phase=="battle"
	order_progress.visible=model.phase=="battle" and not model.skip_board_for_checks
	if order_progress.visible:order_progress.text=_shared_order_hud_text()
	challenge_progress.visible=model.phase=="battle" and not model.skip_board_for_checks and model.board.state.challenge
	if challenge_progress.visible:challenge_progress.text=_challenge_hud_text()
	if model.phase=="battle" and not model.rule_state.is_empty():
		if model.skip_board_for_checks:
			var contract := FurRouteCatalog.entry(model.route)
			rule_progress.text="%s %.1f/%.0f%s · F1 规则" % [["借圈清怪","兑现订单","歇脚秒数"][model.route],model.rule_state.progress,model.rule_state.target," ✓" if model.rule_state.rewarded else ""]
			rule_label.text="%s · %s\n%s\n%s  %.1f / %.0f%s" % [FurRouteCatalog.STATIONS[clampi(model.wave-1,0,5)],contract.name,contract.rule,contract.goal,model.rule_state.progress,model.rule_state.target,"  ✓ 已兑现："+contract.reward if model.rule_state.rewarded else "  → "+contract.reward]
		else:
			var d:Dictionary=model.district.state
			var completed:bool=d.get("completed",false)
			rule_progress.text=_district_progress_text(d,int(model.board.state.cash))
			rule_label.text="%s\n%s\n目标 %.1f / %.0f%s · 地产等级 %d · 兑现后利润回钱袋" % [str(d.name),str(d.goal),float(d.progress),float(d.target)," ✓ 已完成" if completed else "",int(model.board.state.licenses[model.route])]
			if model.board.state.challenge:
				rule_label.text="%s\n%s\n目标 %.1f/%.0f%s · 地产%d · 抢档：%.0f秒清群 + 完整委托" % [str(d.name),str(d.goal),float(d.progress),float(d.target)," ✓" if completed else "",int(model.board.state.licenses[model.route]),float(model.challenge_contract.WINDOW)]
			var patrol:Dictionary=model.patrol.preview(int(model.board.state.position))
			if patrol.get("ok",false):
				var pressure:Dictionary=model.patrol.combined_pressure(float(model.board.state.event_pressure_add),bool(patrol.pressure_active),bool(model.board.state.challenge))
				rule_label.text+="\n巡街%02d/%02d · 本场刷新×%.2f保持 · %s" % [int(patrol.threat_tiles[0]),int(patrol.threat_tiles[1]),float(pressure.spawn_multiplier),"下轮%02d" % int(patrol.next_if_complete) if model.patrol.state.repelled else "成%02d/未成%02d" % [int(patrol.next_if_complete),int(patrol.next_if_incomplete)]]
			if not model.task_formation_preview.is_empty() and not (mode=="client" and snapshot_age>=.75):rule_label.text+="\n蓝色双圈：下一群可能换入口；过早/不安全回退"
	_position_order_hud.call_deferred()
	footer.text="P1 移动 WASD · 冲刺 空格 · 技能 Q"
	if mode in ["host","client"]: footer.text="你是 P%d · 移动 WASD · 冲刺 空格 · 技能 Q" % (1 if mode=="host" else 2)
	elif model.players.size()>1: footer.text+="  |  P2 方向键 · Enter · /"
	footer.text+=("  |  GM调试局" if model.debug_run else "")
	footer.text+="  |  F1 规则 · F8 "+("精简" if view.low_fx else "完整")+" · F9 "+("静音" if muted else "声音")+" · F11 全屏 · Esc 营地"
	if model.phase=="battle":
		footer.text+="  |  近箱 E/R 拾箱"+(" · P2 ,/." if mode=="local" else "")
		footer.text+="  |  经验 %d/%d" % [model.experience,model.next_level_experience]
	modal.visible=model.phase not in ["battle","board"]
	if board_view!=null:
		board_view.visible=model.phase=="board"
		if board_view.visible:_draw_board()
	var draft_signature:=str(model.board.state) if model.phase=="board" else str([model.draft_done,model.draft_revisions,model.draft_is_order])
	if displayed_phase==model.phase and (model.phase not in ["draft","board"] or displayed_drafts==draft_signature):return
	displayed_phase=model.phase;displayed_drafts=draft_signature;_clear_modal()
	if model.phase not in ["victory","defeat"]:
		modal.offset_top=-235;modal.offset_bottom=235;modal.add_theme_stylebox_override("panel",_style())
	match model.phase:
		"camp":
			modal_box.add_child(_label("毛球暴走",36))
			modal_box.add_child(_label("夜市的承诺长出了腿，开始向顾客收账。毛球搭档要抢回关门铃，让夜市下班！\n武器自动攻击，走位与技能由你决定。六轮夜市棋盘：掷骰移动 → 买店升级或接挑战 → 街区割草 → 成长与利润回到棋盘。第三、六站要击败巨型爆米花。"))
			if not status.is_empty():modal_box.add_child(_label(status))
			var seed_row:=HBoxContainer.new();modal_box.add_child(seed_row)
			var seed_caption:=_label("种子：单人 / 本地 / 房主，留空随机",15)
			seed_caption.autowrap_mode=TextServer.AUTOWRAP_OFF;seed_caption.custom_minimum_size=Vector2(310,36)
			seed_caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;seed_row.add_child(seed_caption)
			var seed_input:=LineEdit.new();seed_input.text=seed_text;seed_input.placeholder_text="输入结算种子再试开局";seed_input.max_length=10
			seed_input.custom_minimum_size=Vector2(280,36);seed_row.add_child(seed_input)
			seed_input.text_changed.connect(func(value):seed_text=value)
			var row:=HBoxContainer.new();modal_box.add_child(row)
			for style in 3:
				var style_button:=_button("单人 · "+FurBuildCatalog.NAMES[style],_start_callback(style),row)
				style_button.tooltip_text=FurBuildCatalog.DESCRIPTIONS[style]
			modal_box.add_child(_label("甩锅：接伤回锅能；摸鱼：站定蓄能、移动齐射；画饼：放饵聚怪、延时引爆。",15))
			var local_row:=HBoxContainer.new();modal_box.add_child(local_row)
			_button("本地双人 · 甩锅＋摸鱼",_local_callback([0,1]),local_row)
			_button("本地双人 · 甩锅＋画饼",_local_callback([0,2]),local_row)
			modal_box.add_child(_label("双人直连测试：房主创建后，队友输入房主的局域网地址加入。",15))
			var network_row:=HBoxContainer.new();modal_box.add_child(network_row)
			host_kit=OptionButton.new();host_kit.add_item("甩锅＋摸鱼");host_kit.add_item("甩锅＋画饼")
			host_kit.select(network_kit_selection);host_kit.item_selected.connect(func(value):network_kit_selection=value)
			host_kit.custom_minimum_size=Vector2(180,46);network_row.add_child(host_kit)
			var host_button:=_button("创建房间",func():_host(_selected_host_styles()),network_row)
			host_button.custom_minimum_size=Vector2(150,46)
			address=LineEdit.new();address.text=stored_address;address.text_changed.connect(func(value):stored_address=value)
			address.placeholder_text="房主地址";address.custom_minimum_size=Vector2(180,46);network_row.add_child(address)
			var join_button:=_button("加入房间",func():_join(),network_row);join_button.custom_minimum_size=Vector2(150,46)
			var settings_row:=HBoxContainer.new();modal_box.add_child(settings_row)
			var effect_button:=_button("表现："+("精简" if view.low_fx else "完整")+" · F8",_toggle_effects,settings_row);effect_button.custom_minimum_size=Vector2(185,46)
			var sound_button:=_button("声音："+("静音" if muted else "开启")+" · F9",_toggle_sound,settings_row);sound_button.custom_minimum_size=Vector2(175,46)
			var music_button:=_button("夜市旋律："+("开" if view.music_enabled else "关"),_toggle_music,settings_row);music_button.custom_minimum_size=Vector2(175,46)
			music_button.tooltip_text="只切换夜市旋律；技能与收账提示由声音按钮控制。"
			var screen_button:=_button("窗口 / 全屏 · F11",_toggle_fullscreen,settings_row);screen_button.custom_minimum_size=Vector2(205,46)
		"waiting":
			modal_box.add_child(_label("毛球搭档 · 等待连接",28));modal_box.add_child(_label(status))
			_button("返回",func():_connection_problem("已取消连接"))
		"draft":
			var selected:=1 if mode=="client" else 0
			if mode=="local" and model.draft_done[0]:selected=1
			modal_box.add_child(_label("订单额外改装 · 每人一次合法选择" if model.draft_is_order[selected] else "半枚关门铃 · 中途改造" if model.wave==3 else "波次完成 · 成长选择",28))
			if model.draft_done[selected]:modal_box.add_child(_label("已选择，等待队友完成。"));return
			modal_box.add_child(_label("P%d：%s · 点击或按 1 / 2 / 3" % [selected+1,FurBuildCatalog.NAMES[model.players[selected].build.style]]))
			var build: Dictionary = model.players[selected].build
			modal_box.add_child(_label("当前：%d 把武器 · 伤害 ×%.2f · 移速 ×%.2f · 范围 ×%.2f · 间隔 ×%.2f · 暴击 %d%%\n已改装：%s" % [build.weapons,build.damage,build.speed,build.area,build.interval,int(round(build.crit*100))," / ".join(build.chosen) if not build.chosen.is_empty() else "尚未改装"],15))
			for choice in 3:
				var item: Dictionary=model.draft_options[selected][choice]
				var prefix: String="关门改造 · " if item.get("masterwork",false) else ("招牌改装 · " if item.has("style") else "")
				var button:=_button(prefix+item.name+"\n"+item.detail,_draft_choice_callback(choice,selected))
				if item.has("style"):_accent_button(button,Color("ffd587"))
		"board":_draw_board()
		"route":
			modal_box.add_child(_label("掷骰选关 · 两条路线",28))
			modal_box.add_child(_label("两条路有不同的营业规则和奖励。点击或按 1 / 2 选路；Boss 仍需击败。"))
			var selected:=1 if mode=="client" else 0
			var can_choose:=mode not in ["host","client"] or selected==model.wave%2
			if not can_choose:modal_box.add_child(_label("本轮由队友决定路线。"))
			for choice in 2:
				var face: int=model.dice.x if choice==0 else model.dice.y
				var contract := FurRouteCatalog.entry(face%3)
				var button:=_button("骰子 %d → %s\n%s\n目标：%s → %s" % [face,contract.name,contract.rule,contract.goal,contract.reward],_choice_callback("route",choice,selected))
				_accent_button(button,[Color("ffba79"),Color("cbb0ff"),Color("69e6bd")][face%3])
				button.disabled=not can_choose
		"victory","defeat":_draw_settlement()

func _start_callback(style: int) -> Callable:
	return func():
		var requested:=_requested_seed()
		if requested<0:return
		bridge.close();start_game([style],"solo",requested)

func _defeat_advice() -> String:
	if model.players.is_empty():return "调整成长，再走一次宵夜路。"
	if model.players.size()>1:return "金线表示护盾覆盖。先挂锅印再兑现伤害；搭档倒下后，靠近保持 2.5 秒救援。"
	match int(model.players[0].build.style):
		0:return "锅印击败能回收锅能。离开危险圈，再用 Q 爆发清场；换条营业路线也会改变压力。"
		1:return "站定蓄能，移动才会发射强化齐射。Q 装满蓄能后仍需移动；留好冲刺躲开收账圈。"
		_:return "诱饵留在放置的位置。绕行把追兵聚到饼旁，爆炸前避开收账圈；成长可以改变兑现时间。"

func _selected_host_styles() -> Array[int]:
	var styles:Array[int]=[0,1]
	if host_kit.selected==1:styles[1]=2
	return styles

func _local_callback(styles: Array[int]) -> Callable:
	return func():
		var requested:=_requested_seed()
		if requested<0:return
		bridge.close();start_game(styles,"local",requested)

func _requested_seed() -> int:
	var entered:=seed_text.strip_edges()
	if entered.is_empty():return 0
	if not entered.is_valid_int() or int(entered)<1 or int(entered)>2147483647:
		status="种子请输入 1–2147483647 的整数，或留空随机。";displayed_phase="";_refresh_ui();return -1
	return int(entered)

func _accent_button(button: Button, colour: Color) -> void:
	for state in ["normal","hover","pressed"]:
		var box:=button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		box.border_color=colour;box.border_width_left=5
		button.add_theme_stylebox_override(state,box)

func _choice_callback(kind: String, choice: int, player_index: int) -> Callable:
	return func():_choose(kind,choice,player_index)


func _record_gm(record:Dictionary) -> void:
	if not record.get("intervention",false):return
	model.debug_run=true
	if model.debug_history.size()>=32:model.debug_history.pop_front()
	model.debug_history.append(record.duplicate(true));displayed_phase=""

func _position_order_hud()->void:
	if order_progress==null or rule_label==null:return
	var panel:Control=rule_label.get_parent()
	var top:float=maxf(232.0,panel.position.y+panel.size.y+8.0) if panel.visible else 232.0
	order_progress.offset_top=top;order_progress.offset_bottom=top+28.0
	if challenge_progress!=null:challenge_progress.offset_top=top+36.0;challenge_progress.offset_bottom=top+64.0
	if view!=null:
		var header_end:float=maxf(108.0,panel.position.y+panel.size.y if panel.visible else 0.0)
		if order_progress.visible:header_end=maxf(header_end,top+order_progress.size.y)
		if challenge_progress!=null and challenge_progress.visible:header_end=maxf(header_end,top+36.0+challenge_progress.size.y)
		view.payoff_caption_top=header_end+32.0

func _challenge_hud_text()->String:
	var state:Dictionary=model.challenge_contract.state
	match str(state.get("phase","inactive")):
		"waiting":
			if state.arm_source=="":
				var left:float=maxf(0,float(state.battle_started_at)+model.challenge_contract.ARM_CUTOFF-model.elapsed)
				return "抢档：先做一步委托 · %.1f秒后自动登记" % left
			var lead:float=maxf(0,float(state.arm_at)+model.challenge_contract.ARM_LEAD-model.elapsed)
			var source:String="委托开档" if state.arm_source=="milestone" else "自动开档"
			return "抢档：%s · 预告 %.1f秒" % [source,lead] if lead>0 else "抢档：%s · 等下一压力群" % source
		"marked":return "抢档 %d/%d · 剩 %.1f秒 · %s" % [state.killed_records.size(),state.group.size(),maxf(0,float(state.deadline)-model.elapsed),"委托完成" if state.objective_sequence>0 else "委托未完成"]
		"cleared":return "抢档条件达成 · 站末确认+8" if state.objective_sequence>0 else "抢档清群达标 · 等完整委托"
		"failed":
			var reason:String={"timeout":"超时","identity_lost":"标记身份失效","group_unavailable":"未形成抢档群","no_group":"没有可用压力群"}.get(state.reason,"未达成")
			return "抢档%s · 基础营业继续 · 本场压力保持" % reason
	return "抢档已关闭 · 收益以站末资格回执为准"

func _draw_board() -> void:
	if board_view==null:return
	var selected:=1 if mode=="client" else (int(model.board.state.active) if mode=="local" else 0)
	board_view.render(model.board.snapshot(),selected,Supplies.facts(model.players),model.seed_value,mode,model.shared_order.snapshot(),model.patrol.snapshot())

func _apply_baits(value:Variant)->bool:
	var clean:Dictionary=SnapshotDomains.clean_baits(value,model.players.size())
	if not clean.ok:return false
	model.baits.assign(clean.value);return true

func _apply_estate_state(value:Variant)->bool:
	var clean:Dictionary=SnapshotDomains.clean_estate(value)
	if not clean.ok:return false
	model.estate.state=clean.value;return true

func _apply_enemy_behavior_state(value:Variant)->bool:
	var clean:Dictionary=SnapshotDomains.clean_enemy(value)
	if not clean.ok:return false
	model.enemy_behavior_state=clean.value;return true

func _bounded_number(value:Variant,low:float,high:float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high


func _round_results_snapshot()->Array:
	var records:Variant=model.get("round_results")
	return records.duplicate(true) if records is Array else []

func _apply_round_results(value:Variant)->bool:
	var clean:Dictionary=SnapshotDomains.clean_rounds(value,model.seed_value,int(model.board.state.run_token))
	if not clean.ok:return false
	model.round_results.assign(clean.value);return true

func _campaign_facts()->Dictionary:
	var contributions:Array=[]
	for p in model.players:contributions.append({"rescues":int(p.build.rescues),"link_receipts":int(p.build.link_receipts),"ally_saved_damage":float(p.build.ally_saved_damage)})
	return {"seed":model.seed_value,"run_token":int(model.board.state.run_token),"shared_order":model.shared_order.snapshot(),"outcome":model.phase,"wave":model.wave,"debug_run":model.debug_run,"cash":int(model.board.state.get("cash",0)),"licenses":model.board.state.get("licenses",[0,0,0]).duplicate(),"rounds":_round_results_snapshot(),"contributions":contributions}

func _personal_payoff_text(build:Dictionary)->String:
	var cooperative:="协同触发 %d" % int(build.get("triggers",0))
	if str(build.get("masterwork","")).is_empty():return cooperative
	var names:=["锅浪","追射","连兑饼"]
	var keys:=["payoff_waves","payoff_volleys","payoff_baits"]
	var style:=clampi(int(build.get("style",0)),0,2)
	if build.get("masterwork","")=="assembly":return "接档 %d · 迈步选方向" % int(build.get("payoff_volleys",0))
	return "%s %d · %s" % [names[style],int(build.get(keys[style],0)),cooperative]

func _district_progress_text(d:Dictionary,cash:int)->String:
	if int(d.get("district_id",-1))==2:
		if d.get("completed",false):return "奶茶委托完成 ✓ · %d 金 · F1 目标" % cash
		return "双站 %d / 2 · 合流 %d%% · %d 金 · F1" % [int(d.get("progress",0)),int(clampf(float(d.get("feast_progress",0))/.8,0,1)*100),cash]
	return "%s %.1f / %.0f%s · %d 金 · F1 目标" % [str(d.name).split(" · ")[0],float(d.progress),float(d.target)," ✓" if d.get("completed",false) else "",cash]

func _draw_settlement()->void:
	modal.offset_top=-300;modal.offset_bottom=300
	var panel_style:=_style();panel_style.bg_color.a=1;modal.add_theme_stylebox_override("panel",panel_style)
	modal_box.add_child(_label("夜市打烊成功！" if model.phase=="victory" else "毛球倒下了 · 再试一局",28))
	modal_box.add_child(_label("关门铃终于响了，宵夜留给搭档！" if model.phase=="victory" else _defeat_advice(),15))
	modal_box.add_child(_label("第 %d 站 · 种子 %d · 钱袋 %d · 地产 %s" % [model.wave,model.seed_value,int(model.board.state.get("cash",0)),str(model.board.state.get("licenses",[]))],15))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(800,330);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal_box.add_child(scroll);var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
	var evaluation:=Evaluation.evaluate(_campaign_facts());var summary:=CampaignSummary.new();content.add_child(summary);summary.render(evaluation)
	var roads:Array[String]=[]
	for route_id in model.route_history:roads.append((["甩锅巷","促销街","奶茶摊"] if model.skip_board_for_checks else BoardView.DISTRICT_NAMES)[route_id])
	content.add_child(_label("宵夜路线："+" → ".join(roads),14))
	for index in model.players.size():
		var build:Dictionary=model.players[index].build
		content.add_child(_label("P%d %s · 伤害 %d · 击败 %d · 协同触发 %d · 锅印兑现 %d · 搭档减伤 %d · 救援 %d\n个人爆发：锅浪 %d · 追射 %d · 连兑饼 %d\n改装：%s" % [index+1,FurBuildCatalog.NAMES[build.style],int(build.dealt),build.kills,build.triggers,build.link_receipts,int(build.ally_saved_damage),build.rescues,int(build.get("payoff_waves",0)),int(build.get("payoff_volleys",0)),int(build.get("payoff_baits",0))," / ".join(build.chosen) if not build.chosen.is_empty() else "原装也很勇敢"],14))
	_button("返回营地",_return_to_camp)

func _shared_order_hud_text()->String:
	var order:Dictionary=model.shared_order.state
	if order.is_empty() or int(order.get("selected",-1))<0:return ""
	if order.get("fulfilled",false):return "合伙订单 ✓ 已交付 · "+("下一成长各多选一次合法改装" if not order.get("entitlement",{}).is_empty() and not order.entitlement.get("claimed",false) else "合同已履约")
	var cargo:Dictionary=order.get("cargo",{})
	if not cargo.is_empty():
		var route_choice:int=cargo.get("route_choice",-1)
		if route_choice<0:
			var key:="%d-%d-%d" % [int(order.run_token),int(order.last_wave),int(cargo.id)]
			if key!=order_route_hint_key:
				order_route_hint=OrderPaths.options(order.battle,cargo.origin,cargo.source_charges,int(order.seed));order_route_hint_key=key
			return "合伙订单 · 近箱 E直送 %.0fm / R外圈 %.0fm%s" % [float(order_route_hint.direct_length),float(order_route_hint.outer_length)," · P2逗号/句号" if mode=="local" else ""]
		var carrier:int=cargo.get("carrier",-1)
		return "合伙订单 · %s · %s · 配送 %d/2 → 节点%d" % ["直送" if route_choice==0 else "外圈","P%d载货" % (carrier+1) if carrier>=0 else ("落箱 E拾取（P2逗号）" if mode=="local" else "落箱 E拾原线路"),int(cargo.checkpoint),mini(2,int(cargo.checkpoint)+1)]
	order_route_hint_key="";order_route_hint={}
	var required:int=order.get("required_mask",0);var collected:int=order.get("collected_mask",0);var names:Array[String]=[]
	for index in 3:
		if (required&~collected)&(1<<index):names.append(["串串","物流","奶茶"][index])
	return "合伙订单 · "+("货已齐，下场配送重试" if names.is_empty() else "还缺 "+" + ".join(names)+"货 · 完成对应委托取货")

func _choose_draft(choice:int,actor:int)->void:
	if actor<0 or actor>=model.players.size():return
	var revision:int=model.draft_revisions[actor]
	_submit_draft_choice(choice,int(model.board.state.run_token),model.wave,revision,actor)

func _receive_draft_choice(choice:int,token:int,wave:int,revision:int,actor:int)->void:
	if mode=="client" or model.phase!="draft" or actor<0 or actor>=model.players.size():return
	if token!=int(model.board.state.run_token) or wave!=model.wave or revision!=model.draft_revisions[actor]:return
	model.choose_upgrade(actor,choice,revision);displayed_phase="";_refresh_ui()

func _draft_choice_callback(choice:int,actor:int)->Callable:
	# Bind the card that was rendered; a queued second click is still that card.
	var token:int=model.board.state.run_token;var wave:int=model.wave;var revision:int=model.draft_revisions[actor]
	return func():_submit_draft_choice(choice,token,wave,revision,actor)

func _submit_draft_choice(choice:int,token:int,wave:int,revision:int,actor:int)->void:
	if mode=="client":bridge.send_draft_choice(choice,token,wave,revision);return
	_receive_draft_choice(choice,token,wave,revision,actor)

func _submit_order_pickup(choice:int,actor:int)->void:
	if model.phase!="battle" or choice not in [0,1] or actor<0 or actor>=model.players.size():return
	var cargo:Dictionary=model.shared_order.state.get("cargo",{})
	if cargo.is_empty():return
	var token:int=model.board.state.run_token;var wave:int=model.wave;var id:int=cargo.id;var revision:int=cargo.pickup_revision
	if mode=="client":bridge.send_order_pickup(choice,token,wave,id,revision);return
	_receive_order_pickup(choice,token,wave,id,revision,actor)

func _receive_order_pickup(choice:int,token:int,wave:int,cargo_id:int,revision:int,actor:int)->void:
	if mode=="client":return
	if model.request_order_pickup(actor,choice,token,wave,cargo_id,revision):_refresh_ui()
