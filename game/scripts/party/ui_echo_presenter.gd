class_name FurUIEchoPresenter
extends HBoxContainer
signal choice_requested(choice:int,actor:int,revision:int)
signal resource_requested(key:String,actor:int,revision:int)
signal seal_requested(actor:int,revision:int)
signal retreat_requested(actor:int,revision:int)
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var buttons:Array[Button]=[]
var world:FurUIEchoWorld
var timeline:FurUIEchoTimeline
var _actions:HBoxContainer
var _actor:Label
var _move_hint:Label
var _step:Label
var _step_help:Label
var _progress:Label
var _power:Label
var _resources:VBoxContainer
var _resource_hint:Label
var _seal:Button
var _seal_hint:Label
var _back:Button
var _state:Dictionary={}
var _ai:bool=false
var _counts:Dictionary={}
var _engine:ChapterEcho
func _ready()->void:
	theme=Palette.create();add_theme_constant_override("separation",24)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=890;left.add_theme_constant_override("separation",10);add_child(left)
	world=FurUIEchoWorld.new();world.custom_minimum_size=Vector2(890,485);left.add_child(world)
	_actor=_label("",21);left.add_child(_actor);_move_hint=_label("选择方向时，金色格会提示下一步落点。",15);_move_hint.custom_minimum_size.y=24;_move_hint.add_theme_color_override("font_color",Palette.MUTED);left.add_child(_move_hint)
	_actions=HBoxContainer.new();_actions.add_theme_constant_override("separation",9);left.add_child(_actions)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",10);add_child(right)
	_progress=_label("",20);right.add_child(_progress)
	_step=_label("",25);right.add_child(_step);_step_help=_label("",17);_step_help.custom_minimum_size.y=46;_step_help.add_theme_color_override("font_color",Palette.MUTED);right.add_child(_step_help)
	timeline=FurUIEchoTimeline.new();right.add_child(timeline)
	_power=_label("",18);right.add_child(_power)
	_resources=VBoxContainer.new();_resources.add_theme_constant_override("separation",12);right.add_child(_resources)
	_resource_hint=_label("",14);_resource_hint.custom_minimum_size.y=36;_resource_hint.add_theme_color_override("font_color",Palette.MUTED);right.add_child(_resource_hint)
	_seal=_button("封存双踏板记录");Palette.apply_button(_seal,"primary","clock");_seal.pressed.connect(func():seal_requested.emit(int(_state.actor),int(_state.revision)));right.add_child(_seal)
	_seal_hint=_label("",14);_seal_hint.custom_minimum_size.y=24;_seal_hint.add_theme_color_override("font_color",Palette.MUTED);right.add_child(_seal_hint)
	_back=_button("撤回棋盘 · 保留剩余资源");Palette.apply_button(_back,"quiet","compass");_back.pressed.connect(func():retreat_requested.emit(int(_state.actor),int(_state.revision)));right.add_child(_back)
func configure(snapshot:Dictionary,source:ChapterEcho,ai:bool,counts:Dictionary)->void:
	_state=snapshot.duplicate(true);_engine=source;_ai=ai;_counts=counts.duplicate(true)
	var actor:int=_state.actor;var revision:int=_state.revision;var ai_turn:bool=ai and actor==1;var lit:Array=source.lit_plates()
	world.configure(_state,source.ghost_positions(),lit);timeline.configure(_state,source)
	_actor.text=("泡泡正在规划下一步" if ai_turn else ["小柯的行动","泡泡的行动"][actor])+" · 两人都走完才推进一拍"
	_progress.text="第 %d / 3 轮     第 %d / 8 拍     能量 %d / 2"%[_state.loop+1,_state.beat+1,_state.deliveries]
	_step.text="① 留下站岗的回声" if _state.loop==0 else "② 借用过去，完成交付"
	_step_help.text="让两人分别站上 A / B，然后封存剩余的静止记录。" if _state.loop==0 else "双踏板通电时，两人各到自己的同色交付格送能量。"
	_power.text="当前供电     A "+("已亮" if lit[0] else "未亮")+"     B "+("已亮" if lit[1] else "未亮")
	_power.add_theme_color_override("font_color",Color("357e71") if lit[0] and lit[1] else Palette.INK)
	for child in _actions.get_children():_actions.remove_child(child);child.queue_free()
	buttons.clear()
	var choices:Array=source.choices()
	for i in choices.size():
		var item:Dictionary=choices[i];var button:=_button("%d %s"%[i+1,["↑ 上","→ 右","↓ 下","← 左","等待"][i]]);button.custom_minimum_size=Vector2(168,50);button.disabled=ai_turn or not item.enabled
		button.pressed.connect(func():choice_requested.emit(i,actor,revision));button.tooltip_text=item.detail if item.enabled else "此方向越界或有障碍"
		var next:Vector2i=_state.positions[actor]+ChapterEcho.DIRECTIONS[i]
		button.mouse_entered.connect(func():world.preview_move(next,item.enabled);_move_hint.text=item.detail if item.enabled else "此方向不能通过，请选择其他行动")
		button.mouse_exited.connect(func():world.preview_move(Vector2i.ZERO,false);_move_hint.text="选择方向时，金色格会提示下一步落点。")
		_actions.add_child(button);buttons.append(button)
	for child in _resources.get_children():_resources.remove_child(child);child.queue_free()
	for key:String in ["rotate_tokens","echo_bonus"]:
		var count:int=int(counts.get(key,0));var button:=_button(("旋转旧轨迹" if key=="rotate_tokens" else "延长余辉")+" ×%d"%count);button.custom_minimum_size.x=235;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.disabled=ai_turn or count<=0 or not source.can_resource(key,actor,revision);button.pressed.connect(func():resource_requested.emit(key,actor,revision));_resources.add_child(button)
	_resource_hint.text="旋转券：旧轨迹转90°。余辉券：回声离开踏板后多亮一拍。"
	_seal.disabled=ai_turn or actor!=0 or _state.positions[0]!=_state.plates[0] or _state.positions[1]!=_state.plates[1] or _state.loop>=2
	_seal_hint.text="两人到各自踏板，且回到小柯回合时可封存。" if _seal.disabled else "已就位：封存剩余拍点，开始下一轮！"
	if _state.loop>=2:_seal_hint.text="已经是最后一轮，需要在本轮完成交付。"
	_back.disabled=ai_turn
func _label(value:String,px:int)->Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",px);label.add_theme_font_override("font",FurChapterUITheme.font(px>=22));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func _button(value:String)->Button:
	var button:=Button.new();button.text=value;button.custom_minimum_size=Vector2(150,49);button.add_theme_font_size_override("font_size",17);Palette.apply_button(button,"quiet");return button
