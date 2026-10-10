class_name RunEngine
extends RefCounted

const StateScript = preload("res://scripts/domain/run_state.gd")
const TownScript = preload("res://scripts/domain/town_content.gd")
const RngScript = preload("res://scripts/domain/seeded_rng.gd")

const GOAL_COINS := 18
const GOAL_REPUTATION := 3
const MAX_HEAT := 7

static func new_state(run_seed: int = 1) -> RunState:
	return StateScript.new(run_seed)

static func start_run(state: RunState, merchant: StringName) -> Dictionary:
	if state.phase != StateScript.PHASE_CAMP:
		return _fail(state, "当前不能开局")
	if merchant not in [&"accountant", &"smuggler", &"guildmaster"]:
		return _fail(state, "商人选择无效")
	var next := state.duplicate_state()
	next.phase = StateScript.PHASE_EXPLORING
	next.merchant_id = merchant
	match merchant:
		&"accountant":
			next.coins = 14; next.reputation = 1; next.reroll_tokens = 2
		&"smuggler":
			next.coins = 12; next.heat = 1; next.reroll_tokens = 1
		&"guildmaster":
			next.coins = 10; next.reputation = 2; next.reroll_tokens = 1
	return _ok(next, "run-started", "夜市的灯亮了。")

static func move(state: RunState, delta: Vector2i) -> Dictionary:
	if state.phase != StateScript.PHASE_EXPLORING:
		return _fail(state, "先完成当前互动")
	if abs(delta.x) + abs(delta.y) != 1 or not TownScript.is_walkable(state.position + delta):
		return _fail(state, "道路被挡住了")
	var next := state.duplicate_state()
	next.position += delta
	return _ok(next, "player-moved", "")

static func interact(state: RunState, location_id: StringName) -> Dictionary:
	if state.phase != StateScript.PHASE_EXPLORING:
		return _fail(state, "先完成当前互动")
	if not TownScript.is_in_reach(state.position, location_id):
		return _fail(state, "请走近地点再互动")
	if location_id == &"guild":
		return deliver(state)
	if state.visited.has(location_id):
		return _fail(state, "这个地点本局已经完成")
	var next := state.duplicate_state()
	if location_id == &"station":
		next.reroll_tokens += 1
		next.heat = maxi(0, next.heat - 1)
		next.visited.append(location_id)
		return _ok(next, "station-used", "驿站补充了改骰筹码。")
	next.pending_location = location_id
	next.dice = [0, 0]
	next.locked = [false, false]
	next.rolls_remaining = 0
	next.modified_this_turn = false
	next.last_safe_position = next.position
	next.phase = StateScript.PHASE_DICE
	return _ok(next, "interaction-started", "两颗骰子在黑暗里滚动。")

static func roll_dice(state: RunState) -> Dictionary:
	if state.phase != StateScript.PHASE_DICE or state.pending_location == &"":
		return _fail(state, "当前不能掷骰")
	var first: bool = state.dice[0] == 0
	if not first and state.rolls_remaining < 1:
		return _fail(state, "已经重掷过了")
	if not first and state.locked[0] and state.locked[1]:
		return _fail(state, "请先解锁至少一颗骰子")
	var free_reroll := state.sigils.has(&"cheap-reroll")
	if not first and not free_reroll and state.reroll_tokens < 1:
		return _fail(state, "改骰筹码不足，可去驿站补充")
	var next := state.duplicate_state()
	if not first and not free_reroll:
		next.reroll_tokens -= 1
	var rng := RngScript.new(next.rng_state)
	for index in 2:
		if first or not next.locked[index]:
			next.dice[index] = rng.int(1, 6)
	next.rng_state = rng.state
	next.rolls_remaining = 1 if first else 0
	return _ok(next, "dice-rolled", "掷出 %d + %d" % [next.dice[0], next.dice[1]])

static func lock_die(state: RunState, index: int) -> Dictionary:
	if state.phase != StateScript.PHASE_DICE or state.dice[0] == 0 or state.rolls_remaining < 1:
		return _fail(state, "当前不能锁骰")
	if index < 0 or index > 1:
		return _fail(state, "骰子编号无效")
	var next := state.duplicate_state()
	next.locked[index] = not next.locked[index]
	return _ok(next, "die-locked", "")

static func confirm_roll(state: RunState) -> Dictionary:
	if state.phase != StateScript.PHASE_DICE or state.dice[0] == 0:
		return _fail(state, "先掷骰再确认")
	var next := state.duplicate_state()
	next.phase = StateScript.PHASE_CHOICE
	return _ok(next, "dice-confirmed", "选择应对方式")

static func choose_outcome(state: RunState, choice_id: StringName) -> Dictionary:
	if state.phase != StateScript.PHASE_CHOICE or state.pending_location == &"":
		return _fail(state, "当前没有可结算的互动")
	if choice_id not in [&"safe", &"bold"]:
		return _fail(state, "互动选项无效")
	var next := state.duplicate_state()
	var total: int = next.dice[0] + next.dice[1]
	var threshold := 6 if choice_id == &"safe" else 9
	var cost := 0 if choice_id == &"safe" else 3
	if next.coins < cost:
		return _fail(state, "金币不足")
	next.coins -= cost
	var success := total >= threshold
	if success:
		if next.pending_location == &"shop": next.coins += 9 if choice_id == &"safe" else 18
		if next.pending_location == &"event": next.reputation += 2 if choice_id == &"safe" else 3
		if next.pending_location == &"risk":
			next.coins += 3 if choice_id == &"safe" else 12
			next.reputation += 1
		if next.sigils.has(&"locked-profit") and (next.locked[0] or next.locked[1]):
			next.coins += 2
		next.objectives.append(next.pending_location)
		next.visited.append(next.pending_location)
	else:
		if not next.sigils.has(&"quiet-exit"):
			next.heat += 1
	next.turn += 1
	next.pending_location = &""
	next.dice = [0, 0]
	next.locked = [false, false]
	next.phase = StateScript.PHASE_EXPLORING
	if success and next.objectives.size() == 2:
		next.pending_sigils = [&"cheap-reroll", &"quiet-exit", &"locked-profit"]
		next.phase = StateScript.PHASE_SIGIL
	return _ok(next, "interaction-finished", "成功" if success else "骰点不足，可以再次尝试")

static func choose_sigil(state: RunState, sigil: StringName) -> Dictionary:
	if state.phase != StateScript.PHASE_SIGIL or not state.pending_sigils.has(sigil):
		return _fail(state, "符印不在候选中")
	var next := state.duplicate_state()
	next.sigils.append(sigil)
	next.pending_sigils.clear()
	next.phase = StateScript.PHASE_EXPLORING
	return _ok(next, "sigil-gained", "获得符印")

static func deliver(state: RunState) -> Dictionary:
	if state.phase != StateScript.PHASE_EXPLORING or not TownScript.is_in_reach(state.position, &"guild"):
		return _fail(state, "请在探索时走近商会交单")
	for objective in TownScript.OBJECTIVES:
		if not state.objectives.has(objective):
			return _fail(state, "先完成三项委托")
	var next := state.duplicate_state()
	next.result = &"victory" if next.coins >= GOAL_COINS and next.reputation >= GOAL_REPUTATION and next.heat <= MAX_HEAT else &"defeat"
	next.phase = StateScript.PHASE_RESULT
	return _ok(next, "run-finished", "商会交单成功" if next.result == &"victory" else "交单完成")

static func _ok(state, event_type: StringName, message: String) -> Dictionary:
	return {"state": state, "event": event_type, "message": message, "error": ""}

static func _fail(state, message: String) -> Dictionary:
	return {"state": state, "event": &"", "message": message, "error": message}
