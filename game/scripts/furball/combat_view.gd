class_name FurCombatView
extends Node3D

const CORGI = preload("res://assets/furball/corgi_plush.glb")
const ENEMY = preload("res://assets/furball/popcorn_creature.glb")
const MARKET = preload("res://assets/furball/popcorn_market.glb")
const HATS = [preload("res://assets/furball/hat_pot.glb"),preload("res://assets/furball/hat_mechanic.glb")]
const WEAPONS = [preload("res://assets/furball/weapon_pan.glb"),preload("res://assets/furball/weapon_blaster.glb"),preload("res://assets/furball/weapon_cookie.glb")]
const PartyAssets=preload("res://scripts/party/soft_character_assets.gd")
const COLOURS := [Color("ffac64"),Color("6be7ed")]
var model: FurCombatModel
var party_outcome:=false
var camera: Camera3D
var heroes: Array[Dictionary] = []
var enemy_mesh: MultiMeshInstance3D
var enemy_kind_batches:Array[MultiMeshInstance3D]=[]
var enemy_geometry_override:Mesh
var shadow_mesh: MultiMeshInstance3D
var mark_mesh: MultiMeshInstance3D
var protection_link: MeshInstance3D
var shot_mesh: MultiMeshInstance3D
var pickup_mesh: MultiMeshInstance3D
var bait_nodes: Array[Node3D] = []
var rings: Array[Dictionary] = []
var labels: Array[Dictionary] = []
var clock := 0.0
var low_fx := false
var popup_clock := 0.0
var popups_this_window := 0
var frame_times: Array[float] = []
var peak_frame_ms := 0.0
var showcase := false
var debris_mesh: MultiMeshInstance3D
var debris: Array[Dictionary]=[]
var sound: AudioStreamPlayer
var sound_clock:=0.0
var rule_rings: Array[MeshInstance3D] = []
var rule_captions: Array[Label3D] = []
var action_sounds: Array[AudioStreamPlayer] = []
var action_sound_clocks: Array[float] = [0.0,0.0]
var enemy_motion := FurNetworkMotion.new()
var shot_motion := FurNetworkMotion.new()
var pickup_motion := FurNetworkMotion.new()
var network_motion := false
var warning_voice: AudioStreamPlayer
var warning_clock := 0.0
var market_story: FurMarketStory
var bell_voice: AudioStreamPlayer
var combat_visible:=true
var music_voice: AudioStreamPlayer
var music_enabled:=true
var impact_feedback:FurImpactFeedback
var payoff_view:FurBuildPayoffView
var district_view:FurDistrictView
var task_formations_view
var challenge_view
var enemy_behavior_view:FurEnemyBehaviorView
var order_view
var local_duo:=false
## Set before add_child/_ready. The default retains the original game/gallery.
## Party owns its stage and toy bodies; do not construct discarded legacy art.
var party_profile:=false
var payoff_caption_top:=292.0
const OrderView=preload("res://scripts/furball/shared_order_view.gd")
const TaskFormationsView=preload("res://scripts/furball/task_formations_view.gd")
const ChallengeView=preload("res://scripts/furball/challenge_view.gd")
const MARKET_THEME=preload("res://assets/furball/market-theme.wav")
const BELL_CUE=preload("res://assets/furball/closing-bell.wav")
const WARNING_CUE=preload("res://assets/furball/notice-warning.wav")
const ACTION_CUES = {"sweep":preload("res://assets/furball/pan-tap.wav"),"volley":preload("res://assets/furball/bubble-volley.wav"),"burst":preload("res://assets/furball/cookie-burst.wav"),"ready":preload("res://assets/furball/charge-ready.wav"),"order_fulfilled":preload("res://assets/furball/charge-ready.wav"),"payoff_interrupt":preload("res://assets/furball/charge-ready.wav")}

func _ready() -> void:
	music_enabled=not party_profile
	impact_feedback=FurImpactFeedback.new();add_child(impact_feedback)
	payoff_view=FurBuildPayoffView.new();add_child(payoff_view)
	if not party_profile:
		district_view=FurDistrictView.new();add_child(district_view)
		task_formations_view=TaskFormationsView.new();add_child(task_formations_view)
		challenge_view=ChallengeView.new();add_child(challenge_view)
		order_view=OrderView.new();add_child(order_view)
	enemy_behavior_view=FurEnemyBehaviorView.new();add_child(enemy_behavior_view)
	if not party_profile:
		add_child(MARKET.instantiate())
		market_story=FurMarketStory.new();add_child(market_story)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202c48")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c1d5eb")
	settings.ambient_light_energy = .30
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if party_profile:
		FurAtelierLighting.daylight(settings);settings.sky.sky_material.energy_multiplier=.30;settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("a7cbd3")
	environment.environment = settings; add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58,-28,0)
	sun.light_color = Color("fff0cb"); sun.light_energy = .65
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 55
	if party_profile:
		FurArtLighting.key(sun);sun.rotation_degrees=Vector3(-46,-48,0);sun.light_energy=1.60;sun.light_color=Color("fff0d9")
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40,145,0)
	fill.light_color = Color("b1d9ef"); fill.light_energy = .08 if party_profile else .18
	add_child(fill)
	camera = Camera3D.new(); camera.position = Vector3(0,25,16)
	camera.fov = 47; camera.far = 90; add_child(camera)
	camera.look_at(Vector3(0,0,0)); camera.current = true
	enemy_mesh = _instances(enemy_geometry_override if enemy_geometry_override!=null else _asset_mesh(ENEMY),FurCombatModel.ENEMY_LIMIT)
	if party_profile:
		enemy_kind_batches.append(enemy_mesh)
		for kind in [1,2]:enemy_kind_batches.append(_instances(FurPartyEnemyGeometry.mesh(kind),FurCombatModel.ENEMY_LIMIT))
		# Authoritative arena bounds plus the largest elite silhouette. These
		# batches begin empty; stable bounds avoid one stale empty AABB on first spawn.
		for batch in enemy_kind_batches:batch.multimesh.custom_aabb=AABB(Vector3(-16,-1,-12),Vector3(32,7,24))
	var stamp:=SphereMesh.new();stamp.radius=.12;stamp.height=.24;stamp.radial_segments=4;stamp.rings=1
	mark_mesh=_instances(stamp,FurCombatModel.ENEMY_LIMIT);mark_mesh.material_override=_material(Color("ffc669"),.4)
	protection_link=MeshInstance3D.new();var thread:=CylinderMesh.new();thread.top_radius=.035;thread.bottom_radius=.035;thread.height=1;thread.radial_segments=8
	protection_link.mesh=thread;protection_link.material_override=_material(Color("ffd581"),.25);protection_link.visible=false
	protection_link.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(protection_link)
	var disk := CylinderMesh.new(); disk.top_radius=.42;disk.bottom_radius=.42;disk.height=.005
	shadow_mesh = _instances(disk,FurCombatModel.ENEMY_LIMIT)
	var shadow_material := _material(Color(0.14,.09,.22,.20))
	shadow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mesh.material_override=shadow_material
	var bullet := SphereMesh.new();bullet.radius=.075;bullet.height=.15;bullet.radial_segments=8;bullet.rings=4
	shot_mesh = _instances(FurFeedbackMeshes.mesh("bubble_shot_atelier") if party_profile else bullet,FurCombatModel.SHOT_LIMIT)
	shot_mesh.material_override=_material(Color("b2ffff"),.5)
	var gem := PrismMesh.new();gem.size=Vector3(.16,.25,.16)
	pickup_mesh=_instances(FurFeedbackMeshes.mesh("experience_mote_atelier") if party_profile else gem,FurCombatModel.PICKUP_LIMIT)
	pickup_mesh.material_override=_material(Color("4cef9b"),.2)
	var chip:=BoxMesh.new();chip.size=Vector3(.08,.12,.08)
	debris_mesh=_instances(chip,96);debris_mesh.material_override=_material(Color.WHITE,.15)
	sound=AudioStreamPlayer.new();sound.stream=preload("res://assets/furball/pop.wav")
	sound.volume_db=-20;add_child(sound)
	warning_voice=AudioStreamPlayer.new();warning_voice.stream=WARNING_CUE;warning_voice.volume_db=-15;add_child(warning_voice)
	if not party_profile:
		bell_voice=AudioStreamPlayer.new();bell_voice.stream=BELL_CUE;bell_voice.volume_db=-14;add_child(bell_voice)
		music_voice=AudioStreamPlayer.new();var theme:=MARKET_THEME.duplicate() as AudioStreamWAV
		theme.loop_mode=AudioStreamWAV.LOOP_FORWARD;theme.loop_begin=0;theme.loop_end=int(round(theme.get_length()*theme.mix_rate))
		music_voice.stream=theme;music_voice.volume_db=-28;add_child(music_voice);music_voice.play()
	for index in 2:
		var voice:=AudioStreamPlayer.new();voice.volume_db=-23;add_child(voice);action_sounds.append(voice)
	for i in 12:
		var cookie := WEAPONS[2].instantiate() as Node3D
		cookie.visible=false;add_child(cookie);bait_nodes.append(cookie)
	_create_feedback()
	for index in 7:
		var marker := MeshInstance3D.new()
		var circle := TorusMesh.new(); circle.inner_radius=.96; circle.outer_radius=1.0
		circle.rings=48; circle.ring_segments=6
		marker.mesh=circle;marker.visible=false;marker.position.y=.13
		marker.material_override=_material(Color("ff596d"),.5)
		marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker);rule_rings.append(marker)
		var caption := Label3D.new();var font := FurVisualStyle.font()
		caption.font=font;caption.font_size=48;caption.pixel_size=.013
		caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;caption.no_depth_test=true
		caption.outline_size=8;caption.outline_modulate=Color("26283b");caption.visible=false
		add_child(caption);rule_captions.append(caption)

func bind(next_model: FurCombatModel) -> void:
	model=next_model
	impact_feedback.clear()
	payoff_view.clear()
	_clear_optional_views()
	enemy_behavior_view.clear()
	combat_visible=true;_set_combat_visibility(true)
	clear_network_motion();network_motion=false
	debris.clear();sound.stop();warning_voice.stop();warning_clock=0
	if market_story!=null:market_story.reset()
	if bell_voice!=null:bell_voice.stop()
	for voice in action_sounds:voice.stop()
	for entry in rings:entry.life=0;entry.node.visible=false
	for entry in labels:entry.life=0;entry.node.visible=false
	for hero in heroes:hero.root.queue_free()
	heroes.clear()
	for index in model.players.size():
		var player: Dictionary=model.players[index]
		var root:=Node3D.new();root.name="Corgi_P%d" % (index+1);add_child(root)
		root.position=Vector3(player.pos.x,0,player.pos.y)
		var locomotion:=FurHeroMotion.new();locomotion.reset(root.position)
		var body:Node3D=Node3D.new() if party_profile else CORGI.instantiate() as Node3D
		root.add_child(body);body.rotation.y=PI
		var plush_walk:=FurPlushGait.new()
		if not party_profile:
			plush_walk.attach(body)
			var hat:=FurCharacterDetails.promise_hat() if player.build.style==2 else HATS[player.build.style].instantiate() as Node3D
			hat.position=Vector3(0,2.10,0);body.add_child(hat)
		var circle:=MeshInstance3D.new();var torus:=TorusMesh.new()
		torus.inner_radius=.58;torus.outer_radius=.63;torus.rings=32;torus.ring_segments=8
		circle.mesh=torus;circle.position.y=.06;circle.material_override=_material(COLOURS[index],.3)
		root.add_child(circle)
		var protection:=MeshInstance3D.new();var shield_shape:=TorusMesh.new()
		shield_shape.inner_radius=.73;shield_shape.outer_radius=.78;shield_shape.rings=24;shield_shape.ring_segments=4
		protection.mesh=FurFeedbackMeshes.mesh("rescue_halo_atelier") if party_profile else shield_shape;protection.position.y=.09;protection.visible=false
		protection.material_override=_material(Color("ffd581"),.3);protection.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(protection)
		var rescue:=Label3D.new();var rescue_font:=FurVisualStyle.font()
		rescue.font=rescue_font;rescue.font_size=38;rescue.pixel_size=.012
		rescue.billboard=BaseMaterial3D.BILLBOARD_ENABLED;rescue.no_depth_test=true
		rescue.outline_size=8;rescue.outline_modulate=Color("26283b");rescue.position.y=2.4;rescue.visible=false;root.add_child(rescue)
		var weapons: Array[Node3D]=[]
		for weapon in 6:
			var instance:Node3D=PartyAssets.weapon(player.build.style) if party_profile else WEAPONS[player.build.style].instantiate() as Node3D
			root.add_child(instance);weapons.append(instance)
		heroes.append({"root":root,"body":body,"weapons":weapons,"ring":circle,"rescue":rescue,"protection":protection,"hurt":0.0,"locomotion":locomotion,"plush_walk":plush_walk,"aim_yaw":0.0})

func _set_combat_visibility(visible_value: bool) -> void:
	for hero in heroes:hero.root.visible=visible_value
	for node in [enemy_mesh,shadow_mesh,mark_mesh,shot_mesh,pickup_mesh,debris_mesh]:node.visible=visible_value
	for node in enemy_kind_batches:node.visible=visible_value
	if visible_value:return
	protection_link.visible=false
	for node in bait_nodes:node.visible=false
	for node in rule_rings:node.visible=false
	for node in rule_captions:node.visible=false
	for entry in rings:entry.node.visible=false;entry.life=0
	for entry in labels:entry.node.visible=false;entry.life=0
	debris.clear();sound.stop();warning_voice.stop()
	if bell_voice!=null:bell_voice.stop()
	impact_feedback.clear()
	payoff_view.clear()
	_clear_optional_views()
	enemy_behavior_view.clear()
	for voice in action_sounds:voice.stop()

func set_music(enabled: bool) -> void:
	music_enabled=enabled and not party_profile
	if music_voice==null:return
	if enabled and not music_voice.playing:music_voice.play()
	elif not enabled:music_voice.stop()

func _clear_optional_views()->void:
	for optional in [district_view,order_view,task_formations_view,challenge_view]:
		if optional!=null:optional.clear()

func _material(colour: Color, emission: float=0) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=colour
	material.roughness=.65;material.vertex_color_use_as_albedo=true
	if emission>0:
		material.emission_enabled=true;material.emission=colour;material.emission_energy_multiplier=emission
	return material

func _asset_mesh(asset: PackedScene) -> Mesh:
	var instance:=asset.instantiate()
	var meshes:=instance.find_children("*","MeshInstance3D",true,false)
	var result: Mesh=meshes[0].mesh
	for surface in result.get_surface_count():
		var material:=result.surface_get_material(surface) as StandardMaterial3D
		if material!=null:material.vertex_color_use_as_albedo=true
	instance.free();return result

func _instances(mesh: Mesh, limit: int) -> MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new()
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true;batch.mesh=mesh;batch.instance_count=limit;batch.visible_instance_count=0
	node.multimesh=batch;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node);return node

func _process(delta: float) -> void:
	clock+=delta;popup_clock+=delta
	sound_clock=maxf(0,sound_clock-delta)
	warning_clock=maxf(0,warning_clock-delta)
	for index in 2:action_sound_clocks[index]=maxf(0,action_sound_clocks[index]-delta)
	peak_frame_ms=maxf(peak_frame_ms,delta*1000)
	if frame_times.size()<3600:frame_times.append(delta*1000)
	if popup_clock>.1:popup_clock=0;popups_this_window=0
	if model==null:return
	if market_story!=null:
		var story_milestone:=market_story.update_story(model,delta)
		if story_milestone>0 and bell_voice!=null:
			bell_voice.pitch_scale=1.0 if story_milestone==1 else 1.2
			bell_voice.play()
	if not showcase:
		var should_show:=model.phase not in ["camp","waiting","board"]
		if should_show!=combat_visible:combat_visible=should_show;_set_combat_visibility(should_show)
		if not should_show:model.events.clear();return
	_update_heroes(delta)
	_update_protection()
	_update_batches()
	_update_rule_markers()
	_consume_events()
	_tick_feedback(delta)
	_tick_debris(delta)
	impact_feedback.tick(delta,low_fx)
	var authority_payoff:Variant=model.get("payoff")
	var state:Variant=model.get("payoff_state") if network_motion else (authority_payoff.presentation() if authority_payoff!=null else {})
	payoff_view.render(state if state is Dictionary else {},delta,low_fx)
	payoff_view.render_baits(model.baits if model.phase=="battle" else [],low_fx)
	var district_runtime:Variant=model.get("district")
	if district_view!=null:
		if model.phase=="battle" and district_runtime!=null and not model.skip_board_for_checks:
			district_view.caption_top=payoff_caption_top
			district_view.render(district_runtime.state)
		else:district_view.clear()
	if task_formations_view!=null:
		if model.phase=="battle" and not model.skip_board_for_checks:
			task_formations_view.render(model.task_formation_preview,model.elapsed,delta,network_motion)
		else:task_formations_view.clear()
	if challenge_view!=null:
		if model.phase=="battle" and not model.skip_board_for_checks:
			challenge_view.render(model.challenge_contract.snapshot(),model.enemies,enemy_motion,clock,network_motion,model.elapsed,delta)
		else:challenge_view.clear()
	if order_view!=null:
		if model.phase=="battle" and not model.skip_board_for_checks:
			var carrier_projection:Variant=null
			var cargo:Dictionary=model.shared_order.state.get("cargo",{})
			if not cargo.is_empty() and cargo.phase=="carrying" and int(cargo.carrier)>=0 and int(cargo.carrier)<heroes.size():
				var shown:Vector3=heroes[int(cargo.carrier)].root.position
				carrier_projection=Vector2(shown.x,shown.z)
			order_view.render(model.shared_order.state,low_fx,local_duo,carrier_projection)
		else:order_view.clear()
	if model.phase=="battle":enemy_behavior_view.apply_presentation(model.enemy_behavior_state,low_fx)
	else:enemy_behavior_view.clear()

func _update_heroes(delta: float) -> void:
	for index in heroes.size():
		var player: Dictionary=model.players[index];var hero: Dictionary=heroes[index]
		var destination:=Vector3(player.pos.x,0,player.pos.y)
		hero.hurt=maxf(0,hero.hurt-delta)
		var locomotion: FurHeroMotion=hero.locomotion
		var charge_pose:float=clampf(player.charge/2.5,0,1) if player.build.style==1 and not player.down else 0.0
		locomotion.advance(destination,delta,model.phase=="battle",player.down,player.dash>0,charge_pose,hero.hurt,model.phase=="victory" or (party_profile and party_outcome))
		hero.root.position=locomotion.position
		hero.body.position.y=locomotion.height
		hero.body.rotation=Vector3(locomotion.pitch,locomotion.yaw,locomotion.roll)
		hero.body.scale=locomotion.scale
		if party_profile and hero.has("party_toy"):hero.party_toy.set_motion(locomotion.gait_phase,0.0 if player.down else locomotion.gait_weight)
		hero.plush_walk.update(locomotion.gait_phase,locomotion.gait_weight,locomotion.height)
		hero.ring.scale=Vector3.ONE*(1.0+.05*sin(clock*5))
		hero.ring.material_override.albedo_color=Color("ff7285") if player.down else COLOURS[index]
		hero.rescue.visible=player.down and model.players.size()>1 and model.phase=="battle"
		if hero.rescue.visible:hero.rescue.text="靠近救援 %.1f / 2.5秒" % player.revive
		var count: int=player.build.weapons
		var target := model.nearest_enemy(player.pos,14) if player.build.style==1 else -1
		for weapon in 6:
			var node: Node3D=hero.weapons[weapon];node.visible=weapon<count and not player.down
			var angle:=float(weapon)/count*TAU+clock*(1.7 if player.build.style==0 else .28)
			node.position=Vector3(cos(angle)*.95,1.0+sin(clock*3+weapon)*.04,sin(angle)*.95)
			node.rotation=Vector3(.25 if player.build.style==0 else 0,-angle+PI/2,0)
			if player.build.style==1:
				if target>=0:
					var difference: Vector2=model.enemies.pos[target]-player.pos
					hero.aim_yaw=rotate_toward(float(hero.aim_yaw),atan2(-difference.x,-difference.y),maxf(0,delta)*8.0) if weapon==0 else hero.aim_yaw
				node.rotation.y=hero.aim_yaw

func _update_protection() -> void:
	protection_link.visible=false
	for hero in heroes:hero.protection.visible=false
	if model.phase!="battle" or heroes.size()<2:return
	for index in heroes.size():
		var guard:=model.protecting_guard(index)
		if guard<0 or guard==index:continue
		heroes[index].protection.visible=true
		var origin: Vector3=heroes[guard].root.position;origin.y=.12
		var target: Vector3=heroes[index].root.position;target.y=.12
		var span:=target-origin
		if span.length()<.1:continue
		protection_link.visible=true
		protection_link.transform=Transform3D(Basis(Quaternion(Vector3.UP,span.normalized())).scaled(Vector3(1,span.length(),1)),(origin+target)*.5)
		break

func clear_network_motion() -> void:
	enemy_motion.clear();shot_motion.clear();pickup_motion.clear()

func receive_network_motion(interval: float) -> void:
	network_motion=true
	enemy_motion.receive(model.enemies,clock,interval)
	shot_motion.receive(model.shots,clock,interval)
	pickup_motion.receive(model.pickups,clock,interval)

func _update_batches() -> void:
	var enemies:=model.enemies
	var variant_counts:Array[int]=[0,0,0]
	if not party_profile:enemy_mesh.multimesh.visible_instance_count=enemies.active.size()
	shadow_mesh.multimesh.visible_instance_count=enemies.active.size()
	var marked_count:=0
	for index in enemies.active.size():
		var slot: int=enemies.active[index];var point: Vector2=enemies.pos[slot]
		if network_motion: point=enemy_motion.sample(enemies.identity[slot],point,clock)
		var size:=2.4 if enemies.kind[slot]==2 else (1.35 if enemies.kind[slot]==1 else 1.10)
		var nearest:=Vector2.ZERO
		if not model.players.is_empty():nearest=model.players[0].pos-point
		var angle:=atan2(-nearest.x,-nearest.y)
		var bob: float = absf(sin(clock*(5.5 if enemies.kind[slot]==2 else 9.0)+slot))*.055
		var transform:=Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*size),Vector3(point.x,bob,point.y))
		var target:MultiMeshInstance3D=enemy_mesh;var target_index:int=index
		if party_profile:
			var variant:int=[0,1,2,1,0][clampi(enemies.kind[slot],0,4)]
			target=enemy_kind_batches[variant];target_index=variant_counts[variant];variant_counts[variant]+=1
		target.multimesh.set_instance_transform(target_index,transform)
		var colour:=Color.WHITE
		if not party_profile and enemies.kind[slot]==1:colour=Color("ffcb7d")
		if not party_profile and enemies.kind[slot]==2:colour=Color("c9a8ff")
		if enemies.kind[slot]==3:colour=Color("ff704d")
		if enemies.kind[slot]==4:colour=Color("ffb547")
		if enemies.marked[slot]>0 and enemies.kind[slot] not in [3,4]:colour=Color("ffdb88")
		target.multimesh.set_instance_color(target_index,colour)
		shadow_mesh.multimesh.set_instance_transform(index,Transform3D(Basis().scaled(Vector3(size,1,size)),Vector3(point.x,.04,point.y)))
		shadow_mesh.multimesh.set_instance_color(index,Color.WHITE)
		if enemies.marked[slot]>0:
			mark_mesh.multimesh.set_instance_transform(marked_count,Transform3D(Basis(Vector3.UP,PI*.25),Vector3(point.x,size*.95+.30,point.y)))
			mark_mesh.multimesh.set_instance_color(marked_count,COLOURS[clampi(enemies.owner[slot],0,1)]);marked_count+=1
	if party_profile:
		for kind in 3:enemy_kind_batches[kind].multimesh.visible_instance_count=variant_counts[kind]
	mark_mesh.multimesh.visible_instance_count=marked_count
	shot_mesh.multimesh.visible_instance_count=model.shots.active.size()
	for index in model.shots.active.size():
		var slot: int=model.shots.active[index];var point: Vector2=model.shots.pos[slot]
		if network_motion: point=shot_motion.sample(model.shots.identity[slot],point,clock)
		var angle:=atan2(-model.shots.velocity[slot].x,-model.shots.velocity[slot].y)
		shot_mesh.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(1,1,2.8)),Vector3(point.x,.80,point.y)))
		shot_mesh.multimesh.set_instance_color(index,COLOURS[model.shots.owner[slot]])
	pickup_mesh.multimesh.visible_instance_count=model.pickups.active.size()
	for index in model.pickups.active.size():
		var slot: int=model.pickups.active[index];var point: Vector2=model.pickups.pos[slot]
		if network_motion: point=pickup_motion.sample(model.pickups.identity[slot],point,clock)
		pickup_mesh.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,clock),Vector3(point.x,.19,point.y)))
		pickup_mesh.multimesh.set_instance_color(index,Color.WHITE)
	for i in bait_nodes.size():
		bait_nodes[i].visible=i<model.baits.size()
		if i<model.baits.size():
			bait_nodes[i].position=Vector3(model.baits[i].pos.x,.15,model.baits[i].pos.y)
			bait_nodes[i].scale=Vector3.ONE*(1+.08*sin(clock*12))

func _create_feedback() -> void:
	var font:=FurVisualStyle.font()
	for i in 24:
		var label:=Label3D.new();label.font=font;label.font_size=42;label.pixel_size=.012
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true
		label.outline_size=8;label.outline_modulate=Color("33314d");label.visible=false;add_child(label)
		labels.append({"node":label,"life":0.0,"priority":i<6,"key":""})
	for i in 20:
		var ring:=MeshInstance3D.new();var shape:=TorusMesh.new()
		shape.inner_radius=.93;shape.outer_radius=1.0;shape.rings=32;shape.ring_segments=6
		ring.mesh=shape;ring.material_override=_material(Color.WHITE,.3);ring.visible=false
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ring)
		rings.append({"node":ring,"life":0.0,"duration":.3,"radius":1.0})

func _consume_events() -> void:
	# Merge common hits per coarse region; critical and player feedback retain priority.
	var hits: Dictionary={}
	var goods_arrived:=false
	var patrol_next:=-1
	for event in model.events:
		if event.kind=="order_goods":goods_arrived=true
		if event.kind=="patrol_repelled":patrol_next=clampi(int(event.value),0,11)
	for event in model.events:
		impact_feedback.receive(event,low_fx)
		if event.kind in ["warning","notice","charger_warning","ranger_warning"] and (warning_clock<=0 or event.kind in ["warning","notice"]):
			warning_voice.pitch_scale=1.0 if event.kind=="notice" else .82
			warning_voice.play();warning_clock=.7
		if ACTION_CUES.has(event.kind):_action_sound(event)
		if event.kind=="hit":
			var key:=Vector2i(roundi(event.pos.x/2),roundi(event.pos.y/2))
			if not hits.has(key):hits[key]=event.duplicate()
			else:hits[key].value+=event.value;hits[key].extra=hits[key].extra or event.extra
		elif event.kind in ["burst","sweep","dash","bait","revive","charge","boss_burst","notice_burst","level","receipt","contract"]:
			_ring(event)
		elif event.kind=="hurt":
			if event.owner>=0 and event.owner<heroes.size():heroes[event.owner].hurt=.18
			_popup(event,"-%d" % int(event.value),Color("ff6378"))
		elif event.kind=="ready":_popup(event,"蓄能就绪",COLOURS[event.owner])
		elif event.kind=="pot_wave":_popup(event,"锅浪开路",Color("ffe4a0"))
		elif event.kind=="barrage_ready":_popup(event,"满蓄能 · 连续齐射",COLOURS[event.owner])
		elif event.kind=="chain_ready":_popup(event,"连兑 %d 饼" % int(event.value),COLOURS[event.owner])
		elif event.kind=="payoff_interrupt":_popup(event,"破阵 · 打断%d招" % int(event.value),Color("a9f6e8"))
		elif event.kind=="cart_impact":_popup(event,"借车掀开 %d" % int(event.value),Color("75e0ed"))
		elif event.kind=="estate_open":_popup(event,"店铺补给 · %d级" % int(event.value),Color("ffe4a0"))
		elif event.kind=="estate_boost":_popup(event,"营业冲刺 · 3秒",Color("ffe4a0"))
		elif event.kind=="district_complete" and not goods_arrived:_popup(event,"委托完成 · 下轮巡街%02d" % patrol_next if patrol_next>=0 else "街区委托完成",Color("50e9b0"))
		elif event.kind=="order_goods":_popup(event,["串串到货","物流到货","奶站到货"][clampi(int(event.value),0,2)]+(" · 下轮巡街%02d" % patrol_next if patrol_next>=0 else " · 委托完成"),Color("d7b6ff"))
		# Checkpoint progress persists in the HUD and numbered world markers.
		# A transient caption here covered the carrier's dash/drop instruction.
		elif event.kind=="order_fulfilled":_popup(event,"合伙连单已交付",Color("d7b6ff"))
		# Drop state is immediately projected by the persistent box/actor cue and HUD.
		# Repeating a world popup at that point hides the actionable pickup key.
		elif event.kind=="link":_popup(event,"锅印兑现",COLOURS[event.owner])
		elif event.kind=="pop":
			for i in (1 if low_fx else 3):
				if debris.size()>=96:break
				var angle:=clock*17+i*TAU/3
				debris.append({"pos":Vector3(event.pos.x,.6,event.pos.y),"vel":Vector3(cos(angle)*2.4,3.3,sin(angle)*2.4),"life":.4,"colour":COLOURS[event.owner]})
			if sound_clock<=0:sound.pitch_scale=.9+fmod(clock,.3);sound.play();sound_clock=.08
	for event in hits.values():
		_popup(event,"%d%s" % [int(event.value),"!" if event.extra else ""],Color("ffe989") if event.extra else COLOURS[event.owner])
	model.events.clear()

func _action_sound(event: Dictionary) -> void:
	var owner: int=clampi(event.owner,0,1)
	var important:bool=event.kind in ["burst","order_fulfilled","payoff_interrupt"] or (event.kind=="volley" and event.extra)
	if action_sound_clocks[owner]>0 and not important:return
	var voice:=action_sounds[owner]
	voice.volume_db=-16 if important else (-20 if event.kind=="sweep" else -23)
	voice.stream=ACTION_CUES[event.kind];voice.pitch_scale=.82 if event.kind=="payoff_interrupt" else (1.18 if event.extra else (1.0 if owner==0 else 1.08))
	voice.play();action_sound_clocks[owner]=.12

func _update_rule_markers() -> void:
	for marker in rule_rings: marker.visible=false
	for caption in rule_captions:caption.visible=false
	if model.phase != "battle": return
	var count := 0
	var notice_captions: Array[Vector2]=[]
	for hazard in model.hazards:
		if count >= 5: break
		var notice: bool=hazard.get("kind","receipt")=="notice"
		_show_rule_ring(count, hazard.pos, hazard.radius, Color("ef87ff") if notice else Color("ff536b"))
		var duplicate_caption:=false
		if notice:
			for other in notice_captions:
				if other.distance_squared_to(hazard.pos)<4:duplicate_caption=true
			if not duplicate_caption:notice_captions.append(hazard.pos)
		if not duplicate_caption:_show_rule_caption(count,hazard.pos,("加班通知 %.1f秒" if notice else "收账 %.1f秒") % maxf(0,hazard.ttl),Color("f5ceff") if notice else Color("ffd1d7"))
		count+=1
	# The full danger radius stays visible throughout the boss windup. This
	# reserved marker is independent of cosmetic FX budgets and F8 settings.
	for slot in model.enemies.active:
		var attack:=FurBossCatalog.attack(model.wave,model.boss_pattern)
		if model.enemies.kind[slot] == 2 and model.enemies.life[slot] <= attack.windup and attack.id=="slam":
			_show_rule_ring(5, model.enemies.pos[slot], attack.radius, Color("ff536b"))
			_show_rule_caption(5,model.enemies.pos[slot],attack.title,Color("ffd1d7"))
	if model.skip_board_for_checks and model.route == 2 and not model.rule_state.is_empty():
		_show_rule_ring(6, model.rule_state.point, 2.1, Color("50e9b0") if not model.rule_state.rewarded else Color("95aeac"))
		if not party_profile or not model.rule_state.rewarded:
			_show_rule_caption(6,model.rule_state.point,"续杯完成" if model.rule_state.rewarded else "站定歇脚 %.1f / 3秒" % model.rule_state.progress,Color("b7ffe2"))
			if party_profile:
				# Objective text stays on the circle's front edge; the animal's
				# head remains reserved for charge/combo/hurt feedback. Once done,
				# the persistent mission HUD owns the completion statement.
				rule_captions[6].position=Vector3(model.rule_state.point.x,.28,model.rule_state.point.y+2.35)

func _show_rule_ring(index: int, point: Vector2, radius: float, colour: Color) -> void:
	var marker := rule_rings[index]
	marker.visible=true;marker.position=Vector3(point.x,.13,point.y)
	marker.scale=Vector3(radius,1,radius)
	marker.material_override.albedo_color=colour

func _show_rule_caption(index: int, point: Vector2, text: String, colour: Color) -> void:
	var caption:=rule_captions[index]
	caption.visible=true;caption.position=Vector3(point.x,2.8,point.y)
	caption.text=text;caption.modulate=colour

func _popup(event: Dictionary, text: String, colour: Color) -> void:
	var priority:bool=event.kind in ["hurt","ready","link","pot_wave","barrage_ready","chain_ready","payoff_interrupt","cart_impact","district_complete","estate_open","estate_boost","order_goods","order_checkpoint","order_fulfilled","order_drop_dash","order_drop_damage","order_drop_down"]
	if party_profile and priority:_party_popup(event,text,colour);return
	if not priority and popups_this_window>=(1 if low_fx else 3):return
	var key: String="%s-%d" % [event.kind,event.owner]
	for entry in labels:
		if entry.priority!=priority:continue
		if priority and entry.life>0 and entry.key==key:
			entry.node.text=text;entry.life=.65;return
		if entry.life>0:continue
		entry.life=.65 if priority else .4;entry.key=key;entry.node.visible=true;entry.node.text=text
		entry.node.modulate=colour;entry.node.position=Vector3(event.pos.x,2.65 if priority else 1.65,event.pos.y)
		if event.kind in ["payoff_interrupt","cart_impact"]:entry.node.position=_payoff_caption_position(entry.node.position)
		if not priority:popups_this_window+=1
		return

func _party_popup(event:Dictionary,text:String,colour:Color)->void:
	var policy:Dictionary=FurPartyCombatCaptions.classify(event,text)
	var target:Dictionary={}
	# Search all live keys before considering an empty pooled slot.
	for entry in labels:
		if entry.priority and entry.life>0 and entry.key==policy.key:
			if not FurPartyCombatCaptions.should_replace({"key":entry.key,"rank":entry.get("caption_rank",-1)},policy):return
			target=entry;break
	if target.is_empty():
		for entry in labels:
			if entry.priority and entry.life<=0:target=entry;break
	if target.is_empty():return
	var occupied:Array=[]
	for entry in labels:
		if entry.node!=target.node and entry.life>0:occupied.append(entry)
	target.life=.65;target.key=policy.key;target.caption_rank=policy.rank
	target.node.text=policy.text;target.node.modulate=colour;target.node.visible=true
	target.node.position=FurPartyCombatCaptions.place(self,camera,heroes,Vector3(event.pos.x,2.65,event.pos.y),event.owner,occupied,policy.text)

func _payoff_caption_position(point:Vector3)->Vector3:
	# Project only the consolidated payoff caption below the real expanded HUD.
	# Preserve camera depth and pool allocation; authority hit position stays intact.
	var world:Vector3=to_global(point)
	var screen:Vector2=camera.unproject_position(world)
	var viewport_size:Vector2=camera.get_viewport().get_visible_rect().size
	screen.x=clampf(screen.x,72.0,viewport_size.x-72.0)
	screen.y=clampf(screen.y,payoff_caption_top,viewport_size.y-72.0)
	return to_local(camera.project_position(screen,maxf(.01,-camera.to_local(world).z)))

func _ring(event: Dictionary) -> void:
	for entry in rings:
		if entry.life>0:continue
		entry.duration=.85 if event.kind=="warning" else (.35 if event.kind in ["burst","boss_burst"] else .20);entry.life=entry.duration
		entry.radius=maxf(.3,event.value);entry.node.visible=true
		entry.node.position=Vector3(event.pos.x,.10,event.pos.y)
		entry.node.material_override.albedo_color=Color("ef87ff") if event.kind=="notice_burst" else (Color("ff596d") if event.kind in ["warning","boss_burst"] else COLOURS[event.owner])
		return

func _tick_feedback(delta: float) -> void:
	for entry in labels:
		if entry.life<=0:continue
		entry.life-=delta;entry.node.position.y+=delta*.8
		if entry.key.begins_with("payoff_interrupt-") or entry.key.begins_with("cart_impact-"):entry.node.position=_payoff_caption_position(entry.node.position)
		entry.node.visible=entry.life>0
		var colour: Color=entry.node.modulate;colour.a=clampf(entry.life*3,0,1);entry.node.modulate=colour
	for entry in rings:
		if entry.life<=0:continue
		entry.life-=delta;entry.node.visible=entry.life>0
		var scale_value: float=entry.radius*(.65+.35*(1-entry.life/entry.duration))
		entry.node.scale=Vector3(scale_value,1,scale_value)

func _tick_debris(delta: float) -> void:
	for i in range(debris.size()-1,-1,-1):
		var bit: Dictionary=debris[i];bit.life-=delta
		if bit.life<=0:debris.remove_at(i);continue
		bit.vel.y-=delta*9;bit.pos+=bit.vel*delta
	debris_mesh.multimesh.visible_instance_count=debris.size()
	for i in debris.size():
		var bit: Dictionary=debris[i]
		debris_mesh.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,clock*7).scaled(Vector3.ONE*clampf(bit.life*5,0,1)),bit.pos))
		debris_mesh.multimesh.set_instance_color(i,bit.colour)

func show_gallery(kind: String) -> void:
	if party_profile:return
	showcase=true
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,150,0);key.light_energy=.6;add_child(key)
	if kind=="hero":
		camera.position=Vector3(4.2,3.1,-6.0);camera.look_at(Vector3(0,1.15,0));camera.fov=33
		for hero in heroes:hero.root.visible=false
		var character:=CORGI.instantiate() as Node3D;add_child(character)
		var hat:=HATS[0].instantiate() as Node3D;hat.position.y=2.1;character.add_child(hat)
	elif kind=="enemy":
		camera.position=Vector3(2.2,1.3,-3.5);camera.look_at(Vector3(0,.40,0));camera.fov=30
		for hero in heroes:hero.root.visible=false
		add_child(ENEMY.instantiate())
