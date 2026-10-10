class_name FurChapterCard
extends Button
## Readable choice card: identity, effect, cost and unavailable reason are separate.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const Icons=preload("res://scripts/party/ui_icons.gd")
const Preview=preload("res://scripts/party/chapter_preview_3d.gd")
var chapter:int=0
var selected:bool=false
var compact:bool=false
var expanded:bool=false
var showcase:bool=false
var horizontal:bool=false
var _built:bool=false
var _data:Dictionary={}
var _heading:Label
var _detail:Label
var _badge:Label
var _cost:Label
var _reason:Label
var _icon:TextureRect
var _price_icon:TextureRect
var _preview:FurChapterPreview3D
var _hero:TextureRect
var hero:String=""
var _focus_amount:float=0
func _init()->void:
	focus_mode=Control.FOCUS_ALL;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	resized.connect(_layout);mouse_entered.connect(_wake);mouse_exited.connect(_wake);focus_entered.connect(_wake);focus_exited.connect(_wake);set_process(false)
func _ready()->void:_build();_layout()
func configure(data:Dictionary)->void:
	_data=data.duplicate(true);hero=str(data.get("hero",""));chapter=clampi(int(data.get("chapter",0)),0,2);horizontal=bool(data.get("horizontal",false))
	expanded=bool(data.get("expanded",false));showcase=bool(data.get("showcase",false));compact=bool(data.get("compact",false)) and not expanded
	disabled=not bool(data.get("enabled",true));custom_minimum_size=Vector2(260 if horizontal else 296,(188 if data.get("roomy",false) else 140) if horizontal else (296 if showcase else (338 if expanded else (230 if compact else 290))))
	if not hero.is_empty():custom_minimum_size.y=435
	_build();_heading.text=str(data.get("heading","新的选择"));_detail.text=str(data.get("detail",""));_badge.text=str(data.get("badge",""));_cost.text=str(data.get("cost",""));_reason.text=str(data.get("reason",""))
	_hero.visible=not hero.is_empty()
	if _hero.visible:_hero.texture=load("res://assets/ui/atelier_v1/hero_"+hero+".png")
	_price_icon.texture=Icons.get_icon("coin" if "金" in _cost.text else "check")
	_icon.texture=Icons.get_icon(str(data.get("icon",["compass","mahjong","clock"][chapter])))
	tooltip_text=_heading.text+"\n"+_detail.text+"\n"+_cost.text+("\n"+_reason.text if not _reason.text.is_empty() else "")
	_apply_style();_layout();queue_redraw()
func set_selected(value:bool)->void:selected=value;_apply_style();queue_redraw()
func set_blocked(reason:String)->void:
	disabled=true;_reason.text=reason;tooltip_text+="\n"+reason;_layout();queue_redraw()
func _make_label(font_size:int,colour:Color)->Label:
	var l:=Label.new();l.add_theme_font_size_override("font_size",font_size);l.add_theme_font_override("font",FurChapterUITheme.font(font_size>=22));l.add_theme_color_override("font_color",colour);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(l);return l
func _build()->void:
	if _built:return
	_built=true;theme=Palette.create();text=""
	_icon=Icons.view("compass",Vector2(76,76));add_child(_icon)
	_hero=TextureRect.new();_hero.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_hero.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_hero)
	_heading=_make_label(25,Palette.INK);_heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_detail=_make_label(18,Palette.MUTED);_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_badge=_make_label(14,Palette.accent(chapter));_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_cost=_make_label(18,Palette.INK);_reason=_make_label(14,Color("a56651"));_reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_price_icon=Icons.view("coin",Vector2(27,27));add_child(_price_icon)
	_apply_style()
func _apply_style()->void:
	var normal:=Palette.panel_style();normal.bg_color=Color("fff8ec");normal.shadow_size=7;normal.shadow_offset=Vector2(0,4);normal.shadow_color=Color(.06,.11,.12,.12)
	normal.border_color=Palette.accent(chapter) if selected else Color("d6c29b");normal.set_border_width_all(2 if selected else 1)
	var hover:=normal.duplicate() as StyleBoxFlat;hover.bg_color=Color("fffcf4");hover.border_color=Palette.GOLD;hover.set_border_width_all(2)
	var pressed:=normal.duplicate() as StyleBoxFlat;pressed.bg_color=Palette.PALE[chapter];pressed.shadow_size=3
	var off:=normal.duplicate() as StyleBoxFlat;off.bg_color=Color("e9e6dc");off.border_color=Color("c0bdaf");off.shadow_size=4
	var normal_skin:=FurUICeramicFrame.from_flat(normal)
	if selected:normal_skin.modulate_color=Color("e4f1e7")
	add_theme_stylebox_override("normal",normal_skin);add_theme_stylebox_override("hover",FurUICeramicFrame.from_flat(hover));add_theme_stylebox_override("pressed",FurUICeramicFrame.from_flat(pressed));add_theme_stylebox_override("disabled",FurUICeramicFrame.from_flat(off,false,true));add_theme_stylebox_override("focus",Palette.focus_style())
func _layout()->void:
	if not _built:return
	var w:float=maxf(size.x,custom_minimum_size.x);var h:float=maxf(size.y,custom_minimum_size.y)
	_icon.visible=not showcase and hero.is_empty()
	if showcase:
		if not is_instance_valid(_preview):_preview=Preview.new();_preview.configure(chapter);add_child(_preview);move_child(_preview,0)
		_preview.position=Vector2(12,12);_preview.size=Vector2(w-24,146)
		_heading.position=Vector2(23,173);_heading.size=Vector2(w-46,35);_detail.position=Vector2(23,217);_detail.size=Vector2(w-46,42);_detail.add_theme_font_size_override("font_size",16)
	else:
		if is_instance_valid(_preview):_preview.hide()
		_icon.position=Vector2(17,20);_icon.size=Vector2(57,57) if horizontal else Vector2(76,76)
		_heading.position=Vector2(86 if horizontal else 106,16 if horizontal else 34);_heading.size=Vector2(w-_heading.position.x-22,31 if horizontal else 53)
		_heading.add_theme_font_size_override("font_size",20 if horizontal else 25)
		_detail.position=Vector2(86 if horizontal else 25,54 if horizontal else 121);_detail.size=Vector2(w-_detail.position.x-23,h-_detail.position.y-65)
		_detail.add_theme_font_size_override("font_size",16 if horizontal or compact else 18)
	if not hero.is_empty():
		_hero.position=Vector2(21,38);_hero.size=Vector2(w-42,173);_heading.position=Vector2(25,224);_heading.size=Vector2(w-50,65);_detail.position=Vector2(25,302);_detail.size=Vector2(w-50,68)
	_badge.position=Vector2(w-153,10);_badge.size=Vector2(133,25);_badge.visible=not horizontal
	var foot_y:float=h-42
	_price_icon.position=Vector2(21,foot_y-1);_price_icon.visible=not _cost.text.is_empty()
	_cost.position=Vector2(54,foot_y+1);_cost.size=Vector2(w-83,27);_cost.add_theme_font_size_override("font_size",16 if horizontal else 18)
	_reason.position=Vector2(25,h-76);_reason.size=Vector2(w-50,24);_reason.visible=disabled and not _reason.text.is_empty()
	if _reason.visible:_detail.size.y=maxf(30,h-90-_detail.position.y)
	queue_redraw()
func _wake()->void:
	if FurUIPreferences.reduced_motion:_focus_amount=1 if (has_focus() or is_hovered()) and not disabled else 0;queue_redraw();return
	set_process(true)
	if is_instance_valid(_preview):_preview.set_emphasis(has_focus() or is_hovered())
func _process(delta:float)->void:
	var target:float=1 if (has_focus() or is_hovered()) and not disabled else 0
	_focus_amount=move_toward(_focus_amount,target,delta*8);queue_redraw()
	if is_equal_approx(_focus_amount,target):set_process(false)
func _draw()->void:
	if not _built:return
	var w:float=size.x;var h:float=size.y
	if w<50 or h<70:return
	if _focus_amount>0 and not disabled:
		var rim:=Palette.focus_style();rim.border_color=Color("ccab68");rim.border_color.a=_focus_amount*.55;rim.set_border_width_all(2);rim.expand_margin_left=0;rim.expand_margin_right=0;rim.expand_margin_top=0;rim.expand_margin_bottom=0
		draw_style_box(rim,Rect2(5,5,w-10,h-10))
	draw_line(Vector2(24,h-53),Vector2(w-24,h-53),Color("dfd1b7"),1,true)
	if selected:
		draw_texture_rect(Icons.get_icon("check"),Rect2(w-48,h-46,33,33),false)
	elif not disabled:
		var x:float=w-26+_focus_amount*2;var col:Color=Palette.accent(chapter)
		draw_polyline(PackedVector2Array([Vector2(x-4,h-32),Vector2(x+1,h-27),Vector2(x-4,h-22)]),col,2,true)
	if not hero.is_empty():
		draw_circle(Vector2(w*.5,128),80,Color(Palette.PALE[chapter],.75))
	var alpha:float=.52 if disabled else 1.0
	_icon.modulate=Color(1,1,1,alpha);_heading.modulate=Color(1,1,1,.70 if disabled else 1);_detail.modulate=Color(1,1,1,.85 if disabled else 1)
