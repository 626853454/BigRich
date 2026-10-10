class_name FurSnapshotDomains
extends RefCounted

# Preflight on detached values. No session/model/presentation writes.
const Board=preload("res://scripts/furball/board_runtime.gd")
const SharedOrder=preload("res://scripts/furball/shared_order.gd")
const District=preload("res://scripts/furball/district_runtime.gd")
const Patrol=preload("res://scripts/furball/patrol_rival.gd")
const TaskFormations=preload("res://scripts/furball/task_formations.gd")
const Challenge=preload("res://scripts/furball/challenge_contract.gd")

static func validate(frame:Dictionary)->bool:
	if not frame.has_all(["board","seed_value"]) or not frame.board is Dictionary:return false
	if not frame.has_all(["phase","wave","remaining","elapsed","players","enemies","shots","pickups","baits","events","experience","next_xp","draft","done","dice"]):return false
	if not frame.phase is String or frame.phase not in ["board","battle","draft","route","victory","defeat","waiting"]:return false
	if not frame.wave is int or frame.wave<0 or frame.wave>6 or not _bounded_number(frame.elapsed,0,10000000) or not _bounded_number(frame.remaining,-10000000,10000000):return false
	if not frame.players is Array or frame.players.is_empty() or frame.players.size()>2:return false
	for player in frame.players:
		if not player is Dictionary or not player.has_all(["pos","hp","down","build","pot","charge","skill_cd","revive"]):return false
		if not player.pos is Vector2 or not player.pos.is_finite() or not player.down is bool or not player.build is Dictionary:return false
		if not player.build.get("style") is int or player.build.style<0 or player.build.style>2:return false
		for key in ["hp","pot","charge","skill_cd","revive"]:
			if not _bounded_number(player[key],-1000000,1000000):return false
	if frame.has("board"):
		if not frame.get("seed_value") is int or frame.seed_value<0 or frame.seed_value>2147483647:return false
		if not frame.board is Dictionary or not Board.new().apply_state(frame.board,frame.seed_value):return false
		if frame.board.players!=frame.players.size():return false
		for effect in frame.board.event_resources:
			if effect.kind!=["pot","charge","bait"][frame.players[effect.player_index].build.style]:return false
	if not frame.has("shared_order") or not SharedOrder.valid_state(frame.shared_order,frame.seed_value,frame.players.size(),frame.board.run_token):return false
	var cargo:Dictionary=frame.shared_order.cargo
	if not cargo.is_empty() and cargo.phase=="carrying" and cargo.point!=frame.players[cargo.carrier].pos:return false
	for key in ["order_draft_pending","draft_is_order","draft_revisions"]:
		if not frame.get(key) is Array or frame[key].size()!=frame.players.size():return false
		for value in frame[key]:
			if key=="draft_revisions":
				if not value is int or value<0 or value>2:return false
			elif not value is bool:return false
	if frame.has("district"):
		if not frame.district is Dictionary or not District.new().apply_state(frame.district):return false
	if not valid_patrol_frame(frame):return false
	if not valid_formation_frame(frame):return false
	if frame.has("estate") and not clean_estate(frame.estate).ok:return false
	if frame.has("enemy_behavior_state") and not clean_enemy(frame.enemy_behavior_state).ok:return false
	if not frame.has("round_results") or not clean_rounds(frame.round_results,frame.seed_value,frame.board.run_token).ok:return false
	if not valid_challenge_frame(frame):return false
	if frame.has("payoff") and not valid_payoff(frame.payoff,frame.players.size()):return false
	if not clean_baits(frame.baits,frame.players.size()).ok:return false
	if frame.has("debug_run") and not frame.debug_run is bool:return false
	if frame.has("debug_history") and (not frame.debug_history is Array or frame.debug_history.size()>32):return false
	for key in ["enemies","shots","pickups"]:
		if not frame[key] is Array or frame[key].size()>(256 if key=="enemies" else 192):return false
		for entry in frame[key]:
			if not entry is Array or entry.size()<7 or entry.size()>9:return false
			if not entry[0] is Vector2 or not entry[1] is Vector2 or not entry[0].is_finite() or not entry[1].is_finite():return false
			for index in [2,3,6]:
				if not _bounded_number(entry[index],-1000000000,1000000000):return false
			if not entry[4] is int or not entry[5] is int:return false
			if entry.size()>7 and not _bounded_number(entry[7],-1000000000,1000000000):return false
			if entry.size()>8 and (not entry[8] is int or entry[8]<1 or entry[8]>1000000000):return false
	if not frame.events is Array or frame.events.size()>48:return false
	if frame.has("key_events") and (not frame.key_events is Array or frame.key_events.size()>96):return false
	return true

static func valid_formation_frame(frame:Dictionary)->bool:
	var preview:Variant=frame.get("task_formation_preview")
	if not preview is Dictionary:return false
	var district_id:int=int(frame.district.get("district_id",-1)) if frame.get("district") is Dictionary else -1
	if not TaskFormations.valid_preview(preview,frame.seed_value,frame.board.run_token,frame.wave,frame.elapsed,frame.phase,district_id):return false
	if frame.legacy_diagnostic:return preview.is_empty()
	if preview.is_empty():return true
	return frame.district is Dictionary and frame.district.get("cycle") is int and preview.packet_id<=frame.district.cycle

static func valid_patrol_frame(frame:Dictionary)->bool:
	if not frame.get("legacy_diagnostic") is bool or not Patrol.valid_state(frame.get("patrol"),frame.seed_value,frame.board.run_token):return false
	var patrol:Dictionary=frame.patrol
	if frame.legacy_diagnostic:
		# Explicit pure-combat fixtures configure but never simulate this opponent.
		return patrol.phase=="board" and patrol.settled_round==0 and patrol.history.is_empty()
	if frame.phase=="board":return patrol.phase=="board" and patrol.settled_round+1==frame.board.round
	if frame.phase=="battle":
		if patrol.phase!="battle" or patrol.battle_wave!=frame.wave or frame.board.round!=frame.wave or patrol.battle_landing!=frame.board.position:return false
		if not frame.get("district") is Dictionary or patrol.battle_district!=frame.district.get("district_id") or frame.district.get("wave")!=frame.wave:return false
		if frame.district.get("seed")!=frame.seed_value+frame.wave*101 or patrol.repelled!=frame.district.get("completed",false):return false
		if patrol.repelled and patrol.objective_sequence!=frame.district.get("event_serial"):return false
		return patrol.battle_district==Board.DISTRICTS[frame.board.position]
	if frame.phase=="draft":return patrol.phase=="board" and patrol.settled_round==frame.wave and frame.board.round==frame.wave
	if frame.phase in ["victory","defeat"]:return patrol.phase=="closed" and (frame.phase!="victory" or patrol.settled_round==6)
	# Waiting is normally not published; it may precede the first reliable begin.
	return frame.phase=="waiting" and patrol.phase=="board" and patrol.settled_round==0

static func valid_payoff(value:Variant,player_count:int)->bool:
	if not value is Dictionary or not value.has_all(["waves","counters"]):return false
	if not value.waves is Array or value.waves.size()>4 or not value.counters is Dictionary or value.counters.size()>3:return false
	for key in ["pot_waves","followup_volleys","chain_baits"]:
		if not value.counters.get(key) is int or value.counters[key]<0 or value.counters[key]>1000000000:return false
	var ids:Dictionary={}
	for wave in value.waves:
		if not wave is Dictionary or not wave.has_all(["id","pos","direction","ttl","radius","owner"]):return false
		if not wave.id is int or wave.id<1 or wave.id>1000000000 or ids.has(wave.id):return false
		ids[wave.id]=true
		if not wave.owner is int or wave.owner<0 or wave.owner>=player_count:return false
		if not wave.pos is Vector2 or not wave.pos.is_finite() or absf(wave.pos.x)>32 or absf(wave.pos.y)>32:return false
		if not wave.direction is Vector2 or not wave.direction.is_finite() or wave.direction.length_squared()<.0001 or wave.direction.length_squared()>1.01:return false
		if not _bounded_number(wave.ttl,0,1) or not _bounded_number(wave.radius,0,3):return false
	return true

static func clean_baits(value:Variant,player_count:int)->Dictionary:
	if not value is Array or value.size()>12:return {"ok":false}
	var clean:Array[Dictionary]=[]
	for bait in value:
		if not bait is Dictionary or not bait.has_all(["pos","ttl","owner"]):return {"ok":false}
		if not bait.pos is Vector2 or not bait.pos.is_finite() or absf(bait.pos.x)>32 or absf(bait.pos.y)>32:return {"ok":false}
		if not (bait.ttl is float or bait.ttl is int) or not is_finite(float(bait.ttl)) or bait.ttl<0 or bait.ttl>30:return {"ok":false}
		if not bait.owner is int or bait.owner<0 or bait.owner>=player_count:return {"ok":false}
		var entry:Dictionary={"pos":bait.pos,"ttl":float(bait.ttl),"owner":bait.owner}
		if bait.has("chain_tag"):
			if not bait.chain_tag is int or bait.chain_tag<0 or bait.chain_tag>1000000000:return {"ok":false}
			if bait.chain_tag>0:
				if not bait.get("chain_order") is int or bait.chain_order<1 or bait.chain_order>6:return {"ok":false}
				if not bait.get("chain_from") is Vector2 or not bait.chain_from.is_finite() or absf(bait.chain_from.x)>32 or absf(bait.chain_from.y)>32:return {"ok":false}
				entry.chain_tag=bait.chain_tag;entry.chain_order=bait.chain_order;entry.chain_from=bait.chain_from
			elif bait.has("chain_order") or bait.has("chain_from"):return {"ok":false}
		elif bait.has("chain_order") or bait.has("chain_from"):return {"ok":false}
		clean.append(entry)
	return {"ok":true,"value":clean}


static func clean_estate(value:Variant)->Dictionary:
	if not value is Dictionary or not value.has_all(["district_id","level","boost_remaining","activations"]):return {"ok":false}
	for key in ["district_id","level","activations"]:
		if not value[key] is int:return {"ok":false}
	if value.district_id<0 or value.district_id>2 or value.level<0 or value.level>2 or value.activations<0 or value.activations>32:return {"ok":false}
	if not value.boost_remaining is float and not value.boost_remaining is int:return {"ok":false}
	if not is_finite(float(value.boost_remaining)) or value.boost_remaining<0 or value.boost_remaining>3:return {"ok":false}
	var clean:Dictionary={"district_id":value.district_id,"level":value.level,"boost_remaining":float(value.boost_remaining),"activations":value.activations}
	return {"ok":true,"value":clean}


static func clean_enemy(value:Variant)->Dictionary:
	if not value is Dictionary or not value.has_all(["warnings","projectiles"]):return {"ok":false}
	if not value.warnings is Array or value.warnings.size()>24 or not value.projectiles is Array or value.projectiles.size()>36:return {"ok":false}
	var clean:Dictionary={"warnings":[],"projectiles":[]}
	for key in ["warnings","projectiles"]:
		var identities:Dictionary={}
		for entry in value[key]:
			if not entry is Dictionary or not entry.has_all(["id","pos","ttl"]):return {"ok":false}
			if not entry.id is int or entry.id<1 or entry.id>1000000000 or identities.has(entry.id):return {"ok":false}
			identities[entry.id]=true
			if not entry.pos is Vector2 or not entry.pos.is_finite() or absf(entry.pos.x)>128 or absf(entry.pos.y)>128:return {"ok":false}
			if not _bounded_number(entry.ttl,0,3):return {"ok":false}
			if key=="warnings":
				if not entry.has_all(["kind","direction","length"]):return {"ok":false}
				if not entry.kind is int or entry.kind not in [3,4]:return {"ok":false}
				if not entry.direction is Vector2 or not entry.direction.is_finite() or entry.direction.length_squared()>1.01 or entry.direction.length_squared()<.0001:return {"ok":false}
				if not _bounded_number(entry.length,0,12):return {"ok":false}
				clean.warnings.append({"id":entry.id,"kind":entry.kind,"pos":entry.pos,"direction":entry.direction,"length":float(entry.length),"ttl":float(entry.ttl)})
			else:
				if not entry.has("velocity") or not entry.velocity is Vector2 or not entry.velocity.is_finite() or entry.velocity.length_squared()>32*32:return {"ok":false}
				clean.projectiles.append({"id":entry.id,"pos":entry.pos,"velocity":entry.velocity,"ttl":float(entry.ttl)})
	return {"ok":true,"value":clean}


static func clean_rounds(value:Variant,seed_value:int=-1,run_token:int=-1)->Dictionary:
	if not value is Array or value.size()>6:return {"ok":false}
	var clean:Array[Dictionary]=[];var seen:Dictionary={}
	for record in value:
		if not record is Dictionary or record.size()!=9 or not record.has_all(["round","district_id","objective_completed","challenge","battle_completed","challenge_rule_version","challenge_available","challenge_qualified","challenge_result"]):return {"ok":false}
		if not record.round is int or record.round<1 or record.round>6 or seen.has(record.round):return {"ok":false}
		if not record.district_id is int or record.district_id<0 or record.district_id>2:return {"ok":false}
		for key in ["objective_completed","challenge","battle_completed","challenge_available","challenge_qualified"]:
			if not record[key] is bool:return {"ok":false}
		if not record.challenge_rule_version is int or record.challenge_rule_version!=Challenge.RULE_VERSION or not record.challenge_result is Dictionary:return {"ok":false}
		if not record.challenge and (record.challenge_available or record.challenge_qualified or not record.challenge_result.is_empty()):return {"ok":false}
		if record.challenge_result.is_empty():
			if record.challenge_qualified or record.challenge_available or record.challenge and record.battle_completed:return {"ok":false}
		else:
			if not Challenge.valid_result(record.challenge_result,seed_value,run_token,record.round,record.challenge,record.objective_completed,record.battle_completed):return {"ok":false}
			if record.challenge_available!=record.challenge_result.available or record.challenge_qualified!=record.challenge_result.qualified:return {"ok":false}
		seen[record.round]=true
		clean.append(record.duplicate(true))
	return {"ok":true,"value":clean}

static func valid_challenge_frame(frame:Dictionary)->bool:
	var value:Variant=frame.get("challenge_contract")
	if not value is Dictionary or not value.get("wave") is int or not value.get("district") is int:return false
	if not Challenge.valid_state(value,frame.seed_value,frame.board.run_token,value.wave,value.district,frame.elapsed):return false
	for record in value.killed_records:
		if record.actor>=frame.players.size():return false
	if frame.legacy_diagnostic:return value.wave in [0,frame.wave] and not value.accepted and value.phase in ["inactive","closed"] and value.group.is_empty() and value.killed_records.is_empty() and frame.round_results.is_empty()
	if value.wave!=frame.wave:return false
	if frame.wave==0:return not value.accepted and value.district==-1 and value.battle_started_at==0 and frame.round_results.is_empty()
	if not frame.get("rule") is Dictionary or not _bounded_number(frame.rule.get("started_at"),0,10000000) or value.battle_started_at!=frame.rule.started_at:return false
	if not Challenge.valid_district_context(value,frame.get("district")):return false
	if frame.phase=="battle":
		var local_time:float=float(frame.elapsed)-float(value.battle_started_at)
		var district_time:float=float(frame.district.elapsed)
		if district_time>local_time+Challenge.CLOCK_EPSILON:return false
		if not frame.district.completed and absf(district_time-local_time)>Challenge.CLOCK_EPSILON:return false
	if not frame.get("district") is Dictionary or value.district!=frame.district.get("district_id") or value.wave!=frame.district.get("wave"):return false
	var current:Dictionary={}
	for record in frame.round_results:
		if record.round==frame.wave:current=record
		if record.challenge and record.challenge_result.is_empty() and (record.round!=frame.wave or frame.phase!="battle"):return false
		var turn:Dictionary={}
		for item in frame.board.history:
			if item.round==record.round:turn=item;break
		if turn.is_empty() or (turn.choice==1)!=record.challenge or Board.DISTRICTS[turn.position]!=record.district_id:return false
	if current.is_empty() or current.challenge!=value.accepted or current.challenge_rule_version!=value.rule_version:return false
	if value.accepted and current.objective_completed!=(value.objective_sequence>0):return false
	if value.objective_sequence>0 and (not frame.district.completed or value.objective_sequence!=frame.district.event_serial):return false
	if frame.phase=="battle":
		if value.settled or current.battle_completed or not current.challenge_result.is_empty():return false
		if value.accepted!=frame.board.challenge:return false
		if value.phase=="marked":
			for entity in value.group:
				var killed:=false
				for record in value.killed_records:
					if record.identity==entity.identity:killed=true;break
				if killed:continue
				var found:=false
				for enemy in frame.enemies:
					if enemy is Array and enemy.size()==9 and enemy[8]==entity.identity and enemy[4]==entity.kind:found=true;break
				if not found:return false
	elif value.accepted:
		if not value.settled or current.challenge_result.is_empty():return false
		var result:Dictionary=current.challenge_result
		for key in ["group_serial","spawn_at","clear_at","objective_sequence","reason"]:
			if result[key]!=value[key]:return false
		if result.group_size!=value.group.size() or result.killed_count!=value.killed_records.size():return false
	return true

static func _bounded_number(value:Variant,low:float,high:float)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
