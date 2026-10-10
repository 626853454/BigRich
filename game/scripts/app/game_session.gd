class_name GameSession
extends Node

const TRAVELER = preload("res://assets/models/traveler_blockout.glb")
const SIGIL_TEXT := {
	&"cheap-reroll": "巧手 · 免费重掷",
	&"quiet-exit": "静行 · 失败不加热度",
	&"locked-profit": "守财 · 锁骰成功 +2 金币",
}
const PHASE_TEXT := {
	&"camp": "整装待发", &"exploring": "夜市探索", &"dice-rolled": "掷骰判定",
	&"await-choice": "抉择", &"await-sigil": "符印", &"result": "行程结束",
}

var store := GameStore.new()
var player: PlayerController
var status_label: Label
var message_label: Label
var objectives_label: Label
var interaction_label: Label
var action_row: HBoxContainer
var dice_label: Label
var last_message := "灯火照不到的地方，交易仍在继续。"

func _ready() -> void:
	var restored := store.restore()
	_create_interface()
	_create_player()
	store.changed.connect(_on_state_changed)
	_render(store.state, "已恢复上次行程" if restored else last_message)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("confirm"):
		if store.state.phase == RunState.PHASE_CAMP:
			start_run()
		elif store.state.phase == RunState.PHASE_DICE:
			if store.state.dice[0] == 0: roll()
			else: confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reroll"):
		roll()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		var saved := store.save()
		_render(store.state, "行程已保存" if saved else "保存失败，请检查存档目录")

func _create_player() -> void:
	player = PlayerController.new()
	player.name = "Player"
	var visual := TRAVELER.instantiate() as Node3D
	visual.name = "Visual"
	visual.position.y = -0.7
	player.add_child(visual)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.height = 1.4
	capsule_shape.radius = 0.38
	shape.shape = capsule_shape
	player.add_child(shape)
	var lantern := OmniLight3D.new()
	lantern.name = "TravelLight"
	lantern.position = Vector3(0.4, 0.2, 0.2)
	lantern.light_color = Color("ffc17b")
	lantern.light_energy = 0.65
	lantern.omni_range = 3.2
	player.add_child(lantern)
	get_parent().get_node("World").add_child(player)
	player.setup(store, self)
	player.sync_position()
	(get_parent().get_node("Camera") as FixedOverheadCamera).subject = player

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.052, 0.059, 0.94)
	style.border_color = Color(0.42, 0.33, 0.22, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := FurVisualStyle.font()
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("d5d3c5"))
	root.theme = theme
	layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(24, 20)
	top.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	var title := Label.new()
	title.text = "骰火商路  /  灰灯夜市"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e4bf83"))
	top_box.add_child(title)
	status_label = Label.new()
	top_box.add_child(status_label)
	objectives_label = Label.new()
	objectives_label.add_theme_font_size_override("font_size", 16)
	top_box.add_child(objectives_label)
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -194
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color("b9a683"))
	box.add_child(message_label)
	interaction_label = Label.new()
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(interaction_label)
	dice_label = Label.new()
	dice_label.add_theme_font_size_override("font_size", 24)
	dice_label.add_theme_color_override("font_color", Color("ecc78b"))
	box.add_child(dice_label)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	box.add_child(action_row)

func _exit_tree() -> void:
	store.save()

func _on_state_changed(next: RunState, message: String) -> void:
	_render(next, message)

func _render(state: RunState, message: String) -> void:
	if status_label == null:
		return
	if not message.is_empty():
		last_message = message
	message_label.text = last_message
	status_label.text = "%s    金币 %d    声望 %d    热度 %d / 7    改骰筹码 %d" % [PHASE_TEXT.get(state.phase, ""), state.coins, state.reputation, state.heat, state.reroll_tokens]
	var objective_names: Array[String] = []
	for objective in TownContent.OBJECTIVES:
		objective_names.append(("✓ " if state.objectives.has(objective) else "○ ") + TownContent.LOCATIONS[objective].name)
	objectives_label.text = "委托：" + "   ".join(objective_names) + "  |  交单需金币 ≥18、声望 ≥3、热度 ≤7"
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	dice_label.visible = state.phase in [RunState.PHASE_DICE, RunState.PHASE_CHOICE]
	dice_label.text = "%s %s   +   %s %s" % [_die_text(state.dice[0]), "[锁定]" if state.locked[0] else "", _die_text(state.dice[1]), "[锁定]" if state.locked[1] else ""]
	var nearby := TownContent.nearby(state.position, state.visited)
	if state.phase == RunState.PHASE_CAMP:
		interaction_label.text = "选择商人，开始夜市行程。WASD / 方向键移动 · E 互动 · Esc 保存"
		_add_action("账房先生（Enter）", func(): start_run(&"accountant"))
		_add_action("走私客", func(): start_run(&"smuggler"))
		_add_action("商会掌柜", func(): start_run(&"guildmaster"))
	elif state.phase == RunState.PHASE_EXPLORING:
		interaction_label.text = "附近：%s   |   WASD / 方向键移动 · E 互动 · Esc 保存" % (TownContent.LOCATIONS[nearby].name if nearby != &"" else "沿灯火寻找委托地点")
		if nearby != &"": _add_action("交付委托（E）" if nearby == &"guild" else "互动（E）", func(): interact_nearby())
	elif state.phase == RunState.PHASE_DICE:
		interaction_label.text = "%s · 首次免费；%s。可锁住想保留的骰子。" % [TownContent.LOCATIONS[state.pending_location].name, "巧手符印使本次重掷免费" if state.sigils.has(&"cheap-reroll") else "重掷一次消耗 1 筹码"]
		if state.dice[0] == 0:
			_add_action("掷骰（Enter）", func(): roll())
		else:
			var can_reroll: bool = state.rolls_remaining > 0 and (state.reroll_tokens > 0 or state.sigils.has(&"cheap-reroll")) and not (state.locked[0] and state.locked[1])
			_add_action("免费重掷（R）" if state.sigils.has(&"cheap-reroll") else "重掷（R）", func(): roll(), not can_reroll)
			_add_action("解锁左骰" if state.locked[0] else "锁定左骰", func(): lock(0), state.rolls_remaining < 1)
			_add_action("解锁右骰" if state.locked[1] else "锁定右骰", func(): lock(1), state.rolls_remaining < 1)
			_add_action("确认（Enter）", func(): confirm())
	elif state.phase == RunState.PHASE_CHOICE:
		var rewards := {
			&"shop": "稳妥成功 +9 金币；押注成功 +18 金币",
			&"event": "稳妥成功 +2 声望；押注成功 +3 声望",
			&"risk": "稳妥成功 +3 金币；押注成功 +12 金币；成功均 +1 声望",
		}
		interaction_label.text = "骰点合计 %d · 稳妥需 ≥6 点；押注需 ≥9 点且支付 3 金币。\n%s。失败可再次尝试。" % [state.dice[0] + state.dice[1], rewards[state.pending_location]]
		_add_action("稳妥 · 免费", func(): choose(&"safe"))
		_add_action("押注 · 3 金币", func(): choose(&"bold"), state.coins < 3)
	elif state.phase == RunState.PHASE_SIGIL:
		interaction_label.text = "选择本局符印：巧手每次互动免费重掷一次；静行使失败不增加热度；守财使锁骰成功额外获得 2 金币。"
		for sigil in state.pending_sigils: _add_action(SIGIL_TEXT[sigil], _sigil_callback(sigil))
	elif state.phase == RunState.PHASE_RESULT:
		interaction_label.text = "交单成功，商路仍在延伸。" if state.result == &"victory" else "交单未达标：需要金币 ≥18、声望 ≥3、热度 ≤7。"
		_add_action("重新开始", func(): restart())

func _sigil_callback(sigil: StringName) -> Callable:
	return func(): choose_sigil(sigil)

func _die_text(value: int) -> String:
	return "—" if value == 0 else str(value)

func _add_action(text: String, callback: Callable, disabled := false) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 40)
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_NONE
	var normal := _panel_style()
	normal.bg_color = Color("283335")
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("514536")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	action_row.add_child(button)

func start_run(merchant: StringName = &"accountant") -> void:
	var result := store.dispatch(func(current): return RunEngine.start_run(current, merchant))
	if result.error.is_empty(): player.sync_position()

func move_player(direction: Vector2i) -> Dictionary:
	return store.dispatch(func(current): return RunEngine.move(current, direction), false)

func interact_nearby() -> void:
	if player.step_locked:
		return
	var nearby := TownContent.nearby(store.state.position, store.state.visited)
	if nearby != &"": store.dispatch(func(current): return RunEngine.interact(current, nearby))
	else: _render(store.state, "请走近尚未完成的地点")

func roll() -> void: store.dispatch(func(current): return RunEngine.roll_dice(current))
func lock(index: int) -> void: store.dispatch(func(current): return RunEngine.lock_die(current, index))
func confirm() -> void: store.dispatch(func(current): return RunEngine.confirm_roll(current))
func choose(choice: StringName) -> void: store.dispatch(func(current): return RunEngine.choose_outcome(current, choice))
func choose_sigil(sigil: StringName) -> void: store.dispatch(func(current): return RunEngine.choose_sigil(current, sigil))
func restart() -> void:
	store.dispatch(func(_current): return RunEngine.start_run(RunEngine.new_state(int(Time.get_unix_time_from_system())), &"accountant"))
	player.sync_position()
