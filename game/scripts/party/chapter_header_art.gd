class_name FurChapterHeaderArt
extends Control
## Original static chapter illustrations. No reference images, viewport or input.
var chapter:int=0
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true;resized.connect(queue_redraw)
func configure(value:int)->void:chapter=clampi(value,0,2);queue_redraw()
func _draw()->void:
	if size.x<1 or size.y<1:return
	var colours:Array=[Color("325f69"),Color("28584f"),Color("494760")]
	var base:Color=colours[chapter]
	for i in 12:draw_rect(Rect2(0,size.y*i/12.0,size.x,size.y/12.0+1),base.lightened(float(i)/100.0))
	# Quiet title area on the left, a distinct small scene on the right.
	draw_set_transform(Vector2(size.x-151,size.y*.5-43),0,Vector2(.96,.96))
	if chapter==0:_harbor()
	elif chapter==1:_tea()
	else:_clock()
	draw_set_transform(Vector2.ZERO)
	for x in range(12,int(size.x)-12,20):draw_circle(Vector2(x,size.y-5),.8,Color("c0a577"))
	draw_line(Vector2(12,5),Vector2(size.x-12,5),Color(1,.9,.7,.15),1,true)
func _box(rect:Rect2,colour:Color,radius:int=3)->void:
	var box:=StyleBoxFlat.new();box.bg_color=colour;box.set_corner_radius_all(radius);box.corner_detail=6;draw_style_box(box,rect)
func _harbor()->void:
	for i in 3:draw_arc(Vector2(25+i*42,88),22,.2,PI-.2,14,Color("74b8ba"),2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(17,65),Vector2(116,65),Vector2(99,82),Vector2(34,82)]),Color("bb885f"))
	draw_line(Vector2(20,65),Vector2(113,65),Color("e2bd84"),3,true)
	draw_line(Vector2(66,4),Vector2(66,64),Color("e7d4ac"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(61,9),Vector2(61,56),Vector2(21,56)]),Color("fff0c7"))
	draw_colored_polygon(PackedVector2Array([Vector2(71,13),Vector2(111,55),Vector2(71,55)]),Color("db8b68"))
	draw_line(Vector2(66,4),Vector2(84,8),Color("db8b68"),4,true)
	for i in 3:draw_circle(Vector2(139,27+i*12),12-i,Color("659a85"))
	draw_line(Vector2(139,39),Vector2(139,72),Color("b7946b"),3,true)
func _tea()->void:
	_box(Rect2(14,65,131,15),Color("9d7657"),5)
	_box(Rect2(20,65,119,3),Color("dbb888"),2)
	# Stacked jade-backed ceramic tiles; visible pips are a chapter motif, not a hand.
	for i in 3:
		var x:float=23+i*27;var y:float=17-i*3
		_box(Rect2(x+3,y+4,30,43),Color("679886"),5)
		_box(Rect2(x,y,30,43),Color("f1e4c5"),5)
		_box(Rect2(x+3,y+3,24,37),Color("fff7de"),3)
		for point:Vector2 in [Vector2(9,13),Vector2(21,28)]:
			draw_circle(Vector2(x,y)+point,3.4,Color("2d786a"));draw_circle(Vector2(x,y)+point,1,Color("c7dec0"))
	_box(Rect2(119,40,22,20),Color("ead2a7"),7)
	draw_arc(Vector2(143,49),7,-PI*.6,PI*.6,16,Color("ead2a7"),3,true)
	draw_arc(Vector2(127,22),8,-PI*.7,PI*.4,14,Color(1,.91,.75,.5),1.5,true)
	draw_arc(Vector2(131,10),6,PI*.3,PI*1.3,14,Color(1,.91,.75,.3),1.5,true)
func _clock()->void:
	_box(Rect2(29,12,92,66),Color("9d7954"),8)
	_box(Rect2(35,17,80,55),Color("6d5971"),5)
	for i in 8:
		var angle:float=i*TAU/8;draw_circle(Vector2(75,45)+Vector2(cos(angle),sin(angle))*26,5,Color("b89868"))
	draw_circle(Vector2(75,45),26,Color("d7b679"));draw_circle(Vector2(75,45),21,Color("f4e5c4"))
	for i in 12:
		var axis:=Vector2(cos(i*TAU/12),sin(i*TAU/12));draw_line(Vector2(75,45)+axis*16,Vector2(75,45)+axis*19,Color("81707f"),1.5,true)
	draw_line(Vector2(75,45),Vector2(75,31),Color("705773"),3,true);draw_line(Vector2(75,45),Vector2(87,51),Color("705773"),3,true)
	draw_circle(Vector2(75,45),3,Color("ad8451"))
	for side in [-1,1]:
		draw_colored_polygon(PackedVector2Array([Vector2(75+side*42,34),Vector2(75+side*67,20),Vector2(75+side*59,54),Vector2(75+side*43,61)]),Color("a995bb"))
