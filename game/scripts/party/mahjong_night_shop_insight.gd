class_name FurMahjongNightShopInsight
extends RefCounted
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
const PAIRS={
	"bamboo":{"windbell":"先用小顺子养风铃，再把算盘加出的筹码一起放大。"},
	"dew":{"windbell":"连续做顺子时保留茶气：青盏加筹码，风铃再放大；换牌会少一部分加成。"},
	"silk":{"windbell":"先亮不同花色的小顺，凑齐万筒索；后面的顺子同时吃到锦囊和风铃倍率。"},
	"windbell":{"bamboo":"先亮小顺，再亮大顺；算盘加筹码，风铃按已经亮过的顺子放大。","silk":"先凑齐万筒索，再用后续顺子叠加风铃与锦囊倍率。"},
	"anvil":{"coal":"刻子加筹码并蓄炉温；满炉后把更厚的一组再响一次。"},
	"ember":{"coal":"把对子留到第四张开杠：茶炉放大这一杠，火签让同一笔再响一次。"},
	"crucible":{"coal":"先开杠蓄满茶炉并留下余温，再让后续顺子或刻子吃加成。"},
	"coal":{"anvil":"镇纸抬高刻杠筹码；两次积火后的下一组非杠再响一次。","ember":"开杠时同时得到茶炉倍率和火签再响，随后茶炉蓄满。"},
	"redthread":{"teacup":"用伙伴换出的实体牌成组：双杯加筹码返茶，红绳再放大这组。"},
	"teacup":{"redthread":"先和伙伴交换缺张；接力成组同时拿双杯筹码、返茶与红绳倍率。"}
}

static func describe(data:Dictionary,id:String,actor:int,slot:int)->Dictionary:
	var item:Dictionary=Catalog.ITEMS[id]
	var original:Array=data.build.shared if item.shared else data.build.items[actor]
	var capacity:int=1 if item.shared else 2;var removed:String=""
	var retained:Array=data.build.items[actor].duplicate()
	if original.size()>=capacity and slot>=0 and slot<original.size():
		removed=original[slot]
		if not item.shared:retained.remove_at(slot)
	var badge:String="另一种打法";var instruction:String=Catalog.ITEMS[id].text
	if item.shared:badge="全队共享 · 条件满足才触发"
	else:
		for owned:String in retained:
			if PAIRS.get(id,{}).has(owned):badge="搭配"+Catalog.name_of(owned);instruction=PAIRS[id][owned];break
			if Catalog.ITEMS[owned].route==item.route:badge="同路线补强"
	var names:Array[String]=[]
	for owned:String in retained:names.append(Catalog.name_of(owned))
	return {"badge":badge,"instruction":instruction,"removed":removed,"kept":"、".join(names),"price":item.price,"remaining":data.coins[actor]-item.price,"shared":item.shared}

static func show_item(s:Node,id:String,actor:int,slot:int)->void:
	if s.journey.data.phase!="shop" or actor!=s._shop_actor:return
	var info:Dictionary=describe(s.journey.data,id,actor,slot)
	var preview:Dictionary=s.journey.preview_purchase(id,actor,slot)
	s.mode="shop_detail"
	var column:VBoxContainer=s._new_modal(Rect2(285,137,1030,626))
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);column.add_child(row)
	var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.texture=load("res://assets/mahjong_night/"+id+"_icon.png");icon.custom_minimum_size=Vector2(104,104);icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
	var heading:=VBoxContainer.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(heading)
	s._text(Catalog.name_of(id),35,heading);s._text(info.badge,22,heading)
	s._text("这一件怎样用",22,column)
	s._text(info.instruction,23,column)
	var retention:String="你保留："+info.kept if not info.kept.is_empty() else "将从这一件开始新打法"
	s._text(retention,18,column)
	var replacement:String="装入空的共享槽" if info.shared else "装入空槽，已有挂件保留"
	if not info.removed.is_empty():replacement="替换 "+Catalog.name_of(info.removed)+" · 旧效果会消失，不退金币"
	s._text(replacement,20,column).add_theme_color_override("font_color",Color("f2cb85"))
	s._text(preview.text,18,column)
	s._text("价格 %d币 · 你的钱包 %d币 · 购买后 %d币"%[info.price,s.journey.data.coins[actor],info.remaining],20,column)
	var buy:Button=s._button("确认购买 · "+("替换"+Catalog.name_of(info.removed) if not info.removed.is_empty() else "装入"+Catalog.name_of(id)),func():s._buy_relic(id,actor,slot),Vector2(970,65),"primary");buy.disabled=not preview.ok;column.add_child(buy)
	column.add_child(s._button("再看看 · 不购买",s._shop,Vector2(970,50)))
