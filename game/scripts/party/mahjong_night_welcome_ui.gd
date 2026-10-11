class_name FurMahjongNightWelcomeUI
extends RefCounted
const DETAILS={
	"bamboo":"小关里的每组顺子：多24筹码，再让筹码×1.3。",
	"windbell":"每亮一组顺子，下一组的倍率更高。小的先出，大的压轴。",
	"coal":"两组刻子把炉子蓄满；下组顺子或刻子再响一次。杠会更强，并直接蓄满。",
	"silk":"先亮过两种花色，再用第三种花色：这一组翻倍。",
	"anvil":"每组刻子和杠，都多60筹码。",
	"ember":"四张一样的牌组成杠时，再多响一次。"
}

static func render(p:Variant)->void:
	var n:Dictionary=p.snapshot.night;var w:Dictionary=n.welcome
	var teaching:bool=w.kind=="tutorial"
	p._heading.text=("第一组 · "+["认识顺子","挂件有用啦","越连越响"][int(w.number)-1]) if teaching else "午后小桌 · 第 %d / 3 关"%w.number
	p._subtitle.text="预设教学 · 亲手亮牌，逐步上手" if teaching else ["暖手 · 选两组，过关拿核心","核心上桌 · 熟悉的牌，开始更响","压轴 · 两件帮手一起发力"][int(w.number)-1]+" · 预设小关"
	p._wallets.text="没有倒计时\n可以随时重试"
	p._turn.text="先亮一组就学会了" if teaching and w.number<3 else "亮出的顺序，由你决定"
	p._contract.text="已亮 %d / %d 组"%[w.formed,w.cap]
	p._progress.hide();p._contributions.hide();p._goal_column.hide();p._offer_panel.hide();p._reshape_button.hide()
	p._build_heading.text="这一手的帮手"
	var lines:Array[String]=[]
	for id:String in n.build.items[0]:
		lines.append("[color=#f3d38e]"+FurMahjongNightCatalog.name_of(id)+"[/color]\n"+DETAILS[id])
	p._build_text.text="先用三张牌拿到第一笔分数。" if lines.is_empty() else "\n\n".join(lines)
	if "windbell" in n.build.items[0]:
		p._requests.text="已亮 %d 组顺子\n下一组 ×%.2f\n把更大的顺子留到后面。"%[n.contexts[0].chi_count,pow(1.35,mini(4,n.contexts[0].chi_count))]
		if "silk" in n.build.items[0]:
			var colors:Array[String]=[];var missing:Array[String]=[]
			for suit in 3:
				var word:String=["万","筒","索"][suit]
				colors.append(word+(" ✓" if suit in n.contexts[0].suits else " —"))
				if suit not in n.contexts[0].suits:missing.append(word)
			p._requests.text="三色锦囊 · "+"  ".join(colors)+"\n"+("还差"+"、".join(missing)+"；凑齐那组翻倍。" if not missing.is_empty() else "三色齐了，这次翻倍已兑现。")+"\n风铃下一组 ×%.2f"%pow(1.35,mini(4,n.contexts[0].chi_count))
	elif "coal" in n.build.items[0]:
		p._requests.text="茶炉 %d / 2 格\n"%n.contexts[0].heat+("已蓄满！下组刻子再响一次。" if n.contexts[0].heat>=2 else "每组刻子蓄一格；满后再响。")
	else:p._requests.text="相同花色、连续三个数字，就是顺子。\n点手牌或下方组合，亲手把它亮出来。"
	if w.complete:p._requests.text="这一手已经完成。\n刚才的每一响都已入账。"
	elif w.formed==0 and not n.build.items[0].is_empty():
		p._turn.text="帮手已带上桌 · "+FurMahjongNightCatalog.name_of(n.build.items[0].back())

static func actions(p:Variant)->void:
	p._clear(p._action_row);p.action_buttons.clear();p._reshape_button.hide()
	var w:Dictionary=p.snapshot.night.welcome
	p._hint.text="点一张手牌，再点下方整组亮出。悬停会标出对应的三张牌。"
	if w.kind=="tutorial" and w.number==1:p._hint.text="找发光的一、二、三万：相同花色的连续三张。点「亮出顺子」，看它们真正落桌。"
	if w.complete:p._hint.text="这一关完成了！看完得分，就能带上新的成长。";return
	var shown:int=0
	for index in p.choices.size():
		var option:Dictionary=p.choices[index];var selected:int=index
		if p.selected_index>=0 and p.snapshot.hands[0][p.selected_index] not in option.tiles:continue
		var kind:String="杠" if option.kind=="closed_kong" else ("顺子" if option.kind=="self_chi" else "刻子")
		var names:Array[String]=[]
		for tile:int in option.tiles:names.append(ChapterMahjongTable.tile_name(tile))
		var cause:String=choice_cause(p.snapshot,option)
		var b:Button=p.button("亮出"+kind+" · +%d分\n"%option.preview.total+" / ".join(names)+( "\n"+cause if not cause.is_empty() else ""),func():p._emit("action",selected),Vector2(400,88),"primary")
		if not cause.is_empty():b.add_theme_font_size_override("font_size",16)
		b.set_meta("welcome_choice",index);p._action_row.add_child(b);p.action_buttons.append(b);shown+=1
		b.mouse_entered.connect(func():
			if p.is_busy():return
			p.table_view.highlight_score_tiles(option.tiles)
			var base:int=int(option.preview.ledger[0].value)
			p._combo.gain(option.preview.total,option.preview.kind,"预计")
			p._combo._source.text="出手前预览 · 还没有得分"
			p._combo._formula.add_theme_font_size_override("font_size",29)
			p._combo._formula.text="牌本身 %d + 帮手 %d = %d 分"%[base,maxi(0,option.preview.total-base),option.preview.total])
		b.mouse_exited.connect(func():
			if p.is_busy():return
			p._combo.reset();p.table_view.highlight_score_tiles([]))
	if shown==0:
		p._hint.text="这张不是本关的完整组合；点「看看能亮的组」，再选一组试试。"
	if p.selected_index>=0:
		var clear:Button=p.button("看看能亮的组",func():p.selected_index=-1;p.table_view.select_tile(-1);actions(p),Vector2(228,88))
		p._action_row.add_child(clear);p.action_buttons.append(clear)
	if p.selected_index<0 and w.kind=="tutorial" and w.number==1 and not p.choices.is_empty():p.table_view.highlight_score_tiles(p.choices[0].tiles)

static func choice_cause(s:Dictionary,option:Dictionary)->String:
	var n:Dictionary=s.night;var items:Array=n.build.items[0];var preview:Dictionary=option.preview
	if "coal" in items:
		if option.kind=="closed_kong":return "茶炉翻倍"+(" · 火签再响" if "ember" in items else (" · 镇纸加分" if "anvil" in items else ""))+" · 直接蓄满"
		if preview.repeats>1:return "炉子蓄满了 · 这一组响两次"
		return "亮完蓄满 · 下一组再响" if n.contexts[0].heat==1 else "亮完蓄一格火"
	var names:Array[String]=[]
	for row:Dictionary in preview.ledger:
		if row.source==FurMahjongNightCatalog.name_of("windbell"):names.append("风铃放大")
		elif row.source==FurMahjongNightCatalog.name_of("bamboo") and row.op=="add":names.append("算盘加分")
		elif row.source==FurMahjongNightCatalog.name_of("silk"):names.append("三色凑齐 · 再翻倍")
	if names.is_empty() and "windbell" in items:return "先亮一组 · 给风铃起势"
	return " · ".join(names)
