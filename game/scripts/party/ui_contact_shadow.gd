class_name FurUIContactShadow
extends Node2D
## The native control owns its own hit area. This only grounds the baked porcelain.
var host:Control
var quiet:bool=false
static func attach(control:Control,subtle:bool=false)->void:
	if control.has_node("PorcelainContactShadow"):return
	var shadow:=FurUIContactShadow.new();shadow.name="PorcelainContactShadow";shadow.host=control;shadow.quiet=subtle;shadow.show_behind_parent=true;control.add_child(shadow);control.resized.connect(shadow.queue_redraw)
func _draw()->void:
	if not is_instance_valid(host):return
	var style:=StyleBoxFlat.new();style.bg_color=Color(.13,.19,.18,.12 if quiet else .19);style.set_corner_radius_all(22)
	style.shadow_color=Color(.10,.16,.15,.09 if quiet else .14);style.shadow_size=6 if quiet else 10;style.shadow_offset=Vector2(0,3)
	draw_style_box(style,Rect2(2,5,host.size.x-4,host.size.y-6))
