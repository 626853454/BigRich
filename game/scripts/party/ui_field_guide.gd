class_name FurUIFieldGuide
extends VBoxContainer
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const PAGES:=[
	{"name":"海岛远征","promise":"路线养成构筑，构筑带你走得更远。","steps":[["dice","先决定去哪里","掷骰后逐格前进，在岔路选择步行或付费渡船。普通落点不会强制战斗；挑战站可以进入，也可以离开。"],["shop","把探索变成战备","经营、路线委托和道具改变金币与补给。选择挑战站才一起进入割草战斗，自动攻击，专心走位与配合。"],["forge","带着成长再挑战","胜利后的工坊每人免费改装一件，可花6金追加。下一场保留构筑和经验；获得两处不同挑战印章后，从出口离岛。"]],"keys":"P1  WASD移动  /  Space冲刺  /  Q技能\nP2  方向键移动  /  Enter冲刺  /  斜杠技能","note":"星铃记录个人荣誉；两处不同挑战印章推动章节。"},
	{"name":"云顶雀馆","promise":"在真实牌墙里，做一手属于你的牌。","steps":[["mahjong","摸一张，打一张","136张实体牌，每种四张。起手13张，正常摸到14张；点击自己的手牌，再确认打出。公开残局和随机开局会明确标注。"],["route","同桌合作，合法胡牌","按提示吃、碰、明杠、暗杠或加杠，也可抢杠胡。四面子一将或门清七对可胡；任一伙伴合法胡牌，共同取得本站印章。"],["forge","流派与券改变选择","门清、刻派、连序各有单槽技艺和额外目标。窥牌看真实墙顶并排序，换牌将本次摸牌退至墙尾再摸；牌数保持守恒。"]],"keys":"鼠标  点击自己的实体手牌，再确认弃牌\n数字1–9  选择当前列出的动作；双人轮换操作","note":"牌墙耗尽或累计64次弃牌流局。流派技艺有次数限制。"},
	{"name":"时光空港","promise":"留下过去的脚步，让伙伴在未来相遇。","steps":[["clock","录下这一轮的脚步","每拍两人各走一步，共八拍。你可以先让两人站上A/B踏板，再封存剩余静止动作；记录会成为下一轮的回声。"],["route","让过去维持供电","时间线显示旧轨迹的踏板供电，而非当前动物的位置。真实动物趁回声供电，分别走到自己的交付格送出能量。"],["star","把有限资源用在关键拍","旋转券旋转旧轨迹；余辉券延长一拍踏板余辉。最多三轮，双方都送达才完成挑战。回到棋盘可积累下一场资源。"]],"keys":"方向按钮或数字1–5  移动 / 等待\n先看当前位置与旧轨迹，再决定封存或用券","note":"半透明动物是回声；实心动物是这一拍的真实玩家。"}
]
var page:int=0
var _tabs:Array[Button]=[]
var _body:HBoxContainer
var _footer:Label
func configure(chapter:int)->void:
	page=clampi(chapter,0,2);theme=Palette.create();add_theme_constant_override("separation",17);custom_minimum_size.y=493
	var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",12);add_child(tabs)
	for i in 3:
		var button:=Button.new();button.text=PAGES[i].name;button.custom_minimum_size=Vector2(240,48);button.pressed.connect(_select.bind(i));tabs.add_child(button);_tabs.append(button)
	_body=HBoxContainer.new();_body.add_theme_constant_override("separation",26);_body.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(_body)
	_footer=Label.new();_footer.add_theme_font_size_override("font_size",16);_footer.add_theme_color_override("font_color",Palette.MUTED);_footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(_footer);_select(page)
func _select(index:int)->void:
	page=index
	for i in _tabs.size():Palette.apply_button(_tabs[i],"selected" if i==page else "quiet",["compass","mahjong","clock"][i])
	for child in _body.get_children():_body.remove_child(child);child.queue_free()
	var data:Dictionary=PAGES[page];var side:=PanelContainer.new();side.custom_minimum_size.x=340;var panel:=Palette.panel_style();panel.bg_color=Palette.PALE[page];panel.shadow_size=0;side.add_theme_stylebox_override("panel",panel);_body.add_child(side)
	var inset:=VBoxContainer.new();inset.add_theme_constant_override("separation",17);side.add_child(inset)
	var preview:=FurChapterPreview3D.new();preview.configure(page);preview.custom_minimum_size=Vector2(290,157);inset.add_child(preview)
	inset.add_child(_label(data.promise,21,Palette.INK));inset.add_child(_label(data.keys,16,Palette.MUTED))
	var steps:=VBoxContainer.new();steps.size_flags_horizontal=Control.SIZE_EXPAND_FILL;steps.add_theme_constant_override("separation",22);_body.add_child(steps)
	for i in 3:
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);steps.add_child(row);row.add_child(FurUIIcons.view(data.steps[i][0],Vector2(56,56)))
		var text:=VBoxContainer.new();text.add_theme_constant_override("separation",8);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		text.add_child(_label("%02d  %s"%[i+1,data.steps[i][1]],22,Palette.INK));text.add_child(_label(data.steps[i][2],17,Palette.MUTED))
	_footer.text=data.note
func _label(value:String,px:int,color:Color)->Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",px);label.add_theme_font_override("font",FurChapterUITheme.font(px>=22));label.add_theme_color_override("font_color",color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
