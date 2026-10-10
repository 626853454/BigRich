class_name FurHeroMotion
extends RefCounted

# Presentation state only. Never changes authority position, inputs or collisions.
# Distance drives the gait; continuous envelopes avoid input/idle pose jumps.
var position:=Vector3.ZERO
var velocity:=Vector3.ZERO
var yaw:=PI
var gait_phase:=0.0
var gait_weight:=0.0
var height:=0.0
var roll:=0.0
var pitch:=0.0
var scale:=Vector3.ONE
var initialized:=false
var gait_stride:=1.65
var gait_speed_limit:=INF
const TURN_RATE:=6.0

func reset(point:Vector3) -> void:
	position=point;velocity=Vector3.ZERO;yaw=PI;gait_phase=0;gait_weight=0
	height=0;roll=0;pitch=0;scale=Vector3.ONE;initialized=true

func advance(target:Vector3,delta:float,can_walk:bool,down:bool,dashing:bool,charge:float,hurt:float,celebrate:bool=false) -> void:
	if not initialized:reset(target)
	if delta<=0:return
	var dt:=minf(delta,.1)
	var before:=position
	var teleported:=position.distance_squared_to(target)>36
	# Large state corrections are teleports, not a sprint animation across the map.
	if teleported:
		position=target;velocity=Vector3.ZERO;gait_weight=0
	else:position=position.lerp(target,1-exp(-dt*22))
	var traveled:=position-before
	var measured:=traveled/dt if can_walk and not down and not teleported else Vector3.ZERO
	velocity=velocity.lerp(measured,1-exp(-dt*12))
	var speed:=Vector2(velocity.x,velocity.z).length()
	var weight:=clampf((speed-.15)/3.5,0,1) if can_walk and not down else 0.0
	gait_weight=lerpf(gait_weight,weight,1-exp(-dt*10))
	if can_walk and not down and not teleported:
		# Party toys use a longer stride and a cosmetic cadence cap during
		# dashes. Default values preserve legacy animation and all motion.
		var gait_distance:=minf(traveled.length(),dt*gait_speed_limit)
		gait_phase=fmod(gait_phase+gait_distance*TAU/gait_stride,TAU)
	elif celebrate and not down:gait_phase=fmod(gait_phase+dt*4,TAU)
	if speed>.35 and can_walk and not down:
		var desired:=atan2(-velocity.x,-velocity.z)
		yaw+=clampf(wrapf(desired-yaw,-PI,PI),-TURN_RATE*dt,TURN_RATE*dt)
	var bob:float=(.5-.5*cos(gait_phase*2))*.032*gait_weight
	if celebrate and not down:bob=(.5-.5*cos(gait_phase*2))*.06
	height=lerpf(height,0.0 if down else bob,1-exp(-dt*18))
	# One bounded recoil envelope replaces the old 10Hz oscillating body shake.
	var recoil:float=clampf(hurt/.18,0,1)*.035
	var target_roll:float=PI/2 if down else sin(gait_phase)*.018*gait_weight+recoil
	roll=lerpf(roll,target_roll,1-exp(-dt*(10 if down else 18)))
	pitch=lerpf(pitch,-.13 if dashing and not down else 0.0,1-exp(-dt*16))
	var compression:=clampf(charge,0,1) if not down else 0.0
	scale=scale.lerp(Vector3(1+compression*.025,1-compression*.035,1+compression*.025),1-exp(-dt*12))
