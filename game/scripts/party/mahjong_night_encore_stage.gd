class_name FurMahjongNightEncoreStage
extends Node3D
signal seal_landed
var _seals:Array[Node3D]=[]
var _signature:String=""
var _motion:Tween
var _active:bool=false

func _ready()->void:
	position=Vector3(4.9,.24,-2.3);scale=Vector3.ONE*1.15
	add_child(FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/show/encore_invitation.glb"))
	for actor in 2:
		var seal:Node3D=FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/show/encore_seal.glb")
		seal.rotation.x=PI/2;seal.position=Vector3(-.31 if actor==0 else .31,.76,.19);add_child(seal);_seals.append(seal)
	hide()

func configure(s:Dictionary,viewer:int,speed:float,returning_camera:bool=false)->void:
	if not is_node_ready():return
	var e:Dictionary=s.night.encore;var pending:bool=s.phase=="night_encore_offer"
	rotation.y=PI if viewer==1 else 0.0
	visible=pending or e.active
	var signature:String=JSON.stringify([pending,e.active,e.get("resume",-1),s.night.direction.seed])
	if signature==_signature:return
	_signature=signature
	_active=e.active
	if is_instance_valid(_motion):_motion.kill()
	for actor in 2:
		_seals[actor].position=Vector3(-.31 if actor==0 else .31,.76,.19)
		_seals[actor].visible=e.active or (pending and e.get("resume",-1)==actor)
	if not e.active:return
	var recipient:int=1-int(e.resume);var seal:Node3D=_seals[recipient];var finish:Vector3=seal.position
	seal.position=finish+Vector3(0,1.5,.7)
	seal.hide()
	_motion=create_tween();_motion.set_speed_scale(speed)
	# Let the shared-screen camera return before showing the consequential stamp.
	_motion.tween_interval(.85 if returning_camera else .70)
	_motion.tween_callback(func():seal.show())
	_motion.tween_property(seal,"position",finish,.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_motion.tween_callback(func():seal_landed.emit())
	_motion.tween_property(seal,"position",finish+Vector3(0,.07,.03),.045)
	_motion.tween_property(seal,"position",finish,.085)

func settle()->void:
	if is_instance_valid(_motion):_motion.kill()
	for actor in _seals.size():
		_seals[actor].position=Vector3(-.31 if actor==0 else .31,.76,.19)
		if _active:_seals[actor].show()

func is_animating()->bool:return is_instance_valid(_motion) and _motion.is_running()
