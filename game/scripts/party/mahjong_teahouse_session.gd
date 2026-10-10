extends Control
## Direct playable entrance; same rules/presenter as chapter two. No GM required.
const Rules=preload("res://scripts/party/chapter_mahjong_table.gd")
const Presenter=preload("res://scripts/party/mahjong_teahouse_presenter.gd")
var rules:=Rules.new()
var presenter:FurMahjongTeahousePresenter
var audio:FurPartyBoardAudio
var use_ai:=true
var elapsed:=0.0
var round_number:=0
var wins:=0
var _result_shown:=false
var _lobby:Control
var _footer:HBoxContainer

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audio=FurPartyBoardAudio.new();add_child(audio)
	_lobby_screen()

func _lobby_screen()->void:
	_new_round(true,false)
	_lobby=PanelContainer.new();_lobby.position=Vector2(405,190);_lobby.size=Vector2(790,500);_lobby.theme=FurChapterUITheme.create();add_child(_lobby)
	var margin:=MarginContainer.new();for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,28)
	_lobby.add_child(margin);var column:=VBoxContainer.new();column.add_theme_constant_override("separation",20);margin.add_child(column)
	var title:=Label.new();title.text="同桌茶会 · 3D 合作麻将";title.add_theme_font_size_override("font_size",32);column.add_child(title)
	var text:=Label.new();text.text="真实136张麻将，任一伙伴胡牌共同获胜。\n\n① 选择茶灵：舍字蓄气 / 吃顺换牌 / 碰杠连换。\n② 点手牌后，可打出，或花共享茶气换桌上的公开牌。\n③ 互相喂牌完成茶约，再决定保门清还是吃碰加速。";text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size",21);column.add_child(text)
	for entry in [["1人 + 泡泡AI · 随机开席",true,false],["2名本地玩家 · 轮流打牌",false,false],["教学残局 · 起手公开",true,true]]:
		var b:=Button.new();b.text=entry[0];b.custom_minimum_size=Vector2(690,54);FurChapterUITheme.apply_button(b,"primary" if entry[1] and not entry[2] else "ivory");column.add_child(b);b.pressed.connect(_start_selected.bind(entry[1],entry[2]))

func _start_selected(ai:bool,endgame:bool)->void:
	if is_instance_valid(_lobby):_lobby.queue_free();_lobby=null
	_new_round(ai,endgame)

func _new_round(ai:bool,endgame:bool)->void:
	use_ai=ai;round_number+=1;elapsed=0;_result_shown=false
	if is_instance_valid(presenter):remove_child(presenter);presenter.queue_free()
	if is_instance_valid(_footer):_footer.queue_free();_footer=null
	rules.start(int(randi()%2147483646)+1,use_ai);rules.begin_challenge(0,1,0,endgame)
	presenter=Presenter.new();presenter.configure(rules.state(),use_ai,rules.choices(),{"wilds":0,"redraws":0},{"wilds":false,"redraws":false});add_child(presenter)
	presenter.discard_requested.connect(_discard);presenter.action_requested.connect(_action);presenter.tea_requested.connect(_tea);presenter.retreat_requested.connect(_leave)
	audio.play("embark")

func _process(delta:float)->void:
	if not is_instance_valid(presenter) or is_instance_valid(_lobby):return
	elapsed+=delta
	if presenter.table_view==null or presenter.table_view.is_animating():return
	var s:Dictionary=rules.state()
	if s.phase=="finished":
		if not _result_shown:_show_result(s.result)
		return
	if use_ai and s.actor==1 and elapsed>.9:
		var action:int=rules.ai_choice()
		if action>=0:_action(action,1,s.revision)
		elif s.phase=="discard":
			var exchange:Array=rules.ai_exchange()
			if not exchange.is_empty():_tea("exchange",Vector2i(exchange[0],exchange[1]),1,s.revision)
			else:_discard(rules.ai_discard(),1,s.revision)

func _discard(index:int,actor:int,revision:int)->void:
	if presenter.table_view.is_animating():return
	if rules.discard(index,actor,revision).ok:audio.play("step");_refresh()
func _action(choice:int,actor:int,revision:int)->void:
	if presenter.table_view.is_animating():return
	if rules.apply(choice,actor,revision).ok:audio.play("purchase");_refresh()
func _tea(kind:String,value:Variant,actor:int,revision:int)->void:
	if presenter.table_view.is_animating():return
	var reply:Dictionary=rules.choose_tea(str(value),actor,revision) if kind=="recipe" else rules.exchange_tea(value.x,value.y,actor,revision)
	if reply.ok:audio.play("coin");_refresh()
func _refresh()->void:
	elapsed=0;presenter.configure(rules.state(),use_ai,rules.choices(),{"wilds":0,"redraws":0},{"wilds":false,"redraws":false})
func _leave(_actor:int,_revision:int)->void:
	get_tree().change_scene_to_file("res://scenes/party/adventure.tscn")
func _show_result(result:Dictionary)->void:
	_result_shown=true
	if result.success:wins+=1;audio.play("star")
	presenter.heading.text=("胡牌！同桌完成" if result.success else "流局 · 重新配茶")+"  /  本次胜局 %d"%wins
	_footer=HBoxContainer.new();_footer.position=Vector2(480,760);_footer.add_theme_constant_override("separation",24);add_child(_footer)
	for entry in [["再开一桌 · 换一种茶灵",0],["回冒险大厅",1]]:
		var b:=Button.new();b.text=entry[0];b.custom_minimum_size=Vector2(310,66);FurChapterUITheme.apply_button(b,"primary");_footer.add_child(b)
		if entry[1]==0:b.pressed.connect(_new_round.bind(use_ai,false))
		else:b.pressed.connect(_leave.bind(0,0))

func _unhandled_key_input(event:InputEvent)->void:
	if is_instance_valid(_lobby) or not event is InputEventKey or not event.pressed or event.echo:return
	var index:int=int(event.physical_keycode)-KEY_1
	if index>=0 and index<presenter.buttons.size() and not presenter.buttons[index].disabled:presenter.buttons[index].pressed.emit();get_viewport().set_input_as_handled()
func _exit_tree()->void:
	if is_instance_valid(audio):audio.close()
