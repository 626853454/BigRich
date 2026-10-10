class_name GameStore
extends RefCounted

signal changed(state: RunState, message: String)

var state: RunState
var save_path := "user://dice-fire-caravan-run-v3.json"

func _init() -> void:
	state = RunEngine.new_state(int(Time.get_unix_time_from_system()))

func dispatch(action: Callable, save_after := true) -> Dictionary:
	var result: Dictionary = action.call(state)
	if not result.error.is_empty():
		changed.emit(state, result.error)
		return result
	state = result.state
	if save_after:
		save()
	changed.emit(state, result.message)
	return result

func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(SaveCodec.encode(state))
	return true

func restore() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var restored := SaveCodec.decode(file.get_as_text())
	if restored == null:
		return false
	state = restored
	changed.emit(state, "已恢复上次行程")
	return true
