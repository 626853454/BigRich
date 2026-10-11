class_name FurMahjongNightReceipt
extends RefCounted
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
static func summary(state:Dictionary)->String:
	var n:Dictionary=state.night
	if n.events.is_empty():return ""
	var event:Dictionary=n.events.back();var actor:int=event.actor
	var who:String=["小柯","泡泡"][actor];var first:String="%s 实得 +%d"%[who,event.total]
	if event.has("two_chimes"):first="%s 本手 %d＋%d＝%d"%[who,event.two_chimes.first,event.two_chimes.second,event.two_chimes.total]
	elif FurMahjongNightWelcomePayoff.eligible(event):first+=" · 响%d次"%event.repeats
	var sources:Array[String]=[]
	for row:Dictionary in event.ledger:
		for id:String in Catalog.ITEMS:
			if row.source==Catalog.name_of(id) and row.op in ["add","multiply","chip_mul","repeat"] and row.source not in sources:sources.append(row.source)
	var reason:String=" → ".join(sources)
	if reason.is_empty():reason="已扣除之前入账" if event.ledger.any(func(row:Dictionary)->bool:return row.op=="paid") else "实际牌型入账"
	var next:String=""
	var context:Dictionary=n.contexts[actor];var items:Array=n.build.items[actor]
	if "coal" in items and int(context.heat)>=2:next=who+"炉温满 · 下组顺/刻再响"
	elif "windbell" in items:next=who+("风铃已满层 · 继续亮顺子" if int(context.chi_count)>=4 else "已亮%d顺 · 继续连顺养风铃"%int(context.chi_count))
	elif "coal" in items:next=who+"炉温 %d/2 · 留给下一次爆发"%int(context.heat)
	if not next.is_empty():reason=next
	return "[color=#f4d589]"+first+"[/color]\n"+reason+"\n[url=receipt]查看触发来源与完整账单 ›[/url]"

static func show_detail(s:Node)->void:
	if s.presenter.is_busy() or s.rules._s.night.events.is_empty():return
	s._receipt_return_mode=s.mode;s.mode="score_receipt"
	var column:VBoxContainer=s._new_modal(Rect2(335,124,930,652))
	s._text("刚才这一手 · 分数已经入账",29,column)
	var details:=RichTextLabel.new();details.bbcode_enabled=true;details.custom_minimum_size=Vector2(878,455);details.size_flags_vertical=Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("normal_font_size",21);details.add_theme_font_override("normal_font",s.Palette.font(false));details.add_theme_color_override("default_color",Color("f7eedc"));column.add_child(details)
	details.text=summary(s.rules._s).split("\n[url=")[0]+"\n\n"+"\n".join(s.presenter._score_lines)
	s._text("这里只回看已发生的计算；不会再次得分。空格可在下次演出时跳过。",17,column)
	column.add_child(s._button("看懂了 · 回到牌桌",s._close_score_receipt,Vector2(878,58),"primary"))
