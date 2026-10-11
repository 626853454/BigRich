extends Control
const Rules=preload("res://scripts/party/mahjong_night_table.gd")
const Run=preload("res://scripts/party/mahjong_night_run.gd")
const Presenter=preload("res://scripts/party/mahjong_night_presenter.gd")
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const Lessons=preload("res://scripts/party/mahjong_night_lessons.gd")
const Receipts=preload("res://scripts/party/mahjong_night_receipts.gd")
var rules=Rules.new()
var journey=Run.new()
var presenter:FurMahjongNightPresenter
var audio:FurPartyBoardAudio
var score_audio:FurMahjongNightAudio
var use_ai:bool=true
var elapsed:float=0
var mode:String="lobby"
var _receipt_return_mode:String="table"
var starter:String="windbell"
var modal:Panel
var _result_seen:bool=false
var _shop_actor:int=0
var _replacement:int=0
var _selected_heirloom:int=-1
var _notice:String=""
var _ai_waiting_hu:bool=false
var _ai_declined_this_turn:bool=false
var _pending_ai_choice:int=-1
var _ai_request_announced:bool=false
var _shop_notice:Label
var _replay_seed:int=-1
var _lesson_id:String=""
var _lesson_hint_revision:int=-1
var _lesson_reset:Button
var _frame_state:Dictionary={}
var _lesson_guidance:bool=true
var _lesson_guide_toggle:Button
var _lesson_bests:Dictionary={}
var welcome:FurMahjongNightWelcomeFlow

func _ready()->void:
	welcome=FurMahjongNightWelcomeFlow.new(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audio=FurPartyBoardAudio.new();add_child(audio)
	score_audio=FurMahjongNightAudio.new();add_child(score_audio)
	journey.start(int(randi()%2147483646)+1,starter,use_ai)
	rules.begin_night(journey.table_config())
	presenter=Presenter.new();presenter.configure(rules.state(),rules.choices(),use_ai);add_child(presenter);presenter.command.connect(_command)
	presenter.score_beat.connect(score_audio.beat)
	presenter.score_skipped.connect(score_audio.skip)
	presenter.table_view.table_sound.connect(score_audio.cue)
	presenter.table_view.meld_selected.connect(_select_reshape_meld)
	_lesson_reset=_button("重新试这一手",func():_start_lesson(_lesson_id),Vector2(177,43));_lesson_reset.position=Vector2(163,120);add_child(_lesson_reset);_lesson_reset.hide()
	_lesson_guide_toggle=_button("隐藏指引 · 自由试招",_toggle_lesson_guidance,Vector2(220,43));_lesson_guide_toggle.position=Vector2(350,120);add_child(_lesson_guide_toggle);_lesson_guide_toggle.hide()
	_lobby()

func _new_modal(rect:Rect2)->VBoxContainer:
	if is_instance_valid(modal):remove_child(modal);modal.queue_free()
	modal=Panel.new();modal.position=rect.position;modal.size=rect.size;modal.theme=Palette.create();add_child(modal)
	var dim:=ColorRect.new();dim.position=-rect.position;dim.size=Vector2(1600,900);dim.color=Color(.01,.03,.04,.38);dim.show_behind_parent=true;modal.add_child(dim)
	modal.add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"))
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,26)
	modal.add_child(margin);var column:=VBoxContainer.new();column.add_theme_constant_override("separation",13);margin.add_child(column);return column
func _text(text:String,fs:int,parent:Node)->Label:
	var l:=Label.new();l.text=text;l.add_theme_font_override("font",Palette.font(fs>=25));l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",Color("f8efd9"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(l);return l
func _button(text:String,call:Callable,size:Vector2=Vector2(250,58),variant:String="ivory")->Button:return presenter.button(text,call,size,variant)

func _relic_card(id:String,callback:Callable,dimensions:Vector2,selected:bool=false,show_price:bool=true)->Button:
	var b:=_button("",callback,dimensions,"selected" if selected else "ivory");b.tooltip_text=Catalog.ITEMS[id].text
	var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.texture=load("res://assets/mahjong_night/"+id+"_icon.png");icon.position=Vector2(13,8);icon.size=Vector2(84,84);icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(icon)
	var title:=Label.new();title.text=Catalog.name_of(id);title.position=Vector2(97,15);title.size=Vector2(dimensions.x-111,30);title.add_theme_font_size_override("font_size",20);title.add_theme_color_override("font_color",Color("fff0cf") if selected else Color("254448"));title.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(title)
	var price:=Label.new();price.text=("%d 金币"%Catalog.ITEMS[id].price) if show_price else Catalog.ITEMS[id].route+" · 起步";price.position=Vector2(99,50);price.size=Vector2(dimensions.x-113,25);price.add_theme_font_size_override("font_size",17);price.add_theme_color_override("font_color",Color("f2d49c") if selected else Color("775c3a"));price.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(price)
	var detail:=Label.new();detail.text=Catalog.SHORTS[id];detail.position=Vector2(18,101);detail.size=Vector2(dimensions.x-36,dimensions.y-116);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",17);detail.add_theme_color_override("font_color",Color("f8eed7") if selected else Color("254448"));detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(detail)
	detail.name="RelicDetail"
	return b

func _lobby()->void:
	presenter.set_menu_mode(true)
	welcome.active=false;mode="lobby";presenter._offer_panel.hide();_lesson_reset.hide();_lesson_guide_toggle.hide()
	var column:=_new_modal(Rect2(345,148,910,595))
	_text("百番夜宴",43,column)
	_text("三张牌，亮一组。小小的帮手，会把它变成大大的连响。",24,column)
	_text("第一次来，先亲手打一组；想慢慢玩，就从三段小关养起。",20,column)
	column.add_child(_button("第一次玩 · 跟着亮一组",func():welcome.start("tutorial"),Vector2(858,91),"primary"))
	column.add_child(_button("午后小桌 · 三小关慢慢养成",func():welcome.start("small"),Vector2(858,85)))
	_text("教学与小关是单人预设练习，可以重试，没有倒计时。",17,column)
	column.add_child(_button("完整夜宴 · 随机三桌 / 本地双人 / 进阶练招",_advanced_lobby,Vector2(858,62)))
	_text("空格跳过计分 · F1 查看帮助 · 音画设置随时可用",16,column)

func _advanced_lobby()->void:
	presenter.set_menu_mode(true)
	welcome.active=false
	mode="lobby";presenter._offer_panel.hide();_lesson_reset.hide();_lesson_guide_toggle.hide()
	var column:=_new_modal(Rect2(248,73,1104,750) if _replay_seed>=0 else Rect2(248,104,1104,664))
	_text("百番夜宴",43,column)
	_text("复盘开局 · 换一条构筑，试试另一种打法" if _replay_seed>=0 else "救回一张缺牌，点亮自己的灯，再把小顺子养成大连锁。",23,column)
	_text("三桌合作旅程 · 选目标亮灯 → 得灵感改牌 → 连锁养成\n每桌每人6次打牌。公共河牌分3次翻开；夜市选择绝活与下一桌规则。",19,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);column.add_child(row)
	for id:String in Catalog.STARTERS:
		var chosen:String=id;var item:Dictionary=Catalog.ITEMS[id]
		var b:=_relic_card(id,func():starter=chosen;_advanced_lobby(),Vector2(337,168),starter==id,false);row.add_child(b)
	_text("泡泡从「回甘双杯」起步：你换出到河牌的牌，能成为它的接力得分。",17,column)
	var buttons:=HBoxContainer.new();buttons.add_theme_constant_override("separation",14);column.add_child(buttons)
	buttons.add_child(_button("1人 + 泡泡AI · "+("复盘开宴" if _replay_seed>=0 else "随机开宴"),func():_start_run(true),Vector2(510,64),"primary"))
	buttons.add_child(_button("2名本地玩家 · 轮流同桌",func():_start_run(false),Vector2(510,64)))
	column.add_child(_button("先练一手 · 借形连响的三种解法",_show_lesson_select,Vector2(1044,52)))
	if _replay_seed>=0:
		_text("保留同一副起手与初始牌墙；换一个挂件起点，后续仍由你的选择改变。",17,column)
		column.add_child(_button("改开全新随机局",func():_replay_seed=-1;_lobby(),Vector2(1044,46)))
	_text("F1 查看玩法 · 空格跳过计分 · 顶部可切换演出节奏",16,column)

func _start_run(ai:bool)->void:
	welcome.active=false
	_lesson_id="";_lesson_reset.hide();use_ai=ai;journey.start(_replay_seed if _replay_seed>=0 else int(randi()%2147483646)+1,starter,ai);_begin_table()
func _begin_table()->void:
	presenter.set_menu_mode(false)
	presenter.opening_drawer=""
	if is_instance_valid(modal):remove_child(modal);modal.queue_free();modal=null
	if welcome.active:rules=welcome.make_rules()
	else:rules=Rules.new();rules.begin_night(journey.table_config())
	mode="table";_result_seen=false;elapsed=0;_ai_waiting_hu=false;_ai_declined_this_turn=false
	if not _lesson_id.is_empty():Lessons.setup(rules,_lesson_id)
	if not _lesson_id.is_empty():rules._s.night.lesson.guided=_lesson_guidance
	_lesson_hint_revision=-1;_lesson_reset.visible=not _lesson_id.is_empty()
	_lesson_guide_toggle.visible=not _lesson_id.is_empty();_lesson_guide_toggle.text="隐藏指引 · 自由试招" if _lesson_guidance else "显示分步指引"
	if is_instance_valid(presenter.table_view.night_feedback):presenter.table_view.night_feedback.clear()
	presenter.replay_mode=_replay_seed>=0
	presenter._last_event=0;presenter._shown_score=0;presenter._shown_contributions=[0,0];presenter._contributions.text="小柯 0  ·  泡泡 0";presenter.table_view._wall_slots.clear();presenter.table_view.transforms.clear();presenter.table_view._last_revision=-1
	presenter._ledger.text="新的牌桌 · 先做出一组。\n首次亮牌会展示筹码和触发来源。"
	_refresh();score_audio.cue("reveal")
func _refresh()->void:
	# Commands refresh this read-only snapshot once; idle frames need no deep copy
	# of all physical tiles and the growing score ledger. Rules remain authoritative.
	_frame_state=rules.state();elapsed=0;presenter.configure(_frame_state,rules.presented_choices(),use_ai)
	var n:Dictionary=_frame_state.night;score_audio.set_mood(n.stage,n.ensemble.chain,n.encore.active)

func _process(delta:float)->void:
	if mode!="table" or presenter==null:return
	elapsed+=delta
	_lesson_reset.disabled=presenter.is_busy();_lesson_guide_toggle.disabled=presenter.is_busy()
	if presenter.is_busy():return
	var state:Dictionary=_frame_state
	if welcome.active:welcome.tick(state);return
	_lesson_reset.disabled=false
	_lesson_guide_toggle.disabled=false
	if not _lesson_id.is_empty():
		if state.night.reshape.chains.any(func(c:Dictionary)->bool:return c.actor==0):_show_lesson_result(true);return
		if state.night.continuations.any(func(c:Dictionary)->bool:return c.actor==0):_show_lesson_result(true);return
		if state.phase=="finished":_show_lesson_result(false);return
		if state.actor==0 and not presenter._has_hover_preview:
			_lesson_hint_revision=state.revision
			if not _lesson_guidance:presenter._hint.text="自由试招 · 同一副起手、有限灵感。未弃牌前连响可记本次最好成绩；悬停仍可自行查看预计路线。"
			elif state.melds[0].is_empty():presenter._hint.text=Lessons.LESSONS[_lesson_id].hint
			elif not state.night.reshape.followup[0].is_empty():presenter._hint.text="借牌已回到手中！亮出包含它的新组，完成一次借形连响。"
			elif rules.can_reshape():presenter._hint.text="点击左侧自己已亮出的三张牌，看看哪种改法能接着亮第二组。"
			elif state.night.direction.trick_used[0]:presenter._hint.text="本回合灵感已用。可以继续正常出牌等下一手，或点左上重新练招。"
	if state.actor==0:_ai_declined_this_turn=false;_ai_request_announced=false
	if state.phase=="finished":
		if not _result_seen:_show_table_result()
		return
	if use_ai and state.actor==1 and elapsed>.72:
		if _ai_waiting_hu:return
		if state.phase=="night_cash_offer":rules.answer_cash_out(true,1,state.revision);_refresh();return
		if state.phase=="night_encore_offer":
			var advice:Dictionary=rules.encore_advice();rules.answer_encore(advice.accept,1,state.revision,advice.text);_refresh()
			presenter._hint.text="泡泡："+advice.text;return
		if state.phase=="night_offer":rules.ai_offer();_refresh();return
		var action:int=rules.ai_choice()
		if action>=0 and rules.choices()[action].kind in ["ron","tsumo"]:
			if not _ai_declined_this_turn:_ask_ai_hu(action);return
			action=-1
			for i in rules.choices().size():
				if rules.choices()[i].kind in ["pass","self_pon","self_chi","closed_kong"]:action=i;break
		var reshape_key:String=rules.ai_reshape()
		if not reshape_key.is_empty():_command("reshape",reshape_key,1,state.revision);return
		var continuation:String=rules.ai_continuation()
		if not continuation.is_empty():_command("continue_group",continuation,1,state.revision);return
		var chain_choice:int=rules.ai_chain_choice()
		if chain_choice>=0:_command("action",chain_choice,1,state.revision);return
		var trick:Array=rules.ai_trick()
		if not trick.is_empty():_command("trick",trick,1,state.revision);return
		var assist:Array=rules.ai_assist_exchange()
		if not assist.is_empty():_command("exchange",Vector2i(assist[0],assist[1]),1,state.revision);return
		if state.phase=="discard" and not _ai_request_announced:
			_ai_request_announced=true
			var wanted:int=rules.ai_request_type()
			if wanted>=0 and wanted!=state.night.requests[1]:_command("request_type",wanted,1,state.revision);return
		if action>=0:_command("action",action,1,state.revision)
		elif state.phase=="discard":
			var exchange:Array=rules.ai_exchange()
			if not exchange.is_empty():_command("exchange",Vector2i(exchange[0],exchange[1]),1,state.revision)
			else:
				var slot:int=rules.ai_refresh_slot()
				if slot>=0:_command("refresh_river",slot,1,state.revision)
				else:_command("discard",rules.ai_discard(),1,state.revision)

func _command(kind:String,value:Variant,actor:int,revision:int)->void:
	if welcome.active:
		if presenter.is_busy():return
		if kind=="leave":welcome.active=false;_lobby();return
		if kind=="settings":_show_av_settings();return
		if kind!="action" or mode!="table":return
	if kind=="leave" and not _lesson_id.is_empty() and not presenter.is_busy():_lesson_id="";_lobby();return
	if kind=="review_result" and mode=="review":_show_table_result(false);return
	if kind=="score_receipt" and mode in ["table","review"]:FurMahjongNightReceipt.show_detail(self);return
	if kind=="leave" and mode in ["table","review"] and not presenter.is_busy():get_tree().change_scene_to_file("res://scenes/party/adventure.tscn");return
	if mode!="table" or presenter.is_busy():return
	if kind=="settings":_show_av_settings();return
	if kind=="table_tools":_show_table_tools(actor,revision);return
	if kind=="request_picker":_show_request_picker(actor,revision);return
	if kind=="trick_picker":_show_trick_picker(int(value),actor,revision);return
	if kind=="reshape_picker":_show_reshape_picker(actor,revision);return
	if kind=="river_picker":_show_river_picker(actor,revision);return
	if kind=="first_move":FurMahjongNightFirstMove.show_help(self,actor,revision);return
	if kind=="action_picker":_show_action_picker(actor,revision);return
	var reply:Dictionary={"ok":false,"reason":"unknown_command"}
	match kind:
		"spotlight":reply=rules.choose_spotlight(value,actor,revision)
		"trick":reply=rules.perform_trick(value[0],value[1],value[2],actor,revision)
		"reshape":reply=rules.reshape(value,actor,revision)
		"continue_group":reply=rules.continue_group(value,actor,revision)
		"action":reply=rules.apply(value,actor,revision)
		"discard":reply=rules.discard(value,actor,revision)
		"exchange":reply=rules.exchange_tea(value.x,value.y,actor,revision)
		"refresh_river":reply=rules.refresh_river(value,actor,revision)
		"request_tile":reply=rules.request_tile(value,actor,revision)
		"request_type":reply=rules.request_type(value,actor,revision)
		"cash_request":reply=rules.request_cash_out(actor,revision)
		"cash_answer":reply=rules.answer_cash_out(value,actor,revision)
		"encore_request":reply=rules.request_encore(actor,revision)
		"encore_answer":reply=rules.answer_encore(value,actor,revision)
		"tea":reply=rules.choose_tea(value,actor,revision)
		"offer":reply=rules.offer(value[0],value[1],actor,revision)
		"mulligan":reply=rules.mulligan(value,actor,revision)
		"ready":reply=rules.ready_offer(actor,revision)
	if reply.ok:
		if kind=="trick":score_audio.cue({"boost":"charge","recall":"recall","relay":"relay","stoke":"furnace_charge"}[value[0]])
		elif kind in ["offer","spotlight","tea","ready","request_type"]:score_audio.cue("select")
		_refresh()
		if kind=="trick":presenter._hint.text=rules.state().night.direction.last_notice
	else:
		presenter._hint.text={"cannot_bet_completed_contract":"契约已达成，不能现在补押；保持档位继续。","contract_locked":"契约已锁定，这次可调整押注档位。","not_enough_coins":"金币不足，请保持当前档位。","tea_exchange_unavailable":"茶气不足或本回合交换额度已用完。","mulligan_unavailable":"换起手本桌仅一次，最多3张。","river_refresh_unavailable":"本阶段已经冲泡过，或茶气不足2点。"}.get(reply.get("reason",""),"此操作当前不可用，请重新选择。")

func _show_request_picker(actor:int,revision:int)->void:
	if rules.state().phase!="discard" or rules.state().actor!=actor:return
	mode="request_picker"
	var column:=_new_modal(Rect2(264,130,1072,610))
	_text("下一组，还差哪一张？",32,column)
	_text("这是公开请求，不会凭空造牌。泡泡只从自己的手牌递牌，并为你保留取牌茶气。" if use_ai else "这是公开请求，不会凭空造牌。伙伴轮到自己时，需手动将需要的牌换入公共河。",19,column)
	var recommended:int=rules.ai_request_type();var reason:String=""
	if recommended>=0:
		var owned:int=0
		for id:int in rules.state().hands[actor]:
			if int(id/4)==recommended:owned+=1
		reason="可追 "+ChapterMahjongTable.tile_name(recommended*4)+("：已有三张，可找杠。" if owned==3 else ("：已有对子，可补成刻。" if owned==2 else "：已有相邻牌，可补顺子。"))
	_text(reason+"接力通常花4茶气，只建议当前手牌缺张，不保证伙伴持有。",18,column)
	for family in 4:
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",7);column.add_child(row)
		for ordinal in (9 if family<3 else 7):
			var type:int=family*9+ordinal
			var b:=_button(ChapterMahjongTable.tile_name(type*4)+("\n可追" if type==recommended else ""),func():_finish_request_picker(type,actor,revision),Vector2(104,73),"selected" if rules.state().night.requests[actor]==type else ("primary" if type==recommended else "ivory"))
			b.set_meta("request_type",type);row.add_child(b)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	footer.add_child(_button("取消公开请求",func():_finish_request_picker(-1,actor,revision),Vector2(496,58)))
	footer.add_child(_button("保留原请求 · 返回牌桌",_close_request_picker,Vector2(496,58),"primary"))

func _close_request_picker()->void:
	if is_instance_valid(modal):remove_child(modal);modal.queue_free();modal=null
	mode="table";elapsed=0

func _finish_request_picker(type:int,actor:int,revision:int)->void:
	_close_request_picker();_command("request_type",type,actor,revision)

func _ask_ai_hu(choice:int)->void:
	_ai_waiting_hu=true;_pending_ai_choice=choice;mode="ai_hu"
	var clone=Rules.new();clone._s=rules.state()
	clone.apply(choice,1,clone.state().revision)
	var result:Dictionary=clone.result()
	var column:=_new_modal(Rect2(460,151,680,287))
	_text("泡泡可以胡牌了",29,column)
	_text("现在收桌预计 %s 分 / 目标 %s。\n%s"%[presenter._number(result.total),presenter._number(result.target),"已足够过桌；继续会冒拆散胡牌的风险。" if result.success else "还不够目标；可选择再等一次机会，但胡牌可能被拆散。"],19,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);column.add_child(row)
	row.add_child(_button("同意收桌 · 看连锁",func():_answer_ai_hu(true),Vector2(302,64),"primary"))
	row.add_child(_button("再等一轮 · 继续做牌",func():_answer_ai_hu(false),Vector2(302,64)))

func _answer_ai_hu(accept:bool)->void:
	if is_instance_valid(modal):remove_child(modal);modal.queue_free();modal=null
	_ai_waiting_hu=false
	mode="table"
	if accept:_command("action",_pending_ai_choice,1,rules.state().revision)
	else:_ai_declined_this_turn=true;elapsed=0;presenter._hint.text="泡泡暂缓胡牌；本次个人行动继续，胡牌机会可能消失。"

func _show_table_result(settle_now:bool=true)->void:
	_result_seen=true;mode="result"
	if settle_now and not rules.result().success:score_audio.cue("loss")
	var result:Dictionary=rules.result()
	if settle_now and result.get("encore_bonus",0)>0:score_audio.cue("encore_clear")
	if settle_now:journey.settle(result)
	var column:=_new_modal(Rect2(300,70,1000,758));column.add_theme_constant_override("separation",10)
	_text(("加演成功 · 每席额外4币" if result.get("encore_bonus",0)>0 else ("加演未成 · 耐力减一" if result.get("encore",{}).get("active",false) else ("胡牌 · 夜宴开花" if result.hu else ("同桌过关" if result.success else "差一点 · 调整构筑")))),34,column)
	_text("%s  /  目标 %s"%[presenter._number(result.total),presenter._number(result.target)],42,column)
	_text("小柯 %s分   ·   泡泡 %s分\n本桌奖励 +%d / +%d金币  ·  钱包 %d / %d  ·  耐力 %d / 3"%[presenter._number(result.scores[0]),presenter._number(result.scores[1]),journey.data.coins[0]-result.wallets[0],journey.data.coins[1]-result.wallets[1],journey.data.coins[0],journey.data.coins[1],journey.data.stamina],21,column)
	var memory:Dictionary=_build_memory(result)
	_text("%s · 最高单组 %s 分 · 挂件效果触发 %d 次"%["满堂喝彩" if result.total>=result.target*3 else ("连锁爆发" if result.total>=result.target*2 else ("过桌！" if result.success else "下一手再来")),presenter._number(memory.best_group),memory.triggers],21,column)
	_result_receipt(memory,column,result)
	_text(_agency_receipt(result),17,column)
	var highlights:Array[String]=[]
	for actor in 2:
		var c:Dictionary=result.contracts[actor]
		var outcome:String=("完成，退%d币，额外%d分"%[c.stake,c.extra] if c.met else "未完成，本金%d币已消耗"%c.stake)
		if c.stake==0:outcome="完成 · 本桌未押金币" if c.met else "未完成 · 本桌未押金币"
		highlights.append(["小柯","泡泡"][actor]+" · "+Catalog.CONTRACTS[c.id].name+outcome)
	_text("\n".join(highlights),17,column)
	column.add_child(_button("回看牌桌 · 查看完整计分来源",func():mode="review";remove_child(modal);modal.queue_free();modal=null,Vector2(864,46)))
	if journey.data.phase=="complete":
		_text("三桌全破 · 最终护印已突破！下次换绝活、选席和挂件顺序再来。" if journey.data.victory else "耐力耗尽；下一轮可用不押、换起手和传家行囊稳定组合。",18,column)
		var again:=HBoxContainer.new();again.add_theme_constant_override("separation",12);column.add_child(again)
		again.add_child(_button("新随机旅程 · 重新开宴",func():_replay_seed=-1;_lobby(),Vector2(466,60),"primary"))
		again.add_child(_button("同一开局 · 换构筑再试",func():_replay_seed=int(journey.data.seed);_lobby(),Vector2(466,60)))
	else:column.add_child(_button("带上成长 · 前往夜市" if result.success else "夜市补强 · 重试本桌",_open_shop,Vector2(864,65),"primary"))

func _agency_receipt(result:Dictionary)->String:
	var d:Dictionary=result.get("direction",{});var lines:Array[String]=[]
	if d.is_empty():return ""
	for actor in 2:
		var goals:int=0;var tricks:Dictionary={};var parts:Array[String]=[]
		for event:Dictionary in d.history:
			if event.actor==actor:goals+=1
		for event:Dictionary in d.trick_history:
			if event.actor==actor:tricks[event.id]=int(tricks.get(event.id,0))+1
		for id:String in ["recall","boost","relay","stoke","reshape","continue"]:
			if tricks.has(id):parts.append({"recall":"回手","boost":"催演","relay":"递彩","stoke":"添火","reshape":"借形","continue":"续奏"}[id]+str(tricks[id])+"次")
		var technique:String=result.build.techniques[actor]
		lines.append("%s：亮灯%d街 · %s%s"%[["小柯","泡泡"][actor],goals,"、".join(parts) if not parts.is_empty() else "未使用灵感技艺",(" · "+Catalog.TECHNIQUES[technique].name) if not technique.is_empty() else ""])
	return "\n".join(lines)

func _build_memory(result:Dictionary)->Dictionary:
	var memory:Dictionary={"best_group":0,"triggers":0,"trigger_counts":{}}
	var names:Dictionary={}
	for id:String in Catalog.ITEMS:names[Catalog.name_of(id)]=id
	for event:Dictionary in result.ledger:
		if event.kind in ["chi","pon","kong","closed_kong","added_kong"]:memory.best_group=maxi(memory.best_group,event.total)
		for row:Dictionary in event.ledger:
			if row.has("detail"):memory.best_group=maxi(memory.best_group,int(row.value))
			if row.source in names and row.op!="locked":
				memory.triggers+=1
				var id:String=names[row.source];memory.trigger_counts[id]=int(memory.trigger_counts.get(id,0))+1
			for inner:Dictionary in row.get("detail",[]):
				if inner.source in names and inner.op!="locked":
					memory.triggers+=1
					var id:String=names[inner.source];memory.trigger_counts[id]=int(memory.trigger_counts.get(id,0))+1
	return memory

func _result_receipt(memory:Dictionary,parent:Node,result:Dictionary)->void:
	# Keep the player's own best exposed group visible even when the AI scored more.
	# These are actual new-group receipts, never a hypothetical future score or a hu re-count.
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);parent.add_child(row)
	for actor in 2:
		var best:Dictionary={}
		for event:Dictionary in result.ledger:
			if event.actor==actor and event.kind in ["chi","pon","kong","closed_kong","added_kong"] and int(event.total)>int(best.get("total",-1)):best=event
		var card:=PanelContainer.new();card.custom_minimum_size=Vector2(462,122);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",FurUICeramicFrame.style("ivory"));row.add_child(card)
		var margin:=MarginContainer.new()
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,14)
		card.add_child(margin);var content:=VBoxContainer.new();content.add_theme_constant_override("separation",5);margin.add_child(content)
		var pair:Dictionary=Receipts.best_pair(result.ledger,actor)
		var heading:=_text((["小柯","泡泡"][actor]+" · 本桌最好两响") if not pair.is_empty() else ["小柯 · 你的关键一手","泡泡 · 伙伴的关键一手"][actor],18,content);heading.add_theme_color_override("font_color",Color("91642f"))
		if not pair.is_empty():
			var route:=_text(Receipts.pair_line(pair),17,content);route.add_theme_color_override("font_color",Color("31585c"));route.tooltip_text="按实际出手顺序；第一组显示当时得分的原牌，借形不会改写已付账单。"
			var paid:=_text(Receipts.paid_line(pair),22,content);paid.add_theme_color_override("font_color",Color("176874"));paid.tooltip_text="两笔已经入账的合计，不另加一次分。";continue
		if best.is_empty():
			var empty:=_text("尚未亮出单组 · 夜市先补稳定成组的能力",18,content);empty.add_theme_color_override("font_color",Color("31585c"));continue
		var names:Array[String]=[]
		for tile:int in best.tiles:names.append(ChapterMahjongTable.tile_name(tile))
		var tiles_label:=_text(" / ".join(names),18,content);tiles_label.add_theme_color_override("font_color",Color("31585c"))
		var exact:bool=is_equal_approx(float(best.chips),snappedf(float(best.chips),.01)) and is_equal_approx(float(best.factor),snappedf(float(best.factor),.01)) and is_equal_approx(float(best.chips)*float(best.factor)*int(best.repeats),float(best.total))
		var formula:=_text("%s 筹码 × %s × %d次 %s %s分"%[str(snappedf(float(best.chips),.01)),str(snappedf(float(best.factor),.01)),best.repeats,"=" if exact else "≈",presenter._number(best.total)],22,content);formula.add_theme_color_override("font_color",Color("176874"))
	var ids:Array=memory.trigger_counts.keys();ids.sort_custom(func(a,b):return memory.trigger_counts[a]>memory.trigger_counts[b])
	var links:Array[String]=[]
	for id:String in ids.slice(0,3):links.append(Catalog.name_of(id)+" %d拍"%memory.trigger_counts[id])
	_text("挂件连锁 · "+"  /  ".join(links) if not links.is_empty() else "本桌挂件还未触发；夜市先选能让现有牌组稳定成型的挂件。",16,parent)

func _open_shop()->void:
	mode="shop";_shop_actor=0;_selected_heirloom=-1;_notice="买挂件，或用4币定向升级基础筹码；留下关键实体牌。";_shop()
func _shop()->void:
	mode="shop"
	var actor:int=_shop_actor;var data:Dictionary=journey.data
	if data.build.techniques[actor].is_empty():_show_technique_draft(actor);return
	if actor==0 and journey.next_table() in [2,3] and not data.venue_confirmed.get(str(journey.next_table()),false):_show_venue_draft();return
	var column:=_new_modal(Rect2(170,68,1260,766));column.add_theme_constant_override("separation",10)
	_text("夜市 · "+["小柯","泡泡"][actor]+" 的构筑时间",31,column)
	var next:int=journey.next_table()
	_text("钱包 %d币 · %s第%d桌 / 目标%d分 · %s"%[data.coins[actor],"进入" if data.advance_after_shop else "重试",next,Catalog.TARGETS[next-1],Catalog.VENUES[data.venues[str(next)]].name if next in [2,3] else "带上关键组合，减少起手波动"],18,column)
	var slots:=HBoxContainer.new();slots.add_theme_constant_override("separation",10);column.add_child(slots)
	for index in 2:
		var i:int=index;var id:String=data.build.items[actor][i] if i<data.build.items[actor].size() else ""
		var b:=_button("替换槽 %d · %s"%[i+1,Catalog.name_of(id) if id!="" else "空"],func():_replacement=i;_shop(),Vector2(285,52),"selected" if _replacement==i else "ivory");b.tooltip_text="专属槽满后，购买会替换选中槽；旧挂件不退金币。";slots.add_child(b)
	var shared:=_text("共享槽 · "+("空" if data.build.shared.is_empty() else Catalog.name_of(data.build.shared[0])),17,slots);shared.custom_minimum_size=Vector2(330,52);shared.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	slots.add_child(_button("交换两挂件顺序",func():journey.reorder(actor);_shop(),Vector2(276,52)))
	var products:=HBoxContainer.new();products.add_theme_constant_override("separation",10);column.add_child(products)
	for id:String in data.shops:
		var chosen:String=id;var item:Dictionary=Catalog.ITEMS[id]
		var b:=_relic_card(id,func():FurMahjongNightShopInsight.show_item(self,chosen,actor,0 if item.shared else _replacement),Vector2(230,182))
		var insight:Dictionary=FurMahjongNightShopInsight.describe(data,id,actor,0 if item.shared else _replacement)
		var detail:Label=b.get_node("RelicDetail");detail.text=insight.badge+"\n"+Catalog.SHORTS[id];detail.add_theme_font_size_override("font_size",14)
		var comparison:Dictionary=journey.preview_purchase(id,actor,0 if item.shared else _replacement)
		var comparison_text:String=Catalog.name_of(id)+" · "+comparison.text
		b.tooltip_text+="\n\n"+comparison_text
		b.mouse_entered.connect(func():
			if is_instance_valid(_shop_notice):_shop_notice.text=comparison_text)
		b.mouse_exited.connect(func():
			if is_instance_valid(_shop_notice):_shop_notice.text=_notice)
		b.set_meta("relic_id",id)
		b.disabled=data.coins[actor]<item.price or id in (data.build.shared if item.shared else data.build.items[actor]);products.add_child(b)
	var upgrades:=HBoxContainer.new();upgrades.add_theme_constant_override("separation",10);column.add_child(upgrades)
	for kind:String in ["chi","pon","kong"]:
		var k:String=kind
		var upgrade:=_button("%s %d→%d级 · 4币\n基础筹码 +25"%[{"chi":"顺","pon":"刻","kong":"杠"}[kind],data.build.levels[actor][kind],data.build.levels[actor][kind]+1],func():_upgrade_type(k,actor),Vector2(386,62));upgrade.disabled=data.coins[actor]<4;upgrades.add_child(upgrade)
	var pack_row:=HBoxContainer.new();pack_row.add_theme_constant_override("separation",10);column.add_child(pack_row)
	var planned:int=data.planned_requests[actor]
	var pack_hint:String={1:"先留1张关键牌；扩容后可带组合",2:"可带两张，请伙伴留第三张",3:"可保留一整组，或带不同缺张"}.get(int(data.build.carry_slots[actor]),"选择本桌实际拥有的牌")
	var pack_text:=_text("行囊 %d / %d · 下桌保证入手\n"%[data.build.keepsakes[actor].size(),data.build.carry_slots[actor]]+("约好缺 "+ChapterMahjongTable.tile_name(planned*4) if planned>=0 else pack_hint),16,pack_row);pack_text.custom_minimum_size.x=425
	var expand:=_button("3币 · 增1格（最多3）",func():_notice="行囊扩容，可带完整组合" if journey.pack_slot(actor) else "行囊已满或金币不足";_shop(),Vector2(245,44));expand.disabled=data.build.carry_slots[actor]>=3 or data.coins[actor]<3;pack_row.add_child(expand)
	pack_row.add_child(_button("装入推荐组合",func():journey.use_recommended_keepsakes(actor);_notice="按现有牌、刻印和路线选出组合，可手动调整";_shop(),Vector2(245,44)))
	pack_row.add_child(_button("约好下一手",func():_show_carry_plan(actor),Vector2(245,44),"primary" if planned>=0 else "ivory"))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1206,76);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	var tiles:=HBoxContainer.new();tiles.add_theme_constant_override("separation",6);scroll.add_child(tiles)
	var owned:Array=data.history.back().owned_tiles[actor]
	for id:int in owned:
		var tile:int=id;var stamp:String=data.build.stamps.get(str(id),"")
		var marks:String=("赤封" if stamp=="red" else ("金封" if stamp=="gold" else ""))+("·带" if id in data.build.keepsakes[actor] else "")
		var text:String=ChapterMahjongTable.tile_name(id)+("\n"+marks if marks!="" else "")
		var tile_button:=_button(text,func():
			_selected_heirloom=tile
			if tile in data.build.keepsakes[actor]:_notice="已选中携带牌；可刻印，或点击取出所选"
			else:_notice="已装入传家牌；可刻印" if journey.heirloom(tile,actor) else "行囊已满：先取出一张，或花3币扩容"
			_shop(),Vector2(96,62),"selected" if id in data.build.keepsakes[actor] else "ivory")
		tile_button.autowrap_mode=TextServer.AUTOWRAP_OFF;tile_button.add_theme_font_size_override("font_size",16);tile_button.set_meta("physical_tile",id);tiles.add_child(tile_button)
	var stamps:=HBoxContainer.new();stamps.add_theme_constant_override("separation",10);column.add_child(stamps)
	for kind:String in ["red","gold"]:
		var k:String=kind;var b:=_button("3币 · "+("赤封：面子再计一次" if kind=="red" else "金封：首次面子 +1币"),func():_stamp_tile(k,actor),Vector2(386,52));b.disabled=_selected_heirloom<0 or data.coins[actor]<3 or data.build.stamps.get(str(_selected_heirloom),"")==kind;stamps.add_child(b)
	var remove:=_button("取出所选传家牌 · 免费",func():journey.heirloom(_selected_heirloom,actor);_notice="已取出，腾出一个行囊格";_shop(),Vector2(386,52));remove.disabled=_selected_heirloom not in data.build.keepsakes[actor];stamps.add_child(remove)
	_shop_notice=_text(_notice,17,column)
	column.add_child(_button("购买完成 · 准备下一桌",_finish_shopping,Vector2(1206,58),"primary"))

func _buy_relic(id:String,actor:int,slot:int)->void:
	var before:Dictionary=journey.preview_purchase(id,actor,slot)
	var reply:Dictionary=journey.buy(id,actor,slot);_notice=reply.reason
	if reply.ok:
		score_audio.cue("purchase")
		if before.has("before"):_notice+=" · 上桌同条件样例 %d → %d分；不是下一桌保证。"%[before.before,before.after]
	_shop()

func _upgrade_type(kind:String,actor:int)->void:
	if journey.upgrade(kind,actor):
		_notice="%s升到%d级！之后每组基础筹码 +25，参与挂件倍率和重算。"%[{"chi":"顺子","pon":"刻子","kong":"杠"}[kind],journey.data.build.levels[actor][kind]];score_audio.cue("purchase")
	else:_notice="金币不足"
	_shop()

func _stamp_tile(kind:String,actor:int)->void:
	if journey.stamp(_selected_heirloom,kind,actor):
		_notice=ChapterMahjongTable.tile_name(_selected_heirloom)+("已盖赤封：之后所在面子再计一次。" if kind=="red" else "已盖金封：每桌首次成组得1币。")
		if _selected_heirloom not in journey.data.build.keepsakes[actor]:_notice+=" 还没装进行囊，记得带走。"
		score_audio.cue("encore_accept",1.12)
	else:_notice="请选择牌或检查金币"
	_shop()

func _finish_shopping()->void:
	journey.prepare(_shop_actor)
	if _shop_actor==0:
		if use_ai:_ai_shop();_begin_table()
		else:_shop_actor=1;_replacement=0;_selected_heirloom=-1;_shop()
	else:_begin_table()
func _ai_shop()->void:
	# Reads its run wallet/loadout and the public shop; never the next seeded wall.
	var data:Dictionary=journey.data;var owned:Array=data.history.back().owned_tiles[1]
	if data.build.techniques[1].is_empty():journey.choose_technique("partner",1)
	for id:String in data.shops:
		if id=="redthread" and id not in data.build.items[1] and data.coins[1]>=Catalog.ITEMS[id].price:journey.buy(id,1,1)
		if id=="chorus" and data.build.shared.is_empty() and data.coins[1]>=Catalog.ITEMS[id].price:journey.buy(id,1,0)
	while data.coins[1]>=3 and data.build.carry_slots[1]<3:journey.pack_slot(1)
	journey.use_recommended_keepsakes(1)
	journey.pack_public_request(1)
	if data.coins[1]>=4:journey.upgrade("pon",1)
	if not owned.is_empty():
		var chosen:int=data.build.heirlooms[1]
		if chosen>=0 and data.coins[1]>=3:journey.stamp(chosen,"red",1)
	journey.prepare(1)

func _show_carry_plan(actor:int)->void:
	var column:=_new_modal(Rect2(290,147,1020,594))
	_text("约好下一手 · 把缺张留给伙伴",31,column)
	var names:Array[String]=[]
	for id:int in journey.data.build.keepsakes[actor]:names.append(ChapterMahjongTable.tile_name(id))
	_text("你将携带："+("、".join(names) if not names.is_empty() else "尚未装入传家牌"),23,column)
	_text("先带两张可组合的牌，再约好缺张。泡泡只从上一桌自己确实拥有的牌里留牌，占用它的行囊；下桌仍需实际递入河牌、再交换取回。",19,column)
	var choices:Array=journey.carry_requests_for(actor)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);column.add_child(row)
	for face:int in choices:
		var chosen:int=face
		var b:=_button("请留 "+ChapterMahjongTable.tile_name(face*4),func():journey.plan_carry_request(chosen,actor);_notice="约好缺 "+ChapterMahjongTable.tile_name(chosen*4)+"；下桌公开要牌保留，伙伴能否带来取决于实际持牌";score_audio.cue("select");_shop(),Vector2(222,75),"selected" if journey.data.planned_requests[actor]==face else "ivory");row.add_child(b)
	if choices.is_empty():_text("当前行囊还没有两张可搭配的牌，或已经是完整组合。回夜市扩容、点牌装入后再约。",20,column)
	var partner_face:int=journey.data.planned_requests[1-actor]
	if partner_face>=0:
		_text("伙伴公开需要："+ChapterMahjongTable.tile_name(partner_face*4)+"。帮忙可能会换掉你行囊最后一张。",19,column)
		column.add_child(_button("我来接棒 · 从自己旧牌中留缺张",func():var id:int=journey.pack_public_request(actor);_notice="已为伙伴留 "+ChapterMahjongTable.tile_name(id) if id>=0 else "自己上一桌没有这张牌，无法凭空补齐";_shop(),Vector2(962,60),"primary"))
	else:_text("约好后双方仍可改。传家牌按行囊保留，其余起手照常随机；下一桌要靠实际递牌完成接力。",18,column)
	column.add_child(_button("取消我的约牌",func():journey.plan_carry_request(-1,actor);_notice="已取消约牌";_shop(),Vector2(962,52)))
	column.add_child(_button("返回夜市 · 继续准备",_shop,Vector2(962,58),"primary"))
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE and mode in ["reshape_picker","river_picker","first_move"]:_close_reshape_picker()
		if event.physical_keycode==KEY_ESCAPE and mode=="shop_detail":_shop()
		if event.physical_keycode==KEY_ESCAPE and mode=="score_receipt":_close_score_receipt()
		if event.physical_keycode==KEY_ESCAPE and mode=="welcome_complements":welcome.show_result()
		if event.physical_keycode==KEY_ESCAPE and mode=="table_tools":_close_trick_picker()
		elif event.physical_keycode==KEY_SPACE:presenter.skip_score()
		elif event.physical_keycode==KEY_F1 and mode in ["lobby","table","review"]:_show_help()

func _show_help()->void:
	if welcome.active:welcome.help();return
	var previous:String=mode;mode="help"
	var column:=_new_modal(Rect2(242,70,1116,760))
	_text("把一副牌，玩成一场连锁",32,column)
	_text("每人最多6次弃牌，面子可以先入账。两人的总分达到目标，就能一起过桌。",19,column)
	var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",12);column.add_child(grid)
	var topics:Array=[
		["① 做一组，点一盏灯","每街先选个人目标，只认新亮组。亮灯得2币与1灵感，后续每组再加16筹码。开局可换最多3张散牌；契约可不押，留金币到夜市。"],
		["② 灵感，改变这一手","每次1灵感：回手救缺张，催演放大新亮组，递彩换河牌。爆鸣茶炉还能添火蓄重算，跨回合保留。默认每回合一次；亮灯可补灵感。"],
		["③ 把一组，接成两响","默认每回合亮一组；花1灵感可续奏第二组，或拆换自己的三张明组借回关键牌追击。借形、续奏、催演共用技艺额度；借形不重发旧分。亮组会放弃门清与七对。"],
		["④ 选绝活，再选下一桌","首次夜市免费选一门绝活，持续本轮；还可选合作返场或河灯悬赏。两专属＋一共享挂件，刻印与传家实牌都能成长。别只买倍率，先让牌组稳定成型。"]]
	for topic:Array in topics:
		var card:=PanelContainer.new();card.custom_minimum_size=Vector2(522,178);card.add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"));grid.add_child(card)
		var margin:=MarginContainer.new()
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,15)
		card.add_child(margin);var body:=VBoxContainer.new();body.add_theme_constant_override("separation",8);margin.add_child(body)
		_text(topic[0],23,body);_text(topic[1],18,body)
	_text("胡牌倍率：基础4 ＋ 自摸2 ＋ 门清2 ＋ 七对6 ＋ 清一色6（满足项相加）。\n每组先算「筹码 × 挂件倍率 × 重计」，合法胡牌再放大累计得分。",18,column)
	_text("提前达标后可安稳收桌，或邀请伙伴加演：目标升至1.6倍，成功每席额外4币，失败损失耐力。
帮助期间AI暂停；空格跳过演出，顶部可切1.6×节奏。",16,column)
	column.add_child(_button("明白了 · 回到牌桌",func():
		remove_child(modal);modal.queue_free();modal=null;mode=previous
		if previous=="lobby":_lobby(),Vector2(1064,58),"primary"))
func _exit_tree()->void:
	if is_instance_valid(audio):audio.close()
	if is_instance_valid(score_audio):score_audio.close()


func _show_trick_picker(index:int,actor:int,revision:int)->void:
	var s:Dictionary=rules.state()
	if s.phase!="discard" or s.actor!=actor or s.revision!=revision:return
	mode="trick_picker"
	var column:=_new_modal(Rect2(224,82,1152,658));column.add_theme_constant_override("separation",10)
	_text("灵感 · 让这一手有转机",33,column)
	_text("每次消耗1灵感 · "+("回手后可再接一次技艺" if rules.technique(actor)=="rewind" else "每个人回合限一次")+" · 亮灯可补充，最多3点",18,column)
	if not s.melds[actor].is_empty():
		var reshape_button:=_button("一手两响 · 有第二组就续奏，缺关键牌就借形",func():_close_trick_picker();_show_reshape_picker(actor,revision),Vector2(1084,46),"primary")
		reshape_button.disabled=rules.reshape_options().is_empty() and rules.continuation_options().is_empty();column.add_child(reshape_button)
	var hand_name:String=ChapterMahjongTable.tile_name(s.hands[actor][index]) if index>=0 else "未选手牌"
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);column.add_child(row)
	var boost:=_button(rules.boost_description(actor),func():_finish_trick("boost",index,-1,actor,revision),Vector2(1084,65),"primary")
	boost.disabled=s.night.self_used[actor] or s.night.direction.boost[actor] or (rules.technique(actor)=="spotlight" and s.night.wallets[actor]<1);row.add_child(boost)
	if "coal" in s.night.build.items[actor]:
		boost.custom_minimum_size.x=530
		var fire:=_button("添火 · 炉温 %d → %d / 2\n跨回合保留，满炉下一组顺/刻再计"%[s.night.contexts[actor].heat,mini(2,s.night.contexts[actor].heat+1)],func():_finish_trick("stoke",-1,-1,actor,revision),Vector2(542,65),"primary")
		fire.disabled=s.night.contexts[actor].heat>=2;row.add_child(fire)
	_text("回手 · 用「%s」换回自己的公开弃牌"%hand_name,21,column)
	var recall_scroll:=ScrollContainer.new();recall_scroll.custom_minimum_size=Vector2(1084,82);recall_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(recall_scroll)
	var recall:=HBoxContainer.new();recall.size_flags_horizontal=Control.SIZE_EXPAND_FILL;recall.add_theme_constant_override("separation",7);recall_scroll.add_child(recall)
	var shown:Array=[]
	for tile:int in s.discards[actor]:
		shown.append(tile)
		var preview:Dictionary=rules.forecast_trick("recall",index,tile)
		var b:=_button(ChapterMahjongTable.tile_name(tile)+(str("\n可成组 +",preview.score) if preview.get("score",0)>0 else "\n换回手牌"),func():_finish_trick("recall",index,tile,actor,revision),Vector2(117,63));b.disabled=not preview.ok;recall.add_child(b)
	if shown.is_empty():
		var empty:=_text("还没有自己的弃牌；换起手放出的牌也可回收。",17,recall);empty.custom_minimum_size=Vector2(1030,52);empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_text("递彩 · 用「%s」免费交换公开河牌，换出的实体可供伙伴接力"%hand_name,21,column)
	var river:=HBoxContainer.new();river.add_theme_constant_override("separation",9);column.add_child(river)
	for slot in int(s.night.revealed):
		var target:int=slot;var preview:Dictionary=rules.forecast_trick("relay",index,target)
		var b:=_button(ChapterMahjongTable.tile_name(s.tea.tray[slot])+(str("\n可成组 +",preview.score) if preview.get("score",0)>0 else "\n以灵感代茶气"),func():_finish_trick("relay",index,target,actor,revision),Vector2(207,65));b.disabled=not preview.ok;river.add_child(b)
	_text("先在牌桌点选要换出的手牌。回手与递彩保持实体总数，不触发弃牌茶气或额外摸牌。",17,column)
	column.add_child(_button("保留灵感 · 返回牌桌",_close_trick_picker,Vector2(1084,48)))

func _close_trick_picker()->void:
	if is_instance_valid(modal):remove_child(modal);modal.queue_free();modal=null
	mode="table";elapsed=0

func _close_score_receipt()->void:
	_close_trick_picker();mode=_receipt_return_mode

func _finish_trick(id:String,index:int,target:int,actor:int,revision:int)->void:
	_close_trick_picker();_command("trick",[id,index,target],actor,revision)

func _tile_list(ids:Array)->String:
	var names:Array[String]=[]
	for id:int in ids:names.append(ChapterMahjongTable.tile_name(id))
	return " · ".join(names)

func _select_reshape_meld(index:int,actor:int,revision:int)->void:
	if welcome.active:return
	if mode!="table" or presenter.is_busy():return
	_show_reshape_picker(actor,revision,index)

func _show_reshape_picker(actor:int,revision:int,meld_filter:int=-1)->void:
	var s:Dictionary=rules.state()
	if s.actor!=actor or s.revision!=revision:return
	if not rules.can_reshape():presenter._hint.text="借形改组需要1灵感和本回合未使用的技艺额度。";return
	var options:Array=rules.reshape_options()
	if meld_filter>=0:options=options.filter(func(o:Dictionary)->bool:return o.meld==meld_filter)
	var continuations:Array=rules.continuation_options()
	if options.is_empty() and continuations.is_empty():presenter._hint.text="这组暂时不能合法改组，手里也没有另一组可续奏；可以留灵感等下一手。";return
	mode="reshape_picker"
	presenter._action_row.hide();presenter._hint.text="右侧选续奏或借形。悬停预览：青框补入明组，金框取回或直接亮出。点击才花灵感；Esc返回。"
	if is_instance_valid(modal):remove_child(modal);modal.queue_free()
	modal=Panel.new();modal.position=Vector2(1251,115);modal.size=Vector2(333,590);modal.theme=Palette.create();add_child(modal)
	modal.add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"))
	var column:=VBoxContainer.new();column.position=Vector2(15,15);column.size=Vector2(303,560);column.add_theme_constant_override("separation",8);modal.add_child(column)
	_text("一手两响" if not continuations.is_empty() else "借形改组",28,column)
	_text("花1灵感 · 占本回合技艺\n每个明组限改一次 · 旧组不再得分",16,column)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(303,405);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var cards:=VBoxContainer.new();cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cards.add_theme_constant_override("separation",9);scroll.add_child(cards)
	for continuation:Dictionary in continuations:
		var key:String=continuation.continuation_key
		var card:=_button("续奏 · 花1灵感再亮\n"+_tile_list(continuation.tiles)+"\n这组 +%d 分"%continuation.preview.total,func():_close_reshape_picker();_command("continue_group",key,actor,revision),Vector2(283,122),"primary")
		cards.add_child(card);card.mouse_entered.connect(func():presenter.table_view.highlight_reshape([],continuation.tiles));card.mouse_exited.connect(func():presenter.table_view.highlight_reshape([],[]))
	var shapes:Dictionary={}
	for option:Dictionary in options:
		var shape_key:String=str(option.meld)+":"+_tile_list(option.give)+":"+_tile_list(option.take)
		if shapes.has(shape_key):continue
		shapes[shape_key]=true
		var key:String=option.key
		var future:String="暂不成组 · 留作下一手"
		if option.score>0:future=("可胡牌 · 预计总分 " if option.best.kind=="tsumo" else ("追击" if s.night.self_used[actor] else "可亮")+("顺 " if option.best.kind=="self_chi" else "刻 ")+_tile_list(option.best.tiles)+"\n+")+str(option.score)
		var contract_note:String=""
		if option.contract_before!=option.contract_after:
			contract_note="\n契约进度 %d → %d / %d"%[option.contract_before,option.contract_after,3 if s.night.contracts[actor]=="sequence" else 2]
		if option.bank_after<option.bank_before:contract_note+=" · 收桌少%d"%(option.bank_before-option.bank_after)
		var b:=_button("第%d组：%s → %s\n放入 %s\n取回 %s\n%s"%[option.meld+1,"顺" if option.old_kind=="chi" else "刻","顺" if option.kind=="chi" else "刻",_tile_list(option.give),_tile_list(option.take),future]+contract_note,func():_finish_reshape(key,actor,revision),Vector2(283,177 if not contract_note.is_empty() else 155),"primary" if option.score>0 else "ivory")
		b.tooltip_text="分数指下一次新亮组；旧组不重新计分。改组会即时改变当前契约进度，追击亮组后可能再恢复。"
		b.add_theme_font_size_override("font_size",17);cards.add_child(b)
		b.mouse_entered.connect(func():presenter.table_view.highlight_reshape(option.give,option.take))
		b.mouse_exited.connect(func():presenter.table_view.highlight_reshape([],[]))
	column.add_child(_button("保留灵感 · 返回",_close_reshape_picker,Vector2(303,45)))

func _close_reshape_picker()->void:
	presenter.table_view.highlight_reshape([],[]);presenter._combo.reset();presenter._combo.position=Vector2(180,573);_close_trick_picker();presenter._render_actions();presenter._action_row.show();presenter._lock()

func _finish_reshape(key:String,actor:int,revision:int)->void:
	_close_reshape_picker();_command("reshape",key,actor,revision)

func _show_river_picker(actor:int,revision:int)->void:
	var s:Dictionary=rules.state()
	if s.actor!=actor or s.revision!=revision or s.phase!="discard":return
	var plans:Array=rules.river_opportunities();mode="river_picker"
	presenter._action_row.hide();presenter._hint.text="只看已揭河牌，不猜牌墙。右侧先选换牌方案，再亲手亮组。也可返回，手动选择不同的换出牌。"
	if is_instance_valid(modal):remove_child(modal);modal.queue_free()
	modal=Panel.new();modal.position=Vector2(1251,115);modal.size=Vector2(333,590);modal.theme=Palette.create();add_child(modal)
	modal.add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"))
	var column:=VBoxContainer.new();column.position=Vector2(15,15);column.size=Vector2(303,560);column.add_theme_constant_override("separation",8);modal.add_child(column)
	_text("河牌补形",28,column)
	_text("共享茶气 %d · 每换%d\n只预览，不自动亮牌"%[s.tea.charge,Rules.Tea.cost(s,actor)],17,column)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(303,405);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var cards:=VBoxContainer.new();cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cards.add_theme_constant_override("separation",9);scroll.add_child(cards)
	if plans.is_empty():
		var exhausted:bool=s.tea.swaps[actor]>=(2 if s.tea.recipe=="ember" else 1)
		_text("本回合换牌次数已用完。" if exhausted else ("茶气不足，先打牌或亮组补充。" if s.tea.charge<Rules.Tea.cost(s,actor) else "当前没有换一张就能亮出的新组。"),23,cards)
		_text("可保留茶气、公开请求缺张，或手动换牌铺下一手。方案不考虑暗牌，也不保证下一摸。",18,cards)
	for plan:Dictionary in plans:
		var index:int=plan.index;var slot:int=plan.slot
		var cost:String="再花1灵感续奏" if plan.choice.get("needs_continuation",false) else "换好后可直接亮"
		var future:String=("可胡 · 全桌预计 %d" if plan.choice.kind=="tsumo" else "新组可得 +%d")%plan.points
		var b:=_button("拿 "+ChapterMahjongTable.tile_name(plan.incoming)+" · 换出 "+ChapterMahjongTable.tile_name(plan.outgoing)+"\n"+_tile_list(plan.choice.get("tiles",[]))+"\n"+future+"\n花%d茶气 · "%plan.cost+cost,func():_close_reshape_picker();_command("exchange",Vector2i(index,slot),actor,revision),Vector2(283,150),"primary")
		b.tooltip_text=plan.clue.text+" 这只是当前得分/余牌搭配排序的建议，可自行选择其他换出牌。";cards.add_child(b)
		b.mouse_entered.connect(func():
			presenter.table_view.highlight_reshape([plan.outgoing],[plan.incoming]);presenter._combo.position=Vector2(40,746)
			if plan.choice.has("preview"):
				var forecast:Dictionary=plan.choice.preview
				presenter._combo.present({"source":"补形后"+("续奏" if plan.choice.get("needs_continuation",false) else "亮组")+" · 预计 +%d分"%plan.points,"after_chips":forecast.chips,"after_factor":forecast.factor,"after_repeats":forecast.repeats}))
		b.mouse_exited.connect(func():presenter.table_view.highlight_reshape([],[]);presenter._combo.reset())
	column.add_child(_button("保留茶气 · 返回",_close_reshape_picker,Vector2(303,45)))

func _show_lesson_select()->void:
	mode="lesson_select";_lesson_reset.hide();_lesson_guide_toggle.hide()
	var column:=_new_modal(Rect2(224,158,1152,575))
	_text("同一副起手，三种解法",36,column)
	_text("预设练招 · 在真实3D牌桌亲手亮组、改组、追击。试错可以随时重来。",20,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);column.add_child(row)
	for id:String in Lessons.LESSONS:
		var key:String=id;var lesson:Dictionary=Lessons.LESSONS[id]
		var description:String=lesson.text if _lesson_guidance else {"wind":"风铃偏爱连续顺子。怎样安排两组的先后？","fire":"镇纸给刻子加筹码。先拿哪一组更有利？","seal":"赤封跟着真实那张牌走。能让它参加两组吗？"}[id]
		if _lesson_bests.has(id):description+="\n本次最好两响 · %d分"%_lesson_bests[id]
		var card:=_button(lesson.name+"\n\n"+description,func():_start_lesson(key),Vector2(357,245),"primary" if id=="wind" else "ivory");card.add_theme_font_size_override("font_size",21);row.add_child(card)
	_text("每次改组花1灵感；同一明组每桌只能改一次。借回牌可在本回合追击，弃牌后机会消失。\n练招使用预设起手与构筑；随机旅程从新的一副牌开始。",18,column)
	column.add_child(_button("返回 · 自己开一桌",_lobby,Vector2(1100,54)))

func _start_lesson(id:String)->void:
	if id not in Lessons.LESSONS or presenter.is_busy():return
	_lesson_id=id;_replay_seed=-1;starter="windbell" if id=="wind" else "coal";use_ai=true
	journey.start(int(randi()%2147483646)+1,starter,true);_begin_table()

func _toggle_lesson_guidance()->void:
	if mode!="table" or _lesson_id.is_empty() or presenter.is_busy():return
	_lesson_guidance=not _lesson_guidance
	rules._s.night.lesson.guided=_lesson_guidance;rules._s.revision+=1
	_lesson_guide_toggle.text="隐藏指引 · 自由试招" if _lesson_guidance else "显示分步指引"
	_refresh()

func _show_lesson_result(success:bool)->void:
	mode="lesson_result";_lesson_reset.hide();_lesson_guide_toggle.hide()
	var column:=_new_modal(Rect2(317,174,966,550))
	_text("一手两响 · 做到了" if success else "再换一种出手顺序",35,column)
	var n:Dictionary=rules.state().night
	if success:
		var chain:Dictionary={}
		for event:Dictionary in n.reshape.chains:
			if event.actor==0:chain=event
		var borrowed:bool=not chain.is_empty()
		if not borrowed:
			for event:Dictionary in n.continuations:
				if event.actor==0:chain=event
		var same_hand:bool=rules.state().discard_count==0 and n.turns[0]==0
		if same_hand:_lesson_bests[_lesson_id]=maxi(int(_lesson_bests.get(_lesson_id,0)),int(n.scores[0]))
		_text("本手实得 %d 分 · 第二组贡献 %d 分"%[n.scores[0],chain.total],28,column)
		_text(("本次最好两响 %d分 · 只记未弃牌前的同起手"%_lesson_bests[_lesson_id]) if same_hand else "已打过牌继续完成 · 这次不纳入同起手纪录",18,column)
		_text((Lessons.LESSONS[_lesson_id].text if _lesson_guidance else "你用借回的关键牌，亲手接出了第二组。") if borrowed else "你找到了另一条路：用灵感续奏，直接亮出手中的第二组。",21,column)
		_text("旧组得分保留，借回的实体组成新组，才有第二次连锁。\n换一套挂件，同一副牌就值得重新考虑先后顺序。" if borrowed else "有现成第二组就能续奏；缺关键牌时可以借形。两者都占技艺额度。\n重试时，试试把明组里的关键牌借回来，比较新的收益。",20,column)
		score_audio.cue("breakthrough")
	else:_text("先保留灵感；亮出一组后，把能补成另一种合法明组的手牌放进去。\n借回关键牌再亮新组，就能在同一回合完成追击。",22,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);column.add_child(row)
	row.add_child(_button("换个构筑再试",_show_lesson_select,Vector2(447,62)))
	row.add_child(_button("以%s随机开宴"%("风铃" if _lesson_id=="wind" else "茶炉"),func():_start_run(true),Vector2(447,62),"primary"))
	column.add_child(_button("重试这一手 · 练习借形",func():_start_lesson(_lesson_id),Vector2(906,48)))
	column.add_child(_button("回看自己的牌桌",func():remove_child(modal);modal.queue_free();modal=null;mode="lesson_review";_lesson_reset.show(),Vector2(906,48)))


func _show_technique_draft(actor:int)->void:
	var column:=_new_modal(Rect2(242,140,1116,575))
	_text(["小柯","泡泡"][actor]+" · 为构筑选一门绝活",34,column)
	_text("首次夜市免费选一次，持续整段旅程。改变灵感的用法，不占挂件槽。",19,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",20);column.add_child(row)
	for id:String in Catalog.techniques_for(journey.data.build,actor):
		var chosen:String=id;var item:Dictionary=Catalog.TECHNIQUES[id]
		var card:=PanelContainer.new();card.custom_minimum_size=Vector2(520,348);card.add_theme_stylebox_override("panel",FurUICeramicFrame.style("ivory"));row.add_child(card)
		var margin:=MarginContainer.new()
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
		card.add_child(margin);var body:=VBoxContainer.new();body.add_theme_constant_override("separation",16);margin.add_child(body)
		var title:=_text(item.name,29,body);title.add_theme_color_override("font_color",Color("20525a"))
		var detail:=_text(item.text,21,body);detail.add_theme_color_override("font_color",Color("244850"))
		var choice:=_text(item.decision,18,body);choice.add_theme_color_override("font_color",Color("776139"));choice.size_flags_vertical=Control.SIZE_EXPAND_FILL
		body.add_child(_button("学会 · "+item.name,func():
			if journey.choose_technique(chosen,actor):_notice="已学会 "+item.name;score_audio.cue("purchase");_shop(),Vector2(418,59),"primary"))
	_text("选择后本轮不能更换；下一局可换一门，比较同样起手的不同打法。",17,column)


func _show_action_picker(actor:int,revision:int)->void:
	if rules.state().actor!=actor or rules.state().revision!=revision:return
	mode="action_picker";var column:=_new_modal(Rect2(235,130,1130,610))
	_text("这一手 · 所有合法组合",32,column)
	_text("胡牌与本街亮灯组合优先展示。亮组会放弃门清/七对；自己的三张明组仍可借形一次。",18,column)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1075,388);column.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);scroll.add_child(grid)
	var explained:Array=rules.presented_choices()
	for index:int in presenter._ranked_choices():
		var i:int=index;var option:Dictionary=explained[i]
		if option.kind=="skill":continue
		var caption:String=option.label+("\n"+("借形" if option.chain.method=="reshape" else "续奏")+"两响合计 %d"%option.chain.total if option.has("chain") else "")
		var button:=_button(caption,func():_close_trick_picker();_command("action",i,actor,revision),Vector2(344,108),"primary" if option.kind in ["ron","tsumo"] else "ivory");button.tooltip_text=presenter.chain_instruction(option);grid.add_child(button)
	column.add_child(_button("返回 · 再看手牌",_close_trick_picker,Vector2(1075,58)))


func _show_venue_draft()->void:
	var number:int=journey.next_table();var column:=_new_modal(Rect2(242,142,1116,563))
	_text("下一桌 · 选一种不同的挑战",33,column)
	_text("两席分数目标相同，触发方式不同。由小柯为同桌选择，本段旅程不再换席。",18,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);column.add_child(row)
	for id:String in Catalog.venues_for(number):
		var chosen:String=id;var venue:Dictionary=Catalog.VENUES[id]
		var card:=PanelContainer.new();card.custom_minimum_size=Vector2(520,337);card.add_theme_stylebox_override("panel",FurUICeramicFrame.style("ivory"));row.add_child(card)
		var margin:=MarginContainer.new()
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
		card.add_child(margin);var body:=VBoxContainer.new();body.add_theme_constant_override("separation",17);margin.add_child(body)
		var title:=_text(venue.name,29,body);title.add_theme_color_override("font_color",Color("20525a"))
		var detail:=_text(venue.text,21,body);detail.add_theme_color_override("font_color",Color("244850"))
		var choice:=_text(venue.choice,18,body);choice.add_theme_color_override("font_color",Color("776139"));choice.size_flags_vertical=Control.SIZE_EXPAND_FILL
		body.add_child(_button("赴席 · "+venue.name,func():
			if journey.choose_venue(chosen):_notice="已选 "+venue.name;score_audio.cue("reveal");_shop(),Vector2(418,59),"primary"))
	_text("只改变这一桌的特殊规则。136实体、公共河牌、商店与胡牌仍遵循同一套规则。",17,column)


func _show_av_settings()->void:
	mode="settings";var column:=_new_modal(Rect2(395,192,810,497))
	_text("让演出合你的节奏",32,column)
	_text("设置期间伙伴暂停行动；音量与镜头偏好在当前游玩期间保留。",18,column)
	for category:String in ["music","effects"]:
		var kind:String=category
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);column.add_child(row)
		var title:=_text("背景音乐" if kind=="music" else "牌桌与连锁音效",20,row);title.custom_minimum_size.x=180
		var slider:=HSlider.new();slider.custom_minimum_size=Vector2(445,42);slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=100*(score_audio.music_volume if kind=="music" else score_audio.effects_volume);slider.set_meta("sound_setting",kind);row.add_child(slider)
		var number:=_text("%d%%"%int(slider.value),19,row);number.custom_minimum_size.x=72
		slider.value_changed.connect(func(value:float):
			number.text="%d%%"%roundi(value)
			if kind=="music":score_audio.music_volume=value/100.0
			else:score_audio.effects_volume=value/100.0)
		if kind=="effects":slider.drag_ended.connect(func(changed:bool):
			if changed:score_audio.cue("tile_land"))
	var reduced:bool=presenter.table_view.night_feedback.reduced_motion
	column.add_child(_button("镜头聚焦："+("关闭 · 保持稳定" if reduced else "开启 · 高分时轻微推进"),func():presenter.table_view.night_feedback.reduced_motion=not reduced;_show_av_settings(),Vector2(758,62),"ivory" if reduced else "selected"))
	_text("牌的真实移动与换座仍保留，方便看清行动归属。空格可直接跳过整段计分。",18,column)
	column.add_child(_button("返回牌桌",_close_trick_picker,Vector2(758,60),"primary"))


func _show_table_tools(actor:int,revision:int)->void:
	var s:Dictionary=rules.state()
	if s.phase!="discard" or s.actor!=actor or s.revision!=revision:return
	var options:Array=rules.choices();var has_skill:bool=options.any(func(c:Dictionary)->bool:return c.kind=="skill")
	var show_advice:bool=use_ai and actor==0 and rules.can_invite_encore()
	var rect:=Rect2(360,112,880,650) if has_skill else Rect2(360,149,880,590)
	if show_advice:rect.position.y-=24;rect.size.y+=48
	mode="table_tools";var column:=_new_modal(rect)
	var reached:bool=s.night.bank_preview>=s.night.target
	_text("已经达标 · 接下来由你们决定" if reached else "同桌协作 · 为下一手铺路",32,column)
	var delivery:int=s.night.deliveries[actor]
	_text(("伙伴递来的 "+ChapterMahjongTable.tile_name(delivery)+" 已在河中，请回桌交换。" if delivery in s.tea.tray else "要牌会公开给伙伴；冲泡会改变公共河牌，两人都能利用。"),19,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);column.add_child(row)
	row.add_child(_button("指定需要的牌\n告诉伙伴缺哪一张",func():_from_tools("request_picker",null,actor,revision),Vector2(402,82),"primary"))
	var cancel:=_button("取消公开要牌",func():_from_tools("request_type",-1,actor,revision),Vector2(402,82));cancel.disabled=s.night.requests[actor]<0;row.add_child(cancel)
	for i in options.size():
		if options[i].kind!="skill":continue
		var index:int=i;var skill:Dictionary=options[i]
		column.add_child(_button(skill.label+" · 本桌一次",func():_from_tools("action",index,actor,revision),Vector2(824,61)))
	_text("冲泡换签 · 2茶气 · 每街全队一次（当前 %d 茶气）"%s.tea.charge,21,column)
	var river:=HBoxContainer.new();river.add_theme_constant_override("separation",10);column.add_child(river)
	for slot in int(s.night.revealed):
		var i:int=slot
		var b:=_button(ChapterMahjongTable.tile_name(s.tea.tray[slot])+"\n冲泡换掉",func():_from_tools("refresh_river",i,actor,revision),Vector2(154,76));b.disabled=s.night.refresh_used or s.tea.charge<2;river.add_child(b)
	var bank_note:Label=_text("收桌预计 %s / 目标 %s。达标后可提议结束，伙伴同意才收桌；剩余摸牌机会会放弃。"%[presenter._number(s.night.bank_preview),presenter._number(s.night.target)],19,column)
	var endings:=HBoxContainer.new();endings.add_theme_constant_override("separation",12);column.add_child(endings)
	var bank:=_button("提议收桌 · 先问伙伴",func():_from_tools("cash_request",null,actor,revision),Vector2(402,76),"primary");bank.disabled=s.night.bank_preview<s.night.target;endings.add_child(bank)
	var extra:=_button("邀伙伴加演 · 目标%d\n成功各+4币，失败掉1耐力"%rules.encore_target(),func():_from_tools("encore_request",null,actor,revision),Vector2(410,76));extra.disabled=not rules.can_invite_encore();extra.add_theme_font_size_override("font_size",16);endings.add_child(extra)
	extra.tooltip_text="仅前两桌，提前达标但尚未达到1.6倍目标时可邀请。每桌只邀一次，双方同意后不能撤回；失败按新目标结算。" if not s.night.encore.asked else ("本桌已经加演，按新目标结算。" if s.night.encore.active else "本桌伙伴已婉拒加演。")
	if reached:column.move_child(bank_note,1);column.move_child(endings,2)
	if show_advice:
		var advice:Label=_text("泡泡："+rules.encore_advice().text,17,column)
		if reached:column.move_child(advice,3)
	column.add_child(_button("返回 · 继续做这一手",_close_trick_picker,Vector2(824,58)))

func _from_tools(kind:String,value:Variant,actor:int,revision:int)->void:
	_close_trick_picker();_command(kind,value,actor,revision)
