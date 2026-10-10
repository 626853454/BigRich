class_name SaveCodec
extends RefCounted

const TownScript = preload("res://scripts/domain/town_content.gd")
const StateScript = preload("res://scripts/domain/run_state.gd")

const SCHEMA := 3

static func encode(state) -> String:
	var payload := {
		"schemaVersion": SCHEMA,
		"seed": state.seed,
		"rngState": state.rng_state,
		"phase": state.phase,
		"merchantId": state.merchant_id,
		"position": {"x": state.position.x, "y": state.position.y},
		"lastSafePosition": {"x": state.last_safe_position.x, "y": state.last_safe_position.y},
		"pendingLocation": state.pending_location,
		"dice": state.dice,
		"locked": state.locked,
		"rollsRemaining": state.rolls_remaining,
		"modifiedThisTurn": state.modified_this_turn,
		"objectives": state.objectives,
		"visited": state.visited,
		"sigils": state.sigils,
		"pendingSigils": state.pending_sigils,
		"coins": state.coins,
		"reputation": state.reputation,
		"heat": state.heat,
		"rerollTokens": state.reroll_tokens,
		"turn": state.turn,
		"result": state.result,
	}
	return JSON.stringify(payload)

static func decode(raw: String) -> RunState:
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return null
	var parsed = parser.data
	if not parsed is Dictionary or parsed.get("schemaVersion", -1) != SCHEMA:
		return null
	for field in ["seed", "rngState", "phase", "merchantId", "pendingLocation", "dice", "locked", "rollsRemaining", "modifiedThisTurn", "objectives", "visited", "sigils", "pendingSigils", "coins", "reputation", "heat", "rerollTokens", "turn", "result"]:
		if not parsed.has(field):
			return null
	for field in ["seed", "rngState", "rollsRemaining", "coins", "reputation", "heat", "rerollTokens", "turn"]:
		if not (parsed[field] is int or parsed[field] is float) or float(parsed[field]) != floor(float(parsed[field])):
			return null
	for field in ["phase", "merchantId", "pendingLocation", "result"]:
		if not parsed[field] is String:
			return null
	for field in ["objectives", "visited", "sigils", "pendingSigils"]:
		if not parsed[field] is Array:
			return null
		for value in parsed[field]:
			if not value is String:
				return null
	if not parsed.modifiedThisTurn is bool or not parsed.dice is Array or not parsed.locked is Array:
		return null
	if parsed.dice.size() != 2 or parsed.locked.size() != 2:
		return null
	for die in parsed.dice:
		if not (die is int or die is float) or float(die) != floor(float(die)) or die < 0 or die > 6:
			return null
	for locked in parsed.locked:
		if not locked is bool:
			return null
	if not _valid_position(parsed.get("position", {})) or not _valid_position(parsed.get("lastSafePosition", {})):
		return null
	var state := StateScript.new(int(parsed.seed))
	state.rng_state = int(parsed.rngState)
	state.phase = StringName(parsed.phase)
	state.merchant_id = StringName(parsed.merchantId)
	state.position = Vector2i(int(parsed.position.x), int(parsed.position.y))
	state.last_safe_position = Vector2i(int(parsed.lastSafePosition.x), int(parsed.lastSafePosition.y))
	state.pending_location = StringName(parsed.pendingLocation)
	state.dice = [int(parsed.dice[0]), int(parsed.dice[1])]
	state.locked = Array(parsed.locked)
	state.rolls_remaining = int(parsed.rollsRemaining)
	state.modified_this_turn = bool(parsed.modifiedThisTurn)
	state.objectives = _names(parsed.objectives)
	state.visited = _names(parsed.visited)
	state.sigils = _names(parsed.sigils)
	state.pending_sigils = _names(parsed.pendingSigils)
	state.coins = int(parsed.coins)
	state.reputation = int(parsed.reputation)
	state.heat = int(parsed.heat)
	state.reroll_tokens = int(parsed.rerollTokens)
	state.turn = int(parsed.turn)
	state.result = StringName(parsed.result)
	if not _valid_state(state):
		return null
	return state

static func _valid_position(value: Variant) -> bool:
	if not value is Dictionary or not value.has("x") or not value.has("y"):
		return false
	for coordinate in [value.x, value.y]:
		if not (coordinate is int or coordinate is float) or float(coordinate) != floor(float(coordinate)):
			return false
	return TownScript.is_walkable(Vector2i(int(value.x), int(value.y)))

static func _names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value in values:
			result.append(StringName(value))
	return result

static func _valid_state(state: RunState) -> bool:
	if state.phase not in [StateScript.PHASE_CAMP, StateScript.PHASE_EXPLORING, StateScript.PHASE_DICE, StateScript.PHASE_CHOICE, StateScript.PHASE_SIGIL, StateScript.PHASE_RESULT]:
		return false
	if state.rolls_remaining < 0 or state.rolls_remaining > 1 or state.turn < 0:
		return false
	for objective in state.objectives:
		if objective not in TownScript.OBJECTIVES:
			return false
	for location in state.visited:
		if not TownScript.LOCATIONS.has(location):
			return false
	for sigil in state.sigils + state.pending_sigils:
		if sigil not in [&"cheap-reroll", &"quiet-exit", &"locked-profit"]:
			return false
	if state.phase == StateScript.PHASE_CAMP:
		return state.merchant_id == &""
	if state.merchant_id not in [&"accountant", &"smuggler", &"guildmaster"]:
		return false
	if state.coins < 0 or state.reputation < 0 or state.heat < 0 or state.reroll_tokens < 0:
		return false
	if state.phase in [StateScript.PHASE_DICE, StateScript.PHASE_CHOICE] and state.pending_location == &"":
		return false
	if state.phase in [StateScript.PHASE_DICE, StateScript.PHASE_CHOICE] and state.pending_location not in TownScript.OBJECTIVES:
		return false
	if state.phase == StateScript.PHASE_CHOICE and (state.dice[0] < 1 or state.dice[1] < 1):
		return false
	if state.phase == StateScript.PHASE_SIGIL and state.pending_sigils.is_empty():
		return false
	return true
