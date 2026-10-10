class_name FurPartyArena
extends Node3D
const Presentation=preload("res://scripts/party/party_combat_presentation.gd")
const EnemyGeometry=preload("res://scripts/party/party_enemy_geometry.gd")
const CombatAI=preload("res://scripts/party/party_combat_ai.gd")
const Growth=preload("res://scripts/party/party_growth.gd")

signal completed(won:bool,builds:Array)
var model:FurCombatModel
var view:FurCombatView
var ai_enabled:=true
var running:=false
var collected:=false
var elapsed:=0.0
var round_number:=1
var toys:Array[FurPartyPawn]=[]
var battle_context:Dictionary={}
var temporary_bonuses:Array=[]
var region_stage:FurPartyArenaStage

func begin(seed_value:int,round_value:int,use_ai:bool,builds:Array,context:Dictionary={},start_running:bool=true)->void:
	ai_enabled=use_ai;round_number=round_value;model=FurCombatModel.new()
	battle_context=context.duplicate(true);temporary_bonuses.clear()
	model.start([0,1],seed_value,false)
	for i in 2:
		if builds.size()==2:model.players[i].build=builds[i].duplicate(true)
		var bonus:Dictionary=context.get("bonuses",[{"health_bonus":0.0,"damage_bonus":0.0},{"health_bonus":0.0,"damage_bonus":0.0}])[i]
		var health_bonus:float=clampf(float(bonus.get("health_bonus",0.0)),0.0,32.0)
		var damage_bonus:float=clampf(float(bonus.get("damage_bonus",0.0)),0.0,.24)
		model.players[i].build.health+=health_bonus;model.players[i].build.damage+=damage_bonus
		temporary_bonuses.append({"health_bonus":health_bonus,"damage_bonus":damage_bonus})
		model.players[i].hp=model.players[i].build.health
	# A party round is one bounded arena wave. The adapter owns the starting
	# wave, while live combat/damage/spawning/defeat use the existing model.
	var combat_wave:int=clampi(round_number,1,6)
	model.skip_board_for_checks=true;model.wave=combat_wave-1;model.next_wave(clampi(int(context.get("route",(round_number-1)%3)),0,2))
	view=FurCombatView.new();view.party_profile=true;view.enemy_geometry_override=EnemyGeometry.mesh();add_child(view);view.local_duo=true;view.bind(model);view.set_music(false)
	Presentation.configure(view)
	region_stage=FurPartyArenaStage.new();add_child(region_stage);region_stage.build(model.route)
	for i in 2:
		var hero:Dictionary=view.heroes[i];hero.body.queue_free()
		# Legacy locomotion faces -Z; the new toy's muzzle faces +Z. Keep
		# this art adapter local instead of reversing gameplay or old assets.
		var pivot:=Node3D.new();pivot.name="ToyFacingAdapter";hero.root.add_child(pivot);hero.body=pivot
		var toy:=FurPartyPawn.new();toy.build(i);toy.set_style(int(model.players[i].build.get("style",0)));toy.rotation.y=PI;pivot.add_child(toy)
		hero["party_toy"]=toy
		hero.plush_walk.materials.clear();toys.append(toy)
	running=start_running

func _physics_process(delta:float)->void:
	if not running or model==null:return
	if model.phase!="battle":
		if model.phase in ["draft","victory","defeat"] and not collected:
			collected=true;running=false
			# finish_wave collects remaining XP after the regular tick's level
			# pass. Resolve that real reward before exporting persistent builds.
			model.resolve_experience()
			completed.emit(model.phase!="defeat",persistent_builds())
		return
	elapsed+=delta
	var first:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	model.set_input(0,first,Input.is_action_just_pressed("fur_dash"),Input.is_action_just_pressed("fur_skill"))
	if ai_enabled:
		var ai:=ai_direction()
		model.set_input(1,ai,ai.length_squared()>.1 and fmod(elapsed,2.2)<delta,model.players[1].skill_cd<=0 and model.enemies.active.size()>2)
	else:
		var second:=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		model.set_input(1,second,Input.is_action_just_pressed("fur_dash_p2"),Input.is_action_just_pressed("fur_skill_p2"))
	model.tick(delta)

func persistent_builds()->Array:
	var result:Array=[]
	for actor in model.players.size():
		var build:Dictionary=model.players[actor].build.duplicate(true)
		build.health-=float(temporary_bonuses[actor].health_bonus)
		build.damage-=float(temporary_bonuses[actor].damage_bonus)
		result.append(build)
	return result

func ai_direction()->Vector2:
	return CombatAI.movement(model,elapsed)

func restore_growth(growth:Dictionary)->bool:
	return not running and Growth.restore(model,growth)

func growth_snapshot()->Dictionary:
	return Growth.snapshot(model)

func present_outcome(won:bool)->void:
	running=false
	for toy in toys:toy.walking=false
	view.party_outcome=won
	# Only after authority terminal state: a bounded two-percent push-in
	# preserves the shared camera angle and cannot hide live hazards.
	var tween:=create_tween();tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(view.camera,"size",view.camera.size*.98,.65)

func close()->void:
	running=false
	if view!=null:
		view.set_music(false)
		for child in view.find_children("*","AudioStreamPlayer",true,false):child.stop();child.stream=null
	queue_free()
