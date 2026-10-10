class_name PlayerController
extends CharacterBody3D

var tile_position := TownContent.SPAWN
var step_locked := false
var store: GameStore
var session: Node
var movement_tween: Tween

func sync_position() -> void:
	if movement_tween != null and movement_tween.is_running():
		movement_tween.kill()
	tile_position = store.state.position
	position = TileWorldMapper.to_world(tile_position) + Vector3(0, 0.7, 0)

func setup(game_store: GameStore, game_session: Node) -> void:
	store = game_store
	session = game_session
	position = TileWorldMapper.to_world(tile_position) + Vector3(0, 0.7, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		session.interact_nearby()
		get_viewport().set_input_as_handled()
		return

func _physics_process(_delta: float) -> void:
	if store == null or store.state.phase != RunState.PHASE_EXPLORING or step_locked:
		return
	var direction := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): direction = Vector2i(0, -1)
	elif Input.is_action_pressed("move_down"): direction = Vector2i(0, 1)
	elif Input.is_action_pressed("move_left"): direction = Vector2i(-1, 0)
	elif Input.is_action_pressed("move_right"): direction = Vector2i(1, 0)
	if direction != Vector2i.ZERO:
		step(_screen_direction(direction))

func _screen_direction(input_direction: Vector2i) -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return input_direction
	var world_direction := camera.global_basis.x * float(input_direction.x) + camera.global_basis.z * float(input_direction.y)
	if abs(world_direction.x) > abs(world_direction.z):
		return Vector2i(1 if world_direction.x > 0 else -1, 0)
	return Vector2i(0, 1 if world_direction.z > 0 else -1)

func step(direction: Vector2i) -> void:
	step_locked = true
	var result: Dictionary = session.move_player(direction)
	if result.error.is_empty():
		tile_position = result.state.position
		var visual := get_node_or_null("Visual") as Node3D
		if visual != null:
			visual.rotation.y = atan2(-float(direction.x), -float(direction.y))
		movement_tween = create_tween()
		movement_tween.set_trans(Tween.TRANS_SINE)
		movement_tween.tween_property(self, "position", TileWorldMapper.to_world(tile_position) + Vector3(0, 0.7, 0), 0.12)
	await get_tree().create_timer(0.14).timeout
	step_locked = false
