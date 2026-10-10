class_name FurEntityPool
extends RefCounted

# Stable slots plus a dense active list: spawning and releasing are O(1).
var capacity: int
var active: Array[int] = []
var free_slots: Array[int] = []
var rank := PackedInt32Array()
var pos := PackedVector2Array()
var velocity := PackedVector2Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var life := PackedFloat32Array()
var marked := PackedFloat32Array()
var kind := PackedInt32Array()
var owner := PackedInt32Array()
var identity := PackedInt64Array()
var next_identity := 0
var penetration := PackedInt32Array()

func _init(limit: int) -> void:
	capacity = limit
	# Packed arrays are value types; resize each actual field explicitly.
	rank.resize(limit); pos.resize(limit); velocity.resize(limit)
	hp.resize(limit); max_hp.resize(limit); life.resize(limit); marked.resize(limit)
	kind.resize(limit); owner.resize(limit); identity.resize(limit); penetration.resize(limit)
	rank.fill(-1)
	for i in range(limit - 1, -1, -1): free_slots.append(i)

func acquire(position: Vector2, health: float = 1.0, variant: int = 0) -> int:
	if free_slots.is_empty(): return -1
	var slot: int = free_slots.pop_back()
	rank[slot] = active.size(); active.append(slot)
	pos[slot] = position; velocity[slot] = Vector2.ZERO
	hp[slot] = health; max_hp[slot] = health; life[slot] = 0
	marked[slot] = 0; kind[slot] = variant; owner[slot] = 0
	next_identity += 1; identity[slot] = next_identity
	penetration[slot] = 0
	return slot

func release(slot: int) -> void:
	if slot < 0 or slot >= capacity or rank[slot] < 0: return
	var last: int = active.back()
	var index: int = rank[slot]
	active[index] = last; rank[last] = index
	active.pop_back(); rank[slot] = -1; free_slots.append(slot)

func clear() -> void:
	while not active.is_empty(): release(active.back())
