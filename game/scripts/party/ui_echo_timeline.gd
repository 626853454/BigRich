class_name FurUIEchoTimeline
extends Control
var data:Dictionary={}
var power:Array=[]
func _init()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(440,172)
func configure(snapshot:Dictionary,source:ChapterEcho)->void:
	data=snapshot.duplicate(true);power.clear()
	for beat in 8:
		var occupants:Array=source.ghost_positions(beat)
		for offset in range(1,int(data.afterglow)+1):
			if beat-offset>=0:occupants.append_array(source.ghost_positions(beat-offset))
		power.append([data.plates[0] in occupants,data.plates[1] in occupants])
	queue_redraw()
func _text(at:Vector2,value:String,px:int,color:Color)->void:draw_string(FurChapterUITheme.font(px>=18),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)
func _draw()->void:
	if data.is_empty():return
	var ink:=FurChapterUITheme.INK;var muted:=FurChapterUITheme.MUTED;var cell:float=(size.x-47)/8
	_text(Vector2(0,18),"上一轮回声 · 八拍供电表",18,ink)
	_text(Vector2(0,74),"A",19,Color("b96e47"));_text(Vector2(0,112),"B",19,Color("43808c"))
	for beat in 8:
		var x:float=31+beat*cell;var box:=FurChapterUITheme.panel_style();box.shadow_size=0;box.set_corner_radius_all(11);box.bg_color=Color("e3ede3") if power[beat][0] and power[beat][1] else Color("ede9df");box.border_color=Color("b1945e") if beat==int(data.beat) else Color("ded4c2");box.set_border_width_all(2 if beat==int(data.beat) else 1)
		# Timeline cells are quiet indicators; do not squeeze a wide pill's
		# 44px source caps into a 52px destination and clip its right half.
		box.shadow_size=3;box.shadow_color=Color(0.10,0.16,0.17,.10);box.shadow_offset=Vector2(0,2)
		draw_style_box(box,Rect2(x,34,cell-6,98))
		draw_line(Vector2(x+11,38),Vector2(x+cell-17,38),Color(1,1,.97,.75),1.0,true)
		if beat==int(data.beat):draw_style_box(FurChapterUITheme.focus_style(),Rect2(x+4,38,cell-14,90))
		_text(Vector2(x+cell*.5-8,54),str(beat+1),14,muted)
		for row in 2:
			var center:=Vector2(x+(cell-6)*.5,72+row*37);var lit:bool=power[beat][row]
			draw_texture_rect(FurUIMeterSkin.image("signal_on" if lit else "signal_off"),Rect2(center-Vector2(14,14),Vector2(28,28)),false)
			if lit:draw_polyline(PackedVector2Array([center+Vector2(-4,0),center+Vector2(-1,3),center+Vector2(5,-4)]),Color("fff6df"),1.8,true)
	_text(Vector2(0,157),"尚未封存轨迹 · 先让两人站上 A / B" if data.track[0].is_empty() else "仅回声与余辉；真人站位会额外参与当前供电。",14,muted)
