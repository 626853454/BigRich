class_name FurPartyNotebook
extends Control
## Read-only board reference. The Session pauses board decisions while it is open.
signal closed
var rules:RichTextLabel
var ledger:RichTextLabel

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new();shade.color=Color(0.025,.04,.075,.78);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-570;panel.offset_right=570;panel.offset_top=-325;panel.offset_bottom=325
	var style:=StyleBoxFlat.new();style.bg_color=Color("202c43");style.border_color=Color("bd996c");style.set_border_width_all(2);style.set_corner_radius_all(20)
	style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=22;style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",15);panel.add_child(column)
	var title:=Label.new();title.text="毛球岛 · 玩法与本局账本";title.add_theme_font_size_override("font_size",27);column.add_child(title)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",28);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(row)
	rules=_text_box();ledger=_text_box();row.add_child(rules);row.add_child(ledger)
	var close_button:=Button.new();close_button.text="回到棋盘   F1 / Esc";close_button.custom_minimum_size.y=44;close_button.focus_mode=Control.FOCUS_NONE;close_button.add_theme_font_size_override("font_size",20);close_button.pressed.connect(close);column.add_child(close_button)
	hide()

func _text_box()->RichTextLabel:
	var label:=RichTextLabel.new();label.bbcode_enabled=true;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.custom_minimum_size.x=515
	label.add_theme_font_size_override("normal_font_size",17);label.add_theme_font_size_override("bold_font_size",18);label.add_theme_color_override("default_color",Color("eee1ca"));label.add_theme_constant_override("line_separation",5)
	label.add_theme_font_override("normal_font",FurVisualStyle.font());label.add_theme_font_override("bold_font",FurVisualStyle.font());return label

func show_page(state:Dictionary,builds:Array)->void:
	rules.text="[b]共同守岛，个人争星[/b]\n8轮里一起守住至少4波，算共同过关。个人星铃榜先比星铃，同星再比剩余金币。\n\n[b]每一轮[/b]\n两人各准备、掷骰、选路和处理落点；随后一起战斗。战后每人免费改装一次，可再花6金加装，或留钱。\n\n[b]选哪座岛，也是在选构筑[/b]\n领队每轮轮换；领队落点决定下一场。\n港口：胜利各多2金，工坊偏火力／弹射。\n风车丘：本场火力+12%，偏武器／机动。\n遗迹林：本场生命+12，偏合作／生命。\n\n[b]几笔值得算的钱[/b]\n星铃通常20金；风艇2金走1步。\n买摊位8金：本岛参战生命+2，道具减1金。\n升级花6、当次赚3：生命+4，道具减2金。\n补给免费加12生命；营业押3金加12%火力，胜返7、败返1。准备均只持续一场。\n\n[b]操作[/b]\n棋盘：Space掷骰；数字1–4选择。\nTab全览／滚轮缩放／右键拖动／Home归位。\n战斗自动攻击：P1 WASD／空格闪避／Q技能；P2方向键／Enter／斜杠。"
	rules.text+="\n\n[b]跨岛合伙委托[/b]\n前5轮的奇遇格可放弃即时金币或加骰，约伙伴去下一座岛。接单当场及随后两场内，在目标岛完成地区任务并守住：接单者下颗星省5金，伙伴额外得5金。最晚第7场兑现，留第8轮用券买星。只能有一份在途，星券不叠加；到期未成不扣额外钱，也没有奖励。"
	rules.text+="\n\n[b]成长与声音[/b]\n等级和未满级经验持续带入下一波，波末拾取也会计入升级。F10开关本游戏音乐与音效，本次进程内重开保留选择。"
	rules.text+="\n\n[b]买星也能改变争夺路线[/b]\n买下当前星铃后，下一颗通常随机迁往另外一座岛。前7轮可额外付2金，指定另一个星铃驿站。优惠券只减星价，不能抵这2金。省下航费可以坐风艇；留6金可在战后追加改装。最后一轮没有后续行程，因此不收指定费。"
	var lines:Array[String]=["[b]现在的资金与成长[/b]"]
	for actor in 2:
		var player:Dictionary=state.players[actor];var build:Dictionary=builds[actor];var discount:int=int(state.get("star_discounts",[0,0])[actor])
		lines.append("[color=#ffd38d]%s[/color] · %d星／%d金%s"%[player.name,player.stars,player.coins," · 下颗星省5金" if discount>0 else ""])
		lines.append("%d把武器／火力×%.2f／生命%.0f；已装%d件"%[build.weapons,build.damage,build.health,build.chosen.size()])
		var owned:Array[String]=[]
		for estate in state.properties:
			if estate.owner==actor:owned.append("%02d格Lv.%d"%[estate.node,estate.level])
		lines.append("摊位："+("、".join(owned) if not owned.is_empty() else "尚未经营"))
	var contract:Dictionary=state.get("joint_contract",{})
	if not contract.is_empty():lines.append("\n[b]在途合伙[/b]\n帮%s去%s；最迟第%d场。\n任务完成且守住，才能兑现星券和伙伴金币。"%[FurPartyMap.PLAYER_NAMES[contract.sponsor],FurPartyMap.districts()[contract.target_district].name,contract.expires_round])
	lines.append("\n[b]最近入账与支出[/b]")
	var history:Array=state.get("economy_history",[])
	if history.is_empty():lines.append("两人各带10金币登岛。做出选择后，这里会记下实际交易。")
	for index in range(maxi(0,history.size()-7),history.size()):
		var entry:Dictionary=history[index];var facts:Dictionary=entry.facts;var who:String=FurPartyMap.PLAYER_NAMES[entry.actor] if entry.actor>=0 else "全队"
		var detail:String="准备就绪"
		match str(entry.action):
			"landing":
				detail="星铃 +1，花%d金"%facts.cost if facts.star_delta>0 else "落点金币 %+d%s"%[facts.coin_delta,"，伙伴 %+d"%facts.partner_coin_delta if facts.partner_coin_delta!=0 else ""]
				if facts.get("migration_fee",0)>0:detail+="（含2金指定下一岛）"
				if not facts.get("joint_contract",{}).is_empty():detail="接下跨岛合伙，放弃当次即得收益"
			"ferry":detail="风艇票 −2金"
			"workshop":detail="追加改装 −6金"
			"battle":detail="站胜" if facts.team_won else "撤退";detail+=" · 两人各入账%d／%d金"%[facts.coin_rewards[0],facts.coin_rewards[1]]
			"prepare":detail="营业押3金" if facts.get("cost",0)>0 else "免费补给"
		lines.append("第%d轮 · %s：%s"%[entry.round,who,detail])
	ledger.text="\n".join(lines);rules.scroll_to_line(0);ledger.scroll_to_line(0);show()

func close()->void:
	if not visible:return
	hide();closed.emit()
