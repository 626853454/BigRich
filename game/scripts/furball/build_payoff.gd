class_name FurBuildPayoff
extends RefCounted

# Authority-side bounded action shapes. Rendering and audio consume normal events.
const WAVE_LIMIT:=4
const SALVO_LIMIT:=4
const CHAIN_LIMIT:=6
const FOLLOWUP_SHOT_LIMIT:=192
var waves:Array[Dictionary]=[]
var salvos:Array[Dictionary]=[]
# Authority-only provenance. Stable shot identities prevent a recycled slot from
# turning an ordinary bullet into a breakthrough shot; no new network shot fields.
var followup_shots:Dictionary={}
var sequence:=0
var counters:={"pot_waves":0,"followup_volleys":0,"chain_baits":0}

func reset() -> void:
	waves.clear();salvos.clear();sequence=0
	followup_shots.clear()
	counters={"pot_waves":0,"followup_volleys":0,"chain_baits":0}

func clear_pending() -> void:
	waves.clear();salvos.clear()
	followup_shots.clear()

func is_followup_shot(model:FurCombatModel,slot:int)->bool:
	if slot<0 or slot>=model.shots.capacity or model.shots.rank[slot]<0:return false
	return followup_shots.get(model.shots.identity[slot],-1)==slot

func _prune_followup_shots(model:FurCombatModel)->void:
	for identity in followup_shots.keys():
		var slot:int=followup_shots[identity]
		if slot<0 or slot>=model.shots.capacity or model.shots.rank[slot]<0 or model.shots.identity[slot]!=identity:followup_shots.erase(identity)

func release_pot(model:FurCombatModel,owner:int,banked:float) -> bool:
	if owner<0 or owner>=model.players.size() or not is_finite(banked) or banked<35:return false
	var player:Dictionary=model.players[owner]
	if player.down or player.build.style!=0 or player.build.masterwork!="verdict":return false
	if waves.size()>=WAVE_LIMIT:return false
	sequence+=1
	var direction:Vector2=player.input.normalized() if player.input.length_squared()>.02 else Vector2(0,-1)
	waves.append({"id":sequence,"owner":owner,"pos":player.pos,"direction":direction,"ttl":.65,"radius":minf(3,1.2*player.build.area),"damage":(12+banked*.45)*player.build.damage,"hits":{}})
	counters.pot_waves+=1;model.emit("pot_wave",player.pos,banked,owner,true)
	player.build.payoff_waves+=1
	return true

func release_volley(model:FurCombatModel,owner:int,direction:Vector2,charge:float,initial_target_identity:int=0) -> int:
	if owner<0 or owner>=model.players.size() or not is_finite(charge) or charge<2 or not direction.is_finite() or direction.length_squared()<.001:return 0
	var player:Dictionary=model.players[owner]
	if player.down or player.build.style!=1 or player.build.masterwork not in ["assembly","piercing"]:return 0
	var count:=2 if player.build.masterwork=="assembly" else 1
	if salvos.size()+count>SALVO_LIMIT:return 0
	# Each release shares at most two stable-ID reservations. The sector is
	# committed when movement releases charge; only the origin follows the hero.
	var burst:Dictionary={}
	if player.build.masterwork=="assembly":
		var forward:Vector2=player.input.normalized() if player.input.is_finite() and player.input.length_squared()>.02 else direction.normalized()
		burst={"forward":forward,"initial_identity":initial_target_identity,"reserved":{}}
	for index in count:
		salvos.append({"owner":owner,"direction":direction.normalized(),"delay":.14+index*.14,"charge":charge,"burst":burst})
	model.emit("barrage_ready",player.pos,count,owner,true)
	return count


func _select_volley_target(model:FurCombatModel,player:Dictionary,burst:Dictionary,fallback:Vector2)->Dictionary:
	var result:Dictionary={"identity":0,"direction":fallback}
	if burst.is_empty():return result
	var forward:Vector2=burst.forward
	var best_priority:=-1;var best_distance:=INF;var best_identity:=0
	# Only due salvos scan, once each. No navigation, sorting or random draws.
	for index in mini(model.enemies.active.size(),FurCombatModel.ENEMY_LIMIT):
		var slot:int=model.enemies.active[index]
		if slot<0 or slot>=model.enemies.capacity or model.enemies.rank[slot]<0 or model.enemies.kind[slot]==2:continue
		var identity:int=model.enemies.identity[slot]
		if identity<=0 or identity==burst.initial_identity or burst.reserved.has(identity):continue
		var point:Vector2=model.enemies.pos[slot]
		if not point.is_finite() or not is_finite(model.enemies.hp[slot]) or model.enemies.hp[slot]<=0:continue
		var offset:Vector2=point-player.pos;var distance:float=offset.length_squared()
		if distance<.000001 or distance>169 or offset.dot(forward)<sqrt(distance)*.5:continue
		var priority:=0
		var behavior:Dictionary=model.enemy_behaviors.states.get(identity,{})
		if model.enemies.kind[slot] in [3,4] and behavior.get("slot",-1)==slot and behavior.get("kind",-1)==model.enemies.kind[slot] and behavior.get("phase","")=="windup":priority=1
		if priority>best_priority or (priority==best_priority and (distance<best_distance or (distance==best_distance and (best_identity==0 or identity<best_identity)))):
			best_priority=priority;best_distance=distance;best_identity=identity
			result={"identity":identity,"direction":offset.normalized()}
	return result

func release_chain(model:FurCombatModel,owner:int) -> int:
	if owner<0 or owner>=model.players.size():return 0
	var player:Dictionary=model.players[owner]
	if player.down or player.build.style!=2 or not player.build.bait_chain:return 0
	return _schedule_chain(model,owner,player.pos,8)

func chain_from(model:FurCombatModel,bait:Dictionary) -> int:
	# Tagged participants cannot recursively start an overlapping unbounded chain.
	if bait.get("chain_tag",0)>0:return 0
	return _schedule_chain(model,int(bait.owner),bait.pos,4,bait)

func _schedule_chain(model:FurCombatModel,owner:int,origin:Vector2,radius:float,exclude:Dictionary={}) -> int:
	if owner<0 or owner>=model.players.size():return 0
	var eligible:Array[Dictionary]=[]
	for bait in model.baits:
		if is_same(bait,exclude) or bait.owner!=owner or bait.get("chain_tag",0)>0:continue
		if bait.pos.distance_squared_to(origin)<=radius*radius:eligible.append(bait)
	eligible.sort_custom(func(a:Dictionary,b:Dictionary):return a.pos.distance_squared_to(origin)<b.pos.distance_squared_to(origin))
	var count:=mini(CHAIN_LIMIT,eligible.size())
	if count==0:return 0
	sequence+=1
	for index in count:
		eligible[index]["chain_tag"]=sequence
		eligible[index]["chain_order"]=index+1
		eligible[index]["chain_from"]=origin if index==0 else eligible[index-1].pos
		eligible[index].ttl=minf(eligible[index].ttl,.12+index*.12)
	counters.chain_baits+=count;model.emit("chain_ready",origin,count,owner,true)
	model.players[owner].build.payoff_baits+=count
	return count

func tick(model:FurCombatModel,delta:float) -> void:
	if model.phase!="battle":return
	_prune_followup_shots(model)
	for index in range(waves.size()-1,-1,-1):
		var wave:Dictionary=waves[index]
		wave.ttl-=delta
		if wave.ttl<=0 or wave.owner>=model.players.size() or model.players[wave.owner].down:waves.remove_at(index);continue
		wave.pos+=wave.direction*delta*10
		for slot in model.grid.nearby(wave.pos,wave.radius):
			if wave.hits.size()>=FurCombatModel.ENEMY_LIMIT:break
			if model.enemies.rank[slot]<0 or wave.hits.has(model.enemies.identity[slot]):continue
			if model.enemies.pos[slot].distance_squared_to(wave.pos)>wave.radius*wave.radius:continue
			wave.hits[model.enemies.identity[slot]]=true
			if model.enemies.kind[slot]!=2 or model.enemies.life[slot]>FurBossCatalog.attack(model.wave,model.boss_pattern).windup:
				model.enemies.velocity[slot]+=wave.direction*4
			model.enemy_behaviors.interrupt(model,slot,model.enemies.identity[slot],wave.owner,"pot_wave",wave.id)
			model.damage_enemy(slot,wave.damage,wave.owner)
	for index in range(salvos.size()-1,-1,-1):
		var salvo:Dictionary=salvos[index];salvo.delay-=delta
		if salvo.delay>0:continue
		salvos.remove_at(index)
		if salvo.owner>=model.players.size():continue
		var player:Dictionary=model.players[salvo.owner]
		if player.down:continue
		var target:Dictionary=_select_volley_target(model,player,salvo.get("burst",{}),salvo.direction)
		var emitted:=0
		for weapon in player.build.weapons:
			var slot:=model.shots.acquire(player.pos,(5+model.wave*.4)*player.build.damage*(1+salvo.charge*.35),salvo.owner)
			if slot<0:break
			emitted+=1
			if followup_shots.size()<FOLLOWUP_SHOT_LIMIT:followup_shots[model.shots.identity[slot]]=slot
			var spread:float=(weapon-(player.build.weapons-1)*.5)*.08
			model.shots.velocity[slot]=target.direction.rotated(spread)*19
			model.shots.life[slot]=1.25;model.shots.owner[slot]=salvo.owner
			model.shots.marked[slot]=player.build.bounce
			model.shots.penetration[slot]=2 if player.build.masterwork=="piercing" else 0
		if emitted>0:
			if target.identity>0:salvo.burst.reserved[target.identity]=true
			counters.followup_volleys+=1;player.build.payoff_volleys+=1;model.emit("volley",player.pos,1,salvo.owner,true)

func presentation() -> Dictionary:
	var result:Array=[]
	for wave in waves:result.append({"id":wave.id,"pos":wave.pos,"direction":wave.direction,"ttl":wave.ttl,"radius":wave.radius,"owner":wave.owner})
	return {"waves":result,"counters":counters.duplicate()}
