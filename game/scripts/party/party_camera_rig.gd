class_name FurPartyCameraRig
extends Node3D
## Owns only presentation. Map/model coordinates remain authoritative.
signal mode_changed
var camera:Camera3D
var enabled:=true
var overview:=false
var manual_pan:=Vector3.ZERO
var follow_zoom:=38.0
var overview_zoom:=91.0
var focus:=Vector3.ZERO
var target:=Vector3.ZERO
var region_center:=Vector3.ZERO
var initialized:=false
var board_view_bias:=Vector3.ZERO
const OFFSET:=Vector3(0,32,38)
var follow_offset:=OFFSET
var overview_offset:=OFFSET

func _ready()->void:
	camera=Camera3D.new();camera.name="IslandCamera";camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=follow_zoom;camera.far=220
	add_child(camera);camera.current=true

func set_focus(pawn_position:Vector3,district_center:Vector3,immediate:bool=false)->void:
	focus=pawn_position;region_center=district_center
	if immediate or not initialized:
		target=desired_target();initialized=true;camera.size=overview_zoom if overview else follow_zoom
		_update_pose()

func desired_target()->Vector3:
	return (Vector3(0,1.8,-.7) if overview else region_center.lerp(focus,.30))+manual_pan+board_view_bias*(1.0 if overview else .3)

func tick(delta:float)->void:
	if not enabled or camera==null:return
	target=target.lerp(desired_target(),1.0-exp(-delta*3.2))
	var zoom:float=overview_zoom if overview else follow_zoom
	camera.size=lerpf(camera.size,zoom,1.0-exp(-delta*5.0));_update_pose()

func _update_pose()->void:
	camera.position=target+(overview_offset if overview else follow_offset);camera.look_at(target)

func toggle_overview()->void:
	overview=not overview;manual_pan=Vector3.ZERO;mode_changed.emit()

func return_to_actor()->void:
	overview=false;manual_pan=Vector3.ZERO;mode_changed.emit()

func _unhandled_input(event:InputEvent)->void:
	if not enabled:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_TAB,KEY_M]:toggle_overview();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_HOME:return_to_actor();get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var multiplier:=1.0
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:multiplier=.86
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:multiplier=1.16
		if multiplier!=1.0:
			if overview:overview_zoom=clampf(overview_zoom*multiplier,62.0,116.0)
			else:follow_zoom=clampf(follow_zoom*multiplier,25.0,58.0)
			get_viewport().set_input_as_handled();mode_changed.emit()
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
		var units:=camera.size/maxf(1.0,get_viewport().get_visible_rect().size.x)
		manual_pan+=Vector3(-event.relative.x*units,0,-event.relative.y*units*1.56)
		manual_pan.x=clampf(manual_pan.x,-32,32);manual_pan.z=clampf(manual_pan.z,-25,25)
		get_viewport().set_input_as_handled()

func label()->String:
	return "返回当前动物  Tab" if overview else "群岛全览  Tab"
