class_name FurballGMConsole
extends Control

# Kept separate from session HUD; no gameplay rules live in the console.
const Commands = preload("res://scripts/furball/gm_commands.gd")
var router: Commands
var entry: LineEdit
var transcript: Label
var recent_lines: Array[String] = []

func configure(commands: Commands) -> void:
	router = commands

func blocks_gameplay_input() -> bool:
	# Session polls physical keys independently of GUI event consumption. While
	# this panel is visible it must submit neutral local movement/dash/skill.
	return visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and entry != null:
		entry.release_focus()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	add_theme_font_override("font", FurVisualStyle.font())
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 60); panel.custom_minimum_size = Vector2(960, 280)
	add_child(panel)
	var column := VBoxContainer.new(); panel.add_child(column)
	var label := Label.new(); label.text = "开发调试 · 结果含GM干预 | F10关闭 | 输入help"
	label.add_theme_color_override("font_color", Color(1.0, .7, .22)); column.add_child(label)
	transcript = Label.new(); transcript.custom_minimum_size = Vector2(920, 180)
	transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transcript.mouse_filter = Control.MOUSE_FILTER_IGNORE; column.add_child(transcript)
	entry = LineEdit.new(); entry.placeholder_text = "例如 build 1 core / spawn 0 20 / board help"
	# Enter executes a command while keeping this console ready for the next one.
	entry.keep_editing_on_text_submit = true
	entry.max_length = Commands.MAX_COMMAND_LENGTH; entry.text_submitted.connect(_submit); column.add_child(entry)
	hide()

func _input(event: InputEvent) -> void:
	if router == null or not router.enabled: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		visible = not visible
		if visible: entry.grab_focus()
		else: entry.release_focus()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		hide(); entry.release_focus(); get_viewport().set_input_as_handled()

func _submit(command: String) -> void:
	if router == null: return
	var result := router.execute(command)
	if recent_lines.size() >= 5: recent_lines.pop_front()
	recent_lines.append("> %s\n%s%s" % [command, "✓ " if result.ok else "拒绝：", result.message])
	transcript.text = "\n".join(recent_lines)
	entry.clear(); entry.grab_focus()
