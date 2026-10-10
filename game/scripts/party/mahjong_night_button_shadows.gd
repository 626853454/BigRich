class_name FurMahjongNightButtonShadows
extends Node2D
## Cache unchanged porcelain grounding; rerender only on button layout changes.
## Native Buttons still own their styles, focus, hit tests and animations.
var row:HBoxContainer
var cache:SubViewport
var ink:ShadowInk
const PAD=Vector2(12,12)
class ShadowInk extends Node2D:
	var rectangles:Array[Rect2]=[]
	var style:StyleBoxFlat
	func _init()->void:
		style=StyleBoxFlat.new();style.bg_color=Color(.13,.19,.18,.19);style.set_corner_radius_all(22)
		style.shadow_color=Color(.10,.16,.15,.14);style.shadow_size=10;style.shadow_offset=Vector2(0,3)
	func _draw()->void:
		for rectangle:Rect2 in rectangles:draw_style_box(style,rectangle)
func bind(actions:HBoxContainer,scroll:ScrollContainer)->void:
	row=actions;show_behind_parent=true
	cache=SubViewport.new();cache.transparent_bg=true;cache.disable_3d=true;cache.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(cache)
	ink=ShadowInk.new();cache.add_child(ink)
	row.sort_children.connect(refresh);row.visibility_changed.connect(refresh)
	scroll.get_h_scroll_bar().value_changed.connect(func(_value:float):position=row.position)
func refresh()->void:
	if not is_instance_valid(row):return
	position=row.position;visible=row.visible
	ink.rectangles.clear()
	for child in row.get_children():
		if child is Button and child.visible:
			if child.has_node("PorcelainContactShadow"):child.get_node("PorcelainContactShadow").hide()
			ink.rectangles.append(Rect2(child.position+PAD+Vector2(2,5),child.size-Vector2(4,6)))
	cache.size=Vector2i(maxi(1,ceili(row.size.x+PAD.x*2)),maxi(1,ceili(row.size.y+PAD.y*2)))
	ink.queue_redraw();cache.render_target_update_mode=SubViewport.UPDATE_ONCE
	queue_redraw()
func _draw()->void:
	if is_instance_valid(cache):draw_texture(cache.get_texture(),-PAD)
