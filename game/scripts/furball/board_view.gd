class_name FurBoardView
extends Control

signal action_requested(kind:String,choice:int,actor:int)
signal suggestion_requested(adjustment:int,actor:int)
const Runtime=preload("res://scripts/furball/board_runtime.gd")
const Supplies=preload("res://scripts/furball/team_supplies.gd")
const DistrictCatalog=preload("res://scripts/furball/district_catalog.gd")
const Events=preload("res://scripts/furball/board_events.gd")
const Suggestions=preload("res://scripts/furball/route_suggestion.gd")
const Patrol=preload("res://scripts/furball/patrol_rival.gd")
const Challenge=preload("res://scripts/furball/challenge_contract.gd")
const TRACK:=[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(2,3),Vector2i(1,3),Vector2i(0,3),Vector2i(0,2),Vector2i(0,1)]
const COLOURS:=[Color("ffc374"),Color("75e0ed"),Color("a2e694")]
const DISTRICT_NAMES:=["串串窄巷","物流横街","奶茶双站"]
const CELL:=Vector2(145,80)
const ORIGIN:=Vector2(18,64)
const STEP_SECONDS:=.15
var state:Dictionary={}
var actor:=0
var labels:Array[Label]=[]
var buttons:Array[Button]=[]
var title:Label
var centre:Label
var wallet:Label
var detail:Label
var progress:Label
var investment_picker:OptionButton
var investment_target:=0
var roll_clock:=0.0
var move_clock:=0.0
var landing_clock:=0.0
var animated_path:Array=[]
var passed:Array=[]
var shown_position:=0
var move_origin:=0
var preview_path:Array=[]
var clock:=0.0
var background:StyleBoxFlat
var supply_facts:Array=[]
var supply_mode:=false
var business_tabs:Array[Button]=[]
var display_seed:=1
var control_mode:="solo"
var suggestion_label:Label
var order_state:Dictionary={}
var order_picker:OptionButton
var order_caption:Label
var order_choice:=0
var order_bound_token:=0
var patrol_state:Dictionary={}
var patrol_label:Label

func _ready()->void:
	custom_minimum_size=Vector2(950,580);size=custom_minimum_size
	background=_background()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-475;offset_right=475;offset_top=-290;offset_bottom=290
	mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_font_override("font",FurVisualStyle.font())
	for index in 12:
		var label:=_label("",16);label.position=_cell_rect(index).position+Vector2(8,20);label.size=Vector2(126,54);labels.append(label)
	title=_label("",25);title.position=Vector2(20,12);title.size=Vector2(910,40)
	centre=_label("",17);centre.position=Vector2(178,148);centre.size=Vector2(260,78);centre.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	wallet=_label("",20);wallet.position=Vector2(632,67);wallet.size=Vector2(295,106)
	detail=_label("",16);detail.position=Vector2(632,180);detail.size=Vector2(295,242)
	progress=_label("",16);progress.position=Vector2(22,414);progress.size=Vector2(906,44)
	patrol_label=_label("",14);patrol_label.position=Vector2(22,388);patrol_label.size=Vector2(574,22)
	patrol_label.autowrap_mode=TextServer.AUTOWRAP_OFF;patrol_label.add_theme_color_override("font_color",Color("ffad9d"))
	suggestion_label=_label("",14);suggestion_label.position=Vector2(22,472);suggestion_label.size=Vector2(906,24)
	suggestion_label.autowrap_mode=TextServer.AUTOWRAP_OFF;suggestion_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	suggestion_label.add_theme_color_override("font_color",Color("8ae6f7"));suggestion_label.hide()
	for index in 2:
		var tab:=Button.new();tab.position=Vector2(20+index*460,472);tab.size=Vector2(448,24)
		tab.text=["经营 · 地产 / 挑战 / 留钱","补给 · 奶 / 资源 / 路线券"][index]
		tab.add_theme_font_override("font",FurVisualStyle.font());tab.add_theme_font_size_override("font_size",13)
		for theme_state in ["normal","hover","pressed","disabled","focus"]:
			var compact:=StyleBoxFlat.new();compact.bg_color=Color("2a3a4e");compact.border_color=Color("7188a3");compact.set_border_width_all(1);compact.content_margin_top=1;compact.content_margin_bottom=1
			if theme_state=="disabled":compact.bg_color=Color("1b2639")
			tab.add_theme_stylebox_override(theme_state,compact)
		tab.focus_mode=Control.FOCUS_NONE;tab.pressed.connect(func():supply_mode=index==1;_update_text())
		add_child(tab);business_tabs.append(tab)
	investment_picker=OptionButton.new();investment_picker.position=Vector2(632,382);investment_picker.size=Vector2(295,32)
	investment_picker.add_theme_font_override("font",FurVisualStyle.font());investment_picker.add_theme_font_size_override("font_size",14)
	for index in 3:investment_picker.add_item(DISTRICT_NAMES[index],index)
	investment_picker.item_selected.connect(func(index):investment_target=index;_update_text());add_child(investment_picker);investment_picker.hide()
	order_caption=_label("首轮合伙订单（掷骰时承诺）",14);order_caption.position=Vector2(632,360);order_caption.size=Vector2(295,20);order_caption.hide()
	order_picker=OptionButton.new();order_picker.position=Vector2(632,382);order_picker.size=Vector2(295,32)
	order_picker.add_theme_font_override("font",FurVisualStyle.font());order_picker.add_theme_font_size_override("font_size",15)
	order_picker.item_selected.connect(func(index):order_choice=index;_update_text());add_child(order_picker);order_picker.hide()
	var investment_caption:=_label("投资目标（本轮一次，报价含运费）",14);investment_caption.position=Vector2(632,360);investment_caption.size=Vector2(295,20)
	investment_caption.name="InvestmentCaption";investment_caption.visible=false
	for index in 3:
		var button:=Button.new();button.position=Vector2(20+index*307,498);button.size=Vector2(295,64)
		button.add_theme_font_override("font",FurVisualStyle.font());button.add_theme_font_size_override("font_size",16)
		button.focus_mode=Control.FOCUS_NONE;button.mouse_entered.connect(func():_preview(index));button.mouse_exited.connect(func():preview_path=[];_update_text();queue_redraw())
		button.pressed.connect(func():_act(index));add_child(button);buttons.append(button)
	_update_text()

func _label(text:String,font_size:int)->Label:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FurVisualStyle.font());label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("f5efd9"));add_child(label);return label

func render(snapshot:Dictionary,local_actor:int,player_facts:Array=[],run_seed:int=1,local_mode:String="solo",shared_order:Dictionary={},patrol_snapshot:Dictionary={})->void:
	if snapshot.is_empty():return
	patrol_state=patrol_snapshot.duplicate(true)
	order_state=shared_order.duplicate(true)
	if int(order_state.get("run_token",0))!=order_bound_token:
		order_bound_token=int(order_state.get("run_token",0));order_choice=0
		order_picker.clear()
		for offer in order_state.get("offers",[]):order_picker.add_item(str(offer.title))
	if int(order_state.get("selected",-1))>=0:
		for index in order_state.get("offers",[]).size():
			if order_state.offers[index].id==order_state.selected:order_choice=index
	if order_picker.item_count>0:order_picker.select(order_choice)
	var previous:Dictionary=state
	state=snapshot.duplicate(true);actor=local_actor;supply_facts=player_facts.duplicate(true);display_seed=maxi(1,run_seed);control_mode=local_mode
	if previous.is_empty() or int(previous.get("round",0))!=int(state.round):
		supply_mode=false
		shown_position=int(state.position);animated_path=[];passed=[];roll_clock=0;move_clock=0;landing_clock=0
	elif state.stage=="roll" and int(previous.get("position",0))!=int(state.position):
		shown_position=int(state.position);animated_path=[];passed=[];preview_path=[];move_clock=0;landing_clock=0
	elif previous.get("stage","")=="roll" and state.stage=="move":
		shown_position=int(state.position);animated_path=[];passed=[];roll_clock=.5
	elif state.stage in ["event_choice","business","ready"] and not state.path.is_empty() and (previous.get("stage","") not in ["event_choice","business","ready"] or previous.get("path",[])!=state.path):
		move_origin=int(previous.position);shown_position=move_origin;animated_path=state.path.duplicate();passed=[];move_clock=0
	if state.stage=="business" and previous.get("stage","")!="business":
		investment_target=int(Runtime.PROPERTY.get(int(state.position),Runtime.DISTRICTS[int(state.position)]))
		if int(state.licenses[investment_target])>=2:
			for index in 3:
				if int(state.licenses[index])<2:investment_target=index;break
	if previous.get("stage","")!=state.stage:preview_path=[]
	_update_text();queue_redraw()

func busy()->bool:return roll_clock>0 or not animated_path.is_empty() or landing_clock>0

func _process(delta:float)->void:
	if not visible or state.is_empty():return
	clock+=delta
	var was_busy:=busy()
	roll_clock=maxf(0,roll_clock-delta)
	landing_clock=maxf(0,landing_clock-delta)
	if not animated_path.is_empty():
		move_clock+=delta
		while move_clock>=STEP_SECONDS and not animated_path.is_empty():
			move_clock-=STEP_SECONDS;shown_position=int(animated_path.pop_front());passed.append(shown_position)
			move_origin=shown_position
			if animated_path.is_empty():landing_clock=.3
	if was_busy:_update_text();queue_redraw()

func _cell_rect(index:int)->Rect2:
	return Rect2(ORIGIN+Vector2(TRACK[index])*CELL,CELL-Vector2(5,5))

func _cell_centre(index:int)->Vector2:return _cell_rect(index).get_center()

func _draw()->void:
	if background!=null:draw_style_box(background,Rect2(Vector2.ZERO,size))
	if state.is_empty():return
	var patrol:Dictionary=Patrol.preview_state(patrol_state)
	for index in 12:
		var rect:=_cell_rect(index);var district:int=Runtime.DISTRICTS[index]
		var colour:Color=COLOURS[district]
		draw_rect(rect,colour.darkened(.73))
		draw_rect(rect,colour, false,2 if index!=shown_position else 4)
		if index in preview_path:draw_rect(rect.grow(-3),Color("ffee9a"),false,3)
		elif index in passed:draw_rect(rect.grow(-3),Color("6ee8bc"),false,2)
		if patrol.get("ok",false) and patrol.phase!="closed" and index in patrol.threat_tiles:draw_rect(rect.grow(-10),Color("ff8e7e"),false,2)
		var badge:=rect.position+Vector2(10,10)
		match district:
			0:draw_circle(badge,4,colour)
			1:draw_rect(Rect2(badge-Vector2(4,4),Vector2(8,8)),colour)
			2:draw_colored_polygon(PackedVector2Array([badge+Vector2(0,-5),badge+Vector2(5,0),badge+Vector2(0,5),badge+Vector2(-5,0)]),colour)
		if patrol.get("ok",false) and patrol.phase!="closed" and index==patrol.position:
			var patrol_point:Vector2=rect.position+Vector2(36,3)
			draw_rect(Rect2(patrol_point,Vector2(36,16)),Color("a83c45"));draw_circle(patrol_point+Vector2(7,17),3,Color("162030"));draw_circle(patrol_point+Vector2(29,17),3,Color("162030"))
			draw_string(FurVisualStyle.font(),patrol_point+Vector2(7,13),"巡",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff4de"))
		var next:Vector2=_cell_centre((index+1)%12);var from:Vector2=_cell_centre(index);var middle:Vector2=(from+next)*.5;var direction:Vector2=(next-from).normalized()
		draw_colored_polygon(PackedVector2Array([middle+direction*4,middle-direction*4+direction.orthogonal()*3,middle-direction*4-direction.orthogonal()*3]),Color("ddd7bc"))
	var cart_point:Vector2=_cell_centre(shown_position)+Vector2(30,-21)
	if not animated_path.is_empty():cart_point=_cell_centre(move_origin).lerp(_cell_centre(int(animated_path[0])),move_clock/STEP_SECONDS)+Vector2(30,-21)
	_draw_cart(cart_point)
	var suggested:=Suggestions.display(state,display_seed,actor)
	if suggested.get("visible",false):
		var rect:=_cell_rect(int(suggested.landing));var colour:=Color("8ae6f7")
		draw_rect(rect.grow(-7),colour,false,2)
		var pole:Vector2=rect.position+Vector2(108,8)
		draw_line(pole,pole+Vector2(0,14),colour,2)
		draw_colored_polygon(PackedVector2Array([pole,pole+Vector2(15,4),pole+Vector2(0,8)]),colour)
		draw_string(FurVisualStyle.font(),pole-Vector2(21,-11),"P%d" % (int(suggested.actor)+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,colour)
	var face:int=(int(clock*20)%6)+1 if roll_clock>0 else int(state.face)
	_draw_die(Vector2(274,230),face)

func _background()->StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color("172338");box.border_color=Color("7188a3");box.set_border_width_all(2);box.set_corner_radius_all(14);return box

func _draw_cart(point:Vector2)->void:
	draw_rect(Rect2(point-Vector2(20,13),Vector2(40,24)),Color("ffe192"))
	draw_rect(Rect2(point-Vector2(14,8),Vector2(17,8)),Color("47777f"));draw_rect(Rect2(point+Vector2(7,-8),Vector2(9,8)),Color("47777f"))
	draw_circle(point+Vector2(-12,13),5,Color("152030"));draw_circle(point+Vector2(12,13),5,Color("152030"))

func _draw_die(point:Vector2,face:int)->void:
	draw_rect(Rect2(point,Vector2(70,70)),Color("fff1c7"));draw_rect(Rect2(point,Vector2(70,70)),Color("ddad65"),false,3)
	if face<1:return
	var pips:Array=[]
	if face in [1,3,5]:pips.append(Vector2(35,35))
	if face>=2:pips.append_array([Vector2(18,18),Vector2(52,52)])
	if face>=4:pips.append_array([Vector2(52,18),Vector2(18,52)])
	if face==6:pips.append_array([Vector2(18,35),Vector2(52,35)])
	for pip in pips:draw_circle(point+pip,5,Color("253248"))

func _preview(choice:int)->void:
	preview_path=[]
	if state.get("stage","")!="move" or busy():return
	var helper:=Runtime.new();helper.state=state.duplicate(true);preview_path=helper.preview(choice-1);_update_text();queue_redraw()

func _act(choice:int)->void:
	if busy():return
	if state.stage=="move" and actor!=int(state.active) and control_mode in ["host","client"] and int(state.players)==2:
		var helper:=Runtime.new();helper.state=state.duplicate(true)
		if choice in [0,1,2] and not helper.preview(choice-1).is_empty():suggestion_requested.emit(choice-1,actor)
		return
	if actor!=int(state.active):return
	match str(state.stage):
		"roll":action_requested.emit("board_roll",roll_order_choice(),actor)
		"move":action_requested.emit("board_move",choice,actor)
		"event_choice":
			var proposed:=_event_options()
			if not proposed.ok or choice<0 or choice>2:return
			if choice==2 and not proposed.auto_skip_allowed:return
			if choice<2 and not proposed.offers[choice].available:return
			action_requested.emit("board_event",choice,actor)
		"business":
			if supply_mode:
				if choice<0 or choice>2 or not Supplies.offer(state,supply_facts,Supplies.IDS[choice]).ok:return
				action_requested.emit("board_supply",choice,actor)
			else:action_requested.emit("board_invest" if choice==0 else "board_business",investment_target if choice==0 else choice,actor)

func _update_text()->void:
	if title==null or state.is_empty():return
	detail.add_theme_font_size_override("font_size",16)
	detail.size.y=242
	title.text="夜市大富翁 · 第 %d / 6 轮 · P%d 操骰" % [int(state.round),int(state.active)+1]
	for index in 12:
		var local:int=Runtime.PROPERTY.get(index,-1)
		labels[index].text="%02d %s\n%s" % [index,Runtime.NAMES[index],"共享地产 Lv.%d" % int(state.licenses[local]) if local>=0 else "事件格"]
	centre.text="共享夜市车 · 双向商路\n%s" % ("骰子滚动中…" if roll_clock>0 else "原始骰点 %d → %s" % [int(state.face),"待调整步数" if state.stage=="move" else "%d 步" % int(state.steps)] if int(state.face)>0 else "掷骰后预览落点")
	var dividend:=0
	for level in state.licenses:dividend+=int(level)*2
	wallet.text="钱袋 %d 金 · 步数券 %d\n每站保底 10 + 地产 %d\n共用执照：串%d / 物%d / 奶%d" % [int(state.cash),int(state.nudges),dividend,int(state.licenses[0]),int(state.licenses[1]),int(state.licenses[2])]
	var helper:=Runtime.new();helper.state=state.duplicate(true)
	var destination:int=int(preview_path.back()) if not preview_path.is_empty() else int(state.position)
	var patrol_landing:int=destination if not preview_path.is_empty() or state.stage in ["event_choice","business","ready"] else -1
	var patrol:Dictionary=Patrol.preview_state(patrol_state,patrol_landing)
	patrol_label.visible=patrol.get("ok",false) and patrol.get("phase","")!="closed"
	if patrol_label.visible:
		patrol_label.text="巡街 %02d/%02d · %s · 委托成下轮%02d，未完%02d" % [int(patrol.threat_tiles[0]),int(patrol.threat_tiles[1]),"落点+25%刷新" if patrol.pressure_active else "仅最终落点受压" if patrol_landing<0 else "落点安全",int(patrol.next_if_complete),int(patrol.next_if_incomplete)]
	var district:int=Runtime.DISTRICTS[destination]
	var layout:Dictionary=DistrictCatalog.layout(district,int(state.round),display_seed+int(state.round)*101)
	var street:String=DISTRICT_NAMES[district]+" · "+str(layout.variant_title)
	var description:=_layout_description(district,int(layout.variant_id))
	detail.text="%s落点：%s\n街区：%s\n%s\n本地目标兑现：额外 %d 金\n正向经过开市 +12；倒车不领绕圈补助\n%s" % ["预览 · " if not preview_path.is_empty() else "",Runtime.NAMES[destination],street,description,4+int(state.licenses[district])*2,"轮到你操作" if actor==int(state.active) else "本轮搭档操作；共享所有利润"]
	if not preview_path.is_empty():
		var preview_helper:=Runtime.new();preview_helper.state=state.duplicate(true);preview_helper.state.position=destination
		var local:=preview_helper.property_district();var price:=preview_helper.price()
		detail.text+="\n"+("本地执照 %d 金；异地多付6" % price if price>=0 else "可异地投资执照，另付运费6" if local<0 else "本地执照已满级")
		if destination in Events.TILES:detail.text+="\n事件二选一："+{4:"现金 / 路线券",7:"付8金 / 追缴压力",9:"路线券 / 免费资源"}[destination]
	if not order_state.is_empty() and state.stage!="roll":detail.text+="\n"+_order_destination_text(district)
	progress.text="%s\n%s" % ["骰点确认中" if roll_clock>0 else "车正在经过："+str(passed) if not animated_path.is_empty() else "到站："+Runtime.NAMES[shown_position] if landing_clock>0 else str(state.message),"倒车按骰点2券 / 原步0券 / 正向+1步1券；经营操作每轮一次。" if state.stage=="move" else "每轮一次经营：地产 / 挑战 / 留钱 / 补给互斥。"]
	for index in 3:buttons[index].visible=true;buttons[index].disabled=busy() or actor!=int(state.active)
	for index in 2:
		business_tabs[index].visible=state.stage=="business"
		business_tabs[index].disabled=busy() or supply_mode==(index==1)
	investment_picker.visible=state.stage=="business" and not supply_mode
	get_node("InvestmentCaption").visible=investment_picker.visible
	investment_picker.disabled=busy() or actor!=int(state.active)
	var initial_order:bool=state.stage=="roll" and int(state.round)==1 and not order_state.is_empty()
	order_caption.visible=initial_order;order_picker.visible=initial_order
	order_picker.disabled=busy() or actor!=int(state.active) or int(order_state.get("selected",-1))>=0
	suggestion_label.visible=state.stage=="move" and int(state.players)==2 and control_mode!="solo"
	if suggestion_label.visible:
		var flag:=Suggestions.display(state,display_seed,actor)
		suggestion_label.text=str(flag.label) if flag.get("visible",false) else "队友建议：尚未提出 · 操骰者可直接选择，不用确认"
	match str(state.stage):
		"roll":
			buttons[0].text="1 / 空格 · 掷骰并承诺订单" if initial_order and int(order_state.get("selected",-1))<0 else "1 / 空格 · 掷骰";buttons[1].visible=false;buttons[2].visible=false
			if initial_order:
				detail.size.y=172
				var recipe:Dictionary=order_state.offers[order_choice]
				detail.text="合伙订单 · %s\n缺货：%s\n完成两街委托收货，护送货箱过两节点。\n第5站及之前交付：下一正常成长各多选一次合法改装；第6站仅履约。\n选单不花钱、不占本轮经营。" % [recipe.title,_mask_names(int(recipe.mask))]
			elif not order_state.is_empty():detail.text+="\n"+_order_destination_text(district)
		"move":
			var waiting_remote:bool=actor!=int(state.active) and control_mode in ["host","client"] and int(state.players)==2
			if int(state.players)==2 and control_mode=="local":progress.text=str(state.message)+"\n队友 Shift+1/2/3 建议；操骰者普通 1/2/3 直接选路。"
			elif waiting_remote:progress.text=str(state.message)+"\n你在等待：1/2/3 提建议；操骰者可直接选路，不用确认。"
			for index in 3:
				var path:=helper.preview(index-1)
				buttons[index].text="%d · %s · %d 步\n→ %s" % [index+1,(["建议倒车 / 采用花2券","建议原步 / 不花券","建议 +1 / 采用花1券"] if waiting_remote else ["倒车骰点 / 花2券","原骰点 / 不花券","正向加一 / 花1券"])[index],path.size(),Runtime.NAMES[int(path.back())] if not path.is_empty() else "共享券不足"]
				if not path.is_empty() and Patrol.preview_state(patrol_state,int(path.back())).get("pressure_active",false):buttons[index].text+=" · 巡街+25%"
				buttons[index].disabled=(busy() if waiting_remote else buttons[index].disabled) or path.is_empty() or (waiting_remote and int(state.get("suggestion",{}).get("revision",0))>=3)
				buttons[index].tooltip_text=("倒车按原骰点走，采用时花2券；经过开市不领绕圈12金，落点原收益保持。\n" if index==0 else "")+("建议不花券、不替队友移动；本轮最多首次加两次修改。" if waiting_remote else "直接承诺本路线；无需搭档确认。")
		"event_choice":_draw_event()
		"business":
			detail.add_theme_font_size_override("font_size",15)
			if supply_mode:
				_draw_supplies()
				return
			for index in 3:
				var cost:=helper.investment_price(index)
				investment_picker.set_item_text(index,"%s Lv.%d · %s" % [["串串","物流","奶茶"][index],int(state.licenses[index]),"已满级" if cost<0 else "%d金%s" % [cost," / 运费6" if helper.property_district()!=index else " / 本地"]])
			investment_picker.select(investment_target)
			var price:=helper.investment_price(investment_target)
			buttons[0].text="1 · 所选执照已满级" if price<0 else "1 · %s%s执照 %d 金\n本局每站分红 +2%s" % ["购买" if int(state.licenses[investment_target])==0 else "升级",["串串","物流","奶茶"][investment_target],price," / 含运费6" if helper.property_district()!=investment_target else ""]
			buttons[0].tooltip_text="执照只在本局生效；每级每站分红 +2 金。\n对应街区开场：活人生命 +6，补流派资源。\n一级：锅能 +15 / 蓄能 +1 / 诱饵 +1。\n二级：锅能 +22 / 蓄能 +1.47 / 诱饵 +1。\n二级街区目标触发：快攻3秒，Q冷却减1.5秒，\n再补锅12 / 蓄能0.8 / 饼1。\n异地购买不会改变当前落点街区。"
			investment_picker.tooltip_text=buttons[0].tooltip_text
			var proposed_level:=mini(2,int(state.licenses[investment_target])+1)
			detail.text="落点：%s\n%s\n%s\n本地目标兑现：额外 %d 金\n拟投%s执照 → Lv.%d\n入此街区：+6生命，%s%s" % [Runtime.NAMES[int(state.position)],street,description,4+int(state.licenses[district])*2,["串串","物流","奶茶"][investment_target],proposed_level,"锅15 / 蓄1 / 饼1" if proposed_level==1 else "锅22 / 蓄1.47 / 饼1","\n目标触发：快攻3秒，Q冷却-1.5秒" if proposed_level==2 else ""]
			if investment_target!=district:detail.text+="\n异地补给：到访所选街区才生效"
			buttons[0].disabled=buttons[0].disabled or price<0 or int(state.cash)<price
			var challenge_pressure:Dictionary=Patrol.combined_pressure(float(state.get("event_pressure_add",0.0)),bool(patrol.get("pressure_active",false)),true)
			buttons[1].text="2 · 抢档挑战 · 刷新×%.2f\n%.0f秒清群+完整委托+站胜：8金" % [float(challenge_pressure.spawn_multiplier),float(Challenge.WINDOW)]
			buttons[1].tooltip_text="第一步委托完成后登记抢档，最迟11秒自动登记。\n至少预告0.75秒，再标记下一压力群2–5名敌人。\n从标记群实际生成起%.0f秒内全清。\n还须完成本场完整委托，并正常站胜，才发额外8金。\n接受后本场刷新×%.2f（挑战另加50%%），未达成也保持。\n挑战未达成但正常站胜，仍发基础营业收入；\n全队倒地没有闭站收入，已有钱袋不倒扣。" % [float(Challenge.WINDOW),float(challenge_pressure.spawn_multiplier)]
			buttons[2].text="3 · 留下钱袋\n进入当前街区"
		_:for button in buttons:button.disabled=true

func _draw_supplies()->void:
	detail.text="补给与本轮投资、挑战、留钱互斥\n实际收益（存活资格按购买时）："
	for index in 3:
		var offer:Dictionary=Supplies.offer(state,supply_facts,Supplies.IDS[index])
		var previews:Array[String]=[]
		for effect in offer.get("effects",[]):
			if effect.kind=="nudges":previews.append("共享步数券 +%d" % int(effect.amount))
			elif not effect.eligible:previews.append("P%d倒地 +0" % (int(effect.player_index)+1))
			else:previews.append("P%d%s +%s" % [int(effect.player_index)+1,{"heal":"生命","pot":"锅能","charge":"蓄能","bait":"诱饵"}.get(effect.kind,"资源"),"%.2f" % float(effect.amount) if effect.kind=="charge" else str(int(effect.amount))])
		var preview:String=" / ".join(previews)
		buttons[index].text="%d · %s %d 金\n%s" % [index+1,offer.name,int(offer.price),preview if offer.ok else str(offer.reason)]
		buttons[index].tooltip_text=str(offer.description)+"\n"+preview+("\n"+str(offer.reason) if not offer.ok else "")
		buttons[index].disabled=buttons[index].disabled or not offer.ok
		detail.text+="\n%s：%s" % [offer.name,preview]
		if not offer.ok:detail.text+="\n"+str(offer.reason)
	detail.text+="\n资源在入场地产补给之后兑现；\n选一项后立即进入当前街区。"

func _event_options()->Dictionary:
	var context:=Events.from_board(state,supply_facts,display_seed,actor,false)
	return Events.options(int(state.get("position",-1)),context)

func _draw_event()->void:
	detail.add_theme_font_size_override("font_size",15)
	var proposed:=_event_options()
	if not proposed.ok:
		detail.text=str(proposed.get("reason","事件报价不可用"))
		for button in buttons:button.disabled=true
		return
	detail.text=str(proposed.title)+"\n先承诺事件，本轮经营仍可选一次。"
	for index in 2:
		var offer:Dictionary=proposed.offers[index]
		var benefits:Array[String]=[]
		if offer.cash_delta!=0:benefits.append("钱袋 %d → %d" % [int(state.cash),int(state.cash)+int(offer.cash_delta)])
		if offer.nudges_delta!=0:benefits.append("共享券 %d → %d" % [int(state.nudges),int(state.nudges)+int(offer.nudges_delta)])
		if offer.pressure_add>0:benefits.append("本战刷新 ×1.25；敌血不变")
		for effect in offer.effects:
			benefits.append("P%d%s +%s" % [int(effect.player_index)+1,{"pot":"锅","charge":"蓄","bait":"饼"}[effect.kind],"%.2f" % float(effect.amount) if effect.kind=="charge" else str(int(effect.amount))])
		var preview:String=" / ".join(benefits)
		buttons[index].text="%d · %s\n%s" % [index+1,offer.name,preview if offer.available else offer.reason]
		buttons[index].disabled=buttons[index].disabled or not offer.available
		buttons[index].tooltip_text=preview+"\n"+str(offer.get("risk",offer.reason))
		detail.text+="\n%d · %s\n%s" % [index+1,offer.name,preview if offer.available else offer.reason]
	buttons[2].visible=proposed.auto_skip_allowed
	buttons[2].text="3 · 两项都无收益\n直接进入经营，不扣钱"
	if int(state.position)==9:detail.text+="\n资源为当前地产等级预计收益；\n随后升级可能挤占入场余量，实际裁剪。"
	if int(state.position)==7:detail.text+="\n若再接经营挑战，合计刷新 ×1.75；\n追缴不算挑战成绩，下轮压力清零。"
	progress.text="事件二选一 · P%d承诺\n先选现金、路线或开场收益，再进行本轮经营。" % [int(state.active)+1]

func _layout_description(district:int,variant:int)->String:
	return [
		["错位短账台：上下换道，点亮任意两台","纵向账台：分两翼绕行，点亮任意两台","横向夹道：绕过上下挡板，点亮任意两台"],
		["横向车流：预告后横穿截货，接三件包裹","纵向车流：避开竖向通道，沿车流接三件包裹","交叉车流：认清斜线预告，沿车流接三件包裹"],
		["对角奶站：两站充能，再到合流点开席","两翼奶站：两站充能，再到前方合流点","后方奶站：两站充能，再到后方合流点"]
	][district][variant]

func roll_order_choice()->int:return order_choice if int(state.get("round",0))==1 and int(order_state.get("selected",-1))<0 else 0

func _mask_names(mask:int)->String:
	var parts:Array[String]=[]
	for index in 3:
		if mask&(1<<index):parts.append(["串串","物流","奶茶"][index])
	return " + ".join(parts) if not parts.is_empty() else "无"

func _order_destination_text(district:int)->String:
	if order_state.get("fulfilled",false):return "合伙订单已交付 · 后续取货不重复发改装。"
	var required:int=order_state.get("required_mask",0);var collected:int=order_state.get("collected_mask",0)
	if required==0:return "尚未承诺订单。"
	if required==collected:return "货已齐：本战重试配送，依次走两节点；受伤/已执行冲刺会掉箱。"
	var bit:int=1<<district
	if (required&bit)==0:return "订单不缺此街货；还缺 "+_mask_names(required&~collected)
	if (collected&bit)!=0:return "已有此街货；还缺 "+_mask_names(required&~collected)
	return "完成本街委托→收"+["串串","物流","奶茶"][district]+"货；还缺 "+_mask_names(required&~collected)
