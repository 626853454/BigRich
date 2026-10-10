class_name FurPartyPawn
extends Node3D
const Assets=preload("res://scripts/party/soft_character_assets.gd")
var feet:Array[Node3D]=[]
var arms:Array[Node3D]=[]
var ears:Array[Node3D]=[]
var eyes:Array[Node3D]=[]
var phase:float=0.0
var walking:bool=false
var toy_index:int=0
var torso:Node3D
var scarf_tip:Node3D
var _walk_weight:float=0.0
var _clock:float=0.0
var _external_gait:=false
var _accessory:Node3D
var _character:Node3D

func build(index:int)->void:
	for child:Node in get_children():remove_child(child);child.queue_free()
	feet.clear();arms.clear();ears.clear();eyes.clear()
	toy_index=clampi(index,0,1)
	var character:Node3D=Assets.instantiate(toy_index);add_child(character)
	_character=character
	torso=character.find_child("SoftBodyRig",true,false) as Node3D
	scarf_tip=character.find_child("ScarfTip",true,false) as Node3D
	for side:String in ["L","R"]:
		var foot:Node3D=character.find_child("PaddedFoot_"+side,true,false) as Node3D
		var arm:Node3D=character.find_child("Arm_"+side,true,false) as Node3D
		var ear:Node3D=character.find_child("Ear_"+side,true,false) as Node3D
		var eye:Node3D=character.find_child("Eye_"+side,true,false) as Node3D
		if foot!=null:feet.append(foot)
		if arm!=null:arms.append(arm)
		if ear!=null:ears.append(ear)
		if eye!=null:eyes.append(eye)
	phase=0;_clock=0;_walk_weight=0;_external_gait=false
	_accessory=null

func set_seated(value:bool=true)->void:
	if is_instance_valid(_character):
		for material:ShaderMaterial in _character.get_meta("approved_coat_materials",[]):material.set_shader_parameter("seated_pose",1.0 if value else 0.0)

func set_style(style:int)->void:
	if not is_instance_valid(torso):return
	var travel_cap:=torso.find_child("TravelSailorCap",true,false) as Node3D
	if travel_cap!=null:travel_cap.visible=false
	if is_instance_valid(_accessory):torso.remove_child(_accessory);_accessory.queue_free()
	_accessory=Assets.hat(clampi(style,0,2));_accessory.name="BuildAccessory"
	_accessory.position=Vector3(0,2.46 if toy_index==0 else 2.45,.025);torso.add_child(_accessory)

func set_motion(gait_phase:float,gait_weight:float)->void:
	# Arena locomotion owns one distance-based gait for root and limbs. The
	# board keeps the original local walk clock for its discrete tile steps.
	if not is_finite(gait_phase) or not is_finite(gait_weight):return
	_external_gait=true;phase=fposmod(gait_phase,TAU);_walk_weight=clampf(gait_weight,0.0,1.0)

func _process(delta:float)->void:
	if not is_instance_valid(torso):return
	_clock=fmod(_clock+delta,120.0)
	if not _external_gait:
		_walk_weight=move_toward(_walk_weight,1.0 if walking else 0.0,delta*5.5)
		phase=fmod(phase+delta*lerpf(2.2,10.0,_walk_weight),TAU)
	for i in feet.size():feet[i].rotation.x=sin(phase+i*PI)*(.38*_walk_weight if _external_gait else lerpf(.012,.38,_walk_weight))
	for i in arms.size():arms[i].rotation.x=-sin(phase+i*PI)*(.30*_walk_weight if _external_gait else lerpf(.022,.30,_walk_weight))
	for i in ears.size():ears[i].rotation.x=sin(phase+.7*i)*lerpf(.012,.060,_walk_weight)
	if is_instance_valid(_character) and _character.has_meta("approved_coat_materials"):FurApprovedCharacter.motion(_character,phase,_walk_weight)
	torso.position.y=0.0 if _external_gait else lerpf(sin(phase)*.012,abs(sin(phase))*.055,_walk_weight)
	if is_instance_valid(scarf_tip):scarf_tip.rotation.x=sin(phase-.5)*.10*_walk_weight
	var blink_phase:float=fmod(_clock+toy_index*1.3,4.8)
	var openness:float=1.0-clampf(1.0-abs(blink_phase-.11)/.11,0,1)*.91 if blink_phase<.22 else 1.0
	for eye:Node3D in eyes:eye.scale.y=openness
