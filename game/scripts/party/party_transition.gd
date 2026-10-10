class_name FurPartyTransition
extends Control
## Real waiting state, never an invented loading percentage.
var title:Label
var detail:Label
var _stage:Label
var _age:float=0
var _spinner:TextureRect
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=FurChapterUITheme.create();mouse_filter=Control.MOUSE_FILTER_STOP
	var dim:=ColorRect.new();dim.color=Color(.055,.13,.155,.96);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(dim)
	var card:=PanelContainer.new();card.set_anchors_and_offsets_preset(Control.PRESET_CENTER);card.offset_left=-490;card.offset_right=490;card.offset_top=-180;card.offset_bottom=180
	var plate:=FurChapterUITheme.panel_style();plate.bg_color=Color("f7f0df");plate.set_corner_radius_all(32);plate.content_margin_left=40;plate.content_margin_right=40;plate.content_margin_top=32;plate.content_margin_bottom=32;card.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate));add_child(card)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",28);card.add_child(row)
	var icon:=FurUIIcons.view("compass",Vector2(150,150));icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(icon)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",17);row.add_child(column)
	var eyebrow:=Label.new();eyebrow.text="下一段旅程  /  伙伴集合";eyebrow.add_theme_font_size_override("font_size",16);eyebrow.add_theme_color_override("font_color",FurChapterUITheme.MUTED);column.add_child(eyebrow)
	title=Label.new();title.add_theme_font_override("font",FurChapterUITheme.font(true));title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_font_size_override("font_size",30);column.add_child(title)
	detail=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",18);detail.add_theme_color_override("font_color",FurChapterUITheme.MUTED);column.add_child(detail)
	var status:=HBoxContainer.new();status.add_theme_constant_override("separation",12);column.add_child(status);_spinner=FurUIIcons.view("settings",Vector2(28,28));status.add_child(_spinner)
	_stage=Label.new();_stage.add_theme_font_size_override("font_size",16);status.add_child(_stage);hide();visibility_changed.connect(func():set_process(visible))
func present(context:Dictionary)->void:
	_age=0;title.text="正在抵达 · "+str(context.get("district_name","海岛"));var task:Dictionary=FurRouteCatalog.entry(int(context.get("route",0)))
	detail.text="本场目标：%s\n场景准备好后才开始计时，伙伴一起入场。"%task.goal;_stage.text="正在布置战区";show()
func scene_ready()->void:
	_stage.text="战区已就绪 · 伙伴集合中";detail.text+="\n移动收集经验，靠近倒地伙伴可以救援。"
func _process(delta:float)->void:
	if not visible or not is_instance_valid(_spinner):return
	_age+=delta
	_spinner.modulate.a=1 if FurUIPreferences.reduced_motion else .62+.38*sin(_age*3.2)*sin(_age*3.2)
