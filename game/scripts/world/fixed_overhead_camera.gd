class_name FixedOverheadCamera
extends Camera3D

# Keep a fixed viewing direction while tracking the traveler through the streets.
@export var target := Vector3(0, 1.0, -1.5)
@export var distance := 19.5
@export var yaw_degrees := 172.0
@export var elevation_degrees := 27.0
var subject: Node3D

func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 48.0
	current = true
	_refresh_transform()

func _process(delta: float) -> void:
	if is_instance_valid(subject):
		var desired := subject.global_position + Vector3(0, 0.3, -1.5)
		target = target.lerp(desired, 1.0 - exp(-delta * 4.0))
	_refresh_transform()

func _refresh_transform() -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var elevation := deg_to_rad(elevation_degrees)
	var horizontal := cos(elevation) * distance
	global_position = target + Vector3(sin(yaw) * horizontal, sin(elevation) * distance, cos(yaw) * horizontal)
	look_at(target, Vector3.UP)
