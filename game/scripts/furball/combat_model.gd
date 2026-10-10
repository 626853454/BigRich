class_name FurCombatModel
extends RefCounted

# Pure authority-side simulation. No meshes, audio, UI, or multiplayer calls here.
const ENEMY_LIMIT := 256
const SHOT_LIMIT := 192
const PICKUP_LIMIT := 192
const WAVE_SECONDS := 35.0
const MAX_WAVES := 6
const SharedOrder=preload("res://scripts/furball/shared_order.gd")
const Patrol=preload("res://scripts/furball/patrol_rival.gd")
const TaskFormations=preload("res://scripts/furball/task_formations.gd")
const ChallengeContract=preload("res://scripts/furball/challenge_contract.gd")
const CartImpact=preload("res://scripts/furball/cart_impact.gd")
var enemies := FurEntityPool.new(ENEMY_LIMIT)
var shots := FurEntityPool.new(SHOT_LIMIT)
var pickups := FurEntityPool.new(PICKUP_LIMIT)
var grid := FurSpatialGrid.new()
var rng := RandomNumberGenerator.new()
var draft_rng := RandomNumberGenerator.new()
var route_rng := RandomNumberGenerator.new()
var order_reward_rng := RandomNumberGenerator.new()
var players: Array[Dictionary] = []
var events: Array[Dictionary] = []
var baits: Array[Dictionary] = []
var phase := "camp"
var wave := 0
var remaining := WAVE_SECONDS
var elapsed := 0.0
var spawn_clock := 0.0
var max_enemies := 80
var experience := 0
var next_level_experience := 20
var seed_value := 1
var route := 0
var draft_options: Array = []
var draft_done: Array[bool] = []
var dice := Vector2i(1,2)
var peak_enemies := 0
var event_drops := 0
var tick_index := 0
var event_sequence := 0
var network_events: Array[Dictionary] = []
var network_fx: Array[Dictionary] = []
var rule_state: Dictionary = {}
var hazards: Array[Dictionary] = []
var route_history: Array[int] = []
var rule_rewards := 0
var last_combo_feedback := -1.0
var boss_pattern := 0
var boss_cycles := 0
var board := FurBoardRuntime.new()
var district := FurDistrictRuntime.new()
var payoff := FurBuildPayoff.new()
var payoff_state:Dictionary = {}
var debug_run := false
var debug_history:Array[Dictionary] = []
var skip_board_for_checks := false
var district_cash := 0
var estate := FurEstateBenefits.new()
var enemy_behaviors:=FurEnemyBehaviors.new()
var enemy_behavior_state:Dictionary={}
var director:=FurEncounterDirector.new()
var round_results:Array[Dictionary]=[]
var pending_supply_effects:Array[Dictionary]=[]
var shared_order:=SharedOrder.new()
var patrol:=Patrol.new()
var task_formations:=TaskFormations.new()
var task_formation_preview:Dictionary={}
var challenge_contract:=ChallengeContract.new()
var cart_impact:=CartImpact.new()
var order_draft_pending:Array[bool]=[]
var draft_is_order:Array[bool]=[]
var draft_revisions:Array[int]=[]

func start(styles: Array[int], run_seed: int = 73015, skip_board:bool=false, run_token:int=0) -> void:
	# All run-scoped domains use the same positive INT31 identity, including callers
	# that enter the model directly instead of Session's seed input adapter.
	run_seed=clampi(run_seed,1,2147483647)
	skip_board_for_checks=skip_board;debug_run=false;debug_history.clear()
	cart_impact.reset()
	board.start(run_seed,styles.size(),run_token);payoff.reset();payoff_state={};district_cash=0
	shared_order.configure(run_seed,styles.size(),int(board.state.run_token))
	patrol.configure(run_seed,int(board.state.run_token))
	task_formations.clear();task_formation_preview={}
	challenge_contract.configure(run_seed,int(board.state.run_token),0,-1,false)
	order_draft_pending.clear();draft_is_order.clear();draft_revisions.clear()
	for index in styles.size():
		order_draft_pending.append(false);draft_is_order.append(false);draft_revisions.append(0)
	estate.state={"district_id":0,"level":0,"boost_remaining":0.0,"activations":0}
	enemy_behaviors.authority=true;enemy_behaviors.reset();enemy_behavior_state={}
	round_results.clear();pending_supply_effects.clear()
	seed_value = run_seed; rng.seed = run_seed
	draft_rng.seed=run_seed ^ 0x35a741c9
	route_rng.seed=run_seed ^ 0x5f3759df
	order_reward_rng.seed=run_seed ^ 0x4e21aac7
	players.clear(); enemies.clear(); shots.clear(); pickups.clear(); baits.clear()
	events.clear(); experience = 0; next_level_experience=20; elapsed = 0; wave = 0; peak_enemies = 0
	event_drops=0;tick_index=0
	event_sequence=0;network_events.clear();network_fx.clear()
	hazards.clear();route_history.clear();rule_rewards=0
	last_combo_feedback=-1.0
	boss_pattern=0;boss_cycles=0
	for index in styles.size():
		var build := FurBuildCatalog.create(styles[index])
		players.append({"pos":Vector2(-1.8+index*3.6,0), "hp":100.0, "build":build,
			"input":Vector2.ZERO,"dash":0.0,"dash_cd":0.0,"invuln":0.0,"attack_cd":.2,
			"skill_cd":0.0,"charge":0.0,"pot":0.0,"down":false,"revive":0.0,"aura":0.0})
	if skip_board:next_wave(0)
	else:phase="board";draft_options.clear();draft_done.clear();district.reset()

func emit(kind: String, point: Vector2, value: float = 0, owner: int = 0, extra: bool = false) -> void:
	event_sequence += 1
	var event := {"kind":kind,"pos":point,"value":value,"owner":owner,"extra":extra,"sequence":event_sequence,"time":elapsed,"wave":wave}
	if events.size() < 96:
		events.append(event)
	else:
		event_drops += 1
		if kind not in ["hit","pop"]:
			for index in events.size():
				if events[index].kind in ["hit","pop"]:events[index]=event;break
	# Keep gameplay warnings separate from presentation consumption. Cosmetic hit
	# traffic must never evict a warning before a host snapshot is published.
	if kind != "hit" and kind != "pop":
		if network_events.size() >= 96: network_events.pop_front()
		network_events.append(event)
	else:
		if network_fx.size() >= 48: network_fx.pop_front()
		network_fx.append(event)

func next_wave(modifier: int) -> void:
	payoff.clear_pending();payoff_state={}
	wave += 1; route = modifier; remaining = WAVE_SECONDS; spawn_clock = 0
	district.configure(board.district_id() if not skip_board_for_checks else route,wave,seed_value+wave*101)
	var cart_configured:bool=cart_impact.configure(int(board.state.run_token),wave,int(district.state.district_id))
	assert(cart_configured,"Cart context must match actual battle")
	if not skip_board_for_checks:shared_order.begin_battle(int(district.state.district_id),wave)
	enemy_behaviors.reset();enemy_behavior_state={}
	var pressure_add:=0.0
	if not skip_board_for_checks:
		var patrol_entry:Dictionary=patrol.begin_battle(wave,int(district.state.district_id),int(board.state.position),int(board.state.run_token))
		assert(patrol_entry.get("ok",false),"Patrol must start from the actual sequential board landing")
		var pressure:Dictionary=Patrol.combined_pressure(float(board.state.get("event_pressure_add",0)),bool(patrol_entry.get("pressure_active",false)),bool(board.state.challenge))
		pressure_add=float(pressure.get("pressure_add",0))
	director.configure(int(district.state.district_id),wave,seed_value,not skip_board_for_checks and board.state.challenge,pressure_add)
	var formations_configured:bool=task_formations.configure(seed_value,int(board.state.run_token),wave,int(district.state.district_id))
	assert(formations_configured,"Task formation context must match the actual battle")
	task_formation_preview={}
	challenge_contract.configure(seed_value,int(board.state.run_token),wave,int(district.state.district_id),not skip_board_for_checks and bool(board.state.challenge),elapsed)
	if not skip_board_for_checks and round_results.size()<MAX_WAVES:
		round_results.append({"round":wave,"district_id":int(district.state.district_id),"objective_completed":false,"challenge":bool(board.state.challenge),"battle_completed":false,"challenge_rule_version":ChallengeContract.RULE_VERSION,"challenge_available":false,"challenge_qualified":false,"challenge_result":{}})
	rule_state = FurRouteCatalog.state(route, wave)
	rule_state["started_at"] = elapsed
	hazards.clear();route_history.append(route)
	boss_pattern=1 if wave==6 else 0;boss_cycles=0
	phase = "battle"; draft_options.clear(); draft_done.clear()
	shots.clear(); enemies.clear(); baits.clear(); events.clear(); grid.rebuild(enemies)
	network_events.clear();network_fx.clear()
	for player in players:
		if player.down: player.hp = player.build.health*.4; player.down = false; player.revive = 0
		player.invuln = 1.5
		if skip_board_for_checks and modifier==2: player.hp=minf(player.build.health,player.hp+20)
	if not skip_board_for_checks:estate.enter(self,board.district_id(),int(board.state.licenses[board.district_id()]))
	_consume_event_resources()
	_consume_supply_resources()
	if wave == 3 or wave == 6:
		spawn_enemy(2, Vector2(0,-8))

func spawn_enemy(kind: int = 0, point: Vector2 = Vector2.INF) -> int:
	if enemies.active.size() >= max_enemies: return -1
	if kind in [3,4]:
		var specials:=0
		for existing in enemies.active:
			if enemies.kind[existing] in [3,4]:specials+=1
		if specials>=FurEnemyBehaviors.WARNING_LIMIT:return -1
	if point == Vector2.INF:
		var side := rng.randi_range(0,3)
		if side < 2: point = Vector2(-13.0 if side==0 else 13.0,rng.randf_range(-8.5,8.5))
		else: point = Vector2(rng.randf_range(-12.5,12.5),-8.7 if side==2 else 8.7)
	var health := (17.0+wave*4.0) * (1.35 if players.size()==2 else 1.0)
	if kind == 1: health *= 1.7
	if kind == 3: health *= 1.35
	if kind == 4: health *= .85
	if kind == 2: health *= 20.0
	var slot := enemies.acquire(point, health, kind)
	if slot>=0 and kind==2: enemies.life[slot]=4.0
	peak_enemies = maxi(peak_enemies,enemies.active.size())
	return slot

func set_input(index: int, direction: Vector2, dash: bool, skill: bool) -> void:
	if index < 0 or index >= players.size() or phase != "battle": return
	if not direction.is_finite(): return
	var p: Dictionary = players[index]
	p.input = direction.limit_length(1)
	if p.down: return
	if dash and p.dash_cd <= 0 and direction.length_squared() > .01:
		p.dash = .16; p.dash_cd = 1.8; p.invuln = .30
		if not skip_board_for_checks:_shared_order_events(shared_order.on_dash(index,true,players))
		emit("dash",p.pos,1,index)
	if skill and p.skill_cd <= 0:
		p.skill_cd = 5.0 + p.build.skill_delay
		match int(p.build.style):
			0:
				var banked:float=p.pot
				var damage: float = 15.0+p.pot*1.8
				p.pot = 0; p.aura = .65
				area_damage(p.pos,3.2*p.build.area,damage*p.build.damage*p.build.burst_damage,index,true)
				emit("burst",p.pos,3.2*p.build.area,index)
				payoff.release_pot(self,index,banked)
			1:
				p.charge = 2.5; p.attack_cd = 0
				emit("charge",p.pos,1,index)
			2:
				place_bait(index,true)
				payoff.release_chain(self,index)

func tick(delta: float) -> void:
	if phase != "battle":
		task_formations.clear();task_formation_preview={};return
	delta = minf(delta,.05); elapsed += delta; remaining -= delta
	tick_index += 1
	if not skip_board_for_checks:
		var arming:Dictionary=challenge_contract.tick_arm(elapsed,phase,int(board.state.run_token),wave,enemy_behaviors.authority)
		if arming.get("armed_now",false):emit("challenge_arming",players[0].pos,challenge_contract.ARM_LEAD,0,true)
	estate.tick(delta)
	_tick_players(delta)
	if skip_board_for_checks:
		spawn_clock -= delta
		if spawn_clock <= 0 and remaining > 0:
			spawn_clock = maxf(.10,.42-wave*.035) / (1.25 if route==1 else 1.0)
			spawn_enemy(1 if rng.randf() < .08+wave*.012 else 0)
	else:
		# Advance the original director exactly once, including its existing RNG.
		# Empty groups still expire a pending cue; replacement changes positions only.
		var requests:Array=director.tick(delta,remaining)
		var formation:Dictionary=task_formations.replace_group(requests,players,elapsed,phase,wave,int(board.state.run_token),enemy_behaviors.authority)
		var accepted_entities:Array=[]
		for request in formation.requests:
			var slot:int=spawn_enemy(int(request.kind),request.pos)
			if slot>=0:accepted_entities.append({"identity":enemies.identity[slot],"slot":slot,"kind":int(request.kind),"pos":enemies.pos[slot]})
		if not requests.is_empty() and director.chapter=="pressure":
			challenge_contract.bind_group(director.serial,director.chapter,elapsed,accepted_entities,int(board.state.run_token),wave,enemy_behaviors.authority)
		task_formation_preview=task_formations.pending_preview()
	_tick_enemies(delta)
	enemy_behaviors.tick_projectiles(self,delta);enemy_behavior_state=enemy_behaviors.presentation()
	grid.rebuild(enemies)
	payoff.tick(self,delta);payoff_state=payoff.presentation()
	_tick_attacks(delta)
	_tick_shots(delta)
	_tick_baits(delta)
	_flush_payoff_interrupts()
	_tick_pickups(delta)
	_tick_rules(delta)
	_tick_district(delta)
	if not skip_board_for_checks:_shared_order_events(shared_order.tick(delta,players))
	_tick_challenge()
	resolve_experience()
	var all_down := true
	for p in players:
		if not p.down: all_down = false
	if all_down:
		cancel_shared_order("defeat")
		cart_impact.reset();district.cart_sweeps.clear()
		phase = "defeat"; return
	if remaining <= 0:
		var boss_alive := false
		for slot in enemies.active:
			if enemies.kind[slot]==2: boss_alive = true
		if boss_alive:
			remaining = 0 # Elite waves require defeating the boss, not waiting it out.
		else: finish_wave()

func resolve_experience() -> void:
	while experience>=next_level_experience:
		next_level_experience+=20+players[0].build.level*8
		for i in players.size():
			var p: Dictionary=players[i]
			p.build.level+=1;p.build.damage+=.05;p.build.health+=3
			if not p.down:p.hp=minf(p.build.health,p.hp+3)
			emit("level",p.pos,1.2,i)

func _tick_players(delta: float) -> void:
	for i in players.size():
		var p: Dictionary = players[i]
		p.dash_cd = maxf(0,p.dash_cd-delta); p.skill_cd = maxf(0,p.skill_cd-delta)
		p.invuln = maxf(0,p.invuln-delta); p.dash = maxf(0,p.dash-delta); p.aura = maxf(0,p.aura-delta)
		if p.down:
			var helping := false
			var helper := -1
			for j in players.size():
				if j != i and not players[j].down and p.pos.distance_squared_to(players[j].pos) < 5.0: helping = true; helper=j
			p.revive = p.revive+delta if helping else maxf(0,p.revive-delta)
			if p.revive >= 2.5:
				if helper>=0:players[helper].build.rescues+=1
				p.down = false; p.hp = p.build.health*.35; p.invuln = 2.0; p.revive = 0
				emit("revive",p.pos,1,i)
			continue
		var speed: float = 5.0*p.build.speed*(3.3 if p.dash>0 else 1.0)
		var proposed:Vector2=p.pos+p.input*speed*delta
		p.pos = Vector2(clampf(proposed.x,-12.8,12.8),clampf(proposed.y,-8.2,8.2)) if skip_board_for_checks else district.resolve_motion(p.pos,proposed,.4)

func _tick_enemies(delta: float) -> void:
	enemy_behaviors.prune(self)
	for slot in enemies.active:
		if enemies.kind[slot]==2:
			var attack:=FurBossCatalog.attack(wave,boss_pattern)
			var before: float=enemies.life[slot]
			enemies.life[slot]-=delta
			if before>attack.windup and enemies.life[slot]<=attack.windup:
				if attack.id=="notice":_place_boss_notices(enemies.life[slot]+delta)
				else:emit("warning",enemies.pos[slot],attack.radius)
			if enemies.life[slot]<=0:
				enemies.life[slot]=attack.period;boss_cycles+=1
				if attack.id=="slam":
					emit("boss_burst",enemies.pos[slot],attack.radius)
					for i in players.size():
						var victim: Dictionary=players[i]
						if victim.pos.distance_squared_to(enemies.pos[slot])<attack.radius*attack.radius: hurt_player(i,attack.damage)
				if wave==6:boss_pattern=1-boss_pattern
		var nearest := Vector2.ZERO; var best := INF
		for p in players:
			if p.down: continue
			var distance: float = enemies.pos[slot].distance_squared_to(p.pos)
			if distance < best: best = distance; nearest = p.pos
		for bait in baits:
			var distance: float = enemies.pos[slot].distance_squared_to(bait.pos)
			if distance < 25.0 and distance*.32 < best: best = distance*.32; nearest = bait.pos
		var special:Dictionary=enemy_behaviors.command(self,slot,nearest,delta)
		if special.handled:
			var proposed_special:Vector2=enemies.pos[slot]+special.velocity*delta
			enemies.pos[slot]=proposed_special if skip_board_for_checks else district.resolve_motion(enemies.pos[slot],proposed_special,.45)
			enemies.marked[slot]=maxf(0,enemies.marked[slot]-delta)
			enemies.velocity[slot]=Vector2.ZERO
			if special.contact_damage>0:
				for index in players.size():
					if enemies.pos[slot].distance_squared_to(players[index].pos)<.68*.68:hurt_player(index,float(special.contact_damage))
			continue
		var speed := 1.45+wave*.14
		if enemies.kind[slot]==1: speed *= 1.3
		if enemies.kind[slot]==2: speed *= .7
		if enemies.kind[slot]==2 and enemies.life[slot] <= FurBossCatalog.attack(wave,boss_pattern).windup:
			speed = 0.0; enemies.velocity[slot]=Vector2.ZERO
		var separation := Vector2.ZERO
		if slot%2==tick_index%2 and (enemies.kind[slot]!=2 or enemies.life[slot]>FurBossCatalog.attack(wave,boss_pattern).windup):
			var examined := 0
			for other in grid.nearby(enemies.pos[slot],.75):
				if other==slot or enemies.rank[other]<0:continue
				var difference := enemies.pos[slot]-enemies.pos[other]
				if difference.length_squared()<.38:separation+=difference.normalized()*.7
				examined+=1
				if examined>=6:break
		var steering:Vector2=(nearest-enemies.pos[slot]).normalized() if skip_board_for_checks else district.steer_enemy(enemies.pos[slot],nearest,.45)
		var proposed:Vector2=enemies.pos[slot]+(steering*speed+separation)*delta+enemies.velocity[slot]*delta
		enemies.pos[slot] = proposed if skip_board_for_checks else district.resolve_motion(enemies.pos[slot],proposed,.45)
		enemies.velocity[slot] = enemies.velocity[slot].move_toward(Vector2.ZERO,delta*8.0)
		enemies.marked[slot] = maxf(0,enemies.marked[slot]-delta)
		for i in players.size():
			var p: Dictionary = players[i]
			var radius := 1.3 if enemies.kind[slot]==2 else .68
			if not p.down and p.invuln <= 0 and enemies.pos[slot].distance_squared_to(p.pos) < radius*radius:
				var damage := 18.0 if enemies.kind[slot]==2 else 8.0
				hurt_player(i,damage)

func protecting_guard(index: int) -> int:
	if index<0 or index>=players.size() or players[index].down:return -1
	var best:=-1;var reduction:=0.0
	for guard_index in players.size():
		var guard: Dictionary=players[guard_index]
		if guard.down or guard.build.style!=0:continue
		if guard.pos.distance_squared_to(players[index].pos)>=guard.build.guard_radius*guard.build.guard_radius:continue
		if guard.build.shield_reduction>reduction:best=guard_index;reduction=guard.build.shield_reduction
	return best

func hurt_player(index: int, damage: float) -> bool:
	if index<0 or index>=players.size():return false
	var player: Dictionary=players[index]
	if player.down or player.invuln>0:return false
	var reduction := 0.0
	var provider:=protecting_guard(index)
	if provider>=0:
		var guard: Dictionary=players[provider]
		reduction=guard.build.shield_reduction;guard.pot=minf(guard.build.pot_cap,guard.pot+damage*.5)
		guard.build.triggers+=1;guard.build.saved_damage+=damage*reduction
		if provider==index:guard.build.self_saved_damage+=damage*reduction
		else:guard.build.ally_saved_damage+=damage*reduction
	damage*=1.0-reduction
	var previous_hp:float=player.hp
	player.hp=maxf(0,player.hp-damage);player.invuln=.65
	if player.hp<=0:player.down=true;player.revive=0
	if not skip_board_for_checks:_shared_order_events(shared_order.on_damage(index,true,previous_hp-player.hp,players))
	emit("hurt",player.pos,damage,index)
	return true

func _tick_attacks(delta: float) -> void:
	for i in players.size():
		var p: Dictionary = players[i]
		if p.down: continue
		p.attack_cd -= delta
		if p.build.style==1 and p.input.length_squared() < .02:
			var previous_charge: float=p.charge
			p.charge = minf(2.5,p.charge+delta*p.build.charge_rate)
			if previous_charge<1.0 and p.charge>=1.0:emit("ready",p.pos,1,i)
			if p.charge > 1.0: continue
		elif p.build.style==1 and p.charge >= 1.0:
			# Moving spends saved energy immediately, even if an ordinary volley
			# happened just before the player stopped to charge.
			p.attack_cd = 0
		if p.attack_cd > 0: continue
		var weapons: int = p.build.weapons
		match int(p.build.style):
			0:
				p.attack_cd = .70*p.build.interval*estate.attack_interval()
				area_damage(p.pos,1.8*p.build.area,(7.0+weapons*2.0)*p.build.damage,i,true)
				p.aura = .14; emit("sweep",p.pos,1.8*p.build.area,i)
			1:
				p.attack_cd = .62*p.build.interval*estate.attack_interval()
				var nearest := nearest_enemy(p.pos,13)
				if nearest < 0: continue
				var direction: Vector2 = (enemies.pos[nearest]-p.pos).normalized()
				var charged: bool = p.charge >= 1.0
				if charged: p.build.triggers += 1
				for weapon in weapons:
					var spread: float = (weapon-(weapons-1)*.5)*.10
					var slot := shots.acquire(p.pos,(5.0+wave*.4)*p.build.damage*(1.0+p.charge*.5 if charged else 1.0),i)
					if slot < 0: break
					shots.velocity[slot] = direction.rotated(spread)*17.0
					shots.life[slot] = 1.25; shots.owner[slot] = i; shots.marked[slot] = p.build.bounce
					shots.penetration[slot] = p.build.charged_pierce if charged else 0
				if charged:
					payoff.release_volley(self,i,direction,p.charge,enemies.identity[nearest])
					p.charge = 0
				emit("volley",p.pos,1,i,charged)
			2:
				p.attack_cd = maxf(1.4,3.3-weapons*.18)*p.build.interval*estate.attack_interval()
				place_bait(i,false)

func nearest_enemy(point: Vector2, radius: float, exclude: int = -1) -> int:
	var nearest := -1; var best := radius*radius
	for slot in grid.nearby(point,radius):
		if enemies.rank[slot]<0 or slot==exclude: continue
		var d := enemies.pos[slot].distance_squared_to(point)
		if d<best: nearest=slot;best=d
	return nearest

func area_damage(point: Vector2, radius: float, damage: float, source: int, mark: bool,chain_payoff_id:int=0) -> void:
	for slot in grid.nearby(point,radius):
		if enemies.rank[slot]<0 or enemies.pos[slot].distance_squared_to(point)>radius*radius: continue
		if chain_payoff_id>0:enemy_behaviors.interrupt(self,slot,enemies.identity[slot],source,"chain_bait",chain_payoff_id)
		if mark:
			enemies.marked[slot] = 2.5+players[source].build.synergy
			enemies.owner[slot] = source
		if enemies.kind[slot]!=2 or enemies.life[slot]>FurBossCatalog.attack(wave,boss_pattern).windup:
			enemies.velocity[slot] = (enemies.pos[slot]-point).normalized()*(1.3 if enemies.kind[slot]==2 else 4.5)
		damage_enemy(slot,damage,source)

func damage_enemy(slot: int, damage: float, source: int) -> void:
	if enemies.rank[slot]<0: return
	var build: Dictionary = players[source].build
	var critical: bool = rng.randf()<build.crit
	if critical: damage *= 2
	if enemies.marked[slot]>0 and build.style != 0:
		damage *= 1.0+build.synergy; build.triggers += 1
		var marker: int=enemies.owner[slot]
		if marker>=0 and marker<players.size() and marker!=source:
			players[marker].build.link_receipts+=1;players[marker].build.triggers+=1
			if elapsed-last_combo_feedback>=.3:
				last_combo_feedback=elapsed;emit("link",enemies.pos[slot],1,marker)
	build.dealt += minf(damage,enemies.hp[slot]); enemies.hp[slot] -= damage
	emit("hit",enemies.pos[slot],damage,source,critical)
	if enemies.hp[slot]<=0:
		if not skip_board_for_checks:
			var challenge_state:Dictionary=challenge_contract.snapshot()
			challenge_contract.on_killed(slot,enemies.identity[slot],source,elapsed,int(board.state.run_token),wave,int(challenge_state.group_serial),enemy_behaviors.authority)
		if build.style == 0 and enemies.marked[slot] > 0:
			# A lone guard can turn its own marked kills into the next pot burst.
			players[source].pot = minf(build.pot_cap, players[source].pot + 2.0 + build.synergy * 4)
		if route == 1 and skip_board_for_checks:
			advance_rule(2.0 if enemies.marked[slot] > 0 and build.style != 0 else 1.0)
		build.kills += 1
		var drop := pickups.acquire(enemies.pos[slot],1.0,0)
		var reward:=25 if enemies.kind[slot]==2 else 1
		if drop<0:
			# Preserve progression even if the visual pickup budget is exhausted.
			experience += reward
		else:pickups.hp[drop]=reward
		emit("pop",enemies.pos[slot],1,source); enemies.release(slot)

func _tick_shots(delta: float) -> void:
	for index in range(shots.active.size()-1,-1,-1):
		var slot: int = shots.active[index]
		shots.life[slot]-=delta; shots.pos[slot]+=shots.velocity[slot]*delta
		if shots.life[slot]<=0 or abs(shots.pos[slot].x)>15 or abs(shots.pos[slot].y)>10:
			shots.release(slot);continue
		for target in grid.nearby(shots.pos[slot],1.3):
			if enemies.rank[target]<0:continue
			var hit_radius := 1.25 if enemies.kind[target]==2 else .65
			if enemies.pos[target].distance_squared_to(shots.pos[slot])>hit_radius*hit_radius:continue
			var point: Vector2 = enemies.pos[target]
			if payoff.is_followup_shot(self,slot):enemy_behaviors.interrupt(self,target,enemies.identity[target],shots.owner[slot],"followup_volley",shots.identity[slot])
			damage_enemy(target,shots.hp[slot],shots.owner[slot])
			if shots.penetration[slot]>0:
				shots.penetration[slot]-=1
				shots.pos[slot]=point+shots.velocity[slot].normalized()*(hit_radius+.10)
				break
			if shots.marked[slot]>0:
				var next := nearest_enemy(point,5,target)
				if next>=0:
					shots.velocity[slot]=(enemies.pos[next]-point).normalized()*17;shots.marked[slot]-=1
					shots.pos[slot]=point+shots.velocity[slot].normalized()*(hit_radius+.10)
					break
			shots.release(slot);break

func place_bait(source: int, instant: bool) -> void:
	if baits.size()>=12:return
	var p: Dictionary = players[source]
	var nearest := nearest_enemy(p.pos,7)
	var point: Vector2 = enemies.pos[nearest] if nearest>=0 else p.pos+Vector2(0,-2)
	baits.append({"pos":point,"ttl":.35 if instant else maxf(.8,2.2+p.build.synergy*.3+p.build.bait_delay),"owner":source})
	emit("bait",point,1,source)

func _tick_baits(delta: float) -> void:
	for index in range(baits.size()-1,-1,-1):
		var bait: Dictionary = baits[index];bait.ttl-=delta
		if bait.ttl>0:continue
		var build: Dictionary = players[bait.owner].build
		var radius: float = 2.4*build.area*build.bait_area
		var linked := false
		var caught := 0
		for slot in grid.nearby(bait.pos,radius):
			if enemies.rank[slot]<0 or enemies.pos[slot].distance_squared_to(bait.pos)>radius*radius:continue
			caught+=1
			if enemies.marked[slot]>0:linked=true
		if linked:radius*=1.25;build.triggers+=1
		if build.bait_chain and (linked or caught>=3):payoff.chain_from(self,bait)
		area_damage(bait.pos,radius,(15.0+build.weapons*3)*build.damage*build.bait_damage,bait.owner,false,int(bait.get("chain_tag",0)))
		emit("burst",bait.pos,radius,bait.owner);baits.remove_at(index)

func _flush_payoff_interrupts()->void:
	var feedback:Dictionary=enemy_behaviors.take_interrupt_feedback(self)
	if not feedback.get("ok",false):return
	for event in feedback.get("events",[]):
		emit(str(event.kind),event.point,float(event.value),int(event.owner),bool(event.extra))
	# Hits occur after enemy AI's presentation sampling in this tick. Clear a
	# cancelled warning immediately rather than keeping it visible for one frame.
	if not feedback.get("events",[]).is_empty():enemy_behavior_state=enemy_behaviors.presentation()

func _tick_pickups(delta: float) -> void:
	for index in range(pickups.active.size()-1,-1,-1):
		var slot: int = pickups.active[index]
		var nearest := -1;var best:=INF
		for i in players.size():
			if players[i].down:continue
			var d: float = pickups.pos[slot].distance_squared_to(players[i].pos)
			if d<best:best=d;nearest=i
		if nearest<0:continue
		if best<9:pickups.pos[slot]=pickups.pos[slot].move_toward(players[nearest].pos,delta*8)
		if best<.64:experience+=int(pickups.hp[slot]);pickups.release(slot)

func advance_rule(amount: float) -> void:
	if rule_state.is_empty() or rule_state.rewarded: return
	rule_state.progress = minf(rule_state.target, rule_state.progress + amount)
	if rule_state.progress < rule_state.target: return
	rule_state.rewarded = true; rule_rewards += 1
	experience += FurRouteCatalog.entry(route).xp
	for index in players.size():
		var player: Dictionary = players[index]
		if route == 2 and not player.down: player.hp = minf(player.build.health, player.hp + 14)
		emit("contract", player.pos, 1.4, index)

func _tick_rules(delta: float) -> void:
	if route == 0 and skip_board_for_checks:
		rule_state.clock -= delta
		var receipts:=0
		for hazard in hazards:
			if hazard.get("kind","receipt")=="receipt":receipts+=1
		if rule_state.clock <= 0 and receipts < 3:
			rule_state.clock = 9.0
			for index in players.size():
				if not players[index].down:
					hazards.append({"pos":players[index].pos, "radius":2.8, "ttl":1.4, "owner":index})
					break
	elif route == 2 and skip_board_for_checks and not rule_state.rewarded:
		var occupants := 0
		for player in players:
			if not player.down and player.input.length_squared() < .02 and player.pos.distance_squared_to(rule_state.point) < 4.41 and player.invuln < .6:
				occupants += 1
		if occupants > 0: advance_rule(delta * minf(1.5, occupants))
	for index in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[index]
		if hazard.get("kind","receipt")=="notice":
			var boss_alive:=false
			for slot in enemies.active:
				if enemies.kind[slot]==2:boss_alive=true;break
			if not boss_alive:hazards.remove_at(index);continue
		hazard.ttl -= delta
		if hazard.ttl > 0: continue
		var point: Vector2 = hazard.pos
		var radius: float = hazard.radius
		if hazard.get("kind","receipt")=="notice":
			for player_index in players.size():
				if players[player_index].pos.distance_squared_to(point)<=radius*radius:hurt_player(player_index,FurBossCatalog.NOTICE.damage)
			emit("notice_burst",point,radius);hazards.remove_at(index);continue
		var caught := 0
		# Copy the slot list: damage can release enemies from the pool.
		for slot in enemies.active.duplicate():
			if enemies.kind[slot] == 2 or enemies.pos[slot].distance_squared_to(point) > radius * radius: continue
			var health: float = enemies.hp[slot]
			damage_enemy(slot, 55.0 + wave * 12.0, hazard.owner)
			if enemies.rank[slot] < 0 and health > 0: caught += 1
		for player_index in players.size():
			var player: Dictionary = players[player_index]
			if player.down or player.invuln > 0 or player.pos.distance_squared_to(point) > radius * radius: continue
			hurt_player(player_index,16)
		advance_rule(caught)
		emit("receipt", point, radius, hazard.owner)
		hazards.remove_at(index)

func _place_boss_notices(duration: float) -> void:
	# Replace any previous notice batch. Route receipts keep their own budget.
	for index in range(hazards.size()-1,-1,-1):
		if hazards[index].get("kind","receipt")=="notice":hazards.remove_at(index)
	for player_index in players.size():
		if players[player_index].down:continue
		var point: Vector2=players[player_index].pos
		hazards.append({"kind":"notice","pos":point,"radius":FurBossCatalog.NOTICE.radius,"ttl":duration,"owner":player_index})
		emit("notice",point,FurBossCatalog.NOTICE.radius,player_index)

func finish_wave() -> void:
	if phase!="battle":return
	cart_impact.reset();district.cart_sweeps.clear()
	task_formations.clear();task_formation_preview={}
	var challenge_result:Dictionary=_settle_challenge("completed")
	if not skip_board_for_checks:shared_order.end_battle(wave,"completed")
	if not skip_board_for_checks:patrol.finish_battle(wave,"completed")
	if not skip_board_for_checks and not round_results.is_empty():
		round_results.back().battle_completed=true
		round_results.back().objective_completed=bool(district.state.get("completed",false))
	if not skip_board_for_checks:board.finish_battle(district.state.get("completed",false),challenge_result)
	payoff.clear_pending();payoff_state={}
	enemy_behaviors.reset();enemy_behavior_state={}
	for slot in pickups.active:experience+=int(pickups.hp[slot])
	pickups.clear();enemies.clear();shots.clear();baits.clear()
	hazards.clear()
	if wave>=MAX_WAVES:phase="victory";return
	phase="draft";draft_options.clear();draft_done.clear()
	var reward:Dictionary=shared_order.claim_entitlement(wave,"draft") if not skip_board_for_checks else {"ok":false}
	for index in players.size():
		var p:Dictionary=players[index]
		order_draft_pending[index]=bool(reward.get("ok",false)) and index in reward.get("entitlement",{}).get("actors",[])
		draft_is_order[index]=false;draft_revisions[index]=0
		draft_options.append(FurBuildCatalog.draft(draft_rng,p.build,players.size()>1,wave==3));draft_done.append(false)
		p.hp=minf(p.build.health,p.hp+12);p.down=false;p.revive=0

func choose_upgrade(player_index: int, choice: int,expected_revision:int=-1) -> bool:
	if phase!="draft" or player_index<0 or player_index>=players.size() or choice<0 or choice>2 or draft_done[player_index]:return false
	if expected_revision>=0 and expected_revision!=draft_revisions[player_index]:return false
	var item: Dictionary = draft_options[player_index][choice]
	if not FurBuildCatalog.apply(players[player_index].build,item.id):return false
	players[player_index].hp = minf(players[player_index].hp, players[player_index].build.health)
	if item.id=="heal":players[player_index].hp=minf(players[player_index].build.health,players[player_index].hp+35)
	draft_revisions[player_index]+=1
	if order_draft_pending[player_index]:
		order_draft_pending[player_index]=false;draft_is_order[player_index]=true
		draft_options[player_index]=FurBuildCatalog.draft(order_reward_rng,players[player_index].build,players.size()>1,true)
		return true
	draft_is_order[player_index]=false
	draft_done[player_index]=true
	if not draft_done.has(false):
		if not skip_board_for_checks:
			board.begin_round(wave+1);phase="board";return true
		phase="route";dice=Vector2i(route_rng.randi_range(1,6),route_rng.randi_range(1,6))
		# Every roll offers a real choice between two different rule categories.
		if dice.x % 3 == dice.y % 3: dice.y = dice.y % 6 + 1
	return true

func choose_route(choice: int) -> bool:
	if phase!="route" or choice<0 or choice>1:return false
	var face: int = dice.x if choice==0 else dice.y
	next_wave(face%3);return true


func board_suggest(request:Dictionary,actor:int,now_ms:int) -> bool:
	if phase!="board" or skip_board_for_checks:return false
	var result:Dictionary=board.suggest(request,seed_value,actor,now_ms,true)
	return result.get("ok",false)

func select_board_order(choice:int,actor:int)->bool:
	if phase!="board" or skip_board_for_checks or board.state.stage!="roll" or int(board.state.round)!=1 or actor!=int(board.state.active):return false
	var result:Dictionary=shared_order.select(choice,{"stage":"order_select","round":1,"actor":actor,"active":int(board.state.active),"authority":true,"run_token":int(board.state.run_token)})
	return result.get("ok",false)

func roll_board(forced_face:int=0,order_choice:int=0,actor:int=0)->bool:
	if phase!="board" or board.state.stage!="roll" or actor!=int(board.state.active) or forced_face<0 or forced_face>6:return false
	if int(board.state.round)==1 and shared_order.state.get("selected",-1)<0:
		if not select_board_order(order_choice,actor):return false
	elif order_choice!=0:return false
	return board.roll(forced_face)

func cancel_shared_order(outcome:String="cancel")->void:
	task_formations.clear();task_formation_preview={}
	if phase=="battle":_settle_challenge(outcome)
	if not skip_board_for_checks and not shared_order.state.get("battle",{}).is_empty():shared_order.end_battle(wave,outcome)
	if not skip_board_for_checks and patrol.state.get("phase","")=="battle":patrol.finish_battle(wave,outcome)

func request_order_pickup(actor:int,choice:int,run_token:int,battle_wave:int,cargo_id:int,expected_revision:int)->bool:
	if phase!="battle" or skip_board_for_checks or not enemy_behaviors.authority:return false
	if actor<0 or actor>=players.size() or choice not in [0,1] or run_token!=int(board.state.run_token) or battle_wave!=wave:return false
	var cargo:Dictionary=shared_order.state.get("cargo",{})
	if cargo.is_empty() or cargo_id!=int(cargo.id) or expected_revision!=int(cargo.get("pickup_revision",-1)):return false
	var result:Dictionary=shared_order.pickup(actor,choice,players,expected_revision)
	_shared_order_events(result)
	return result.get("ok",false)

func _shared_order_events(result:Dictionary)->void:
	if not result.get("ok",false):return
	for event in result.get("events",[]):
		if event.kind=="order_checkpoint" and shared_order.state.get("fulfilled",false):continue
		emit(str(event.kind),event.point,1,maxi(0,int(event.actor)),true)

func board_choose(kind:String,choice:int,player_index:int,event_serial:int=0) -> bool:
	if phase!="board" or player_index!=int(board.state.active):return false
	var accepted:=false
	match kind:
		"board_roll":accepted=roll_board(0,choice,player_index)
		"board_move":accepted=choice in [0,1,2] and board.move(choice-1)
		"board_event":
			if choice in [0,1,2] and event_serial>0:
				var result:Dictionary=board.resolve_event(choice,FurTeamSupplies.facts(players),seed_value,event_serial,player_index,true)
				accepted=result.get("ok",false)
		"board_business":
			accepted=board.business(choice)
			if accepted:next_wave(board.district_id())
		"board_invest":
			accepted=board.invest(choice)
			if accepted:next_wave(board.district_id())
		"board_supply":
			accepted=choice in [0,1,2] and apply_board_supply(FurTeamSupplies.IDS[choice])
			if accepted:next_wave(board.district_id())
	return accepted

func apply_board_supply(supply_id:String) -> bool:
	if phase!="board" or skip_board_for_checks:return false
	var transaction:Dictionary=board.purchase_supply(supply_id,FurTeamSupplies.facts(players))
	if not transaction.get("ok",false):return false
	if supply_id=="milk":
		# Commit against purchase-time eligibility, before wave revival/estate healing.
		for effect in transaction.effects:
			if effect.eligible and effect.amount>0:
				var player:Dictionary=players[effect.player_index]
				player.hp=minf(player.build.health,player.hp+float(effect.amount))
	elif supply_id=="resources":pending_supply_effects.assign(transaction.effects.duplicate(true))
	# Shared tickets have already been credited once by the board transaction.
	return true

func _consume_supply_resources() -> void:
	var effects:Array[Dictionary]=pending_supply_effects.duplicate(true)
	pending_supply_effects.clear()
	_apply_entry_resources(effects)

func _consume_event_resources() -> void:
	if skip_board_for_checks:return
	var effects:Array=board.state.get("event_resources",[]).duplicate(true)
	board.state["event_resources"]=[]
	_apply_entry_resources(effects)

func _apply_entry_resources(effects:Array) -> void:
	for effect in effects:
		if not effect.get("eligible",false) or float(effect.get("amount",0))<=0:continue
		var index:int=effect.player_index
		if index<0 or index>=players.size():continue
		var player:Dictionary=players[index]
		if player.down:continue
		match str(effect.kind):
			"pot":player.pot=minf(player.build.pot_cap,player.pot+float(effect.amount))
			"charge":player.charge=minf(2.5,player.charge+float(effect.amount))
			"bait":
				if baits.size()<12:place_bait(index,false)

func _tick_district(delta:float) -> void:
	if skip_board_for_checks:return
	var wants_arm:bool=challenge_contract.state.accepted and challenge_contract.state.arm_source==""
	var previous_district:Variant=null
	if wants_arm and int(district.state.district_id)==1:previous_district=district.snapshot()
	var district_events:Array=district.tick(delta,players)
	_tick_cart_impact()
	var post_district:Variant=null
	if wants_arm and not district_events.is_empty():post_district=district.snapshot()
	for event in district_events:
		if wants_arm and challenge_contract.state.arm_source=="" and event.kind in ["district_checkpoint","district_parcel"]:
			var arming:Dictionary=challenge_contract.observe_milestone(event,post_district,elapsed,int(board.state.run_token),wave,enemy_behaviors.authority,previous_district)
			if arming.get("armed_now",false):emit("challenge_arming",event.point,challenge_contract.ARM_LEAD,maxi(0,int(event.owner)),true)
		estate.on_event(self,event)
		match str(event.kind):
			"district_warning":
				task_formations.queue_warning(event,district.snapshot(),elapsed,phase,int(board.state.run_token),enemy_behaviors.authority)
			"district_reward":
				board.state.cash=mini(999,int(board.state.cash)+int(event.cash));district_cash+=int(event.cash)
				experience+=int(event.xp)
				for p in players:
					if not p.down:p.hp=minf(p.build.health,p.hp+float(event.health))
			"district_damage":hurt_player(int(event.owner),float(event.value))
			"district_complete":
				challenge_contract.on_district_complete(event,district.snapshot(),int(board.state.run_token),wave,enemy_behaviors.authority)
				rule_rewards+=1
				if not round_results.is_empty():round_results.back().objective_completed=true
				var repel:Dictionary=patrol.on_district_complete(event,district.snapshot(),int(board.state.run_token),wave*3+int(district.state.district_id))
				if repel.get("ok",false):
					for feedback in repel.get("events",[]):emit(str(feedback.kind),feedback.point,float(feedback.next_position),maxi(0,int(event.owner)),true)
				var receipt:Dictionary=shared_order.on_district_complete(event,district.snapshot())
				if receipt.get("ok",false) and receipt.get("received",false):emit("order_goods",event.point,int(district.state.district_id),maxi(0,int(event.owner)),true)
		emit(str(event.kind),event.point,float(event.value),maxi(0,int(event.owner)))
	rule_state.progress=district.state.progress;rule_state.target=district.state.target;rule_state.rewarded=district.state.completed
	task_formation_preview=task_formations.pending_preview()

func _tick_cart_impact()->void:
	if phase!="battle" or skip_board_for_checks or int(district.state.district_id)!=1:
		return
	var active_ids:Array=[]
	for packet in district.state.packets:active_ids.append(int(packet.id))
	var targets:Array=[]
	if not district.cart_sweeps.is_empty():
		for slot in enemies.active:
			targets.append({"slot":slot,"identity":enemies.identity[slot],"kind":enemies.kind[slot],"pos":enemies.pos[slot]})
	var result:Dictionary=cart_impact.process(district.cart_sweeps,targets,active_ids,int(board.state.run_token),wave,enemy_behaviors.authority)
	if not result.get("ok",false):return
	var moved:=0;var total:=Vector2.ZERO
	for request in result.moves:
		var slot:int=request.slot
		if enemies.rank[slot]<0 or enemies.identity[slot]!=request.identity or enemies.kind[slot] not in [0,1]:continue
		var resolved:Vector2=district.resolve_motion(enemies.pos[slot],request.to,.45)
		if enemies.pos[slot].distance_squared_to(resolved)<=.000001:continue
		enemies.pos[slot]=resolved;moved+=1;total+=resolved
	# One consolidated actual-effect feedback per authority tick; no damage or
	# interrupt, and no new event fields/pool/packet state in the wire contract.
	if moved>0:
		grid.rebuild(enemies)
		emit("cart_impact",total/float(moved),moved,0,true)

func _tick_challenge()->void:
	if skip_board_for_checks:return
	var observed:Array=[]
	for target in challenge_contract.snapshot().group:
		var slot:int=target.slot
		observed.append({"slot":slot,"identity":enemies.identity[slot],"active":enemies.rank[slot]>=0})
	# Seal timeout only after this tick's real attacks and district callbacks.
	challenge_contract.tick(elapsed,observed,phase,int(board.state.run_token),wave,enemy_behaviors.authority)

func _settle_challenge(outcome:String)->Dictionary:
	var finished:Dictionary=challenge_contract.finish(wave,outcome,int(board.state.run_token),enemy_behaviors.authority)
	assert(finished.get("ok",false),"Challenge must close once from the actual current battle")
	var result:Dictionary=finished.get("result",{})
	if not skip_board_for_checks and not round_results.is_empty():
		var facts:Dictionary=round_results.back()
		facts.challenge_rule_version=ChallengeContract.RULE_VERSION
		facts.challenge_available=bool(result.get("available",false))
		facts.challenge_qualified=bool(result.get("qualified",false))
		facts.challenge_result=result.duplicate(true)
		facts.objective_completed=bool(district.state.get("completed",false))
		facts.battle_completed=outcome=="completed"
	return result
