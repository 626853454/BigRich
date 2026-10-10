class_name FurUIJourneyBadge
extends Control
var data:Dictionary={}
func _init()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func configure(snapshot:Dictionary)->void:data=snapshot.duplicate(true);queue_redraw()
func _draw()->void:
	if data.is_empty():return
	var chapter:int=int(data.get("chapter",0));var p:=FurChapterUITheme.panel_style();p.shadow_size=8;draw_style_box(FurUICeramicFrame.from_flat(p,true),Rect2(Vector2.ZERO,size))
	if data.get("combat",false):
		draw_texture_rect(FurUIIcons.get_icon("shield"),Rect2(12,15,59,59),false)
		draw_string(FurChapterUITheme.font(true),Vector2(81,34),"海岛挑战 %d"%int(data.get("challenge",1)),HORIZONTAL_ALIGNMENT_LEFT,-1,24,FurChapterUITheme.INK)
		var remaining:float=maxf(0,float(data.get("remaining",0)));var seconds:String="%.0fs"%ceilf(remaining) if remaining>0 else "决战"
		draw_string(FurChapterUITheme.font(true),Vector2(size.x-88,37),seconds,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("ad7048"))
		var cap:float=maxf(1,float(data.get("xp_cap",1)));var xp:float=float(data.get("xp",0));var ratio:float=clampf(xp/cap,0,1)
		draw_string(FurChapterUITheme.font(),Vector2(82,63),"Lv%d   ·   经验 %.0f / %.0f"%[data.get("level",1),xp,cap],HORIZONTAL_ALIGNMENT_LEFT,-1,15,FurChapterUITheme.MUTED)
		draw_style_box(FurUIMeterSkin.box(),Rect2(82,74,size.x-108,13))
		if ratio>.025:draw_style_box(FurUIMeterSkin.box("gold"),Rect2(84,76,(size.x-112)*ratio,9))
		return
	draw_texture_rect(FurUIIcons.get_icon(["compass","mahjong","clock"][chapter]),Rect2(14,12,60,60),false)
	draw_string(FurChapterUITheme.font(true),Vector2(81,35),["海岛远征","云顶雀馆","时光空港"][chapter],HORIZONTAL_ALIGNMENT_LEFT,-1,25,FurChapterUITheme.INK)
	draw_string(FurChapterUITheme.font(),Vector2(82,62),"第 %d 章   ·   %s"%[chapter+1,"自由试玩" if data.get("practice",false) else "三章同行"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,FurChapterUITheme.MUTED)
	for i in 2:
		var center:=Vector2(size.x-68+i*34,44);var earned:bool=i<int(data.get("stamps",0))
		draw_circle(center,14,Color("236c72") if earned else Color("e4dccb"));draw_arc(center,14,0,TAU,32,Color("c4a770"),1,true)
		if earned:draw_texture_rect(FurUIIcons.get_icon("check"),Rect2(center-Vector2(15,15),Vector2(30,30)),false)
		else:draw_string(FurChapterUITheme.font(),center+Vector2(-4,5),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("91856d"))
	draw_string(FurChapterUITheme.font(),Vector2(size.x-89,79),"挑战印章",HORIZONTAL_ALIGNMENT_LEFT,-1,12,FurChapterUITheme.MUTED)
