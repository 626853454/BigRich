class_name FurEnemyBehaviors
extends RefCounted

# Authority-only enemy actions. Clients consume presentation dictionaries.
const STATE_LIMIT := 256
const PROJECTILE_LIMIT := 36
const WARNING_LIMIT := 24
const CHARGE_WINDUP := .6
const CHARGE_DURATION := .35
const CHARGE_SPEED := 9.0
const RANGER_WINDUP := .7
const COOLDOWN := 4.0
const PROJECTILE_SPEED := 9.0
const PROJECTILE_TTL := 3.0
const FAN_ANGLE := .16
const INTERRUPT_STAGGER := .45
const INTERRUPT_RECOVER := 1.2
const INTERRUPT_COOLDOWN := 2.5
const INTERRUPT_TICK_LIMIT := 8
const INTERRUPT_KINDS := ["pot_wave","followup_volley","chain_bait"]
var authority := false
var states: Dictionary = {}
var projectiles: Array[Dictionary] = []
var sequence := 0
var dropped_bursts := 0
var context_seed := -1
var context_wave := -1
var last_tick := -1
var context_run_token := -1
var interrupt_tick := -1
var interrupt_count := 0
var interrupt_feedback: Dictionary = {}
var interrupt_feedback_taken := false

func reset() -> void:
	states.clear(); projectiles.clear(); sequence = 0; dropped_bursts = 0
	context_seed = -1; context_wave = -1; last_tick = -1
	context_run_token = -1; interrupt_tick = -1; interrupt_count = 0; interrupt_feedback = {}
	interrupt_feedback_taken = false

func _ensure_context(model: FurCombatModel) -> void:
	var token:int=int(model.board.state.get("run_token",0))
	if context_seed != model.seed_value or context_wave != model.wave or context_run_token != token or model.tick_index < last_tick:
		reset(); context_seed = model.seed_value; context_wave = model.wave
		context_run_token = token
	last_tick = model.tick_index

func prune(model: FurCombatModel) -> void:
	_ensure_context(model)
	# One bounded state scan per authority frame, never one scan per enemy.
	for identity in states.keys():
		var state: Dictionary = states[identity]
		var slot: int = state.slot
		if slot < 0 or slot >= model.enemies.capacity or model.enemies.rank[slot] < 0 or model.enemies.identity[slot] != identity or model.enemies.kind[slot] not in [3, 4]:
			states.erase(identity)
	for index in range(projectiles.size() - 1, -1, -1):
		if not _owner_alive(model, int(projectiles[index].owner_id)): projectiles.remove_at(index)

func command(model: FurCombatModel, slot: int, target: Vector2, delta: float) -> Dictionary:
	var result := {"handled": false, "velocity": Vector2.ZERO, "contact_damage": 0.0, "state": "none"}
	if slot < 0 or slot >= model.enemies.capacity or model.enemies.rank[slot] < 0: return result
	var kind: int = model.enemies.kind[slot]
	if kind not in [3, 4]: return result
	result.handled = true
	if not authority or model.phase != "battle" or not target.is_finite() or not is_finite(delta) or delta <= 0: return result
	_ensure_context(model)
	var identity: int = model.enemies.identity[slot]
	var point: Vector2 = model.enemies.pos[slot]
	if not states.has(identity):
		if states.size() >= STATE_LIMIT: return result
		states[identity] = {"slot": slot, "kind": kind, "phase": "windup" if kind == 3 else "cooldown", "remaining": CHARGE_WINDUP if kind == 3 else 0.0, "direction": _direction(point, target), "origin": point, "pos": point,"interrupt_next":0.0,"payoff_ids":{}}
		if kind == 3: model.emit("charger_warning", point, CHARGE_WINDUP)
	var state: Dictionary = states[identity]
	state.pos = point
	var dt := minf(delta, .05)
	if kind == 3:
		var movement := _charger(model, state, point, target, dt)
		result.velocity = movement.displacement / dt
		result.contact_damage = 12.0 if movement.charging else 0.0
	else:
		var was_stagger:bool=state.phase=="stagger"
		result.velocity = _ranger(model, identity, state, point, target, dt)
		result.contact_damage = 0.0 if was_stagger or state.phase=="stagger" else 8.0
	result.state = state.phase
	return result

func _charger(model: FurCombatModel, state: Dictionary, point: Vector2, target: Vector2, dt: float) -> Dictionary:
	var budget := dt
	var displacement := Vector2.ZERO
	var charging := false
	for transition in 3:
		if budget <= .000001: break
		var portion := minf(budget, maxf(0, float(state.remaining)))
		if state.phase == "charge":
			displacement += state.direction * CHARGE_SPEED * portion; charging = charging or portion > 0
		elif state.phase == "cooldown": displacement += _direction(point + displacement, target) * 1.2 * portion
		state.remaining = maxf(0, float(state.remaining) - portion); budget -= portion
		if float(state.remaining) > .000001: break
		match str(state.phase):
			"stagger": state.phase = "cooldown"; state.remaining = INTERRUPT_RECOVER
			"windup": state.phase = "charge"; state.remaining = CHARGE_DURATION
			"charge": state.phase = "cooldown"; state.remaining = COOLDOWN
			"cooldown":
				state.phase = "windup"; state.remaining = CHARGE_WINDUP
				state.direction = _direction(point + displacement, target); state.origin = point + displacement
				model.emit("charger_warning", state.origin, CHARGE_WINDUP)
	return {"displacement": displacement, "charging": charging}

func _ranger(model: FurCombatModel, identity: int, state: Dictionary, point: Vector2, target: Vector2, dt: float) -> Vector2:
	if state.phase=="stagger":
		state.remaining=maxf(0,float(state.remaining)-dt)
		if float(state.remaining)<=.000001:state.phase="cooldown";state.remaining=INTERRUPT_RECOVER
		return Vector2.ZERO
	if state.phase == "windup":
		state.remaining = maxf(0, float(state.remaining) - dt)
		if float(state.remaining) <= .000001:
			_fire_fan(model, identity, point, state.direction)
			state.phase = "cooldown"; state.remaining = COOLDOWN
		return Vector2.ZERO
	state.remaining = maxf(0, float(state.remaining) - dt)
	var distance := point.distance_to(target)
	var direction := _direction(point, target)
	if distance > 8.0: return direction * 1.5
	if distance < 6.0: return -direction * 1.5
	if float(state.remaining) <= .000001:
		state.phase = "windup"; state.remaining = RANGER_WINDUP
		state.direction = direction; state.origin = point
		model.emit("ranger_warning", point, RANGER_WINDUP)
	return Vector2.ZERO

# Call only after an authority-owned payoff accepted an actual hit. No damage/money.
# Stable source IDs are monotonic per payoff kind; normal attacks never call this.
func interrupt(model:FurCombatModel,slot:Variant,expected_identity:Variant,owner:Variant,payoff_kind:Variant,payoff_id:Variant)->Dictionary:
	if not authority or model.phase!="battle":return _interrupt_reject("not_authority")
	if not slot is int or slot<0 or slot>=model.enemies.capacity or model.enemies.rank[slot]<0 or not expected_identity is int or expected_identity<1 or model.enemies.identity[slot]!=expected_identity:return _interrupt_reject("stale_identity")
	if not owner is int or owner<0 or owner>=model.players.size() or not payoff_kind is String or payoff_kind not in INTERRUPT_KINDS or not payoff_id is int or payoff_id<1:return _interrupt_reject("bad_payoff")
	if model.players[owner].down or not is_finite(model.elapsed) or model.elapsed<0 or model.tick_index<0 or not model.enemies.pos[slot].is_finite() or not model.board.state.get("run_token") is int or model.board.state.run_token<1:return _interrupt_reject("bad_live_facts")
	var build:Dictionary=model.players[owner].build
	var built:bool=(payoff_kind=="pot_wave" and build.style==0 and build.masterwork=="verdict") or (payoff_kind=="followup_volley" and build.style==1 and build.masterwork in ["assembly","piercing"]) or (payoff_kind=="chain_bait" and build.style==2 and build.masterwork=="chain" and build.bait_chain)
	if not built or model.enemies.kind[slot] not in [3,4]:return _interrupt_reject("not_formed_or_target")
	_ensure_context(model)
	if not states.has(expected_identity):return _interrupt_reject("not_warning")
	var state:Dictionary=states[expected_identity]
	if state.slot!=slot or state.kind!=model.enemies.kind[slot] or state.phase!="windup" or not is_finite(float(state.remaining)) or float(state.remaining)<=0:return _interrupt_reject("not_warning")
	if model.elapsed<float(state.interrupt_next) or payoff_id<=int(state.payoff_ids.get(payoff_kind,0)):return _interrupt_reject("cooldown_or_duplicate")
	if interrupt_tick==model.tick_index and interrupt_count>=INTERRUPT_TICK_LIMIT:return _interrupt_reject("tick_budget")
	if interrupt_tick!=model.tick_index:
		interrupt_tick=model.tick_index;interrupt_count=0;interrupt_feedback={};interrupt_feedback_taken=false
	state.phase="stagger";state.remaining=INTERRUPT_STAGGER;state.interrupt_next=model.elapsed+INTERRUPT_COOLDOWN;state.payoff_ids[payoff_kind]=payoff_id
	interrupt_count+=1
	if not interrupt_feedback_taken:
		if interrupt_feedback.is_empty():interrupt_feedback={"kind":"payoff_interrupt","point":model.enemies.pos[slot],"value":interrupt_count,"owner":owner,"extra":true,"tick":model.tick_index}
		else:interrupt_feedback.value=interrupt_count
	return {"ok":true,"interrupted":true,"identity":expected_identity,"kind":state.kind,"phase":"stagger","duration":INTERRUPT_STAGGER}

func take_interrupt_feedback(model:FurCombatModel)->Dictionary:
	if not authority or model.phase!="battle":return {"ok":false,"events":[]}
	_ensure_context(model)
	var events:Array[Dictionary]=[]
	if interrupt_tick==model.tick_index and not interrupt_feedback_taken and not interrupt_feedback.is_empty():
		events.append(interrupt_feedback.duplicate(true));interrupt_feedback={};interrupt_feedback_taken=true
	return {"ok":true,"events":events}

static func _interrupt_reject(reason:String)->Dictionary:return {"ok":false,"interrupted":false,"reason":reason}

func _fire_fan(model: FurCombatModel, identity: int, point: Vector2, direction: Vector2) -> void:
	if projectiles.size() + 3 > PROJECTILE_LIMIT: dropped_bursts += 1; return
	for index in 3:
		sequence += 1
		projectiles.append({"id": sequence, "owner_id": identity, "pos": point, "velocity": direction.rotated((index - 1) * FAN_ANGLE) * PROJECTILE_SPEED, "ttl": PROJECTILE_TTL, "damage": 8.0})
	model.emit("enemy_volley", point, 3)

func tick_projectiles(model: FurCombatModel, delta: float) -> void:
	if not authority or model.phase != "battle" or not is_finite(delta) or delta <= 0: return
	_ensure_context(model)
	var dt := minf(delta, .05)
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		if not _owner_alive(model, int(shot.owner_id)):
			projectiles.remove_at(index); continue
		shot.ttl = maxf(0, float(shot.ttl) - dt)
		if float(shot.ttl) <= 0:
			projectiles.remove_at(index); continue
		var from: Vector2 = shot.pos
		var desired: Vector2 = from + shot.velocity * dt
		var resolved: Vector2 = desired if model.skip_board_for_checks else model.district.resolve_motion(from, desired, .14)
		# Clip against the first wall/boundary before testing victims. Even a victim
		# behind a thin wall cannot be hit by the unresolved part of this segment.
		var blocked := not desired.is_equal_approx(resolved)
		var segment := resolved - from
		var victim := -1
		var earliest := INF
		for player_index in model.players.size():
			var player: Dictionary = model.players[player_index]
			if player.down: continue
			if not model.skip_board_for_checks and _wall_between(model, from, player.pos): continue
			var fraction := clampf((player.pos - from).dot(segment) / segment.length_squared(), 0.0, 1.0) if segment.length_squared() > .000001 else 0.0
			if player.pos.distance_squared_to(from + segment * fraction) <= .58 * .58 and fraction < earliest:
				earliest = fraction; victim = player_index
		if victim >= 0:
			model.hurt_player(victim, float(shot.damage)); projectiles.remove_at(index)
		elif blocked: projectiles.remove_at(index)
		else: shot.pos = resolved

func _owner_alive(model: FurCombatModel, identity: int) -> bool:
	if not states.has(identity): return false
	var slot: int = states[identity].slot
	return slot >= 0 and slot < model.enemies.capacity and model.enemies.rank[slot] >= 0 and model.enemies.identity[slot] == identity

func _direction(point: Vector2, target: Vector2) -> Vector2:
	var difference := target - point
	return difference.normalized() if difference.length_squared() > .000001 else Vector2(0, -1)

func _wall_between(model: FurCombatModel, from: Vector2, to: Vector2) -> bool:
	for obstacle in model.district.state.obstacles:
		var wall: Rect2 = obstacle.grow(.10)
		var low := 0.0; var high := 1.0; var valid := true
		var direction := to - from
		for axis in 2:
			var source: float = from[axis]; var step: float = direction[axis]
			if absf(step) < .000001:
				if source < wall.position[axis] or source > wall.end[axis]: valid = false; break
			else:
				var enter: float = (wall.position[axis] - source) / step
				var leave: float = (wall.end[axis] - source) / step
				if enter > leave: var saved := enter; enter = leave; leave = saved
				low = maxf(low, enter); high = minf(high, leave)
				if low > high: valid = false; break
		if valid: return true
	return false

func presentation() -> Dictionary:
	var warnings: Array[Dictionary] = []
	for identity in states:
		var state: Dictionary = states[identity]
		if state.phase != "windup" or warnings.size() >= WARNING_LIMIT: continue
		# Knockback can shift an enemy during its warning. Follow its actual body
		# while retaining the originally committed attack direction.
		warnings.append({"id": identity, "kind": state.kind, "pos": state.pos, "direction": state.direction, "length": CHARGE_SPEED * CHARGE_DURATION if state.kind == 3 else 9.0, "ttl": state.remaining})
	var shots: Array[Dictionary] = []
	for shot in projectiles: shots.append({"id": shot.id, "pos": shot.pos, "velocity": shot.velocity, "ttl": shot.ttl})
	return {"warnings": warnings, "projectiles": shots}
