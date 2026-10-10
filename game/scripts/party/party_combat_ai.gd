class_name FurPartyCombatAI
extends RefCounted

# Read-only local ally controller. The model still owns movement, attacks,
# invulnerability, revival and goal accumulation. No RNG or navigation cache.
const ENEMY_BUDGET := 80
const HAZARD_BUDGET := 8
const X_LIMIT := 12.8
const Y_LIMIT := 8.2
const ARRIVAL := .32
const EVADE_DISTANCE := 2.5
const ESCAPE_DIRECTIONS := [Vector2.RIGHT, Vector2(.70710678, .70710678), Vector2.DOWN,
	Vector2(-.70710678, .70710678), Vector2.LEFT, Vector2(-.70710678, -.70710678),
	Vector2.UP, Vector2(.70710678, -.70710678)]

static func movement(model: FurCombatModel, elapsed: float) -> Vector2:
	if model == null or model.phase != "battle" or model.players.size() != 2 or not is_finite(elapsed):
		return Vector2.ZERO
	var ally: Dictionary = model.players[1]
	var human: Dictionary = model.players[0]
	if ally.down or not _point(ally.pos) or not _point(human.pos): return Vector2.ZERO
	var position: Vector2 = ally.pos
	var escape: Vector2 = _escape_hazards(model, position)
	if escape.length_squared() > .01: return escape
	if human.down: return _towards(position, human.pos, 1.2)
	var away := Vector2.ZERO
	for index in mini(ENEMY_BUDGET, model.enemies.active.size()):
		var slot: int = model.enemies.active[index]
		if model.enemies.rank[slot] < 0 or not _point(model.enemies.pos[slot]): continue
		var difference: Vector2 = position - model.enemies.pos[slot]
		var distance: float = difference.length_squared()
		if distance < EVADE_DISTANCE * EVADE_DISTANCE:
			if distance < .001: difference = Vector2.RIGHT if model.enemies.identity[slot] % 2 else Vector2.LEFT
			away += difference.normalized() / maxf(distance, .15)
	if away.length_squared() > .025:
		return _safe_step(model, position, away.normalized())
	if model.route == 2 and not model.rule_state.is_empty() and not model.rule_state.get("rewarded", false) and _point(model.rule_state.get("point")):
		var point: Vector2 = model.rule_state.point
		var target: Vector2 = point
		var human_occupies: bool = human.input.length_squared() < .02 and human.pos.distance_squared_to(point) < 4.41 and human.invuln < .6
		if human_occupies:
			# Cover beside P1, inside the real 2.1m objective radius. A fixed
			# center fallback avoids revolving around a stationary teammate.
			var side: Vector2 = point - human.pos
			if side.length_squared() < .04: side = Vector2.RIGHT
			target = point + side.normalized() * 1.25
		var travel: Vector2 = _towards(position, target, ARRIVAL)
		if travel != Vector2.ZERO: return _safe_step(model, position, travel)
		return _charged_step(model, position, ally, elapsed)
	# A gun's stationary charge remains purposeful after the goal is done.
	if int(ally.build.style) == 1 and float(ally.charge) < 2.49 and position.length() < 10.0:
		return Vector2.ZERO
	var follow: Vector2 = human.pos + Vector2(sin(elapsed * .7), cos(elapsed * .7)) * 2.5
	return _safe_step(model, position, _towards(position, follow, .45))

static func _charged_step(model: FurCombatModel, position: Vector2, ally: Dictionary, elapsed: float) -> Vector2:
	if int(ally.build.style) != 1 or float(ally.charge) < 2.49: return Vector2.ZERO
	# One real step releases the usual charged attack; no extra shot is made
	# by the controller. The model resets charge after successful firing.
	return _safe_step(model, position, Vector2(cos(elapsed * .7), sin(elapsed * .7)))

static func _escape_hazards(model: FurCombatModel, position: Vector2) -> Vector2:
	var inside := false
	for index in mini(HAZARD_BUDGET, model.hazards.size()):
		var hazard: Dictionary = model.hazards[index]
		if not _hazard(hazard): continue
		if position.distance_to(hazard.pos) < float(hazard.radius) + .5: inside = true; break
	if not inside: return Vector2.ZERO
	var best := Vector2.ZERO
	var score := -INF
	for direction in ESCAPE_DIRECTIONS:
		var proposed: Vector2 = _clamp(position + direction * .9)
		if proposed.distance_squared_to(position) < .04: continue
		var current_score: float = _clearance(model, proposed)
		if current_score > score:
			score = current_score; best = (proposed - position).normalized()
	return best

static func _safe_step(model: FurCombatModel, position: Vector2, direction: Vector2) -> Vector2:
	if direction.length_squared() < .01: return Vector2.ZERO
	var proposed: Vector2 = _clamp(position + direction.normalized() * .9)
	if proposed.distance_squared_to(position) < .01: return Vector2.ZERO
	if _clearance(model, proposed) < 0.0:
		# Do not enter a fresh warning while pursuing a teammate/goal. Choose
		# a tangent with safe clearance, or stop if every route is threatened.
		var tangent := Vector2(-direction.y, direction.x).normalized()
		for option in [tangent, -tangent]:
			var turn: Vector2 = _clamp(position + option * .9)
			if turn.distance_squared_to(position) > .04 and _clearance(model, turn) >= 0.0: return (turn-position).normalized()
		return Vector2.ZERO
	return (proposed - position).normalized()

static func _clearance(model: FurCombatModel, point: Vector2) -> float:
	var value := 100.0
	for index in mini(HAZARD_BUDGET, model.hazards.size()):
		var hazard: Dictionary = model.hazards[index]
		if _hazard(hazard): value = minf(value, point.distance_to(hazard.pos) - float(hazard.radius) - .5)
	return value

static func _hazard(hazard: Dictionary) -> bool:
	return _point(hazard.get("pos")) and typeof(hazard.get("radius")) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(hazard.radius)) and float(hazard.radius) > 0.0 and typeof(hazard.get("ttl")) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(hazard.ttl)) and float(hazard.ttl) > 0.0

static func _point(value: Variant) -> bool:
	return value is Vector2 and is_finite(value.x) and is_finite(value.y)

static func _clamp(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, -X_LIMIT, X_LIMIT), clampf(point.y, -Y_LIMIT, Y_LIMIT))

static func _towards(position: Vector2, target: Vector2, tolerance: float) -> Vector2:
	return (target-position).normalized() if position.distance_squared_to(target) > tolerance*tolerance else Vector2.ZERO
