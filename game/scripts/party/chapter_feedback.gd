class_name FurChapterFeedback
extends Control
## One legible toast per confirmed event. No economy or challenge authority.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const DURATION:float=1.55
const PARTICLE_CAP:int=10
var generation:int=0
var last_text:String=""
var _age:float=DURATION
var _origin:=Vector2.ZERO
var _colour:=Color.WHITE
var _kind:String=""
var _label:Label
var _card:PanelContainer
var _icon:TextureRect
var _rest:=Vector2.ZERO
func _init()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)
func _ready()->void:
	_card=PanelContainer.new();_card.mouse_filter=Control.MOUSE_FILTER_IGNORE;_card.custom_minimum_size=Vector2(280,61);add_child(_card)
	var plate:=Palette.panel_style();plate.bg_color=Color("fff8e9");plate.shadow_size=9;plate.content_margin_top=9;plate.content_margin_bottom=9;plate.content_margin_left=14;plate.content_margin_right=22;plate.set_corner_radius_all(18);_card.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate,true))
	var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_theme_constant_override("separation",12);_card.add_child(row)
	_icon=FurUIIcons.view("check",Vector2(42,42));row.add_child(_icon)
	_label=Label.new();_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;_label.add_theme_font_override("font",FurChapterUITheme.font(true));_label.add_theme_font_size_override("font_size",20);_label.add_theme_color_override("font_color",Palette.INK);row.add_child(_label);_card.hide()
func play(kind:String,chapter:int,origin:Vector2,text:String="")->void:
	_kind=kind;_origin=origin;_age=0;generation+=1;last_text=text;_colour=Color("ad7454") if kind=="blocked" else (Palette.GOLD if kind in ["coin","stamp"] else Palette.accent(chapter))
	if not is_instance_valid(_card):return
	_label.text=text;_icon.texture=FurUIIcons.get_icon({"coin":"coin","stamp":"star","blocked":"compass"}.get(kind,"check"))
	var width:float=maxf(280,FurChapterUITheme.font(true).get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+94)
	_card.size=Vector2(width,61);_rest=Vector2(clampf(origin.x-width*.5,24,1576-width),clampf(origin.y-42,145,784));_card.position=_rest;_card.modulate=Color.WHITE;_card.show();show();set_process(true);queue_redraw()
func is_active()->bool:return _age<DURATION
func clear()->void:
	_age=DURATION;set_process(false);queue_redraw()
	if is_instance_valid(_card):_card.hide()
func _process(delta:float)->void:
	_age=minf(DURATION,_age+maxf(delta,0));var settle:float=smoothstep(0,.18,_age);var opacity:float=1-smoothstep(1.22,DURATION,_age)
	if is_instance_valid(_card):
		_card.modulate.a=opacity;_card.position=_rest+(Vector2.ZERO if FurUIPreferences.reduced_motion else Vector2(0,8*(1-settle)))
	queue_redraw()
	if _age>=DURATION:clear()
func _draw()->void:
	if _age>=.65 or FurUIPreferences.reduced_motion or _kind=="blocked":return
	var t:float=_age/.65;var col:=Color(_colour,(1-t)*.6);var center:=_rest+Vector2(_card.size.x*.5,20)
	for i in PARTICLE_CAP:
		var angle:float=i*TAU/PARTICLE_CAP;var p:Vector2=center+Vector2(cos(angle)*(_card.size.x*.52+12*t),sin(angle)*(34+18*t));var r:float=2.5*(1-t)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r*.5,0),p+Vector2(0,r),p+Vector2(-r*.5,0)]),col)
