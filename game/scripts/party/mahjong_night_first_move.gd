class_name FurMahjongNightFirstMove
extends RefCounted
## Deliberate, read-only help. The player still confirms a swap and plays a group.
static func advice(rules:RefCounted)->Dictionary:
	var state:Dictionary=rules.state()
	if state.phase!="discard":return {}
	for plan:Dictionary in rules.river_opportunities():
		if not plan.choice.get("needs_continuation",false):return {"kind":"river","plan":plan}
	var actor:int=state.actor;var best:Dictionary={};var weight:int=100000
	for i in state.hands[actor].size():
		var clue:Dictionary=rules.hand_clue(i)
		# Protect pairs and public partner requests before considering nearby tiles.
		var value:int=(clue.same-1)*20+clue.near.size()*3+(50 if clue.partner_wants else 0)
		if value<weight:weight=value;best={"kind":"discard","index":i,"tile":clue.tile,"clue":clue,"isolated":value==0}
	return best

static func show_help(s:Node,actor:int,revision:int)->void:
	var state:Dictionary=s.rules.state()
	if state.actor!=actor or state.revision!=revision or state.phase!="discard":return
	var result:Dictionary=advice(s.rules)
	if result.is_empty():return
	s.mode="first_move";s.presenter._action_row.hide()
	s.presenter._hint.text="先看一种具体走法。确认前不花茶气、不出牌；也可返回自己决定。"
	if is_instance_valid(s.modal):s.remove_child(s.modal);s.modal.queue_free()
	s.modal=Panel.new();s.modal.position=Vector2(1251,115);s.modal.size=Vector2(333,590);s.modal.theme=s.Palette.create();s.add_child(s.modal)
	s.modal.add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"))
	var column:=VBoxContainer.new();column.position=Vector2(15,15);column.size=Vector2(303,560);column.add_theme_constant_override("separation",8);s.modal.add_child(column)
	s._text("试试这一手",28,column)
	if result.kind=="river":
		var p:Dictionary=result.plan;var index:int=p.index;var slot:int=p.slot
		s._text("① 拿河牌的 "+ChapterMahjongTable.tile_name(p.incoming)+"\n换出手里的 "+ChapterMahjongTable.tile_name(p.outgoing),21,column)
		s._text("花 %d 茶气 · 目前共有 %d"%[p.cost,state.tea.charge],18,column)
		s._text("② 换好后，按胡牌收下这手" if p.choice.kind=="tsumo" else "② 换好后，自己亮出\n"+s._tile_list(p.choice.get("tiles",[])),21,column)
		s._text(("可胡 · 全桌预计 %d分" if p.choice.kind=="tsumo" else "这一组预计 +%d分")%p.points,23,column)
		var tradeoff:String="会拆开同牌材料" if p.clue.same>=2 else ("会拆开一张邻牌" if not p.clue.near.is_empty() else "换出一张当前散牌")
		if p.clue.partner_wants:tradeoff="换出牌正好是伙伴要的"
		var explanation:Label=s._text("换牌本身不得分。\n"+tradeoff+"，由你决定。",16,column);explanation.tooltip_text=p.clue.text
		s.presenter.table_view.highlight_reshape([p.outgoing],[p.incoming])
		column.add_child(s._button("确认换牌 · 花%d茶气"%p.cost,func():
			s._close_reshape_picker();s._command("exchange",Vector2i(index,slot),actor,revision),Vector2(303,62),"primary"))
	else:
		var index:int=result.index
		var reason:String="暂时没有同牌或邻张相连" if result.isolated else "它也有用，但手里别的组合联系更多"
		s._text("暂时没有一换就能亮的组",21,column)
		if state.tea.charge<s.rules.Tea.cost(state,actor):s._text("当前茶气不足，先保留。",17,column)
		s._text("可以考虑打出\n"+ChapterMahjongTable.tile_name(result.tile),25,column)
		s._text(reason+"。\n"+result.clue.text,18,column)
		s._text("打出后结束这一回合，等下一摸。\n建议只看自己手牌与公开牌，不保证下一张。",17,column)
		s.presenter.table_view.highlight_score_tiles([result.tile])
		column.add_child(s._button("先选中这张 · 还不打出",func():
			s._close_reshape_picker();s.presenter._select(index,actor,revision),Vector2(303,64),"primary"))
	column.add_child(s._button("看看所有河牌换法",func():s._close_reshape_picker();s._show_river_picker(actor,revision),Vector2(303,48)))
	column.add_child(s._button("我自己来 · 返回",s._close_reshape_picker,Vector2(303,48)))
