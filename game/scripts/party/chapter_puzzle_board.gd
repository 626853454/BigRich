class_name ChapterPuzzleBoard
extends Control
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var kind:="mahjong"
var data:Dictionary={}
var engine:RefCounted
var portraits:Array[Texture2D]=[]

func configure(activity:String,state:Dictionary,source:RefCounted,faces:Array[Texture2D]=[])->void:
	kind=activity;data=state.duplicate(true);engine=source;portraits=faces.duplicate();mouse_filter=Control.MOUSE_FILTER_IGNORE;queue_redraw()

func _text(where:Vector2,value:String,size_px:int=20,colour:Color=Palette.INK)->void:
	draw_string(FurVisualStyle.font(),where,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,colour)

func _box(rect:Rect2,fill:Color,border:Color,radius:int=16)->void:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border;style.set_border_width_all(2);style.set_corner_radius_all(radius);style.shadow_color=Color(0,0,0,.13);style.shadow_size=4;style.shadow_offset=Vector2(0,4);draw_style_box(style,rect)

func _draw()->void:
	if data.is_empty():return
	if kind=="mahjong":_mahjong()
	else:_echo()

func _mahjong()->void:
	var goals:Dictionary=data.get("goals",{})
	var names:=["风闸 · 顺子开","盾甲 · 刻子破","陷阱 · 将眼护"]
	var keys:=["gate","armor","trap"]
	for i in 3:
		var alive:bool=bool(goals.get(keys[i],true));var x:float=38+i*328
		_box(Rect2(x,12,310,82),Color("eff3dd") if alive else Color("c5e9d7"),Color("c8b98e"))
		_text(Vector2(x+20,47),names[i],24)
		_text(Vector2(x+20,77),"等待破解" if alive else "已解除  ✓",16,Color("7e9275"))
	_text(Vector2(38,129),"公开牌谱 · 所有搭配都来自这九张牌，灰牌本场已耗",19)
	var hand:Array=data.get("hand",[])
	var in_challenge:bool=data.get("phase","")=="challenge"
	var tea:Dictionary=data.get("tea",{})
	for i in data.get("deck",[]).size():
		var value:int=data.deck[i];var suit:int=(value-1)/3;var rank:int=(value-1)%3+1;var x:float=42+i*111
		var spent:bool=in_challenge and i not in hand
		_box(Rect2(x,150,96,134),Color("d8d8cf") if spent else Color("fffced"),Color("afa890") if spent else Color("b99a64"),13)
		if tea.get("accepted",false) and i==int(tea.get("protected_slot",-1)):
			var mark:=StyleBoxFlat.new();mark.bg_color=Color.TRANSPARENT;mark.border_color=Color("d39634");mark.set_border_width_all(4);mark.set_corner_radius_all(15);draw_style_box(mark,Rect2(x-3,147,102,140));_text(Vector2(x+38,176),"护送",14,Color("ac7038"))
		_text(Vector2(x+13,176),"%02d"%(i+1),14,Color("a49b8a"))
		var colour:Color=[Color("54978a"),Color("7096b7"),Color("bc6c75")][suit]
		_text(Vector2(x+30,216),str(rank),36,colour if not spent else Color("99988e"))
		_text(Vector2(x+27,254),ChapterMahjong.tile_name(value).right(1),29,colour if not spent else Color("99988e"))
		if spent:draw_line(Vector2(x+16,266),Vector2(x+80,168),Color("a59c8b"),2,true)
	var relics:Array=data.get("relics",[])
	var relic_names:Array[String]=[]
	for relic in relics:relic_names.append({"bridge":"将眼搭桥","echo":"顺子连携","thrift":"惜牌护符"}.get(relic,relic))
	_text(Vector2(38,323),"规则遗物："+("尚无 · 在棋盘的牌谱工坊选取" if relics.is_empty() else " / ".join(PackedStringArray(relic_names))),18)
	if tea.get("accepted",false):
		var patterns:Array=tea.get("patterns",[])
		_text(Vector2(38,353),"茶约：顺%s  刻%s  眼%s · 金框牌胜利时须在手 · 万能已备%d"%["✓" if "sequence" in patterns else "○","✓" if "triplet" in patterns else "○","✓" if "pair" in patterns else "○",data.get("wild",0)],17,Color("ac7038"))
	else:_text(Vector2(38,353),"同花1·2·3为顺，三张相同为刻，两张相同为眼 · 万能已备%d"%data.get("wild",0),17,Palette.MUTED)

func _echo()->void:
	var cell:=60.0;var origin:=Vector2(55,18);var ghosts:Array=engine.ghost_positions();var lit:Array=engine.lit_plates()
	for y in 5:
		for x in 5:
			var p:=Vector2i(x,y);var rect:=Rect2(origin+Vector2(x,y)*cell,Vector2(54,54))
			var wall:bool=p in data.walls;var fill:=Color("f7efdd")
			if wall:fill=Color("a6a2b2")
			var plate:int=data.plates.find(p)
			if plate>=0:fill=Color("b3ead0") if lit[plate] else Color("eac6dd")
			if p in data.delivery_points:fill=Color("f4d383")
			_box(rect,fill,Color("b7a887"),9)
			if plate>=0:_text(rect.position+Vector2(15,35),"AB"[plate],24)
			elif p in data.delivery_points:
				var who:int=data.delivery_points.find(p)
				_text(rect.position+Vector2(7,34),"交付" if data.delivery_points[0]==data.delivery_points[1] else ["柯箱","泡箱"][who],18,[Color("bb745e"),Color("4a9694")][who])
			elif wall:_text(rect.position+Vector2(16,35),"×",22)
	for i in ghosts.size():
		var point:Vector2=origin+Vector2(ghosts[i])*cell+Vector2(28,28)
		draw_arc(point,20,0,TAU,24,Color("a294c9"),3,true);_text(point+Vector2(-15,-22),"回声",12,Color("8876ad"))
		if portraits.size()==2:draw_texture_rect(portraits[i],Rect2(point-Vector2(20,20),Vector2(40,40)),false,Color(.78,.69,.93,.38))
	for i in 2:
		var point:Vector2=origin+Vector2(data.positions[i])*cell+Vector2(24+i*8,26+i*7)
		draw_circle(point,19,[Color("e99b80"),Color("76bdbb")][i])
		if portraits.size()==2:draw_texture_rect(portraits[i],Rect2(point-Vector2(25,29),Vector2(50,50)),false)
		else:_text(point+Vector2(-9,7),["柯","泡"][i],17,Color("fffaf0"))
	_text(Vector2(396,45),"把上一轮的自己，留在需要的位置",23)
	_text(Vector2(396,80),"先录：两人各到 A / B → 封存记录",19)
	_text(Vector2(396,110),"再送：回声压板，各自走同色交付点",19)
	_text(Vector2(396,151),"旧轨迹供电表 · 只计算已录回声与余辉",17,Palette.MUTED)
	for beat in 8:
		var occupants:Array=engine.ghost_positions(beat)
		for offset in range(1,int(data.afterglow)+1):
			if beat-offset>=0:occupants.append_array(engine.ghost_positions(beat-offset))
		var lights:Array=[data.plates[0] in occupants,data.plates[1] in occupants];var x:float=399+beat*69
		_box(Rect2(x,169,58,64),Color("c2e7d4") if lights[0] and lights[1] else Color("eee4d9"),Palette.GOLD if beat==data.beat else Color("d4c5ae"),10)
		_text(Vector2(x+21,195),str(beat+1),17)
		_text(Vector2(x+13,221),("A" if lights[0] else "·")+(" B" if lights[1] else " ·"),14)
	_text(Vector2(396,268),"第%d/3轮 · 第%d/8拍 · 能量 %d/2"%[data.loop+1,data.beat+1,data.deliveries],24)
	_text(Vector2(396,303),"当前真人 + 回声：A%s / B%s"%["已通电" if lit[0] else "未通电","已通电" if lit[1] else "未通电"],17,Palette.MUTED)
	_text(Vector2(396,334),"旋转券改轨迹；回声券让离开的踏板多亮。",17,Palette.MUTED)
