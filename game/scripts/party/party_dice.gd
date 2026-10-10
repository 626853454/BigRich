class_name FurPartyDice
extends Node3D
const Geometry=preload("res://scripts/party/pawn_geometry.gd")

var cube:Node3D
var rolling:=false
var clock:=0.0
var face:=1
var duration:=1.15
var target_rotation:=Vector3.ZERO
signal settled(value:int)

func _ready()->void:
	cube=Node3D.new();add_child(cube)
	var porcelain:=FurTravelArtAssets.instance("ceramic_dice_atelier");cube.add_child(porcelain)
	visible=false

func throw_value(value:int)->void:
	face=clampi(value,1,6);clock=0;rolling=true;visible=true;cube.rotation=Vector3.ZERO
	target_rotation=[Vector3.ZERO,Vector3(PI/2,0,0),Vector3(0,0,PI/2),Vector3(0,0,-PI/2),Vector3(-PI/2,0,0),Vector3(PI,0,0)][face-1]

func _process(delta:float)->void:
	if not rolling:return
	clock+=delta;var t:=minf(clock/duration,1.0)
	# Settle continuously onto the authoritative face. The old final-frame
	# Euler assignment could snap by 180 degrees after the visible tumble.
	var flight:=minf(t/.72,1.0)
	var spin_end:=Vector3(TAU*1.7,TAU*1.2,TAU*.8)
	if t<.72:
		cube.position.y=sin(flight*PI)*2.4
		cube.rotation=spin_end*flight
	else:
		var rest:float=(t-.72)/.28
		cube.position.y=sin(rest*PI)*.16*(1.0-rest)
		cube.quaternion=Quaternion.from_euler(spin_end).slerp(Quaternion.from_euler(target_rotation),smoothstep(0.0,1.0,rest))
	if t>=1:
		rolling=false;cube.position.y=0
		settled.emit(face)
