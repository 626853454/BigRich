class_name FurMahjongTeahousePresenter
extends Control
signal discard_requested(index:int,actor:int,revision:int)
signal action_requested(choice:int,actor:int,revision:int)
signal resource_requested(key:String,actor:int,revision:int)
signal retreat_requested(actor:int,revision:int)
signal tea_requested(kind:String,value:Variant,actor:int,revision:int)
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const View=preload("res://scripts/party/mahjong_table_view.gd")
const Tea=preload("res://scripts/party/mahjong_teahouse_rules.gd")
var table_view:FurMahjongTableView
var buttons:Array[Button]=[]
var snapshot:Dictionary={}
var use_ai:=true
var selected_index:=-1
var available_actions:Array=[]
var resource_counts:Dictionary={}
var resource_allowed:Dictionary={}
var heading:Label
var status:Label
var hint:Label
var actions:GridContainer
var _turn:Label
var _brew:Label
var _orders:Label
var _selection:Label
var _wall:Label
var _recipe_buttons:Dictionary={}
var _tray_buttons:Array[Button]=[]
var _resource_buttons:Dictionary={}
var _back:Button
var _built:=false
var _was_busy:=false

func _ready()->void:
	theme=Palette.create();custom_minimum_size=Vector2(1600,900);mouse_filter=Control.MOUSE_FILTER_IGNORE
	table_view=View.new();table_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(table_view);table_view.tile_selected.connect(_select);table_view.tray_selected.connect(_tray_pick)
	var top:=_panel(Rect2(22,18,1556,82))
	heading=_label("云顶雀馆 · 同桌茶会",28);heading.position=Vector2(20,8);heading.size=Vector2(540,38);top.add_child(heading)
	status=_label("真实136张 · 四面子一将 / 门清七对",15);status.position=Vector2(22,49);status.size=Vector2(680,24);top.add_child(status)
	_turn=_label("",23);_turn.position=Vector2(720,15);_turn.size=Vector2(480,44);top.add_child(_turn)
	_back=_button("离席",func():retreat_requested.emit(int(snapshot.get("actor",0)),int(snapshot.get("revision",0))));_back.position=Vector2(1370,14);_back.size=Vector2(160,52);top.add_child(_back)
	var left:=_panel(Rect2(22,690,428,191))
	var title:=_label("同桌茶约",21);title.position=Vector2(16,10);title.size=Vector2(230,32);left.add_child(title);title.hide()
	_orders=_label("",15);_orders.position=Vector2(16,53);_orders.size=Vector2(396,87);left.add_child(_orders)
	_wall=_label("",13);_wall.position=Vector2(16,170);_wall.size=Vector2(395,20);left.add_child(_wall)
	var right:Panel=left
	_brew=_label("",22);_brew.position=Vector2(16,10);_brew.size=Vector2(396,36);right.add_child(_brew)
	var y:=48
	for id:String in Tea.RECIPES:
		var recipe:Dictionary=Tea.RECIPES[id]
		var button:=_button(recipe.name+" · "+recipe.short,_choose_recipe.bind(id));button.position=Vector2(14,y);button.size=Vector2(400,36);button.tooltip_text=recipe.detail;right.add_child(button);_recipe_buttons[id]=button;y+=39
	_selection=_label("点选手牌，再选茶盘换入牌",16);_selection.position=Vector2(16,140);_selection.size=Vector2(395,32);right.add_child(_selection)
	for slot in 3:
		var b:=_button("",_exchange.bind(slot));b.position=Vector2(14,304+slot*50);b.size=Vector2(266,46);right.add_child(b);b.hide();_tray_buttons.append(b)
	for i in 2:
		var key:String=["wilds","redraws"][i]
		var b:=_button("",_resource.bind(key));b.position=Vector2(1300+i*138,114);b.size=Vector2(130,50);add_child(b);_resource_buttons[key]=b
	var notice:=_panel(Rect2(470,690,1108,46))
	hint=_label("摸牌入手后，点击实体牌选择。",16);hint.position=Vector2(16,8);hint.size=Vector2(1076,34);notice.add_child(hint)
	actions=GridContainer.new();actions.position=Vector2(470,749);actions.size=Vector2(1108,130);actions.columns=3;actions.add_theme_constant_override("h_separation",10);actions.add_theme_constant_override("v_separation",8);add_child(actions)
	_built=true
	if not snapshot.is_empty():_render()

func _panel(rect:Rect2)->Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.mouse_filter=Control.MOUSE_FILTER_STOP
	var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.10,.105,.91);style.border_color=Color(.69,.57,.32,.75);style.set_border_width_all(1);style.set_corner_radius_all(18);style.shadow_size=10;style.shadow_color=Color(0,0,0,.15);p.add_theme_stylebox_override("panel",style);add_child(p);return p

func _label(value:String,font_size:int)->Label:
	var l:=Label.new();l.text=value;l.add_theme_font_override("font",Palette.font(font_size>=21));l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("f7eedb"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;return l

func _button(value:String,callback:Callable)->Button:
	var b:=Button.new();b.text=value;b.add_theme_font_size_override("font_size",16);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.pressed.connect(callback);Palette.apply_button(b,"ivory");return b

func configure(data:Dictionary,ai:bool,choices:Array,counts:Dictionary,allowed:Dictionary)->void:
	if snapshot.get("revision",-1)!=data.get("revision",-1):selected_index=-1
	snapshot=data.duplicate(true);use_ai=ai;available_actions=choices.duplicate(true);resource_counts=counts.duplicate(true);resource_allowed=allowed.duplicate(true)
	if _built:_render()

func _process(_delta:float)->void:
	if not _built or snapshot.is_empty():return
	var busy:bool=table_view.is_animating()
	if busy!=_was_busy:_was_busy=busy;_lock_controls()

func _select(index:int,actor:int,revision:int)->void:
	if table_view.is_animating() or snapshot.get("actor",-1)!=actor or snapshot.get("revision",-1)!=revision or snapshot.get("phase","")!="discard" or (use_ai and actor==1):return
	if index<0 or index>=snapshot.hands[actor].size():return
	selected_index=index;table_view.select_tile(index);_render_actions();_render_tea();_lock_controls();_show_waits()

func _render()->void:
	var actor:int=snapshot.actor;var phase:String=snapshot.phase
	status.text=("公开残局 · 起手预设" if snapshot.get("mode","")=="endgame" else "随机136张 · 公共茶盘3张")+"  /  真实吃碰杠胡 · 任一伙伴胡牌共同过站"
	_turn.text=("泡泡正在思考" if use_ai and actor==1 else ["小柯的回合","泡泡的回合"][actor])+" · "+{"discard":"选牌 / 换牌","claim":"响应弃牌","peek":"重排墙顶","finished":"本局结算"}.get(phase,phase)
	_wall.text="牌墙 %d 张 · 弃牌 %d / 64"%[snapshot.wall.size(),snapshot.discard_count]
	table_view.configure(snapshot,use_ai,selected_index);_render_actions();_render_tea();_lock_controls()

func _render_tea()->void:
	if not snapshot.has("tea"):return
	var t:Dictionary=snapshot.tea;var actor:int=snapshot.actor
	_brew.text="%s   ·   茶气 %d / 9"%[Tea.RECIPES[t.recipe].name,t.charge]
	var names:Array=["开门迎客 · 完成一次吃碰杠","三色茶会 · 已舍万筒索","同桌接力 · 双方都开副露"]
	var lines:Array[String]=[]
	for i in 3:lines.append(("✓ " if t.orders[i] else "○ ")+names[i]+("  已完成" if t.orders[i] else "  +2茶气"))
	_orders.text="\n".join(lines);_orders.visible=t.locked;_selection.visible=t.locked
	for id:String in _recipe_buttons:
		var b:Button=_recipe_buttons[id];b.text=("● " if t.recipe==id else "")+Tea.RECIPES[id].name+" · "+Tea.RECIPES[id].short;Palette.apply_button(b,"selected" if t.recipe==id else "ivory");b.visible=not t.locked
		for style_name in ["normal","hover","pressed","disabled"]:
			var compact:StyleBox=b.get_theme_stylebox(style_name).duplicate();compact.content_margin_top=2;compact.content_margin_bottom=2;b.add_theme_stylebox_override(style_name,compact)
	var name:String=ChapterMahjongTable.tile_name(snapshot.hands[actor][selected_index]) if selected_index>=0 and selected_index<snapshot.hands[actor].size() else ""
	_selection.text=("用 "+name+" 换取 · 每次 %d 茶气"%Tea.cost(snapshot,actor)) if not name.is_empty() else "点手牌 → 点中央茶盘牌交换"
	for i in 3:_tray_buttons[i].text="茶盘 %d  ·  %s"%[i+1,ChapterMahjongTable.tile_name(t.tray[i])]
	for key in _resource_buttons:
		_resource_buttons[key].visible=int(resource_counts.get(key,0))>0
		_resource_buttons[key].text=("窥牌券" if key=="wilds" else "换摸券")+" ×%d"%resource_counts.get(key,0)

func _render_actions()->void:
	for child in actions.get_children():actions.remove_child(child);child.queue_free()
	buttons.clear()
	var actor:int=snapshot.actor;var revision:int=snapshot.revision;var phase:String=snapshot.phase
	if phase=="discard":
		var chosen:int=selected_index
		var caption:String="点手牌，再确认打出" if chosen<0 else "打出 · "+ChapterMahjongTable.tile_name(snapshot.hands[actor][chosen])+"  +茶气"
		var b:=_button(caption,func():discard_requested.emit(chosen,actor,revision));b.set_meta("requires_selection",true);Palette.apply_button(b,"primary");actions.add_child(b);buttons.append(b)
	for i in available_actions.size():
		var item:Dictionary=available_actions[i];var b:=_button(item.label,_action.bind(i,actor,revision));b.tooltip_text=item.get("detail","");Palette.apply_button(b,"primary" if item.kind in ["ron","tsumo"] else "ivory");actions.add_child(b);buttons.append(b)
	for i in buttons.size():buttons[i].custom_minimum_size=Vector2(360,55);buttons[i].text="%d  %s"%[i+1,buttons[i].text]
	hint.text=snapshot.get("tea",{}).get("message","点击手牌")
	if phase=="claim":hint.text="上家打出 "+ChapterMahjongTable.tile_name(snapshot.last_discard.tile)+" · 吃碰获得茶气；过则摸牌。"
	if phase=="peek":hint.text="选择真实墙顶三张的顺序，下一次通常由伙伴先摸。"
	if phase=="finished":hint.text="胡牌！真实手牌与副露组成四面子一将 / 门清七对。" if snapshot.result.success else "本局结束，茶盘与牌墙全部保留真实实体。"

func _lock_controls()->void:
	var actor:int=snapshot.actor;var locked:bool=(use_ai and actor==1) or table_view.is_animating() or snapshot.phase=="finished"
	for b in buttons:b.disabled=locked or (b.get_meta("requires_selection",false) and selected_index<0)
	for id in _recipe_buttons:_recipe_buttons[id].disabled=locked or snapshot.tea.locked
	for slot in 3:_tray_buttons[slot].disabled=locked or not Tea.can_swap(snapshot,selected_index,slot,actor)
	for key in _resource_buttons:_resource_buttons[key].disabled=locked or int(resource_counts.get(key,0))<=0 or not resource_allowed.get(key,false)
	_back.disabled=locked

func _action(choice:int,actor:int,revision:int)->void:
	if not table_view.is_animating():action_requested.emit(choice,actor,revision)
func _choose_recipe(id:String)->void:tea_requested.emit("recipe",id,int(snapshot.actor),int(snapshot.revision))
func _exchange(slot:int)->void:tea_requested.emit("exchange",Vector2i(selected_index,slot),int(snapshot.actor),int(snapshot.revision))
func _resource(key:String)->void:resource_requested.emit(key,int(snapshot.actor),int(snapshot.revision))

func _tray_pick(slot:int,actor:int,revision:int)->void:
	if actor!=snapshot.actor or revision!=snapshot.revision:return
	if selected_index<0:hint.text="先点击一张手牌，再点击茶盘中的牌交换。";return
	if not Tea.can_swap(snapshot,selected_index,slot,actor):hint.text="茶气不足、换牌次数已用完，或两张牌相同；换别的牌或打牌蓄气。";return
	_exchange(slot)

func _show_waits()->void:
	if selected_index<0:return
	var actor:int=snapshot.actor;var hand:Array=snapshot.hands[actor].duplicate();hand.remove_at(selected_index)
	var used:Array=hand.duplicate()
	for meld in snapshot.melds[actor]:used.append_array(meld.tiles)
	var names:Array[String]=[]
	for type in 34:
		for copy in 4:
			var id:int=type*4+copy
			if id in used:continue
			var test:Array=hand.duplicate();test.append(id)
			if ChapterMahjongTable.winning_hand(test,snapshot.melds[actor],snapshot.styles[actor]).valid:names.append(ChapterMahjongTable.type_name(type))
			break
	if not names.is_empty():hint.text="打出后听牌："+" / ".join(names)+" · 也可先看看茶盘有没有补形牌。"
	else:hint.text="可确认打出，或点击桌面中央茶盘换牌。换出的牌会留给伙伴。"
