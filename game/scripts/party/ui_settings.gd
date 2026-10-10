class_name FurUISettings
extends VBoxContainer
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var volume_label:Label
func _ready()->void:
	FurUIPreferences.ensure_loaded();theme=Palette.create();add_theme_constant_override("separation",16)
	var audio:=_section("sound","声音","音乐与游戏反馈，找到适合你的音量。")
	var volume:=HSlider.new();volume.min_value=0;volume.max_value=100;volume.step=1;volume.value=roundf(AudioServer.get_bus_volume_linear(0)*100);volume.size_flags_horizontal=Control.SIZE_EXPAND_FILL;volume.custom_minimum_size=Vector2(390,40)
	var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",22);audio.add_child(controls);controls.add_child(volume)
	volume_label=_text("%d%%"%volume.value,22);volume_label.custom_minimum_size.x=70;controls.add_child(volume_label)
	volume.value_changed.connect(func(value:float):AudioServer.set_bus_volume_linear(0,value/100);FurUIPreferences.volume=value/100;volume_label.text="%d%%"%value;FurUIPreferences.save())
	var mute:=CheckButton.new();mute.text="静音";mute.button_pressed=AudioServer.is_bus_mute(0);mute.custom_minimum_size.x=165;controls.add_child(mute)
	mute.toggled.connect(func(on:bool):AudioServer.set_bus_mute(0,on);FurUIPreferences.muted=on;FurUIPreferences.save())
	var ui:=_section("settings","界面体验","保留清晰反馈，也允许更安静、更稳定的画面。")
	var row:=HBoxContainer.new();ui.add_child(row)
	var sounds:=CheckButton.new();sounds.text="界面确认音";sounds.button_pressed=FurUIPreferences.interface_sounds;sounds.custom_minimum_size=Vector2(360,48);row.add_child(sounds)
	sounds.toggled.connect(func(on:bool):FurUIPreferences.interface_sounds=on;FurUIPreferences.save())
	var motion:=CheckButton.new();motion.text="减少界面动效";motion.button_pressed=FurUIPreferences.reduced_motion;motion.custom_minimum_size=Vector2(360,48);row.add_child(motion)
	motion.toggled.connect(func(on:bool):FurUIPreferences.reduced_motion=on;FurUIPreferences.save())
	var note:=_text("减少菜单入场、卡片悬停和界面反馈动效；保留骰子与角色的玩法动画。",16);note.add_theme_color_override("font_color",Palette.MUTED);ui.add_child(note)
	var keys:=_section("book","键盘也很顺手","Tab 切换控件 · Enter 确认 · Esc 返回 · F11 全屏 · F10 静音")
	keys.add_child(_text("棋盘：Space 掷骰，数字键选择。战斗：P1 用 WASD / Space / Q；P2 用方向键 / Enter / 斜杠。",16))
func _text(value:String,font_size:int)->Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",font_size);label.add_theme_font_override("font",FurChapterUITheme.font(font_size>=22));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func _section(icon:String,title:String,detail:String)->VBoxContainer:
	var panel:=PanelContainer.new();var plate:=Palette.panel_style();plate.bg_color=Color("fff9ed");plate.shadow_size=4;plate.content_margin_top=20;plate.content_margin_bottom=24;panel.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate,false,true));add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",9);panel.add_child(box)
	var header:=HBoxContainer.new();box.add_child(header);header.add_child(FurUIIcons.view(icon,Vector2(43,43)))
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",3);header.add_child(words);words.add_child(_text(title,22));var label:=_text(detail,16);label.add_theme_color_override("font_color",Palette.MUTED);words.add_child(label)
	return box
