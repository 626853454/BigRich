class_name FurUIUpgradeCard
extends Button
## An offer surface; costs and application still belong to the session/domain.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var _price:Label
var _reason:Label
func configure(item:Dictionary,build:Dictionary,index:int,paid:bool,reason:String="")->void:
	custom_minimum_size=Vector2(300,428);size_flags_horizontal=Control.SIZE_EXPAND_FILL;focus_mode=Control.FOCUS_ALL;theme=Palette.create();mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var core:bool=bool(item.get("masterwork",false));var accent:=Color("267678") if core else Palette.INK
	var plate:=Palette.panel_style();plate.bg_color=Color("fff9ec");plate.border_color=Color("c5aa72") if core else Color("d5cab4");plate.set_border_width_all(2 if core else 1);plate.shadow_size=7
	var hover:=plate.duplicate() as StyleBoxFlat;hover.bg_color=Color("fffdf4");hover.border_color=Color("278483");hover.set_border_width_all(2)
	var off:=plate.duplicate() as StyleBoxFlat;off.bg_color=Color("eae6dc");off.shadow_size=3
	var hover_skin:=FurUICeramicFrame.from_flat(hover);hover_skin.modulate_color=Color(.91,1.0,.96)
	var off_skin:=FurUICeramicFrame.style("muted").duplicate() as StyleBoxTexture;off_skin.modulate_color=Color(.91,.92,.90)
	add_theme_stylebox_override("normal",FurUICeramicFrame.from_flat(plate));add_theme_stylebox_override("hover",hover_skin);add_theme_stylebox_override("pressed",hover_skin);add_theme_stylebox_override("disabled",off_skin);add_theme_stylebox_override("focus",Palette.focus_style())
	var icon_key:String=FurUIBuildPreview.icon_for(str(item.id))
	if item.get("local_offer",false) or item.has("style") or str(item.id) in ["weapon","power","bank","bounce"]:icon_key="weapon_"+["pan","blaster","cookie"][int(build.style)]
	var icon:=FurUIIcons.view(icon_key,Vector2(104,104));icon.position=Vector2(17,10);add_child(icon)
	var kind:String="构筑核心 · 二选一" if core else ("地区精选" if item.get("local_offer",false) else ("流派专属" if item.has("style") else "基础改装"))
	var number:=_label("%02d  /  %s"%[index+1,kind],14,accent);number.position=Vector2(108,27);number.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);number.offset_left=135;number.offset_top=28;number.offset_right=-20;number.offset_bottom=49
	var title:=_label(str(item.name),23,Palette.INK);title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);title.offset_left=25;title.offset_top=109;title.offset_right=-25;title.offset_bottom=169
	var detail:=_label(str(item.detail),16,Palette.MUTED);detail.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);detail.offset_left=25;detail.offset_top=177;detail.offset_right=-25;detail.offset_bottom=260
	var compare:=VBoxContainer.new();compare.mouse_filter=Control.MOUSE_FILTER_IGNORE;compare.add_theme_constant_override("separation",6);compare.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);compare.offset_left=25;compare.offset_right=-25;compare.offset_top=269;compare.offset_bottom=347;add_child(compare)
	for delta in FurUIBuildPreview.changes(build,str(item.id)).slice(0,3):
		var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;compare.add_child(row)
		var label:=Label.new();label.text=delta.label;label.add_theme_font_size_override("font_size",15);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label)
		var value:=Label.new();value.text=delta.before+"  →  "+delta.after;value.add_theme_font_size_override("font_size",16);value.add_theme_color_override("font_color",Color("277b68") if delta.improved else Color("ad684b"));value.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(value)
	_price=_label("6 金币 · 追加一件" if paid else "免费选择 · 永久保留",17,Palette.INK);_price.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);_price.offset_left=55;_price.offset_right=-20;_price.offset_top=-49;_price.offset_bottom=-20
	var coin:=FurUIIcons.view("coin" if paid else "check",Vector2(28,28));coin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);coin.position=Vector2(22,-49);add_child(coin)
	_reason=_label(reason,14,Color("a66550"));_reason.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);_reason.offset_left=25;_reason.offset_right=-25;_reason.offset_top=-88;_reason.offset_bottom=-64
	disabled=not reason.is_empty();tooltip_text=str(item.name)+"\n"+str(item.detail)+( "\n"+reason if disabled else "")
	if disabled:
		icon.modulate=Color(.78,.81,.79);title.add_theme_color_override("font_color",Palette.MUTED);_price.add_theme_color_override("font_color",Palette.MUTED)
	FurUIButtonDetail.attach(self)
func _label(value:String,px:int,color:Color)->Label:
	var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",px);label.add_theme_font_override("font",FurChapterUITheme.font(px>=22));label.add_theme_color_override("font_color",color);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label);return label
func _draw()->void:
	draw_line(Vector2(24,size.y-61),Vector2(size.x-24,size.y-61),Color("dfd3bd"),1,true)
	if not disabled:draw_polyline(PackedVector2Array([Vector2(size.x-28,size.y-40),Vector2(size.x-23,size.y-35),Vector2(size.x-28,size.y-30)]),Palette.INK,2,true)
