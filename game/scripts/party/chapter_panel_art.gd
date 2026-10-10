class_name FurChapterPanelArt
extends Node2D
## Read-only panel dressing. Node2D keeps PanelContainer's child layout untouched.
const ArtSkin=preload("res://scripts/party/chapter_ui_skin.gd")
var host:Control
var role:String="menu"
var chapter:int=0
static func attach(panel:Control,kind:String="menu",index:int=0)->FurChapterPanelArt:
	var art:=FurChapterPanelArt.new();art.host=panel;art.role=kind;art.chapter=clampi(index,0,2)
	panel.add_child(art);panel.move_child(art,0);panel.resized.connect(art.queue_redraw);art.queue_redraw()
	var transparent:=StyleBoxFlat.new();transparent.bg_color=Color.TRANSPARENT;transparent.content_margin_left=20;transparent.content_margin_right=20;transparent.content_margin_top=15;transparent.content_margin_bottom=15
	panel.add_theme_stylebox_override("panel",transparent)
	return art
func _draw()->void:
	if not is_instance_valid(host):return
	var extent:=host.size
	if extent.x<1 or extent.y<1:return
	var rect:=Rect2(Vector2.ZERO,extent)
	if role=="gallery":
		# Keep the illustration visible between the title and the actionable footer.
		var glass:=StyleBoxFlat.new();glass.bg_color=Color(.98,.96,.90,.92)
		glass.set_corner_radius_all(16);glass.border_color=Color("dfc69a");glass.set_border_width_all(1)
		glass.shadow_color=Color(.07,.15,.20,.22);glass.shadow_size=9;glass.shadow_offset=Vector2(0,5)
		draw_style_box(glass,Rect2(0,0,extent.x,107))
		var lower:=glass.duplicate() as StyleBoxFlat;lower.bg_color=Color(.98,.96,.90,.90)
		# Actual menu controls occupy y420..603 in the 700px panel. Do not
		# extend a blank glass sheet to the panel's unused lower edge.
		var footer_top:float=maxf(0,extent.y-280)
		draw_style_box(lower,Rect2(0,footer_top,extent.x,183))
		return
	draw_style_box(ArtSkin.box("orange" if role=="player0" else ("blue" if role=="player1" else "menu")),rect)
	var accent:Color=[Color("c26949"),Color("317d6d"),Color("6b628d")][chapter]
	if role.begins_with("player"):
		accent=Color("b97145") if role=="player0" else Color("437f96")
		draw_circle(Vector2(49,extent.y*.5+2),37,Color(0.12,.18,.17,.13))
		draw_circle(Vector2(49,extent.y*.5),35,Color("fcf6e6"))
		draw_arc(Vector2(49,extent.y*.5),35,-PI*.7,PI*.6,36,accent,2.0,true)
		draw_line(Vector2(93,16),Vector2(93,extent.y-16),Color(accent,.4),1.0,true)
	elif role=="title":
		draw_line(Vector2(19,extent.y-12),Vector2(extent.x-19,extent.y-12),accent,3.0,true)
		_compass(Vector2(extent.x-27,24),12,accent)
	else:
		# The content starts at x20/y15. Ornament stays outside that rectangle.
		draw_line(Vector2(8,29),Vector2(8,extent.y-29),Color("917850"),2.0,true)
		draw_line(Vector2(extent.x-8,29),Vector2(extent.x-8,extent.y-29),Color("917850"),2.0,true)
		for x:float in [9.0,extent.x-9]:
			for y:float in [10.0,extent.y-10]:_compass(Vector2(x,y),4,Color("ae8b53"))
func _compass(point:Vector2,radius:float,colour:Color)->void:
	draw_arc(point,radius,0,TAU,24,colour,1.0,true)
	var tips:=PackedVector2Array([point+Vector2(0,-radius),point+Vector2(3,0),point+Vector2(0,radius),point+Vector2(-3,0)])
	draw_colored_polygon(tips,colour)
