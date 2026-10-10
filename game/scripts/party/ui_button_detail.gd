class_name FurUIButtonDetail
extends Node2D
## Short state ornament. Does not move or resize the button hit area.
var host:Button
var amount:float=0.0
var press_age:float=1.0
var accent:=Color("d9b771")
var _audio:AudioStreamPlayer
static func attach(button:Button)->void:
	if button.has_node("PremiumStateDetail"):return
	var detail:=FurUIButtonDetail.new();detail.name="PremiumStateDetail";detail.host=button;button.add_child(detail)
	button.resized.connect(detail.queue_redraw);button.mouse_entered.connect(detail.activate);button.mouse_exited.connect(detail.activate)
	button.focus_entered.connect(detail.activate);button.focus_exited.connect(detail.activate);button.button_down.connect(detail.press);detail.set_process(false)
func activate()->void:
	if not is_instance_valid(host):return
	FurUIPreferences.ensure_loaded()
	if FurUIPreferences.reduced_motion:
		amount=1.0 if (host.is_hovered() or host.has_focus()) and not host.disabled else 0.0;queue_redraw();return
	set_process(true)
func press()->void:
	if host.disabled:return
	FurUIPreferences.ensure_loaded()
	if FurUIPreferences.interface_sounds:
		if not is_instance_valid(_audio):_audio=AudioStreamPlayer.new();_audio.volume_db=-15;add_child(_audio)
		_audio.stream=load("res://assets/ui/premium_v1/ui_confirm.wav");_audio.play()
	if FurUIPreferences.reduced_motion:return
	press_age=0;set_process(true)
func _exit_tree()->void:
	if is_instance_valid(_audio):_audio.stop();_audio.stream=null
func _process(delta:float)->void:
	if not is_instance_valid(host):set_process(false);return
	var target:float=1.0 if (host.is_hovered() or host.has_focus()) and not host.disabled else 0.0
	amount=move_toward(amount,target,delta*8.5);press_age=minf(1.0,press_age+delta*6.0);queue_redraw()
	if is_equal_approx(amount,target) and press_age>=1.0:set_process(false)
func _draw()->void:
	if not is_instance_valid(host) or host.disabled or host.size.x<55:return
	if amount>.001:
		var col:=Color(accent,amount*.65);var y:float=host.size.y-8
		draw_line(Vector2(host.size.x*.5-13,y),Vector2(host.size.x*.5+13,y),col,1.5,true)
	if press_age<1.0:
		var edge:=StyleBoxFlat.new();edge.bg_color=Color.TRANSPARENT;edge.border_color=Color(accent,(1-press_age)*.55)
		edge.set_corner_radius_all(19);edge.set_border_width_all(2);draw_style_box(edge,Rect2(4,4,host.size.x-8,host.size.y-8))
