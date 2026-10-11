class_name FurMahjongNightFeedback
extends Node3D

# Presentation only. Capped pooled geometry; this node never changes scoring,
# tile IDs, wallet coins, AI decisions or the table's random generator.
var _chips:MultiMeshInstance3D
var _title:Label3D
var _motion:Tween
var _count:int=0
var camera:Camera3D
var _lens:Tween
var reduced_motion:bool=false
var _showlight:=FurMahjongNightShowlight.new()
var score_link:FurMahjongNightScoreLink

func _ready()->void:
	score_link=FurMahjongNightScoreLink.new();add_child(score_link)
	var source:Node3D=FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/fixtures/score_token.glb")
	var instance:MeshInstance3D=source.get_child(0)
	_chips=MultiMeshInstance3D.new();_chips.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chips.multimesh=MultiMesh.new();_chips.multimesh.transform_format=MultiMesh.TRANSFORM_3D;_chips.multimesh.mesh=instance.mesh
	_chips.material_override=instance.material_override;_chips.multimesh.instance_count=24;_chips.multimesh.visible_instance_count=0;add_child(_chips);source.free()
	_title=Label3D.new();_title.font=FurChapterUITheme.font(true);_title.font_size=90;_title.pixel_size=.012
	_title.modulate=Color("ffdf92");_title.outline_modulate=Color("16413e");_title.outline_size=10;_title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_title.position=Vector3(0,2.7,2.2);_title.no_depth_test=true;_title.hide();add_child(_title)

func burst(amount:int,target:int,before:int,origin:Vector3,speed:float,plain_base:int=-1,allow_target_with_base:bool=false)->void:
	if amount<=0:return
	clear()
	_count=clampi(6+int(10.0*float(amount)/maxi(target,1)),6,24);_chips.multimesh.visible_instance_count=_count
	var broke:bool=before<target and before+amount>=target
	var explosive:bool=amount>=target
	if plain_base>0:
		# Build impact follows real amplification, even at a high ordinary-table
		# goal. Learning has group caps instead, so it suppresses target crossing.
		broke=broke and allow_target_with_base;explosive=amount>=plain_base*2
		_count=clampi(5+roundi(3.0*float(amount-plain_base)/plain_base),5,24);_chips.multimesh.visible_instance_count=_count
	_showlight.configure(get_parent())
	if broke or explosive:
		_title.text="突破目标 · %.2f 倍"%(float(before+amount)/maxi(target,1)) if broke else "连锁爆发 · +%d分"%amount
		if plain_base>0:_title.text="帮手接响 · %d → %d"%[plain_base,amount]
		_title.modulate.a=1;_title.show()
	if not reduced_motion and is_instance_valid(camera) and (broke or (explosive if plain_base>0 else amount>=target*.5)):
		_lens=create_tween();_lens.set_speed_scale(speed)
		_lens.tween_property(camera,"fov",38.6,.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_lens.tween_property(camera,"fov",40.0,.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion=create_tween();_motion.set_speed_scale(speed)
	_motion.tween_method(func(t:float):
		if broke or explosive:_showlight.sample(smoothstep(0.0,.16,t)*(1.0-smoothstep(.58,1.0,t)))
		for i in _count:
			var delay:float=float(i%6)*.035;var f:float=clampf((t-delay)/.79,0,1)
			var spread:float=(float(i%6)-2.5)*.48
			var end:Vector3=Vector3(spread*.24,3.65,-.45)
			var start:Vector3=origin+Vector3(spread,0,float(i/6)*.22)
			var position_value:Vector3=start.lerp(end,f)+Vector3(spread*sin(f*PI)*.35,sin(f*PI)*(1.0+float(i%3)*.13),0)
			var size_value:float=(.90+sin(f*PI)*.50)*clampf((1.0-f)*9.0,0,1)
			var basis:=Basis(Vector3.RIGHT,f*TAU*1.1+float(i)*.24).rotated(Vector3.UP,f*TAU*.6).scaled(Vector3.ONE*size_value)
			_chips.multimesh.set_instance_transform(i,Transform3D(basis,position_value))
		_title.position.y=2.7+sin(clampf(t,0,1)*PI)*.20
		_title.modulate.a=clampf((1.0-t)*5.0,0,1),0.0,1.0,.68)
	_motion.tween_callback(func():_chips.multimesh.visible_instance_count=0;_title.hide();_showlight.reset())

func clear()->void:
	if is_instance_valid(score_link):score_link.clear()
	_showlight.reset()
	if is_instance_valid(_motion):_motion.kill()
	if is_instance_valid(_lens):_lens.kill()
	if is_instance_valid(camera):camera.fov=40.0
	if is_instance_valid(_chips):_chips.multimesh.visible_instance_count=0
	if is_instance_valid(_title):_title.hide()
