class_name FurMahjongNightWelcomeReceipt
extends HBoxContainer

## A compact recap of actual paid events, with no progression currency or
## hidden grading. The bars compare these groups against this hand's peak.
func build(receipt:Dictionary)->void:
	custom_minimum_size.y=108;add_theme_constant_override("separation",12)
	var index:int=0
	for event:Dictionary in receipt.groups:
		index+=1
		var card:=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.custom_minimum_size=Vector2(0,108);card.add_theme_stylebox_override("panel",FurUICeramicFrame.style("ivory"));add_child(card)
		var margin:=MarginContainer.new();card.add_child(margin)
		for side:String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
		var column:=VBoxContainer.new();column.add_theme_constant_override("separation",1);margin.add_child(column)
		text("第%d组 · "%index+{"chi":"顺子","pon":"刻子","kong":"杠"}.get(event.kind,event.kind),16,column)
		text("+%d 分"%event.total,28,column)
		text("牌 %d  +  帮手 %d"%[event.welcome_base,event.total-event.welcome_base],14,column)
		var bar:=ProgressBar.new();bar.custom_minimum_size.y=6;bar.show_percentage=false;bar.max_value=maxi(1,receipt.peak);bar.value=event.total;column.add_child(bar)
		var fill:=StyleBoxFlat.new();fill.bg_color=Color("308c88");fill.set_corner_radius_all(3);bar.add_theme_stylebox_override("fill",fill)
		var bg:=StyleBoxFlat.new();bg.bg_color=Color("cfddd5");bg.set_corner_radius_all(3);bar.add_theme_stylebox_override("background",bg)
		card.set_meta("actual_score",event.total);card.set_meta("actual_base",event.welcome_base)

func text(value:String,font_size:int,parent:Node)->void:
	var line:=Label.new();line.text=value;line.add_theme_font_override("font",FurChapterUITheme.font(font_size>=24));line.add_theme_font_size_override("font_size",font_size);line.add_theme_color_override("font_color",Color("24494b"));line.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(line)
