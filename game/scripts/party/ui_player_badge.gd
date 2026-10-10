class_name FurUIPlayerBadge
extends Control
## Read-only participant identity. Board finances and combat life use distinct rows.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const Icons=preload("res://scripts/party/ui_icons.gd")
var actor:int=0
var portrait:Texture2D
var data:Dictionary={}
func _init()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func configure(index:int,face:Texture2D,snapshot:Dictionary)->void:
	actor=index;portrait=face;data=snapshot.duplicate(true);queue_redraw()
func _text(at:Vector2,value:String,size_px:int,color:Color)->void:
	draw_string(Palette.font(size_px>=20),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
func _draw()->void:
	if data.is_empty():return
	var col:Color=Color("c8784d") if actor==0 else Color("54868f")
	var extent:Vector2=size
	var plate:=Palette.panel_style();plate.bg_color=Color("fcf4e5");plate.shadow_size=10;plate.shadow_color=Color(.06,.11,.13,.13)
	plate.border_color=col if data.get("active",false) else Color("d5c7ac");plate.border_width_bottom=3 if data.get("active",false) else 1
	draw_style_box(FurUICeramicFrame.from_flat(plate,true),Rect2(Vector2.ZERO,extent))
	draw_circle(Vector2(43,42),32,Color("e0d3b8"));draw_circle(Vector2(43,40),31,Color("fff9ed"));draw_arc(Vector2(43,40),32,-PI*.9,PI*.25,48,col,1.5,true)
	if portrait!=null:draw_texture_rect(portrait,Rect2(10,7,66,66),false)
	draw_texture_rect(preload("res://assets/ui/atelier_v1/portrait_frame.png"),Rect2(4,1,78,78),false)
	if data.get("active",false):draw_arc(Vector2(43,40),35,-PI*.86,PI*.82,64,col,2.0,true)
	_text(Vector2(85,30),"小柯" if actor==0 else "泡泡",22,Palette.INK)
	var tag:=StyleBoxFlat.new();tag.bg_color=Color(col,.16);tag.set_corner_radius_all(6);draw_style_box(tag,Rect2(extent.x-67,12,48,24))
	_text(Vector2(extent.x-57,30),"AI" if data.get("ai",false) else "P%d"%(actor+1),14,col)
	if data.get("combat",false):
		var hp:float=maxf(0,float(data.get("hp",0)));var cap:float=maxf(1,float(data.get("max_hp",1)))
		draw_style_box(FurUIMeterSkin.box(),Rect2(87,46,extent.x-108,14))
		if hp>0:draw_style_box(FurUIMeterSkin.box("coral" if hp/cap<.3 else "teal"),Rect2(89,48,(extent.x-112)*clampf(hp/cap,0,1),10))
		_text(Vector2(87,77),"%.0f / %.0f"%[hp,cap],15,Palette.INK)
		_text(Vector2(extent.x-100,77),"待救援" if data.get("down",false) else "生命",14,Color("ae5749") if data.get("down",false) else Palette.MUTED)
		if data.get("down",false):_text(Vector2(20,94),"伙伴靠近可救援 · %.1f / 2.5秒"%float(data.get("revive",0)),12,Palette.MUTED)
	else:
		draw_texture_rect(Icons.get_icon("coin"),Rect2(82,42,29,29),false);_text(Vector2(112,63),str(data.get("coins",0)),21,Palette.INK)
		draw_texture_rect(Icons.get_icon("star"),Rect2(172,42,29,29),false);_text(Vector2(204,63),str(data.get("stars",0)),21,Palette.INK)
		_text(Vector2(20,85),str(data.get("summary","")),13,Palette.MUTED)
