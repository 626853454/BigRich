class_name FurMahjongNightOpeningUI
extends RefCounted
## Disclosure only: opening/closing a drawer never sends a rules command.
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
const Tea=preload("res://scripts/party/mahjong_teahouse_rules.gd")

static func toggle(p:Control,section:String)->void:
	if p.is_busy() or (p.use_ai and p.snapshot.actor==1):return
	p.opening_drawer="" if p.opening_drawer==section else section
	p._render_actions();p._render_offer();p._lock()

static func text_row(parent:Node,text:String,size:int=17)->Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",Color("f7eedc"));parent.add_child(l);return l

static func add_button(p:Control,parent:Node,text:String,callback:Callable,size:Vector2,variant:String="ivory")->Button:
	var b:Button=p.button(text,callback,size,variant);parent.add_child(b);p.action_buttons.append(b);return b

static func actions(p:Control)->void:
	var n:Dictionary=p.snapshot.night;var actor:int=p.snapshot.actor
	p._hint.text="先看看手牌，准备好就开牌。换牌、茶灵和押约都可按需调整。" if n.stage==0 else "看清已翻开的河牌再决定；可以保留当前押约，直接揭下一张。"
	if n.stage==0:
		add_button(p,p._action_row,"收起换牌" if p.opening_drawer=="hand" else ("换牌已用 · 看手牌" if n.mulligan_used[actor] else "调整起手 · 可选"),func():toggle(p,"hand"),Vector2(222,85))
		if p.opening_drawer=="hand":
			var mark:=add_button(p,p._action_row,"帮我标出散牌\n保护对子、邻张和传家牌",p._suggest_opening,Vector2(267,85));mark.set_meta("invalid",n.mulligan_used[actor])
			var swap:=add_button(p,p._action_row,"换掉选中 %d 张\n本桌一次，不获得茶气"%p.opening_selection.size(),func():p._emit("mulligan",p.opening_selection.duplicate()),Vector2(280,85),"primary")
			swap.set_meta("invalid",p.opening_selection.is_empty() or n.mulligan_used[actor])
			p._hint.text="点选最多3张手牌再确认换掉；也可收起，保留这手牌。" if not n.mulligan_used[actor] else "本桌换牌已用过；看看手中的对子与邻张，准备好就开牌。"
		add_button(p,p._action_row,"收起茶灵" if p.opening_drawer=="tea" else "茶灵 · "+Tea.RECIPES[p.snapshot.tea.recipe].name,func():toggle(p,"tea"),Vector2(225,85))
		if p.opening_drawer=="tea":
			for id:String in Tea.RECIPES:
				var tea_id:String=id
				add_button(p,p._action_row,Tea.RECIPES[id].name+"\n"+Tea.RECIPES[id].short,func():p._emit("tea",tea_id),Vector2(230,85),"selected" if p.snapshot.tea.recipe==id else "ivory")
	add_button(p,p._action_row,"收起押约" if p.opening_drawer=="stake" else "调整押约 · 可选",func():toggle(p,"stake"),Vector2(225,85))

static func offer(p:Control)->void:
	p._offer_panel.visible=p.snapshot.phase=="night_offer";p._clear(p._offer_column);p._clear(p._goal_column)
	p._ledger.visible=not p._offer_panel.visible;p._ledger_heading.visible=not p._offer_panel.visible
	p._goal_column.visible=p._offer_panel.visible;p._build_text.visible=not p._offer_panel.visible;p._build_heading.visible=not p._offer_panel.visible;p._requests.visible=not p._offer_panel.visible
	if not p._offer_panel.visible:return
	var n:Dictionary=p.snapshot.night;var actor:int=p.snapshot.actor;var expanded:bool=p.opening_drawer=="stake"
	p._offer_panel.size.y=299 if expanded else 178
	p._offer_column.size.y=270 if expanded else 150
	var goal:Dictionary=FurMahjongNightDirection.GOALS[n.direction.selected[actor]]
	text_row(p._goal_column,"这一街 · "+goal.name,20)
	var detail:=text_row(p._goal_column,goal.text,16);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_button(p,p._goal_column,"收起追灯目标" if p.opening_drawer=="goal" else "换个追灯目标 · 可选",func():toggle(p,"goal"),Vector2(282,48))
	if p.opening_drawer=="goal":
		for id:String in n.direction.offers[actor]:
			var goal_id:String=id;var item:Dictionary=FurMahjongNightDirection.GOALS[id]
			var b:=add_button(p,p._goal_column,item.name+"\n"+item.text,func():p._emit("spotlight",goal_id),Vector2(282,80),"selected" if n.direction.selected[actor]==id else "ivory");b.add_theme_font_size_override("font_size",16)
	text_row(p._goal_column,"亮灯 +2币 / +1灵感\n之后每组 +16筹码\n只算本街新亮组，暗胡不补灯",15)
	var title:=text_row(p._offer_column,["小柯","泡泡"][actor]+(" · 看好手牌就开局" if n.stage==0 else " · 下一张河牌仍盖着"),23)
	var promised:int=n.get("promised_tiles",[-1,-1])[1-actor]
	if n.stage==0 and promised>=0 and promised in p.snapshot.hands[1-actor] and n.requests[actor]==int(promised/4):title.text+=" · 伙伴带了 "+ChapterMahjongTable.tile_name(promised)
	if expanded:
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);p._offer_column.add_child(row)
		for id:String in Catalog.CONTRACTS:
			var contract:String=id
			var b:=add_button(p,row,Catalog.CONTRACTS[id].name,func():p._emit("offer",[contract,n.tiers[actor]]),Vector2(245,52),"selected" if n.contracts[actor]==id else "ivory")
			b.tooltip_text=Catalog.CONTRACTS[id].text;b.set_meta("invalid",n.stage>0 and n.contracts[actor]!=id)
		text_row(p._offer_column,"成约条件："+Catalog.CONTRACTS[n.contracts[actor]].text)
		var wager:=HBoxContainer.new();wager.add_theme_constant_override("separation",8);p._offer_column.add_child(wager)
		for i in 3:
			var tier:int=i
			var b:=add_button(p,wager,["不押 · 保留金币","押2币 · 成约 ×1.3","押5币 · 成约 ×1.5"][i],func():p._emit("offer",[n.contracts[actor],tier]),Vector2(245,52),"selected" if n.tiers[actor]==i else "ivory")
			b.set_meta("invalid",i<n.tiers[actor] or Catalog.STAKES[i]-n.paid[actor]>n.wallets[actor])
		text_row(p._offer_column,"成功退本金；失败损失押金。成约后不能补押，两人独立钱包。",15)
	else:
		text_row(p._offer_column,("不押金币 · 可以直接准备" if n.paid[actor]==0 else "已押 %d币 · 成约 ×%.1f · 成功退本金，失败损失押金"%[n.paid[actor],Catalog.STAKE_MULT[n.tiers[actor]]]),18)
		text_row(p._offer_column,"当前约定："+Catalog.CONTRACTS[n.contracts[actor]].name+" · "+Catalog.CONTRACTS[n.contracts[actor]].text,15)
	add_button(p,p._offer_column,"准备好了 · "+("公开前三张" if n.stage==0 else "翻开下一张"),func():p._emit("ready",null),Vector2(748,49),"primary")
