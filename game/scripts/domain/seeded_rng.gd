class_name SeededRng
extends RefCounted

var state: int

func _init(seed: int) -> void:
	state = seed & 0xffffffff
	if state == 0:
		state = 0x6d2b79f5

func next_float() -> float:
	state = (state + 0x6d2b79f5) & 0xffffffff
	var value := state
	value = (value ^ (value >> 15)) * (value | 1)
	value &= 0xffffffff
	value ^= value + ((value ^ (value >> 7)) * (value | 61) & 0xffffffff)
	value &= 0xffffffff
	value ^= value >> 14
	return float(value & 0xffffffff) / 4294967296.0

func int(minimum: int, maximum: int) -> int:
	if maximum < minimum:
		push_error("Invalid random range")
		return minimum
	return minimum + int(floor(next_float() * float(maximum - minimum + 1)))
