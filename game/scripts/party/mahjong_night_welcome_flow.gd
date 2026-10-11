class_name FurMahjongNightWelcomeFlow
extends RefCounted

var session:Variant
var active:bool=false
var kind:String="tutorial"
var number:int=1
var route:String="wind"
var extra:String=""
var seed_value:int=73011
var history:Dictionary={}
var bests:Dictionary={}
var peak_bests:Dictionary={}

func _init(owner:Variant)->void:session=owner

func start(selected:String)->void:
	active=true;kind=selected;number=1;route="wind";extra="";history.clear()
	seed_value=int(randi()%2147483646)+1
	session._lesson_id="";session.use_ai=false;session._replay_seed=-1
	session._begin_table()

func make_rules()->Variant:
	var table=FurMahjongNightWelcome.new()
	table.begin_welcome(kind,number,route,extra,seed_value)
	return table

func tick(state:Dictionary)->void:
	if state.night.welcome.complete:show_result()

func show_result()->void:
	session.mode="welcome_result"
	var receipt:Dictionary=session.rules.receipt();history[str(number)]=receipt.duplicate(true)
	var hand_key:String=JSON.stringify([kind,number,route,extra,seed_value])
	var previous:int=int(bests.get(hand_key,0));bests[hand_key]=maxi(previous,receipt.total)
	peak_bests[hand_key]=maxi(int(peak_bests.get(hand_key,0)),receipt.peak)
	if bests.size()>64:
		var oldest:String=bests.keys()[0];bests.erase(oldest);peak_bests.erase(oldest)
	var recap:bool=receipt.groups.size()>1
	var column:VBoxContainer=session._new_modal(Rect2(330,98,940,700) if recap else Rect2(330,155,940,577))
	if recap:column.add_theme_constant_override("separation",8)
	session._text(("第一组，学会了！" if number==1 else ("挂件真的让它变强了" if number==2 else "你已经打出了一手成长")) if kind=="tutorial" else "小关 %d 完成 · 慢慢打，也能很响"%number,33,column)
	session._text("%d 分 · 最高一组 %d"%[receipt.total,receipt.peak],42,column)
	session._text("同样这些牌，不带挂件是 %d 分。\n这次由你的真实组合打出 %d 分，挂件多赚了 %d 分。"%[receipt.base,receipt.total,receipt.gain] if receipt.gain>0 else "你亲手亮出的每一组，都已经真正得分。\n接下来，给这些熟悉的牌装上一个帮手。",22,column)
	if previous>0:session._text(("换个顺序，多打了 %d 分！"%(receipt.total-previous)) if receipt.total>previous else "这副起手 · 本次最好 %d 分"%bests[hand_key],20,column)
	if recap:
		var cards:=FurMahjongNightWelcomeReceipt.new();column.add_child(cards);cards.build(receipt)
	if kind=="tutorial":
		var line:String=["接下来拿一件竹节算盘。同样的一二三万，再打一次就知道差别。","再加一枚风铃：先亮小顺子，让更大的顺子吃到后面的倍率。","已经掌握：认一组、选帮手、想顺序。去三段小关自己选一条路线吧。"][number-1]
		session._text(line,20,column)
		column.add_child(session._button(["拿上竹节算盘 · 再试一组","加入风铃 · 连亮三组","去午后小桌 · 自己选构筑"][number-1],_next_tutorial,Vector2(888,68),"primary"))
	elif number<3:
		session._text("过关就获得一件帮手；每次只选一个，带进下一关。",20,column)
		column.add_child(session._button("选一件成长 · 下一小关",show_reward,Vector2(888,68),"primary"))
	else:
		session._text(comparison_text()+"\n同一副起手，只换搭档再试；成绩也受出牌顺序影响。",20,column)
		var next_row:=HBoxContainer.new();next_row.add_theme_constant_override("separation",12);column.add_child(next_row)
		next_row.add_child(session._button("同牌换搭配 · 直接试成型",show_complements,Vector2(438,68),"primary"))
		var advanced:Button=session._button("试试完整夜宴 · 随机牌与AI",open_advanced,Vector2(438,68))
		advanced.tooltip_text="进入完整夜宴准备页。默认选中你熟悉的核心挂件，从核心重新成长；可以选AI或本地双人。小关成绩仍在本次会话中保留。"
		next_row.add_child(advanced)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);column.add_child(row)
	row.add_child(session._button("同样的牌 · 换个顺序重试",session._begin_table,Vector2(438,52)))
	row.add_child(session._button("返回入口",func():active=false;session._lobby(),Vector2(438,52)))

func comparison_text()->String:
	var lines:Array[String]=[]
	for id:String in FurMahjongNightWelcome.reward_options(route):
		var key:String=JSON.stringify([kind,number,route,id,seed_value])
		lines.append(FurMahjongNightCatalog.name_of(id)+(" 总%d / 单%d"%[int(bests[key]),int(peak_bests.get(key,0))] if bests.has(key) else " 未试过"))
	return "同牌实打纪录："+" · ".join(lines)

func show_complements()->void:
	if not active or kind!="small" or number!=3 or not session.rules.receipt().complete:return
	session.mode="welcome_complements"
	var column:VBoxContainer=session._new_modal(Rect2(330,132,940,624))
	session._text("同样的牌，换一个搭档",33,column)
	session._text("通关试搭 · 保留"+FurMahjongNightCatalog.name_of("coal" if route=="fire" else "windbell")+"和原来的起手。\n只替换第二件挂件，从零计分；不带进完整夜宴。",22,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);column.add_child(row)
	for id:String in FurMahjongNightWelcome.reward_options(route):
		var chosen:String=id
		var card:Button=session._relic_card(id,func():try_complement(chosen),Vector2(436,250),false,false)
		var key:String=JSON.stringify([kind,number,route,id,seed_value])
		card.get_node("RelicDetail").text=FurMahjongNightWelcomeUI.DETAILS[id]+"\n"+("同牌总分纪录 %d · 单组峰值 %d"%[int(bests[key]),int(peak_bests.get(key,0))] if bests.has(key) else "还没试过 · 亲手打一遍")
		card.set_meta("welcome_complement",id);row.add_child(card)
	session._text("可以试不同顺序。这里只比较你亲手打出的成绩，不预设谁更强。",19,column)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	footer.add_child(session._button("保留当前成绩 · 返回",show_result,Vector2(438,54)))
	footer.add_child(session._button("换条路线 · 再来三小关",func():start("small"),Vector2(438,54)))

func try_complement(id:String)->void:
	if not active or kind!="small" or number!=3 or session.mode!="welcome_complements":return
	if id not in FurMahjongNightWelcome.reward_options(route):return
	extra=id;session.score_audio.cue("select");session._begin_table()

func open_advanced()->void:
	active=false;session.starter="coal" if route=="fire" else "windbell"
	session._advanced_lobby()

func _next_tutorial()->void:
	if number==3:start("small");return
	number+=1;session._begin_table()

func show_reward()->void:
	session.mode="welcome_reward"
	var column:VBoxContainer=session._new_modal(Rect2(330,153,940,578))
	session._text("只选一件，下一关就能用",33,column)
	session._text("想越打越高，还是蓄满后爆响？" if number==1 else "给自己的核心配一个搭档。",22,column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);column.add_child(row)
	var ids:Array=["windbell","coal"] if number==1 else FurMahjongNightWelcome.reward_options(route)
	for id:String in ids:
		var chosen:String=id
		var card:Button=session._relic_card(id,func():take_reward(chosen),Vector2(436,250),false,false)
		card.tooltip_text=FurMahjongNightWelcomeUI.DETAILS[id]
		card.get_node("RelicDetail").text=FurMahjongNightWelcomeUI.DETAILS[id]
		card.set_meta("welcome_reward",id);row.add_child(card)
	session._text("顺子：先小后大，让后面的牌更值钱。\n茶炉：先亮两组刻子蓄热，下一组再响一次。" if number==1 else ("竹节算盘：每组都多筹码。\n三色锦囊：万、筒、索凑齐后，最后一组冲得更高。" if route=="wind" else "玉石镇纸：每组刻和杠都更扎实。\n双响火签：杠再多响一次。开杠蓄满后，还能接一组大刻子。"),20,column)
	column.add_child(session._button("再看一眼刚才的得分",show_result,Vector2(888,50)))

func take_reward(id:String)->void:
	var legal:Array=["windbell","coal"] if number==1 else FurMahjongNightWelcome.reward_options(route)
	if session.mode!="welcome_reward" or id not in legal:return
	if number==1:route="wind" if id=="windbell" else "fire"
	else:extra=id
	number+=1;session.score_audio.cue("select");session._begin_table()

func help()->void:
	var previous:String=session.mode;session.mode="welcome_help"
	var column:VBoxContainer=session._new_modal(Rect2(392,177,816,520))
	session._text("这张小桌，只记三件事",32,column)
	session._text("1. 顺子是同花色连续三张；刻子是三张一样；杠是四张一样。\n\n2. 点击下方完整组合，把手里的实体牌亮出来，立刻得分。\n\n3. 挂件会自动触发。想好顺序，再让后面的那组更响。",23,column)
	session._text("小关没有倒计时、押约或换牌资源。最多亮三组，可随时重试；这里是预设学习小关，完整随机夜宴另有入口。",18,column)
	column.add_child(session._button("懂了，继续慢慢玩",func():session._close_request_picker();session.mode=previous,Vector2(764,60),"primary"))
