class_name FurChapterBoardHUD
extends Control
## Read-only action and build summaries. Choices remain owned by the session.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var _labels:Dictionary={}
var _data:Dictionary={}
var compact:bool=true
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(850,74);resized.connect(_layout)
func configure(data:Dictionary)->void:
	_data=data.duplicate(true)
	if _labels.is_empty():
		for key:String in ["action","objective","build","hint"]:
			var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_override("font",Palette.font(key=="action"));label.add_theme_font_size_override("font_size",23 if key=="action" else (19 if key=="build" else 15))
			label.add_theme_color_override("font_color",Color("fff5e2") if key in ["action","objective"] else Palette.INK);add_child(label);_labels[key]=label
	for key in _labels:_labels[key].text=str(data.get(key,""))
	_labels.build.text=_labels.build.text.replace("\n","  ·  ")
	_layout();queue_redraw()
func _layout()->void:
	if _labels.is_empty():return
	var width:float=maxf(850,size.x);var split:float=width*.63
	_labels.action.position=Vector2(66,8);_labels.action.size=Vector2(split-96,31)
	_labels.objective.position=Vector2(66,40);_labels.objective.size=Vector2(split-99,36)
	_labels.build.position=Vector2(split+23,7);_labels.build.size=Vector2(width-split-48,31)
	_labels.hint.position=Vector2(split+23,39);_labels.hint.size=Vector2(width-split-48,35)
func _draw()->void:
	var width:float=maxf(850,size.x);var split:float=width*.63
	var active:=Palette.panel_style("dark");active.shadow_size=8;active.bg_color=Color("193f49");active.border_color=Color("688586")
	draw_style_box(FurUICeramicFrame.from_flat(active,true),Rect2(0,0,split-5,74))
	var build:=Palette.panel_style();build.shadow_size=8;build.bg_color=Color("f7f0e2");draw_style_box(FurUICeramicFrame.from_flat(build,true),Rect2(split+5,0,width-split-5,74))
	var icon:String="shield" if _data.get("mode","")=="combat" else "compass"
	draw_texture_rect(FurUIIcons.get_icon(icon),Rect2(11,12,49,49),false)
	draw_line(Vector2(split+24,37),Vector2(width-25,37),Color("d9cbb1"),1,true)
