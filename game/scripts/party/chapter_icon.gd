class_name FurChapterIcon
extends Control
## Resolution independent chapter seals; no textures or process callback.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var chapter:int=0
var icon_kind:String="chapter"

func configure(index:int,kind:String="chapter")->void:
	chapter=clampi(index,0,2);icon_kind=kind;mouse_filter=Control.MOUSE_FILTER_IGNORE;queue_redraw()

func _draw()->void:
	var side:float=minf(size.x,size.y)
	if side<1:return
	draw_set_transform((size-Vector2.ONE*side)*.5,0,Vector2.ONE*side/100.0)
	draw_circle(Vector2(50,54),43,Color(0.20,0.15,0.23,.15))
	draw_circle(Vector2(50,49),43,Color("c89e62"))
	draw_circle(Vector2(50,47),40,Color("fff2d2"))
	draw_circle(Vector2(50,47),35,Palette.PALE[chapter])
	draw_arc(Vector2(50,47),37,-2.7,-.65,24,Color("fffdf2"),2,true)
	if icon_kind in ["coin","cost"]:_coin()
	elif icon_kind in ["paw","build","heart"]:_paw()
	elif icon_kind in ["route","dice"]:_dice()
	elif chapter==0:_island()
	elif chapter==1:_mahjong()
	else:_clock()
	for p:Vector2 in [Vector2(16,17),Vector2(82,77)]:
		draw_line(p-Vector2(0,4),p+Vector2(0,4),Color("b98a4f"),2,true)
		draw_line(p-Vector2(4,0),p+Vector2(4,0),Color("b98a4f"),2,true)

func _island()->void:
	draw_colored_polygon(PackedVector2Array([Vector2(22,58),Vector2(76,58),Vector2(65,72),Vector2(33,72)]),Color("98634b"))
	draw_style_box(_round_box(Color("dfb477"),7),Rect2(21,53,57,13))
	draw_line(Vector2(49,24),Vector2(49,57),Color("745045"),4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(47,25),Vector2(47,51),Vector2(24,51)]),Color("fffbed"))
	draw_colored_polygon(PackedVector2Array([Vector2(53,29),Vector2(74,51),Vector2(53,51)]),Color("df8673"))
	for row in 2:
		for x in 3:draw_arc(Vector2(30+x*19,72+row*6),8,.12,PI-.12,12,Color("69aab0"),2.3,true)

func _mahjong()->void:
	draw_style_box(_round_box(Color("67998b"),7),Rect2(31,22,38,53))
	draw_style_box(_round_box(Color("fffced"),6),Rect2(27,18,38,53))
	draw_style_box(_round_box(Color("e8dac4"),4),Rect2(31,22,30,45))
	draw_style_box(_round_box(Color("fffbeb"),3),Rect2(32,23,28,42))
	for p:Vector2 in [Vector2(40,35),Vector2(51,35),Vector2(40,51),Vector2(51,51)]:
		draw_circle(p,4,Color("589185"));draw_circle(p,1.4,Color("d8edd4"))
	draw_line(Vector2(72,28),Vector2(72,53),Color("ad814d"),2,true)
	draw_style_box(_round_box(Color("d98875"),8),Rect2(65,33,14,19))
	draw_line(Vector2(72,54),Vector2(72,62),Color("bd925a"),2,true)

func _clock()->void:
	for i in 8:
		var a:float=i*TAU/8
		var p:=Vector2(50,47)+Vector2(cos(a),sin(a))*26
		draw_circle(p,6,Color("ba935a"))
	draw_circle(Vector2(50,47),27,Color("ae8450"))
	draw_circle(Vector2(50,47),23,Color("fff4d7"))
	draw_circle(Vector2(50,47),20,Color("e4dced"))
	for i in 12:
		var v:=Vector2(cos(i*TAU/12),sin(i*TAU/12))
		draw_line(Vector2(50,47)+v*16,Vector2(50,47)+v*18,Color("786589"),1.5,true)
	draw_line(Vector2(50,47),Vector2(50,34),Color("6e6087"),3,true)
	draw_line(Vector2(50,47),Vector2(61,53),Color("6e6087"),3,true)
	draw_circle(Vector2(50,47),3,Color("bd9150"))
	for side in [-1,1]:
		var pts:=PackedVector2Array([Vector2(50+side*25,45),Vector2(50+side*42,37),Vector2(50+side*35,53),Vector2(50+side*24,57)])
		draw_colored_polygon(pts,Color("a59ac3"))

func _coin()->void:
	draw_circle(Vector2(50,48),23,Color("b88843"));draw_circle(Vector2(50,45),22,Color("efc874"));draw_arc(Vector2(50,45),17,0,TAU,40,Color("ffedb6"),2,true)
	draw_line(Vector2(44,44),Vector2(50,35),Color("a97936"),3,true);draw_line(Vector2(50,35),Vector2(56,44),Color("a97936"),3,true);draw_line(Vector2(42,48),Vector2(58,48),Color("a97936"),3,true);draw_line(Vector2(50,40),Vector2(50,58),Color("a97936"),3,true)

func _paw()->void:
	draw_circle(Vector2(50,55),14,Palette.ACCENTS[chapter]);draw_circle(Vector2(40,59),8,Palette.ACCENTS[chapter]);draw_circle(Vector2(60,59),8,Palette.ACCENTS[chapter])
	for p:Vector2 in [Vector2(31,42),Vector2(44,32),Vector2(58,32),Vector2(70,42)]:draw_circle(p,6,Palette.ACCENTS[chapter])

func _dice()->void:
	draw_style_box(_round_box(Color("baaa91"),8),Rect2(30,30,43,43));draw_style_box(_round_box(Color("fffaf0"),8),Rect2(27,25,43,43))
	for p:Vector2 in [Vector2(38,36),Vector2(58,36),Vector2(48,46),Vector2(38,57),Vector2(58,57)]:draw_circle(p,3.7,Palette.INK)

func _round_box(colour:Color,radius:int)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=colour;style.set_corner_radius_all(radius);style.corner_detail=8;return style
