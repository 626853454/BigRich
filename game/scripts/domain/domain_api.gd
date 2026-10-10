class_name DomainApi
extends RefCounted

const TownScript = preload("res://scripts/domain/town_content.gd")
const EngineScript = preload("res://scripts/domain/run_engine.gd")
const CodecScript = preload("res://scripts/domain/save_codec.gd")

func is_walkable(position: Vector2i) -> bool:
	return TownScript.is_walkable(position)

func is_spawn_walkable() -> bool:
	return TownScript.is_walkable(TownScript.SPAWN)

func new_state(run_seed: int):
	return EngineScript.new_state(run_seed)

func start_run(state, merchant: StringName) -> Dictionary:
	return EngineScript.start_run(state, merchant)

func move(state, delta: Vector2i) -> Dictionary:
	return EngineScript.move(state, delta)

func interact(state, location_id: StringName) -> Dictionary:
	return EngineScript.interact(state, location_id)

func roll_dice(state) -> Dictionary:
	return EngineScript.roll_dice(state)

func confirm_roll(state) -> Dictionary:
	return EngineScript.confirm_roll(state)

func choose_outcome(state, choice_id: StringName) -> Dictionary:
	return EngineScript.choose_outcome(state, choice_id)

func encode(state) -> String:
	return CodecScript.encode(state)

func decode(raw: String):
	return CodecScript.decode(raw)
