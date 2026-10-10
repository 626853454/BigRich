class_name FurMahjongNightPresenter
extends Control
var replay_mode:bool=false
signal command(kind:String,value:Variant,actor:int,revision:int)
signal score_beat(operation:String,step:int)
signal score_skipped
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
const Tea=preload("res://scripts/party/mahjong_teahouse_rules.gd")
const View=preload("res://scripts/party/mahjong_table_view.gd")
const Rules=preload("res://scripts/party/mahjong_night_table.gd")
var table_view:FurMahjongTableView
var snapshot:Dictionary={}
var choices:Array=[]
var use_ai:bool=true
var selected_index:int=-1
var selected_river:int=-1
var opening_selection:Array=[]
var action_buttons:Array[Button]=[]
var _heading:Label
var _subtitle:Label
var _score:Label
var _wallets:Label
var _turn:Label
var _contract:Label
var _requests:Label
var _hint:Label
var _build_text:RichTextLabel
var _ledger:RichTextLabel
var _ledger_heading:Label
var _progress:ProgressBar
var _action_row:HBoxContainer
var _offer_panel:Panel
var _offer_column:VBoxContainer
var _goal_column:VBoxContainer
var _build_heading:Label
var _built:bool=false
var _locked:bool=true
var _score_motion:Tween
var _shown_score:float=0
var _last_event:int=0
var _gain:Label
var _back:Button
var _settings:Button
var _score_lines:Array[String]=[]
var _beat_index:int=0
var _skipping_score:bool=false
var _combo:FurMahjongNightCombo
var _pace:Button
var fast_presentation:bool=false
var _hint_before_hover:String=""
var _has_hover_preview:bool=false
var _score_pending:bool=false
var _score_queue:Array=[]
var _score_due:int=0
var _contributions:Label
var _shown_contributions:Array=[0,0]
var _score_focus_active:bool=false
var _skip_score_button:Button
var _reshape_button:Button

func _ready()->void:
	theme=Palette.create();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop:=ColorRect.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.color=Color("102d35");backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	table_view=View.new();table_view.position=Vector2(0,85);table_view.size=Vector2(1240,630);add_child(table_view)
	table_view.tile_selected.connect(_select);table_view.tray_selected.connect(_exchange)
	table_view.tray_hovered.connect(_preview_exchange)
	_settings=button("音画设置",func():_emit("settings",null),Vector2(128,43));_settings.position=Vector2(24,120);add_child(_settings)
	_reshape_button=button("借形改组 · 1灵感\n从已亮组借回关键牌",func():_emit("reshape_picker",null),Vector2(243,67),"primary");_reshape_button.position=Vector2(25,177);add_child(_reshape_button);_reshape_button.hide()
	var top:=panel(Rect2(22,16,1556,90))
	_heading=label("百番夜宴",30,Rect2(20,8,380,40),top)
	_subtitle=label("麻将 × 组牌肉鸽",15,Rect2(22,52,590,25),top)
	_pace=button("节奏 1×",_toggle_pace,Vector2(144,39));_pace.position=Vector2(439,5);_pace.tooltip_text="切换1×/1.6×演出速度，只改变动画节奏；空格跳过当前计分。";top.add_child(_pace)
	_score=label("0 / 350",31,Rect2(605,4,420,42),top);_score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_progress=ProgressBar.new();_progress.position=Vector2(606,63);_progress.size=Vector2(410,12);_progress.show_percentage=false;top.add_child(_progress)
	_progress.add_theme_font_size_override("font_size",8)
	_contributions=label("小柯 0  ·  泡泡 0",15,Rect2(606,36,410,22),top);_contributions.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var bar_bg:=StyleBoxFlat.new();bar_bg.bg_color=Color("0b262a");bar_bg.set_corner_radius_all(7);bar_bg.border_color=Color("8f825d");bar_bg.set_border_width_all(1);_progress.add_theme_stylebox_override("background",bar_bg)
	var bar_fill:=StyleBoxFlat.new();bar_fill.bg_color=Color("d4b879");bar_fill.set_corner_radius_all(7);_progress.add_theme_stylebox_override("fill",bar_fill)
	_wallets=label("",18,Rect2(1070,12,280,60),top)
	_back=button("离席",func():_emit("leave",null),Vector2(130,48));_back.position=Vector2(1394,17);top.add_child(_back)
	var rail:=panel(Rect2(1256,121,322,582))
	_turn=label("",22,Rect2(18,13,284,60),rail)
	_contract=label("",16,Rect2(18,77,284,50),rail)
	_requests=label("",16,Rect2(18,327,284,95),rail);_requests.add_theme_color_override("font_color",Color("f4d38b"))
	_build_heading=label("本桌构筑",16,Rect2(18,129,284,22),rail)
	_goal_column=VBoxContainer.new();_goal_column.position=Vector2(18,136);_goal_column.size=Vector2(284,280);_goal_column.add_theme_constant_override("separation",8);rail.add_child(_goal_column)
	_build_text=rich(Rect2(18,153,285,173),rail);_build_text.add_theme_font_size_override("normal_font_size",16)
	_ledger_heading=label("最近一次 · 计分来源",16,Rect2(18,427,284,26),rail)
	_ledger=rich(Rect2(18,458,285,106),rail)
	_ledger.scroll_following=true
	_gain=label("",44,Rect2(428,153,520,70),self);_gain.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_gain.mouse_filter=Control.MOUSE_FILTER_IGNORE;_gain.hide()
	_combo=FurMahjongNightCombo.new();add_child(_combo)
	var bottom:=panel(Rect2(22,716,1556,166))
	_hint=label("",17,Rect2(18,8,1515,35),bottom)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(16,47);scroll.size=Vector2(1524,111);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;bottom.add_child(scroll)
	_action_row=HBoxContainer.new();_action_row.add_theme_constant_override("separation",10);scroll.add_child(_action_row)
	var button_shadows:=FurMahjongNightButtonShadows.new();button_shadows.name="NightActionShadows";scroll.add_child(button_shadows);button_shadows.bind(_action_row,scroll)
	_skip_score_button=button("跳过计分 · 空格",skip_score,Vector2(296,78));_skip_score_button.position=Vector2(1212,59);bottom.add_child(_skip_score_button);_skip_score_button.hide()
	_offer_panel=panel(Rect2(285,126,800,299));_offer_panel.hide()
	_offer_column=VBoxContainer.new();_offer_column.position=Vector2(24,13);_offer_column.size=Vector2(752,270);_offer_column.add_theme_constant_override("separation",7);_offer_panel.add_child(_offer_column)
	_combo.move_to_front()
	_built=true
	if not snapshot.is_empty():_render()

func panel(rect:Rect2)->Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size
	p.add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"));add_child(p);return p
func label(text:String,font_size:int,rect:Rect2,parent:Node)->Label:
	var l:=Label.new();l.text=text;l.position=rect.position;l.size=rect.size;l.add_theme_font_override("font",Palette.font(font_size>=24));l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("f7eedc"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func rich(rect:Rect2,parent:Node)->RichTextLabel:
	var l:=RichTextLabel.new();l.position=rect.position;l.size=rect.size;l.bbcode_enabled=true;l.add_theme_font_override("normal_font",Palette.font(false));l.add_theme_font_size_override("normal_font_size",17);l.add_theme_color_override("default_color",Color("eee8d4"));parent.add_child(l);return l
func button(text:String,callback:Callable,dimensions:Vector2=Vector2(220,64),variant:String="ivory")->Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size=dimensions;b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.add_theme_font_size_override("font_size",17);Palette.apply_button(b,variant);b.pressed.connect(callback);return b
func _clear(node:Node)->void:
	for child in node.get_children():node.remove_child(child);child.queue_free()

func configure(data:Dictionary,options:Array,ai:bool)->void:
	_has_hover_preview=false
	if _built and not is_busy():_combo.reset();table_view.highlight_score_tiles([])
	if data.get("revision",-1)!=snapshot.get("revision",-1):selected_index=-1;selected_river=-1;opening_selection.clear()
	if data.get("table_event",{}).get("kind","") in ["trick_recall","trick_relay"] and data.table_event.tiles.size()==2:
		selected_index=data.hands[data.actor].find(data.table_event.tiles[1])
	snapshot=data.duplicate(true);choices=options.duplicate(true);use_ai=ai
	if _built:_render()
func is_busy()->bool:return _score_pending or not _score_queue.is_empty() or table_view==null or table_view.is_animating() or (is_instance_valid(_score_motion) and _score_motion.is_running())
func _process(_delta:float)->void:
	if not _built or snapshot.is_empty():return
	if _score_pending and not table_view.is_animating():_score_pending=false;_animate_score()
	if not _score_queue.is_empty() and not table_view.is_animating() and Time.get_ticks_usec()>=_score_due:_advance_score()
	var locked:bool=is_busy() or (use_ai and snapshot.actor==1 and snapshot.phase!="finished")
	if locked!=_locked:
		_locked=locked
		if not locked:_render_actions();_render_offer()
		_lock()
	_apply_score_focus()

func _apply_score_focus(force:bool=false)->void:
	var focus:bool=_score_pending or not _score_queue.is_empty() or (is_instance_valid(_score_motion) and _score_motion.is_running())
	if not force and focus==_score_focus_active:return
	_score_focus_active=focus;_action_row.visible=not focus;_skip_score_button.visible=focus
	_combo.position=Vector2(40,746) if focus else Vector2(180,573)
	var offering:bool=snapshot.get("phase","")=="night_offer"
	_build_text.visible=not focus and not offering;_build_heading.visible=not focus and not offering;_requests.visible=not focus and not offering
	_ledger_heading.text="连锁账单 · 按触发顺序" if focus else "最近一次 · 计分来源"
	_ledger_heading.position.y=135 if focus else 427
	_ledger.position.y=166 if focus else 458;_ledger.size.y=398 if focus else 106
func _lock()->void:
	for b:Button in action_buttons:b.disabled=_locked or bool(b.get_meta("invalid",false))
	_reshape_button.disabled=_locked or bool(_reshape_button.get_meta("invalid",false))
	_back.disabled=is_busy();_settings.disabled=is_busy()
	if is_busy():_hint.text="实体落桌 → 挂件连锁 → 得分入账  ·  空格跳过演出"
func _emit(kind:String,value:Variant)->void:
	if is_busy():return
	command.emit(kind,value,int(snapshot.actor),int(snapshot.revision))

func _render()->void:
	var n:Dictionary=snapshot.night;var actor:int=snapshot.actor
	_heading.text=("复盘开局" if replay_mode else "百番夜宴")+" · 第 %d / 3 桌"%n.table
	_subtitle.text=("双声门神 · 双方先开一组，解除倍率护印" if n.boss else ("河灯悬赏 · 每阶段首组使用新揭河牌 +80筹码" if n.table==2 else "公共河牌3 → 4 → 5 · 组牌得分，共同过桌"))
	if n.venue in Catalog.VENUES:_subtitle.text=Catalog.VENUES[n.venue].name+" · "+{"river":"新河牌首组+80","refrain":"双方本街亮灯，各获下组返场","duet":"双方开组解除护印","prism":"两人各用技艺、至少两种，解除护印"}[n.venue]
	_subtitle.text+=" · 耐力%d · 合奏×%.2f"%[n.get("stamina",3),1.0+.25*int(n.ensemble.chain)]
	_progress.visible=not n.has("lesson")
	if n.has("lesson"):_heading.text=("练招 · " if n.lesson.get("guided",true) else "自由试招 · ")+n.lesson.name;_subtitle.text="预设同一副起手与构筑 · 分步指引可开关；本次最好只记未弃牌前的连响"
	if n.encore.active:_subtitle.text="加演押席 · 达标各多4币 · 失败掉1耐力 · 合奏×%.2f"%(1.0+.25*int(n.ensemble.chain))
	_wallets.text="小柯  %d金币    泡泡  %d金币\n共享茶气 %d / 9  ·  %s"%[n.wallets[0],n.wallets[1],snapshot.tea.charge,Tea.RECIPES[snapshot.tea.recipe].name]
	var stage_names:Array=["读牌立约","翻牌 · 已开3张","转牌 · 已开4张","河牌 · 已开5张"]
	_turn.text=("泡泡AI" if use_ai and actor==1 else ["小柯","泡泡"][actor])+"  "+stage_names[n.stage]+"\n剩余打牌 %d / 6"%maxi(0,6-n.turns[actor])
	var contract:String=n.contracts[actor];var count:int=0
	for meld:Dictionary in snapshot.melds[actor]:
		if (contract=="sequence" and meld.kind=="chi") or (contract=="triplet" and meld.kind in ["pon","kong"]):count+=1
	_contract.text=Catalog.CONTRACTS[contract].name+" · "+("须合法胡且同门9张" if contract=="suit" else "已亮 %d / %d"%[count,3 if contract=="sequence" else 2])+"\n押金 %d币 · 成约 ×%.1f"%[n.paid[actor],Catalog.STAKE_MULT[n.tiers[actor]]]
	var messages:Array[String]=[]
	for a in 2:
		if n.get("deliveries",[-1,-1])[a] in snapshot.tea.tray:messages.append(["小柯","泡泡"][a]+"的 "+ChapterMahjongTable.tile_name(n.deliveries[a])+" 已送到河牌")
		elif n.get("requests",[-1,-1])[a]>=0:
			var promised:int=n.get("promised_tiles",[-1,-1])[1-a]
			messages.append((["泡泡","小柯"][a]+"为你带了 " if promised>=0 and int(promised/4)==n.requests[a] and promised in snapshot.hands[1-a] else ["小柯","泡泡"][a]+"想要 ")+ChapterMahjongTable.tile_name(n.requests[a]*4))
	_requests.text="\n".join(messages) if not messages.is_empty() else "公开要牌，让伙伴帮你接力"
	var direction:Dictionary=n.direction;var goal:Dictionary=FurMahjongNightDirection.GOALS[direction.selected[actor]]
	_requests.text=("已亮灯 · " if direction.done[actor] else "本街追灯 · ")+goal.name+"\n灵感 %d / 3 · 喝彩 +%d筹码"%[direction.inspiration[actor],direction.applause[actor]]+"\n"+(_requests.text if not messages.is_empty() else goal.text)
	if direction.refrain[actor]>0:_requests.text+=" · 返场%d"%direction.refrain[actor]
	var tooltips:Array[String]=[]
	for a in 2:
		for id:String in n.build.items[a]:tooltips.append(Catalog.name_of(id)+"："+Catalog.ITEMS[id].text)
	_build_text.tooltip_text="\n\n".join(tooltips)
	table_view.selected_indices.clear();table_view.configure(snapshot,use_ai,selected_index)
	_render_build();_render_actions();_render_offer();_animate_score()
	_locked=is_busy() or (use_ai and actor==1 and snapshot.phase!="finished");_lock()
	_apply_score_focus(true)

func _render_build()->void:
	var n:Dictionary=snapshot.night
	var build_lines:Array[String]=[]
	for a in 2:
		build_lines.append("[color=#d4b97c]"+["小柯","泡泡"][a]+" · 顺%d / 刻%d / 杠%d级[/color]"%[n.build.levels[a].chi,n.build.levels[a].pon,n.build.levels[a].kong])
		var ordered:Array[String]=[]
		for id:String in n.build.items[a]:ordered.append(Catalog.name_of(id))
		build_lines.append(" → ".join(ordered) if not ordered.is_empty() else "空槽：商店可补构筑")
		var shown_heat:int=table_view.night_relics._heat_drawn[a] if is_instance_valid(table_view.night_relics) else int(n.contexts[a].heat)
		var warmth:String="炉温 %d/2"%shown_heat if "coal" in n.build.items[a] else "已打 %d 顺"%n.contexts[a].chi_count
		var next_bonus:String=" · 下顺×%.2f"%pow(1.35,mini(4,n.contexts[a].chi_count)) if "windbell" in n.build.items[a] else ((" · 下顺/刻再计" if shown_heat==2 else " · 灵感可添火") if "coal" in n.build.items[a] else " · 接力牌才触发")
		build_lines.append("[color=#bbd5cd]"+warmth+next_bonus+"[/color]")
	for id:String in n.build.shared:build_lines.append("[color=#a6dbcb]共享 · "+Catalog.name_of(id)+"[/color]")
	_build_text.text="\n".join(build_lines)

func _render_actions()->void:
	_clear(_action_row);action_buttons.clear()
	var phase:String=snapshot.phase;var actor:int=snapshot.actor
	_reshape_button.visible=phase=="discard" and not snapshot.melds[actor].is_empty() and not (use_ai and actor==1)
	var reshape_rules=Rules.new();reshape_rules._s=snapshot.duplicate(true)
	var reshape_possible:bool=reshape_rules.can_reshape() and not Rules.Reshape.candidates(snapshot.hands[actor],snapshot.melds[actor],snapshot.night.reshape.used[actor]).is_empty()
	var continue_possible:bool=not reshape_rules.continuation_options().is_empty()
	_reshape_button.set_meta("invalid",not reshape_possible and not continue_possible)
	_reshape_button.text="一手两响 · 1灵感\n直接续奏 / 借形改组" if continue_possible else "借形改组 · 1灵感\n从已亮组借回关键牌"
	if not continue_possible and not reshape_possible:
		_reshape_button.text="一手两响\n本回合已用技艺" if snapshot.night.direction.trick_used[actor] else ("一手两响\n灵感不足 · 亮灯可补充" if snapshot.night.direction.inspiration[actor]<=0 else "一手两响\n还差关键牌 · 看河牌补形")
	if phase=="night_offer":
		_hint.text="点选最多3张手牌可换起手；准备后先揭河牌，再正常摸牌。" if snapshot.night.stage==0 else "新一张河牌仍盖着：可加码或保持。揭牌后本次押约锁定。"
		if snapshot.night.stage==0:
			var mark:=button("帮我标出散牌\n保护对子、邻张和传家牌",_suggest_opening,Vector2(240,85));mark.set_meta("invalid",snapshot.night.mulligan_used[actor]);_action_row.add_child(mark);action_buttons.append(mark)
			var b:=button("换掉选中 %d 张\n本桌一次，不获得茶气"%opening_selection.size(),func():_emit("mulligan",opening_selection.duplicate()),Vector2(280,85))
			b.set_meta("invalid",opening_selection.is_empty() or snapshot.night.mulligan_used[actor]);_action_row.add_child(b);action_buttons.append(b)
			for id:String in Tea.RECIPES:
				var tea_id:String=id;var b2:=button(Tea.RECIPES[id].name+"\n"+Tea.RECIPES[id].short,func():_emit("tea",tea_id),Vector2(230,85),"selected" if snapshot.tea.recipe==id else "ivory");_action_row.add_child(b2);action_buttons.append(b2)
		return
	if phase=="finished":
		_hint.text="本桌结束：可以回看亮出的牌与完整计分来源。空格跳过演出。"
		var review:=button("查看结算 · 继续成长",func():_emit("review_result",null),Vector2(330,85),"primary");_action_row.add_child(review);action_buttons.append(review);return
	if phase=="night_cash_offer":
		_hint.text="伙伴想安稳收桌。现在保留已得分，但放弃剩余摸牌、胡牌番数与更多溢出奖励。"
		for option in [["同意 · 带走本桌收益",true],["继续 · 一起做大胡",false]]:
			var accept:bool=option[1];var b:=button(option[0],func():_emit("cash_answer",accept),Vector2(380,88),"primary" if accept else "ivory");_action_row.add_child(b);action_buttons.append(b)
		return
	if phase=="night_encore_offer":
		var n:Dictionary=snapshot.night;var raised:int=ceili(float(n.encore.base_target)*1.6)
		_hint.text="伙伴邀你加演：目标 %d → %d。成功各多4金币；失败掉1耐力。已得分保留，同意后不可撤回。"%[n.target,raised]
		for entry in [["同意加演 · 追额外4币",true],["婉拒 · 保留原目标",false]]:
			var accept:bool=entry[1];var b:=button(entry[0],func():_emit("encore_answer",accept),Vector2(386,88),"primary" if accept else "ivory");_action_row.add_child(b);action_buttons.append(b)
		return
	if phase=="discard":
		var name:String=ChapterMahjongTable.tile_name(snapshot.hands[actor][selected_index]) if selected_index>=0 else "先点一张手牌"
		var discard_text:String="打出 · "+name+"\n蓄茶 · 结束回合" if selected_index>=0 else "先选一张手牌\n打出结束回合"
		var b:=button(discard_text,func():_emit("discard",selected_index),Vector2(204,88),"primary");b.set_meta("invalid",selected_index<0);_action_row.add_child(b);action_buttons.append(b)
		var trick:=button("灵感 %d\n回手 / 催演 / 递彩"%snapshot.night.direction.inspiration[actor],func():_emit("trick_picker",selected_index),Vector2(220,88),"primary" if snapshot.night.direction.boost[actor] else "ivory")
		if "coal" in snapshot.night.build.items[actor]:trick.text="灵感 %d\n添火 / 改牌 / 催演"%snapshot.night.direction.inspiration[actor]
		trick.set_meta("invalid",snapshot.night.direction.inspiration[actor]<=0 or snapshot.night.direction.trick_used[actor]);_action_row.add_child(trick);action_buttons.append(trick)
		var river:=button("河牌补形\n看可成牌换法",func():_emit("river_picker",null),Vector2(180,88));_action_row.add_child(river);action_buttons.append(river)
		var has_skill:bool=choices.any(func(c:Dictionary)->bool:return c.kind=="skill")
		var tools:=button("同桌协作"+(" / 观牌" if has_skill else "")+"\n要牌 · 换签 · 收桌",func():_emit("table_tools",null),Vector2(204,88));_action_row.add_child(tools);action_buttons.append(tools)
	var displayed:int=0;var hidden_choices:bool=false
	for index:int in _ranked_choices():
		var i:int=index;var c:Dictionary=choices[index]
		if c.kind=="skill":continue
		if c.kind.begins_with("self_") and selected_index>=0 and snapshot.hands[actor][selected_index] not in c.tiles:continue
		if phase=="discard" and displayed>=2:hidden_choices=true;continue
		displayed+=1
		var extra:String=("\n借形" if c.chain.method=="reshape" else "\n续奏")+"两响合计 %d"%c.chain.total if c.has("chain") else ("\n可点亮本街目标" if can_light(c) else "")
		if snapshot.night.has("lesson") and snapshot.night.lesson.get("guided",true) and snapshot.melds[actor].is_empty() and c.get("tiles",[])==[0,4,8]:extra="\n练招 · 先亮这组"
		var b:=button(c.label+extra,func():_emit("action",i),Vector2(226,88),"primary" if c.kind in ["ron","tsumo"] or can_light(c) else "ivory");b.tooltip_text=c.get("detail","");_action_row.add_child(b);action_buttons.append(b)
		_action_row.move_child(b,displayed-1)
		if c.has("preview"):
			b.mouse_entered.connect(func():
				if is_busy():return
				if c.has("chain"):_hint_before_hover=_hint.text;_hint.text=chain_instruction(c);_has_hover_preview=true
				var preview:Dictionary=c.preview
				_combo.present({"source":"预计亮牌 · +%d分"%preview.total,"after_chips":preview.chips,"after_factor":preview.factor,"after_repeats":preview.repeats})
				table_view.highlight_score_tiles(c.tiles))
			b.mouse_exited.connect(func():
				if is_busy():return
				if c.has("chain"):_hint.text=_hint_before_hover;_has_hover_preview=false
				_combo.reset();_restore_borrowed_focus())
	if hidden_choices:
		var more:=button("展开所有组牌选择",func():_emit("action_picker",null),Vector2(166,88));_action_row.add_child(more);action_buttons.append(more);_action_row.move_child(more,displayed)
	_hint.text="点手牌 → 点已翻开的河牌，可花%d茶气交换；亮面子立刻计分，但会放弃门清/七对。"%Tea.cost(snapshot,actor)
	if phase=="discard":
		var d:Dictionary=snapshot.night.direction
		if "coal" in snapshot.night.build.items[actor] and snapshot.night.contexts[actor].heat==2:_hint.text="茶炉蓄满：下一组顺/刻再计一次。可叠加催演；保留热量继续摸牌也可以。"
		elif choices.any(func(c:Dictionary)->bool:return c.has("chain")):_hint.text="这手能接两响：先亮组，再把灵感用于续奏或借形。若先催演，本回合便不能接第二响；也可保留暗手冲胡。"
		elif choices.any(func(c:Dictionary)->bool:return c.kind in ["self_chi","self_pon"]):_hint.text="催演放大一组；续奏多亮一组；借形找回关键牌。它们共用本回合技艺额度。也可以留暗手冲胡。"
		elif "coal" in snapshot.night.build.items[actor] and not d.trick_used[actor] and d.inspiration[actor]>0:_hint.text="暂时没有完整面子。可花灵感添火铺下一手，或留灵感改牌；「同桌协作」能公开要缺张。"
		elif not d.trick_used[actor] and d.inspiration[actor]>0:_hint.text="暂时没有完整面子。点选散牌后，可用灵感回手/递彩补牌；也可公开要缺张，等伙伴接力。"
	if phase=="discard" and selected_index>=0:
		var clue=Rules.new();clue._s=snapshot.duplicate(true)
		_hint.text="选中 "+ChapterMahjongTable.tile_name(snapshot.hands[actor][selected_index])+" · "+clue.hand_clue(selected_index).text+" 再点同牌可取消。"
	elif phase=="discard" and snapshot.night.get("deliveries",[-1,-1])[actor] in snapshot.tea.tray:_hint.text="伙伴送来的 "+ChapterMahjongTable.tile_name(snapshot.night.deliveries[actor])+" 已在河牌。选手牌再点它交换；茶气不足时可以用灵感递彩。"
	if phase=="discard" and selected_index<0 and snapshot.night.bank_preview>=snapshot.night.target:
		_hint.text="已达标！可在「同桌协作」安稳收桌"+("，或邀伙伴加演追额外金币；也可继续做牌。" if snapshot.night.table<3 and not snapshot.night.encore.asked and snapshot.night.bank_preview<ceili(float(snapshot.night.encore.base_target)*1.6) else "，也可继续做大胡，争取溢出奖励。")
	if phase=="discard" and selected_index<0 and snapshot.table_event.kind in ["encore","offer"] and not str(snapshot.night.encore.get("note","")).is_empty():_hint.text="泡泡："+snapshot.night.encore.note
	if phase=="discard" and not snapshot.night.reshape.followup[actor].is_empty():_hint.text="借形追击已准备：用刚借回的金框实体牌，可再亮一组。只限本回合；打出手牌就放弃追击。"
	if phase=="claim":_hint.text="回应 "+ChapterMahjongTable.tile_name(snapshot.last_discard.tile)+("：末张仅可胡或过，不额外增加个人回合。" if snapshot.discard_count>=12 else "：吃碰可立即得分；过则正常摸牌。")
	if phase=="peek":_hint.text="观潮技艺：仅这3张牌已公开。选择真实牌墙顺序。"
	if not is_busy():_restore_borrowed_focus()

func _restore_borrowed_focus()->void:
	var ids:Array=[]
	if snapshot.get("phase","")=="discard" and not (use_ai and snapshot.actor==1):
		for id:int in snapshot.night.reshape.followup[snapshot.actor]:
			if id in snapshot.hands[snapshot.actor]:ids.append(id)
	table_view.highlight_score_tiles(ids)

func _render_offer()->void:
	_offer_panel.visible=snapshot.phase=="night_offer";_clear(_offer_column)
	_ledger.visible=not _offer_panel.visible;_ledger_heading.visible=not _offer_panel.visible
	_goal_column.visible=_offer_panel.visible;_build_text.visible=not _offer_panel.visible;_build_heading.visible=not _offer_panel.visible;_requests.visible=not _offer_panel.visible;_clear(_goal_column)
	if not _offer_panel.visible:return
	var n:Dictionary=snapshot.night;var actor:int=snapshot.actor
	var goal_title:=Label.new();goal_title.text="先选一个本街目标";goal_title.add_theme_font_size_override("font_size",20);goal_title.add_theme_color_override("font_color",Color("f8dfa7"));_goal_column.add_child(goal_title)
	for id:String in n.direction.offers[actor]:
		var goal_id:String=id;var goal:Dictionary=FurMahjongNightDirection.GOALS[id]
		var choice:=button("本街 · "+goal.name+"\n"+goal.text,func():_emit("spotlight",goal_id),Vector2(282,86),"selected" if n.direction.selected[actor]==id else "ivory");choice.add_theme_font_size_override("font_size",16);_goal_column.add_child(choice);action_buttons.append(choice)
	var reward:=Label.new();reward.text="亮灯：+2币 / +1灵感\n之后每组 +16筹码\n只认本街新亮组，暗胡不补灯";reward.add_theme_font_size_override("font_size",15);reward.add_theme_color_override("font_color",Color("f4dfb5"));_goal_column.add_child(reward)
	var title:=Label.new();title.text=["小柯","泡泡"][actor]+(" · 读牌后立约" if n.stage==0 else " · 揭牌前最后决定");title.add_theme_font_size_override("font_size",23);title.add_theme_color_override("font_color",Color("f7eedc"));_offer_column.add_child(title)
	var promised:int=n.get("promised_tiles",[-1,-1])[1-actor]
	if n.stage==0 and promised>=0 and promised in snapshot.hands[1-actor] and n.requests[actor]==int(promised/4):title.text+=" · 伙伴已带 "+ChapterMahjongTable.tile_name(promised)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);_offer_column.add_child(row)
	for id:String in Catalog.CONTRACTS:
		var contract:String=id
		var b:=button(Catalog.CONTRACTS[id].name,func():_emit("offer",[contract,n.tiers[actor]]),Vector2(245,52),"selected" if n.contracts[actor]==id else "ivory")
		b.tooltip_text=Catalog.CONTRACTS[id].text
		b.set_meta("invalid",n.stage>0 and n.contracts[actor]!=id);row.add_child(b);action_buttons.append(b)
	var condition:=Label.new();condition.text="成约条件："+Catalog.CONTRACTS[n.contracts[actor]].text;condition.add_theme_font_size_override("font_size",17);condition.add_theme_color_override("font_color",Color("e6d9b6"));_offer_column.add_child(condition)
	var wager:=HBoxContainer.new();wager.add_theme_constant_override("separation",8);_offer_column.add_child(wager)
	for i in 3:
		var tier:int=i
		var b:=button(["不押 · 保留金币","押2币 · 成约 ×1.3","押5币 · 成约 ×1.5"][i],func():_emit("offer",[n.contracts[actor],tier]),Vector2(245,52),"selected" if n.tiers[actor]==i else "ivory")
		b.set_meta("invalid",i<n.tiers[actor] or Catalog.STAKES[i]-n.paid[actor]>n.wallets[actor]);wager.add_child(b);action_buttons.append(b)
	var note:=Label.new();note.text="成功退本金；失败损失押金。成约后不能补押，两人独立钱包。";note.add_theme_font_size_override("font_size",15);note.add_theme_color_override("font_color",Color("e6d9b6"));_offer_column.add_child(note)
	var ready:=button("准备好了 · "+("公开前三张" if n.stage==0 else "翻开下一张"),func():_emit("ready",null),Vector2(748,49),"primary");_offer_column.add_child(ready);action_buttons.append(ready)

func _select(index:int,actor:int,revision:int)->void:
	if is_busy() or actor!=snapshot.actor or revision!=snapshot.revision or (use_ai and actor==1):return
	if snapshot.phase=="night_offer" and snapshot.night.stage==0:
		if index in opening_selection:opening_selection.erase(index)
		elif opening_selection.size()<3:opening_selection.append(index)
		_mark_opening_tiles();_render_actions();_render_offer();_locked=false;_lock();return
	if snapshot.phase!="discard":return
	_has_hover_preview=false;_combo.reset();table_view.highlight_score_tiles([])
	selected_index=-1 if selected_index==index else index;selected_river=-1;table_view.select_tile(selected_index);_render_actions();_locked=false;_lock()

func _suggest_opening()->void:
	if is_busy() or (use_ai and snapshot.actor==1):return
	var simulator=Rules.new();simulator._s=snapshot.duplicate(true)
	opening_selection=simulator.mulligan_suggestion();_mark_opening_tiles();_render_actions();_render_offer();_locked=false;_lock()
	_hint.text="已标出%d张无对子、无近邻的散牌；可手动调整，再点换掉。建议不查看牌墙。"%opening_selection.size() if not opening_selection.is_empty() else "没有明显散牌：当前手牌已有对子或相邻牌，可自行挑选或直接准备。"

func _mark_opening_tiles()->void:
	table_view.select_opening_tiles(opening_selection)
	var ids:Array=[]
	for index:int in opening_selection:ids.append(snapshot.hands[snapshot.actor][index])
	table_view.highlight_score_tiles(ids)
func _exchange(slot:int,actor:int,revision:int)->void:
	if is_busy() or actor!=snapshot.actor or revision!=snapshot.revision or (use_ai and actor==1):return
	if selected_index<0:
		selected_river=slot;_render_actions();_locked=false;_lock();_hint.text="已选河牌 "+ChapterMahjongTable.tile_name(snapshot.tea.tray[slot])+"；可在「同桌协作」花2茶气换签，或先选手牌再与它交换。";return
	_emit("exchange",Vector2i(selected_index,slot))

func _preview_exchange(slot:int)->void:
	if is_busy():return
	if slot<0:
		if _has_hover_preview:_hint.text=_hint_before_hover;_combo.reset();_restore_borrowed_focus();_has_hover_preview=false
		return
	if snapshot.phase!="discard" or selected_index<0 or (use_ai and snapshot.actor==1):return
	if not _has_hover_preview:_hint_before_hover=_hint.text
	_has_hover_preview=true
	var simulator=Rules.new();simulator._s=snapshot.duplicate(true)
	var preview:Dictionary=simulator.forecast_exchange(selected_index,slot)
	_combo.reset();table_view.highlight_score_tiles([])
	if not preview.ok:
		_hint.text="这次暂不能交换：茶气不足、已用完交换次数，或牌面相同。没有支付茶气。";return
	var names:String=ChapterMahjongTable.tile_name(preview.outgoing)+" → "+ChapterMahjongTable.tile_name(preview.incoming)
	var option:Dictionary=preview.best
	_hint.text="交换预览 · "+names+" · 花%d茶气 · "%preview.cost+("暂未组成可亮新面子，仍可为下一手铺牌。" if option.is_empty() else option.label.replace("\n"," · "))+("；亮组还需1灵感续奏" if option.get("needs_continuation",false) else "")+"。点击才支付。"
	if option.has("preview"):
		var score:Dictionary=option.preview
		_combo.present({"source":"换牌后可亮组 · +%d分"%score.total,"after_chips":score.chips,"after_factor":score.factor,"after_repeats":score.repeats})
		table_view.highlight_score_tiles(option.tiles)
	elif option.get("kind","")=="tsumo":
		var future_hand:Array=snapshot.hands[snapshot.actor].duplicate();future_hand.erase(preview.outgoing);future_hand.append(preview.incoming)
		_combo.gain(int(option.preview_total),"hu");_combo._source.text="换牌后可胡 · 全桌预计";table_view.highlight_score_tiles(future_hand)

func _animate_score()->void:
	var n:Dictionary=snapshot.night;var total:int=n.scores[0]+n.scores[1]
	_progress.max_value=n.target
	if n.events.size()<=_last_event:
		_shown_contributions=n.scores.duplicate();_contributions.text="小柯 %s  ·  泡泡 %s"%[_number(_shown_contributions[0]),_number(_shown_contributions[1])]
		_score_number(float(total),n.target);return
	if table_view.is_animating():_score_pending=true;return
	_score_pending=false
	var recent:Array=n.events.slice(_last_event);_last_event=n.events.size()
	_score_queue.clear();_score_lines.clear();_beat_index=0;_skipping_score=false;_ledger.text=""
	if is_instance_valid(_score_motion):_score_motion.kill()
	var subtotal:float=_shown_score
	for event:Dictionary in recent:
		for row:Dictionary in event.ledger:
			for inner:Dictionary in row.get("detail",[]):
				var detail:Dictionary=inner.duplicate(true);detail.preview_only=true
				_score_queue.append({"type":"row","row":detail,"actor":event.actor,"pause":_step_pause(inner,.065)})
			_score_queue.append({"type":"row","row":row.duplicate(true),"actor":event.actor,"pause":_step_pause(row,.065)})
		_score_queue.append({"type":"gain","amount":event.total,"actor":event.actor,"kind":event.kind,"tiles":event.tiles.duplicate(),"before":subtotal,"after":subtotal+event.total,"pause":.98 if event.kind=="hu" else .46})
		if event.has("two_chimes"):_score_queue.append({"type":"two_chimes","actor":event.actor,"pair":event.two_chimes.duplicate(true),"pause":.80})
		subtotal+=event.total
	_score_queue.append({"type":"end","pause":0.0});_score_due=Time.get_ticks_usec()

func _advance_score()->void:
	# One visible/audio beat per rendered frame, with a fresh real-time deadline.
	# A stalled render never dumps several overdue sounds into the same frame.
	if _score_queue.is_empty():return
	var entry:Dictionary=_score_queue.pop_front();var pace:float=1.6 if fast_presentation else 1.0
	_score_due=Time.get_ticks_usec()+roundi(float(entry.pause)*1000000.0/pace)
	match entry.type:
		"row":_score_step(entry.row,entry.actor)
		"gain":
			_event_gain(entry.amount,entry.actor,entry.kind,entry.tiles)
			if is_instance_valid(_score_motion):_score_motion.kill()
			_score_motion=create_tween();_score_motion.set_speed_scale(pace)
			_score_motion.tween_method(_score_number.bind(int(snapshot.night.target),int(entry.actor),float(entry.before),float(_shown_contributions[entry.actor])),float(entry.before),float(entry.after),.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		"two_chimes":
			_combo.duo(entry.pair,["小柯","泡泡"][entry.actor]);table_view.celebrate_score(entry.actor,.45)
			_score_lines.append("本手两响 %d + %d = %d（已分别入账）"%[entry.pair.first,entry.pair.second,entry.pair.total]);_ledger.text="\n".join(_score_lines)
		"end":_gain.hide();_combo.reset();table_view.highlight_score_tiles([]);table_view.reset_score_echo();table_view.reset_score_stamp();_skipping_score=false

func _step_pause(row:Dictionary,fallback:float)->float:
	if row.op=="heat":return .43
	if row.op=="repeat":return .34
	if row.op in ["lamp","refrain_gain"]:return .55
	if row.op in ["support","refund"]:return .30
	if row.source.begins_with("合法胡牌"):return .26
	for id:String in Catalog.ITEMS:
		if Catalog.name_of(id)==row.source:return maxf(.17,fallback)
	if row.op in ["repeat","multiply","chip_mul"]:return maxf(.115,fallback)
	return minf(.065,fallback)

func _score_step(row:Dictionary,actor:int)->void:
	var symbol:String={"add":"+","multiply":"×","chip_mul":"筹码×","repeat":"再计","coin":"金币 +","base":"筹码 ","paid":"已记 ","locked":"护印 "}.get(row.op,"")
	var phrase:String=row.source+"  "+symbol+str(snappedf(float(row.value),.01))
	if row.op=="lamp":phrase=row.source+" · +2币 / +1灵感 / 后续+16筹码"
	if row.op=="refrain_gain":phrase="双灯返场 · 双方下个新亮组各再计一次"
	if row.op=="heat":phrase="茶炉重算已兑现 · 炉温归零" if row.get("spent",false) else ("茶炉蓄满 · 下一组顺/刻再计一次" if int(row.value)==2 else "茶炉积火 · 炉温1/2，可花灵感添火")
	_score_lines.append(phrase);_ledger.text="\n".join(_score_lines)
	_gain.hide();_combo.present(row);table_view.highlight_score_tiles(row.get("tiles",[]))
	if row.op=="heat" and not row.get("preview_only",false) and is_instance_valid(table_view.night_relics):table_view.night_relics.commit_heat(actor,int(row.value),not _skipping_score);_render_build()
	if is_instance_valid(table_view.night_stagecraft):
		if row.op=="lamp":table_view.night_stagecraft.commit_reward(actor)
		elif row.op=="support":table_view.night_stagecraft.commit_reward(1-actor)
	if not _skipping_score:
		if row.op=="base":_beat_index=0
		if row.op=="repeat":table_view.echo_score_tiles(row.get("tiles",[]))
		if row.source=="赤封" and row.op=="repeat":table_view.pulse_score_stamp(row.get("tiles",[]))
		if is_instance_valid(table_view.night_relics):
			table_view.night_relics.pulse(row.source,actor)
			var activation:Dictionary=table_view.night_relics.activation(row.source,actor)
			if not activation.is_empty() and is_instance_valid(table_view.night_feedback):
				var center:=Vector3.ZERO;var count:int=0
				for id:int in row.get("tiles",[]):
					if table_view.transforms.has(id):center+=table_view.transforms[id].origin;count+=1
				if count>0:table_view.night_feedback.score_link.activate(center/float(count)+Vector3.UP*.25,activation.point,table_view.camera_3d,activation.route,1.6 if fast_presentation else 1.0)
		if is_instance_valid(table_view.night_fixtures):table_view.night_fixtures.pulse(row.source)
		if row.op=="lamp" and is_instance_valid(table_view.night_stagecraft):table_view.night_stagecraft.celebrate(actor)
		elif row.op=="support" and is_instance_valid(table_view.night_stagecraft):table_view.night_stagecraft.celebrate(1-actor)
		var sound_op:String=row.op
		if row.op=="heat" and row.get("spent",false):sound_op="heat_spent"
		if row.op in ["add","multiply","chip_mul","repeat"]:
			for id:String in Catalog.ITEMS:
				if row.source==Catalog.name_of(id):sound_op=Catalog.ITEMS[id].route+":"+row.op;break
		score_beat.emit(sound_op,_beat_index);_beat_index+=1

func _event_gain(amount:int,actor:int,kind:String,tiles:Array=[])->void:
	_gain.hide();_combo.gain(amount,kind,["小柯","泡泡"][actor])
	if not _skipping_score and is_instance_valid(table_view.night_feedback):
		var origin:=Vector3(0,.65,3.6 if actor==0 else -3.6)
		var sum:=Vector3.ZERO;var count:int=0
		for id:int in tiles:
			if table_view.transforms.has(id):sum+=table_view.transforms[id].origin;count+=1
		if count>0:origin=sum/float(count)+Vector3(0,.35,0)
		table_view.night_feedback.burst(amount,int(snapshot.night.target),roundi(_shown_score),origin,1.6 if fast_presentation else 1.0)
		if kind=="hu":table_view.celebrate_score(actor)
		elif amount>=maxf(120.0,float(snapshot.night.target)*.20):table_view.celebrate_score(actor,clampf(float(amount)/maxi(1,snapshot.night.target),.35,.75))
	_score_lines.append("[color=#e9c977]%s 入账 +%s[/color]"%[["小柯","泡泡"][actor],_number(amount)]);_ledger.text="\n".join(_score_lines)
	if not _skipping_score:
		var crossed:bool=_shown_score<float(snapshot.night.target) and _shown_score+amount>=float(snapshot.night.target)
		score_beat.emit(("overkill" if amount>=int(snapshot.night.target)*2 else "hu") if kind=="hu" else ("breakthrough" if crossed else "total"),_beat_index)
func _score_number(value:float,target:int,actor:int=-1,total_before:float=0,actor_before:float=0)->void:
	if actor>=0:_shown_contributions[actor]=roundi(actor_before+value-total_before)
	_contributions.text="小柯 %s  ·  泡泡 %s"%[_number(_shown_contributions[0]),_number(_shown_contributions[1])]
	_shown_score=value;_score.text=("实得 %s 分"%_number(roundi(value))) if snapshot.night.has("lesson") else "%s / %s"%[_number(roundi(value)),_number(target)];_progress.value=value
func _number(value:int)->String:
	var raw:String=str(value);var result:String=""
	for i in raw.length():result+=raw[i];var left:int=raw.length()-i-1;if left>0 and left%3==0:result+="," 
	return result
func skip_score()->void:
	_skipping_score=true;table_view.mute_presentation=true
	if _score_pending:
		if is_instance_valid(table_view._motion):table_view._motion.custom_step(10.0)
		_score_pending=false;_animate_score()
	_skipping_score=true
	if is_instance_valid(_score_motion):_score_motion.kill()
	for entry:Dictionary in _score_queue:
		if entry.type=="row":_score_step(entry.row,entry.actor)
		elif entry.type=="gain":_event_gain(entry.amount,entry.actor,entry.kind,entry.tiles)
	_score_queue.clear();_shown_contributions=snapshot.night.scores.duplicate();_score_number(snapshot.night.scores[0]+snapshot.night.scores[1],snapshot.night.target)
	if is_instance_valid(table_view.night_relics):table_view.night_relics.reset_pulses()
	if is_instance_valid(table_view.night_feedback):table_view.night_feedback.clear()
	if is_instance_valid(table_view.night_stagecraft):table_view.night_stagecraft.reset()
	if is_instance_valid(table_view.night_tea_service):table_view.night_tea_service.settle()
	if is_instance_valid(table_view.night_encore_stage):table_view.night_encore_stage.settle()
	table_view.reset_score_pose();table_view.reset_score_echo();table_view.reset_score_stamp();table_view.highlight_score_tiles([]);_gain.hide();_combo.reset();_skipping_score=false
	table_view.mute_presentation=false;score_skipped.emit()

func _toggle_pace()->void:
	fast_presentation=not fast_presentation;_pace.text="节奏 1.6×" if fast_presentation else "节奏 1×"
	table_view.presentation_speed=1.6 if fast_presentation else 1.0
	if is_instance_valid(table_view._motion):table_view._motion.set_speed_scale(table_view.presentation_speed)
	if is_instance_valid(_score_motion):_score_motion.set_speed_scale(table_view.presentation_speed)


func chain_instruction(option:Dictionary)->String:
	if not option.has("chain"):return option.get("detail","")
	var plan:Dictionary=option.chain.plan
	var names:Callable=func(ids:Array)->String:
		var words:Array[String]=[]
		for id:int in ids:words.append(ChapterMahjongTable.tile_name(id))
		return "/".join(words)
	var middle:String="花1灵感续奏"
	var second:Array=plan.get("tiles",[])
	if option.chain.method=="reshape":
		middle="1灵感：放入"+names.call(plan.give)+"，借回"+names.call(plan.take)
		second=plan.best.get("tiles",[])
	return "路线预览 · 先亮"+names.call(option.tiles)+" → "+middle+" → 再亮"+names.call(second)+"；%d+%d=%d分，逐步点击执行。"%[option.chain.first,option.chain.second,option.chain.total]

func _ranked_choices()->Array:
	var ranked:Array=[];var d:Dictionary=snapshot.night.direction;var actor:int=snapshot.actor
	for index in choices.size():
		var option:Dictionary=choices[index];var value:float=0
		if option.kind in ["ron","tsumo"]:value=1000000000
		elif option.has("preview"):
			value=maxf(option.preview.total,option.get("chain",{}).get("total",0))
			if can_light(option):value+=1000000
		if snapshot.night.has("lesson") and snapshot.night.lesson.get("guided",true) and snapshot.melds[actor].is_empty() and option.get("tiles",[])==[0,4,8]:value+=2000000
		ranked.append({"index":index,"value":value})
	ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.value>b.value or (a.value==b.value and a.index<b.index))
	return ranked.map(func(entry:Dictionary)->int:return entry.index)

func can_light(option:Dictionary)->bool:
	var d:Dictionary=snapshot.night.direction;var actor:int=snapshot.actor
	if d.done[actor] or option.kind not in ["self_chi","self_pon","chi","pon","kong","closed_kong"] or not option.has("preview"):return false
	var kind:String="kong" if option.kind=="closed_kong" else option.kind.trim_prefix("self_")
	return FurMahjongNightDirection.matches(d.selected[actor],kind,option.preview.tiles,option.preview.get("replay_context",{}),d.river_taken[actor])
