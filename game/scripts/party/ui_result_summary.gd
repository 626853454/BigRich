class_name FurUIResultSummary
extends VBoxContainer
## Receipt-only summary. This never awards a reward or advances a chapter.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
func configure(data:Dictionary,faces:Array[Texture2D])->void:
	theme=Palette.create();add_theme_constant_override("separation",18);custom_minimum_size.y=436
	var banner:=PanelContainer.new();var style:=Palette.panel_style();style.bg_color=Color("e1eee7") if data.get("success",false) else Color("ece5dc");style.shadow_size=0;banner.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(style));add_child(banner)
	var band:=HBoxContainer.new();band.add_theme_constant_override("separation",20);banner.add_child(band);band.add_child(FurUIIcons.view("star" if data.get("success",false) else "compass",Vector2(88,88)))
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",7);band.add_child(words);words.add_child(_label(str(data.get("headline","本次挑战结束")),25,Palette.INK));words.add_child(_label(str(data.get("detail","")),17,Palette.MUTED))
	var stamp_column:=VBoxContainer.new();stamp_column.custom_minimum_size.x=155;band.add_child(stamp_column)
	var stamp:=_label("%d / 2"%int(data.get("stamps",0)),36,Color("2a786f"));stamp.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stamp_column.add_child(stamp)
	var stamp_label:=_label("挑战印章",14,Palette.MUTED);stamp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stamp_column.add_child(stamp_label)
	var rows:=HBoxContainer.new();rows.add_theme_constant_override("separation",20);add_child(rows)
	for i in 2:
		var receipt:Dictionary=data.players[i];var card:=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.custom_minimum_size.y=176
		var plate:=Palette.panel_style();plate.bg_color=Color("fff9ee");plate.shadow_size=4;card.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate));rows.add_child(card)
		var col:=VBoxContainer.new();col.add_theme_constant_override("separation",10);card.add_child(col)
		var header:=HBoxContainer.new();header.add_theme_constant_override("separation",12);col.add_child(header)
		var portrait:=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.custom_minimum_size=Vector2(54,54);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=faces[i];header.add_child(portrait)
		var name:=_label(["小柯","泡泡"][i],23,Palette.INK);name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(name)
		header.add_child(FurUIIcons.view("coin",Vector2(36,36)))
		var earned:=_label("+%d"%int(receipt.get("coins",0)),30,Color("94743e"));earned.autowrap_mode=TextServer.AUTOWRAP_OFF;earned.custom_minimum_size.x=90;earned.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;header.add_child(earned)
		col.add_child(_label(str(receipt.get("detail","")),17,Palette.MUTED));col.add_child(_label("当前钱包  %d 金币"%int(receipt.get("wallet",0)),16,Palette.INK))
	var retained:=PanelContainer.new();var pale:=Palette.panel_style();pale.bg_color=Color("ebe8df");pale.shadow_size=0;pale.set_border_width_all(0);retained.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(pale,true));add_child(retained)
	var line:=HBoxContainer.new();line.add_theme_constant_override("separation",16);retained.add_child(line);line.add_child(FurUIIcons.view("bag",Vector2(47,47)))
	var label:=_label(str(data.get("retained","")),17,Palette.MUTED);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
func _label(value:String,px:int,color:Color)->Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",px);label.add_theme_font_override("font",FurChapterUITheme.font(px>=22));label.add_theme_color_override("font_color",color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
