class_name FurPartyGrowth
extends RefCounted

# Local run adapter only. The original Model retains ownership of actual
# levelling. This copies its two cumulative XP counters between Party Arenas.
const COUNTER_LIMIT := 1000000
const KEYS := ["experience", "next_level_experience"]

static func _level(model: FurCombatModel) -> int:
	if model == null or model.players.size() != 2: return -1
	var first: Variant = model.players[0].build.get("level")
	var second: Variant = model.players[1].build.get("level")
	if typeof(first) != TYPE_INT or typeof(second) != TYPE_INT or first != second or first < 1 or first > 512: return -1
	return int(first)

static func _threshold(level: int) -> int:
	# Original cumulative loop: threshold += 20 + old_level * 8, then level++.
	return 4 * level * level + 16 * level

static func _valid(growth: Variant, level: int) -> bool:
	if level < 1 or not growth is Dictionary or growth.size() != 2: return false
	for key in KEYS:
		if not growth.has(key) or typeof(growth[key]) != TYPE_INT or growth[key] < 0 or growth[key] > COUNTER_LIMIT: return false
	if growth.next_level_experience != _threshold(level) or growth.experience >= growth.next_level_experience: return false
	return level == 1 or growth.experience >= _threshold(level - 1)

static func snapshot(model: FurCombatModel) -> Dictionary:
	if model == null: return {}
	var result: Dictionary = {"experience": model.experience, "next_level_experience": model.next_level_experience}
	return result if _valid(result, _level(model)) else {}

static func restore(model: FurCombatModel, growth: Variant) -> bool:
	if model == null or model.phase != "battle" or model.elapsed != 0.0 or model.tick_index != 0 or not growth is Dictionary: return false
	var level: int = _level(model)
	if growth.is_empty():
		return level == 1 and model.experience == 0 and model.next_level_experience == 20
	if not _valid(growth, level): return false
	# Both counters are validated before either assignment. Returned/input
	# dictionaries never remain attached to Model, so mutation cannot alias it.
	model.experience = int(growth.experience)
	model.next_level_experience = int(growth.next_level_experience)
	return true
