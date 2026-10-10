class_name FurChapterUITheme
extends RefCounted
const ArtSkin=preload("res://scripts/party/chapter_ui_skin.gd")
const Detail=preload("res://scripts/party/ui_button_detail.gd")
const Icons=preload("res://scripts/party/ui_icons.gd")
const INK:=Color("183e46")
const MUTED:=Color("627478")
const PAPER:=Color("f7f0e3")
const GOLD:=Color("cba767")
const ACCENTS:=[Color("c36c45"),Color("216f76"),Color("80709f")]
const PALE:=[Color("f4e7d7"),Color("e2eeeb"),Color("eae5f0")]
static var _theme:Theme
static func font(bold:bool=false)->Font:
	return preload("res://assets/ui/eighthour_v1/SweiGothicCJKsc-Black.ttf") if bold else preload("res://assets/art/sevenhour_v1/NotoSansSC-Medium.ttf")
static func _symbol(name:String)->Texture2D:
	var refined:String="res://assets/ui/atelier_v1/"+name+".png"
	return load(refined) if ResourceLoader.exists(refined) else load("res://assets/ui/premium_v1/"+name+".svg")
static func accent(chapter:int=0)->Color:return ACCENTS[clampi(chapter,0,2)]
static func panel_style(kind:String="cream",chapter:int=0)->StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color("173e49") if kind=="dark" else (PALE[clampi(chapter,0,2)] if kind=="tint" else PAPER)
	box.border_color=Color("43646c") if kind=="dark" else Color("d3c19d");box.set_border_width_all(1);box.border_width_bottom=2
	box.set_corner_radius_all(22);box.corner_detail=12;box.shadow_color=Color(.04,.09,.10,.21);box.shadow_size=13;box.shadow_offset=Vector2(0,7)
	box.content_margin_left=24;box.content_margin_right=24;box.content_margin_top=20;box.content_margin_bottom=20
	return box
static func focus_style()->StyleBoxFlat:
	var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("d7a852");focus.set_border_width_all(3);focus.set_corner_radius_all(22)
	focus.expand_margin_left=4;focus.expand_margin_right=4;focus.expand_margin_top=4;focus.expand_margin_bottom=4;return focus
static func create()->Theme:
	if _theme!=null:return _theme
	var theme:=Theme.new();theme.default_font=font();theme.default_font_size=18
	for type:String in ["Label","Button","CheckButton","CheckBox","OptionButton","RichTextLabel","LineEdit","SpinBox","TabBar"]:
		for key:String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:theme.set_color(key,type,INK)
		theme.set_color("font_disabled_color",type,Color("596563"));theme.set_font_size("font_size",type,18)
	for type:String in ["Button","OptionButton"]:
		for state:String in ["normal","hover","pressed","disabled"]:theme.set_stylebox(state,type,ArtSkin.box({"normal":"ivory","hover":"ivory_hover","pressed":"ivory_pressed","disabled":"disabled"}[state]))
		theme.set_stylebox("focus",type,focus_style());theme.set_constant("outline_size",type,0);theme.set_constant("h_separation",type,10);theme.set_constant("icon_max_width",type,34)
	for type:String in ["Panel","PanelContainer"]:theme.set_stylebox("panel",type,FurUICeramicFrame.style())
	var popup:=panel_style();popup.set_corner_radius_all(16)
	theme.set_stylebox("panel","PopupMenu",FurUICeramicFrame.from_flat(popup,true));theme.set_stylebox("panel","TooltipPanel",FurUICeramicFrame.from_flat(popup,true))
	theme.set_color("font_color","PopupMenu",INK);theme.set_color("font_hover_color","PopupMenu",INK);theme.set_color("font_disabled_color","PopupMenu",MUTED)
	theme.set_font_size("font_size","PopupMenu",18);theme.set_font_size("font_size","TooltipLabel",16);theme.set_color("font_color","TooltipLabel",INK)
	var hover:=panel_style("tint",1);hover.shadow_size=0;hover.set_corner_radius_all(10);hover.content_margin_top=7;hover.content_margin_bottom=7
	theme.set_stylebox("hover","PopupMenu",hover);theme.set_constant("v_separation","PopupMenu",12)
	for type:String in ["LineEdit","TextEdit"]:
		theme.set_stylebox("normal",type,panel_style());theme.set_stylebox("focus",type,focus_style());theme.set_color("font_color",type,INK);theme.set_color("caret_color",type,INK)
	var track:=StyleBoxFlat.new();track.bg_color=Color("dad4c8");track.border_color=Color("b6b8ad");track.set_border_width_all(1);track.set_corner_radius_all(6);track.content_margin_top=4;track.content_margin_bottom=4
	var fill:=track.duplicate() as StyleBoxFlat;fill.bg_color=Color("277c80");fill.border_color=Color("21646d")
	theme.set_stylebox("background","ProgressBar",FurUIMeterSkin.box());theme.set_stylebox("fill","ProgressBar",FurUIMeterSkin.box("teal"));theme.set_color("font_color","ProgressBar",INK)
	for type:String in ["HSlider","VSlider"]:
		var slider_track:=FurUIMeterSkin.box().duplicate() as StyleBoxTexture
		var slider_fill:=FurUIMeterSkin.box("teal").duplicate() as StyleBoxTexture
		# Slider draws at style minimum height, unlike a full-rect ProgressBar.
		# Two-pixel margins squeezed the authored recessed rail almost invisible.
		slider_track.content_margin_top=10;slider_track.content_margin_bottom=10
		slider_fill.content_margin_top=7;slider_fill.content_margin_bottom=7
		theme.set_stylebox("slider",type,slider_track);theme.set_stylebox("grabber_area",type,slider_fill);theme.set_stylebox("grabber_area_highlight",type,slider_fill)
		theme.set_icon("grabber",type,_symbol("slider_normal"));theme.set_icon("grabber_highlight",type,_symbol("slider_hover"));theme.set_icon("grabber_disabled",type,_symbol("slider_disabled"))
	for type:String in ["HScrollBar","VScrollBar"]:
		theme.set_stylebox("scroll",type,track);theme.set_stylebox("grabber",type,fill);theme.set_stylebox("grabber_highlight",type,fill);theme.set_stylebox("grabber_pressed",type,fill)
		for name:String in ["increment","decrement","increment_highlight","decrement_highlight","increment_pressed","decrement_pressed"]:theme.set_icon(name,type,_symbol("empty_scroll"))
	for type:String in ["CheckButton","CheckBox"]:
		theme.set_constant("icon_max_width",type,78 if type=="CheckButton" else 36)
		for state:String in ["normal","hover","pressed","hover_pressed","disabled"]:theme.set_stylebox(state,type,StyleBoxEmpty.new())
		theme.set_stylebox("focus",type,focus_style());theme.set_constant("h_separation",type,12)
	for key:String in ["checked","unchecked","checked_disabled","unchecked_disabled"]:
		var state:String=("off" if key.begins_with("unchecked") else "on")+("_disabled" if key.ends_with("disabled") else "")
		theme.set_icon(key,"CheckButton",_symbol("toggle_"+state));theme.set_icon(key+"_mirrored","CheckButton",_symbol("toggle_"+state))
	for key:String in ["checked","unchecked","checked_disabled","unchecked_disabled"]:theme.set_icon(key,"CheckBox",_symbol("check_"+("off" if key.begins_with("unchecked") else "on")+("_disabled" if key.ends_with("disabled") else "")))
	theme.set_icon("arrow","OptionButton",_symbol("arrow_down"));theme.set_color("default_color","RichTextLabel",INK)
	var tab:=panel_style("tint",1);tab.shadow_size=0;tab.border_width_bottom=0;tab.set_corner_radius_all(12);tab.content_margin_left=22;tab.content_margin_right=22;tab.content_margin_top=11;tab.content_margin_bottom=11
	theme.set_stylebox("tab_selected","TabBar",tab)
	var quiet:=tab.duplicate() as StyleBoxFlat;quiet.bg_color=Color("efe9de");quiet.border_color=Color("d9ccb4");theme.set_stylebox("tab_unselected","TabBar",quiet);theme.set_stylebox("tab_hovered","TabBar",hover)
	theme.set_color("font_selected_color","TabBar",INK);theme.set_color("font_unselected_color","TabBar",MUTED);theme.set_stylebox("tab_focus","TabBar",focus_style())
	theme.set_constant("separation","HBoxContainer",16);theme.set_constant("separation","VBoxContainer",12)
	theme.set_constant("h_separation","GridContainer",16);theme.set_constant("v_separation","GridContainer",12)
	_theme=theme;return theme
static func apply_button(button:Button,kind:String="primary",icon:String="")->void:
	button.theme=create();button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;button.focus_mode=Control.FOCUS_ALL
	var dark:bool=kind in ["primary","toolbar","selected","danger"]
	var base:String=kind if kind in ["primary","toolbar","selected","danger"] else "ivory"
	button.add_theme_stylebox_override("normal",ArtSkin.box(base));button.add_theme_stylebox_override("hover",ArtSkin.box("primary_hover" if dark else "ivory_hover"))
	button.add_theme_stylebox_override("pressed",ArtSkin.box("primary_pressed" if dark else "ivory_pressed"));button.add_theme_stylebox_override("disabled",ArtSkin.box("disabled"));button.add_theme_stylebox_override("focus",focus_style())
	for key:String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(key,Color("fff7e6") if dark else INK)
	button.add_theme_color_override("font_disabled_color",Color("4d5959"));button.add_theme_constant_override("h_separation",10);button.add_theme_constant_override("icon_max_width",34)
	if kind=="quiet":
		for state:String in ["normal","hover","pressed","disabled"]:
			var quiet:=panel_style();quiet.bg_color=Color("fff5e2") if state=="normal" else (Color("e2eeeb") if state!="disabled" else Color("e0e1d7"));quiet.border_color=Color("c5b89b");quiet.shadow_size=4;quiet.shadow_offset=Vector2(0,3);quiet.set_corner_radius_all(16)
			quiet.content_margin_top=5;quiet.content_margin_bottom=5;quiet.content_margin_left=14;quiet.content_margin_right=14
			var skin:StyleBoxTexture=ArtSkin.box({"normal":"ivory","hover":"ivory_hover","pressed":"ivory_pressed","disabled":"disabled"}[state]).duplicate() as StyleBoxTexture
			skin.content_margin_top=5;skin.content_margin_bottom=5;skin.content_margin_left=14;skin.content_margin_right=14;button.add_theme_stylebox_override(state,skin)
	if not icon.is_empty():button.icon=Icons.get_icon(icon);button.expand_icon=true
	Detail.attach(button);FurUIContactShadow.attach(button,kind=="quiet")
