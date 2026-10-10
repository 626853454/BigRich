class_name FurMahjongTablePresenter
extends VBoxContainer
## Layout owns no hand or economy rules; buttons emit the exact snapshot revision.
signal discard_requested(index:int,actor:int,revision:int)
signal action_requested(choice:int,actor:int,revision:int)
signal resource_requested(key:String,actor:int,revision:int)
signal retreat_requested(actor:int,revision:int)
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const View=preload("res://scripts/party/mahjong_table_view.gd")
const Tiles=preload("res://scripts/party/mahjong_tile_geometry.gd")
var table_view:FurMahjongTableView
var heading:Label
var status:Label
var hint:Label
var actions:GridContainer
var tools:VBoxContainer
var buttons:Array[Button]=[]
var snapshot:Dictionary={}
var use_ai:=true
var selected_index:=-1
var available_actions:Array=[]
var resource_counts:Dictionary={}
var resource_allowed:Dictionary={}
var _built:=false
var _turn:Label
var _selection:Label
var _selection_help:Label
var _selected_tile:FurUIMahjongTilePreview
var _wall:ProgressBar
var _wall_text:Label
var _style:Label
var _goal:Label
var _resource_buttons:Dictionary={}
var _resource_reasons:Dictionary={}
var _back:Button
var _header_badge:Label
func _ready()->void:
	theme=Palette.create();add_theme_constant_override("separation",13)
	var header:=HBoxContainer.new();header.add_theme_constant_override("separation",14);add_child(header);header.add_child(FurUIIcons.view("mahjong",Vector2(61,61)))
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",3);header.add_child(words)
	heading=_label("云顶雀馆",28);words.add_child(heading);status=_label("",15);status.add_theme_color_override("font_color",Palette.MUTED);words.add_child(status)
	_header_badge=_label("同桌合作",17);_header_badge.custom_minimum_size=Vector2(120,45);_header_badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;header.add_child(_header_badge)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",18);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(body)
	var play:=VBoxContainer.new();play.size_flags_horizontal=Control.SIZE_EXPAND_FILL;play.add_theme_constant_override("separation",10);body.add_child(play)
	table_view=View.new();table_view.custom_minimum_size=Vector2(1090,520);table_view.size_flags_vertical=Control.SIZE_EXPAND_FILL;table_view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;play.add_child(table_view);table_view.tile_selected.connect(_select)
	var notice:=PanelContainer.new();var paper:=Palette.panel_style("dark");paper.set_corner_radius_all(14);paper.content_margin_left=16;paper.content_margin_right=16;paper.content_margin_top=9;paper.content_margin_bottom=9;paper.shadow_size=0;notice.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(paper,true));play.add_child(notice)
	hint=_label("点选一张手牌，再确认打出。",16);hint.custom_minimum_size.y=39;hint.add_theme_color_override("font_color",Color("fff3de"));notice.add_child(hint)
	actions=GridContainer.new();actions.columns=3;actions.add_theme_constant_override("h_separation",10);actions.add_theme_constant_override("v_separation",9);play.add_child(actions)
	var rail:=PanelContainer.new();rail.custom_minimum_size.x=360;var plate:=Palette.panel_style();plate.bg_color=Color("fff9ee");plate.shadow_size=6;plate.content_margin_left=18;plate.content_margin_right=18;plate.content_margin_top=17;plate.content_margin_bottom=17;rail.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate));body.add_child(rail)
	tools=VBoxContainer.new();tools.add_theme_constant_override("separation",10);rail.add_child(tools)
	_turn=_label("",24);tools.add_child(_turn)
	var select_row:=HBoxContainer.new();select_row.custom_minimum_size.y=146;tools.add_child(select_row)
	_selected_tile=FurUIMahjongTilePreview.new();select_row.add_child(_selected_tile)
	var selection_words:=VBoxContainer.new();selection_words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selection_words.size_flags_vertical=Control.SIZE_SHRINK_CENTER;select_row.add_child(selection_words)
	_selection=_label("点选一张牌",23);selection_words.add_child(_selection);_selection_help=_label("手牌抬起后，仍需确认才会打出。",15);_selection_help.add_theme_color_override("font_color",Palette.MUTED);selection_words.add_child(_selection_help)
	_wall_text=_label("",16);tools.add_child(_wall_text);_wall=ProgressBar.new();_wall.custom_minimum_size.y=8;_wall.max_value=136;_wall.show_percentage=false;tools.add_child(_wall)
	_style=_label("",22);tools.add_child(_style);_goal=_label("",15);_goal.add_theme_color_override("font_color",Palette.MUTED);_goal.custom_minimum_size.y=64;tools.add_child(_goal)
	for key:String in ["wilds","redraws"]:
		var button:=_button("",func():
			var actor:int=int(snapshot.get("actor",0));resource_requested.emit(key,actor,int(snapshot.get("revision",0))))
		Palette.apply_button(button,"ivory","mahjong" if key=="wilds" else "route");tools.add_child(button);_resource_buttons[key]=button
		var reason:=_label("",13);reason.add_theme_color_override("font_color",Palette.MUTED);tools.add_child(reason);_resource_reasons[key]=reason
	var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;tools.add_child(spacer)
	_back=_button("撤回棋盘",func():retreat_requested.emit(int(snapshot.get("actor",0)),int(snapshot.get("revision",0))));Palette.apply_button(_back,"quiet","compass");tools.add_child(_back)
	_built=true
	if not snapshot.is_empty():_render()
func configure(data:Dictionary,ai:bool,choices:Array,counts:Dictionary,allowed:Dictionary)->void:
	if snapshot.get("revision",-1)!=data.get("revision",-1):selected_index=-1
	snapshot=data.duplicate(true);use_ai=ai;available_actions=choices.duplicate(true);resource_counts=counts.duplicate(true);resource_allowed=allowed.duplicate(true)
	if _built:_render()
func _label(text:String,font_size:int)->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size);label.add_theme_font_override("font",FurChapterUITheme.font(font_size>=22));label.add_theme_color_override("font_color",Palette.INK);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func _button(text:String,callback:Callable)->Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(300,49);button.add_theme_font_size_override("font_size",17);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.pressed.connect(callback);Palette.apply_button(button,"ivory");return button
func _select(index:int,actor:int,revision:int)->void:
	if snapshot.get("actor",-1)!=actor or snapshot.get("revision",-1)!=revision or snapshot.get("phase","")!="discard" or (use_ai and actor==1):return
	if index<0 or index>=snapshot.hands[actor].size():return
	selected_index=index;table_view.select_tile(index);_render_actions();_render_rail()
func _render()->void:
	var actor:int=snapshot.get("actor",0);var phase:String=snapshot.get("phase","")
	heading.text="云顶雀馆 · "+("自由洗牌" if snapshot.get("mode","")=="random" else ["顺子残局","碰刻残局","七对残局"][clampi(int(snapshot.get("variant",0)),0,2)])
	status.text="四面子一将 / 门清七对 · 任一伙伴胡牌，共同获得印章"
	_header_badge.text="搭档思考中" if use_ai and actor==1 else ("响应弃牌" if phase=="claim" else ("窥牌排序" if phase=="peek" else "点牌 · 确认"))
	table_view.configure(snapshot,use_ai,selected_index);_render_actions();_render_rail()
func _render_rail()->void:
	var actor:int=int(snapshot.get("actor",0));var ai_turn:bool=use_ai and actor==1;var phase:String=snapshot.get("phase","")
	_turn.text=("泡泡 · AI 思考中" if ai_turn else ["小柯 · 轮到你","泡泡 · 轮到你"][actor]);_turn.add_theme_color_override("font_color",Color("b96e47") if actor==0 else Color("397e87"))
	var type_index:int=-1
	if selected_index>=0 and selected_index<snapshot.hands[actor].size():type_index=int(snapshot.hands[actor][selected_index])/4
	elif phase=="claim" and snapshot.has("last_discard"):type_index=int(snapshot.last_discard.get("tile",-1))/4
	_selected_tile.show_tile(type_index)
	_selection.text=Tiles.face_name(type_index) if type_index>=0 else ("等待伙伴" if ai_turn else ("重排墙顶" if phase=="peek" else "点选一张牌"))
	_selection_help.text="上家弃牌 · 选择吃碰杠胡或过" if phase=="claim" else ("先看下面的顺序，再确认" if phase=="peek" else ("已选中 · 确认后打出" if selected_index>=0 else ("伙伴完成本回合后继续" if ai_turn else "手牌抬起后，仍需确认才会打出。")))
	var wall_count:int=snapshot.get("wall",[]).size();var discarded:int=int(snapshot.get("discard_count",0));_wall.value=wall_count;_wall_text.text="牌墙 %d 张   ·   已打 %d / 64 手"%[wall_count,discarded]
	var style:String=str(snapshot.get("styles",["closed","closed"])[actor]);_style.text={"closed":"门清 · 观潮","triplet":"刻子 · 换骨","sequence":"连序 · 接龙"}.get(style,style)
	var used:bool=snapshot.get("skill_used",[false,false])[actor]
	_goal.text={"closed":"保持门清胡牌","triplet":"胡牌含至少3组刻子或杠","sequence":"胡牌含至少3组顺子"}.get(style,"")+"，胜者额外 +3 金。\n技艺："+("本场已使用" if used else "本场剩余 1 次")
	_goal.tooltip_text={"closed":"无明副露时，技艺可窥真实墙顶3牌。","triplet":"实际碰杠后，技艺可换本次摸入牌。","sequence":"实际吃牌后，技艺可窥真实墙顶3牌。"}.get(style,"")
	for key:String in ["wilds","redraws"]:
		var count:int=int(resource_counts.get(key,0));var allowed:bool=resource_allowed.get(key,false);var button:Button=_resource_buttons[key]
		button.text=("窥牌券" if key=="wilds" else "换牌券")+"   × %d"%count;button.disabled=ai_turn or count<=0 or not allowed
		_resource_reasons[key].text="等待搭档回合结束" if ai_turn else ("暂无券 · 可在棋盘收集" if count<=0 else ("当前牌局阶段不可使用" if not allowed else ("看墙顶3张并选顺序" if key=="wilds" else "本次摸牌退墙尾，再摸一张")))
	_back.disabled=ai_turn;_back.tooltip_text="撤回不发印章，保留流派与剩余资源"
func _render_actions()->void:
	for child in actions.get_children():actions.remove_child(child);child.queue_free()
	buttons.clear()
	var actor:int=int(snapshot.get("actor",0));var revision:int=int(snapshot.get("revision",0));var ai_turn:bool=use_ai and actor==1;var phase:String=snapshot.get("phase","")
	if phase=="discard":
		var caption:String="先点选一张手牌"
		if selected_index>=0 and selected_index<snapshot.hands[actor].size():caption="打出 · "+Tiles.face_name(int(snapshot.hands[actor][selected_index])/4)
		var chosen:int=selected_index;var discard:=_button(caption,func():discard_requested.emit(chosen,actor,revision));discard.disabled=chosen<0 or ai_turn;actions.add_child(discard);buttons.append(discard);Palette.apply_button(discard,"primary")
		hint.text="点选实体手牌，再确认打出。金色底托标出本次摸牌；也可先选择合法的自摸或杠。"
	elif phase=="claim":
		var tile:int=snapshot.get("last_discard",{}).get("tile",-1);hint.text="上家打出 "+(Tiles.face_name(tile/4) if tile>=0 else "一张牌")+"。吃碰后须打牌；选择「过」则正常摸牌。"
	elif phase=="peek":hint.text="只重排真实墙顶3张。下一次通常先由伙伴摸牌；吃碰杠会改变摸牌时机。"
	else:hint.text="万、筒、索与字牌，共136张实体牌。"
	if int(snapshot.get("discard_count",0))==0 and snapshot.get("mode","")=="endgame":
		hint.text="公开残局："+str(snapshot.get("scenario",{}).get("condition","起手与墙首公开，其余洗牌。"));hint.tooltip_text=hint.text
	if ai_turn:hint.text="泡泡正在根据自己的手牌作出选择，请等待本回合完成。"
	for i in available_actions.size():
		var item:Dictionary=available_actions[i];var kind:String=item.get("kind","")
		var caption:String=str(item.get("label",kind)).replace("墙顶 ","")
		var button:=_button(caption,_emit_action.bind(i,actor,revision));button.disabled=ai_turn or not item.get("enabled",true);button.tooltip_text=str(item.get("detail",""));actions.add_child(button);buttons.append(button)
		Palette.apply_button(button,"primary" if kind in ["tsumo","ron"] else ("selected" if kind=="skill" else "ivory"))
	actions.columns=mini(3,maxi(1,buttons.size()))
	for i in buttons.size():
		buttons[i].text="%d  %s"%[i+1,buttons[i].text];buttons[i].custom_minimum_size=Vector2(350,57);buttons[i].add_theme_font_size_override("font_size",16)
func _emit_action(index:int,actor:int,revision:int)->void:action_requested.emit(index,actor,revision)
