class_name FurPartySession
extends Node3D

const Map=preload("res://scripts/party/party_map.gd")
const Model=preload("res://scripts/party/party_model.gd")
const World=preload("res://scripts/party/world_builder.gd")
const Pawn=preload("res://scripts/party/toy_pawn.gd")
const Dice=preload("res://scripts/party/party_dice.gd")
const Arena=preload("res://scripts/party/party_arena.gd")
const CameraRig=preload("res://scripts/party/party_camera_rig.gd")
const FerryView=preload("res://scripts/party/party_ferry_view.gd")
const Workshop=preload("res://scripts/party/party_workshop.gd")
const WorkshopAI=preload("res://scripts/party/party_workshop_ai.gd")
const BoardAudio=preload("res://scripts/party/party_board_audio.gd")
const Music=preload("res://scripts/party/party_music.gd")
const Notebook=preload("res://scripts/party/party_notebook.gd")
const Transition=preload("res://scripts/party/party_transition.gd")
var model:=Model.new()
var board_tiles:Array[Dictionary]=Map.nodes()
var board_districts:Array[Dictionary]=Map.districts()
var world:Node3D
var board_root:Node3D
var camera:Camera3D
var camera_rig:FurPartyCameraRig
var overview_button:Button
var loadout_button:Button
var mission_label:Label
var mission_panel:PanelContainer
var environment:WorldEnvironment
var pawns:Array[Node3D]=[]
var dice:Node3D
var ferry:FurPartyFerryView
var arena:Node3D
var canvas:CanvasLayer
var hud:Control
var player_panels:Array[PanelContainer]=[]
var player_labels:Array[Label]=[]
var round_label:Label
var phase_title:Label
var phase_detail:Label
var option_row:HBoxContainer
var roll_button:Button
var mode_picker:OptionButton
var instruction:Label
var toast:Label
var toast_backplate:PanelContainer
var phase_panel:PanelContainer
var presentation:="idle"
var wait_clock:=0.0
var move_time:=0.0
var move_duration:=.42
var sailing:=false
var move_actor:=0
var move_from:=Vector3.ZERO
var move_to:=Vector3.ZERO
var move_region_from:=Vector3.ZERO
var move_region_to:=Vector3.ZERO
var moves_seen:=0
var roll_face:=0
var serial_seen:=-1
var builds:Array=[]
var upgrade_actor:=0
var upgrade_options:Array[Dictionary]=[]
var upgrade_free_done:=false
var battle_plan:Dictionary={}
var challenge_token:=0
var ai_enabled:=true
var clock:=0.0
var last_result:="轮流掷骰探索海岛；两人行动后，一起迎战！"
var qa_commands_enabled:=false
var board_audio:FurPartyBoardAudio
var music:FurPartyMusic
var sound_button:Button
var sound_muted:=false
var battle_recap:Dictionary={}
var notebook:FurPartyNotebook
var notebook_button:Button
var joint_panel:PanelContainer
var joint_label:Label
var transition:FurPartyTransition
var scene_generation:=0
var run_growth:Dictionary={"experience":0,"next_level_experience":20}

func _ready()->void:
	qa_commands_enabled="--party-qa" in OS.get_cmdline_user_args()
	board_root=Node3D.new();board_root.name="BoardWorld";add_child(board_root)
	world=World.new();world.name="ToyHarbor";board_root.add_child(world);world.build(board_tiles,Map.edges())
	_setup_camera()
	for i in 2:
		var pawn:=Pawn.new();pawn.name="Animal_%d"%i;pawn.build(i);board_root.add_child(pawn);pawns.append(pawn)
		var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.68;torus.outer_radius=.79;torus.rings=32;torus.ring_segments=8
		ring.mesh=torus;ring.position.y=.08;var mat:=StandardMaterial3D.new();mat.albedo_color=Map.COLOURS[i];mat.emission_enabled=true;mat.emission=Map.COLOURS[i]*.3;ring.material_override=mat;pawn.add_child(ring)
	dice=Dice.new();board_root.add_child(dice);dice.settled.connect(_dice_settled)
	ferry=FerryView.new();board_root.add_child(ferry)
	board_audio=BoardAudio.new();add_child(board_audio)
	music=Music.new();add_child(music)
	var run_rng:=RandomNumberGenerator.new();run_rng.randomize()
	_make_ui();start_party(true,run_rng.randi_range(1,2147483647))

func _setup_camera()->void:
	environment=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("697d9e")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b6c5e6");settings.ambient_light_energy=.48
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.environment=settings;board_root.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-32,0);sun.light_color=Color("ffdfb0");sun.light_energy=.85;sun.shadow_enabled=true;sun.directional_shadow_max_distance=70;board_root.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-35,130,0);fill.light_color=Color("aaa6eb");fill.light_energy=.22;board_root.add_child(fill)
	camera_rig=CameraRig.new();board_root.add_child(camera_rig);camera=camera_rig.camera
	camera_rig.mode_changed.connect(_update_camera_button)

func _update_camera_button()->void:
	if is_instance_valid(overview_button):overview_button.text=camera_rig.label()

func start_party(use_ai:bool,seed_value:int)->void:
	scene_generation+=1
	if is_instance_valid(transition):transition.hide()
	if is_instance_valid(notebook):notebook.close()
	if arena!=null:arena.close();arena=null
	music.set_mode("board")
	ai_enabled=use_ai;mode_picker.selected=0 if use_ai else 1;model.start(seed_value,use_ai);builds=[FurBuildCatalog.create(0),FurBuildCatalog.create(1)]
	run_growth={"experience":0,"next_level_experience":20}
	presentation="idle";wait_clock=0;serial_seen=-1;moves_seen=0;dice.rolling=false;dice.visible=false;sailing=false;ferry.hide();battle_recap.clear()
	board_root.show();camera.current=true;camera_rig.enabled=true;camera_rig.return_to_actor();_restore_environment()
	for i in 2:pawns[i].position=_pawn_position(0,i);pawns[i].rotation=Vector3.ZERO;pawns[i].walking=false
	camera_rig.set_focus(board_tiles[0].pos,board_districts[0].center,true)
	last_result="轮流掷骰探索海岛；两人行动后，一起迎战！";_refresh()

func _pawn_position(node:int,actor:int)->Vector3:
	var shared:bool=model.state.players[1-actor].node==node
	return board_tiles[node].pos+Vector3((-.79 if actor==0 else .79) if shared else 0.0,.20,.10 if shared else 0.0)

func _process(delta:float)->void:
	if presentation in ["loading","result"]:return
	if is_instance_valid(notebook) and notebook.visible:return
	clock+=delta;wait_clock+=delta
	if arena!=null:
		var battle=arena.model
		var battle_round:int=arena.round_number
		round_label.text="%s · 波%d/%d · Lv%d · %d/%d经验"%[battle_plan.district_name,battle_round,Model.MAX_ROUNDS,battle.players[0].build.level,battle.experience,battle.next_level_experience]
		phase_title.text="第 %d 波 · 击败收账员才能离场"%battle_round if battle.remaining<=0 else "第 %d 波 · 一起撑过 %.0f 秒"%[battle_round,battle.remaining]
		phase_detail.text="自动攻击 · P1 WASD / 空格 / Q   |   "+("泡泡熊 AI 会走位、蓄能和救援" if ai_enabled else "P2 方向键 / Enter / 斜杠")
		for i in 2:
			var player:Dictionary=battle.players[i];var ready:String="✓" if player.skill_cd<=0 else "%.0fs"%ceilf(player.skill_cd)
			var skill_key:String="Q" if i==0 else ("AI" if ai_enabled else "/")
			var resource:String="锅 %.0f/%.0f · %s%s"%[player.pot,player.build.pot_cap,skill_key,ready]
			if player.build.style==1:resource="蓄 %.1f/2.5 · %s%s"%[player.charge,skill_key,ready]
			elif player.build.style==2:
				var bait_count:=0
				for bait in battle.baits:
					if bait.owner==i:bait_count+=1
				resource="饼 %d枚 · %s%s"%[bait_count,skill_key,ready]
			player_labels[i].text="%s·%s  %d把\n生命 %.0f / %.0f\n%s"%[Map.PLAYER_NAMES[i],["锅卫","齐射","诱饵"][player.build.style],player.build.weapons,player.hp,player.build.health,resource]
		var task:Dictionary=FurRouteCatalog.entry(battle.route)
		var rule_text:String=_task_rule(battle.route)
		mission_label.text="%s\n%s\n进度 %.0f / %.0f\n%s\n%s"%[battle_plan.district_name,task.goal,battle.rule_state.progress,battle.rule_state.target,rule_text,"奖励已兑现 ✓" if battle.rule_state.rewarded else task.reward]
		var contract:Dictionary=battle_plan.get("joint_contract",{})
		if not contract.is_empty():
			mission_label.text+="\n\n合伙委托 → "+board_districts[contract.target_district].name
			mission_label.text+="\n"+(("任务已成，再守到终场" if battle.rule_state.rewarded else "完成任务后还须守住") if contract.target_district==battle.route else "本场不在委托目标岛")
		return
	var camera_state:Dictionary=model.state
	var active_tile:Dictionary=board_tiles[camera_state.players[camera_state.active].node]
	var camera_region:Vector3=board_districts[active_tile.district].center
	if presentation=="walk":camera_region=move_region_from.lerp(move_region_to,smoothstep(0.0,1.0,minf(move_time/move_duration,1.0)))
	camera_rig.set_focus(pawns[camera_state.active].position,camera_region)
	camera_rig.tick(delta)
	if presentation=="walk":
		move_time+=delta;var t:=minf(move_time/move_duration,1.0);var smooth:=t*t*(3-2*t)
		pawns[move_actor].position=move_from.lerp(move_to,smooth)+Vector3.UP*sin(t*PI)*(.04 if sailing else .12)
		if FurIslandComposition.enabled and not sailing and int(board_tiles[0].get("chapter",0))==0:
			var correction:float=FurIslandComposition.elevation(pawns[move_actor].position)-lerpf(FurIslandComposition.elevation(move_from),FurIslandComposition.elevation(move_to),smooth)
			pawns[move_actor].position.y+=correction
		var direction:=move_to-move_from
		pawns[move_actor].rotation.y=lerp_angle(pawns[move_actor].rotation.y,atan2(direction.x,direction.z),1-exp(-delta*12))
		if sailing:ferry.follow(pawns[move_actor].position,pawns[move_actor].rotation.y,delta)
		if t>=1:presentation="idle";pawns[move_actor].walking=false;sailing=false;ferry.hide();wait_clock=0;_refresh()
		return
	if presentation=="dice":return
	if presentation=="loadout":return
	if presentation=="recap":return
	if presentation=="landing_pause":
		if wait_clock>.95:model.finish_turn(model.state.active);presentation="idle";wait_clock=0;_refresh()
		return
	if presentation=="upgrade":
		if upgrade_actor==1 and ai_enabled and wait_clock>1.1:
			if not upgrade_free_done:_choose_upgrade(_ai_upgrade_index())
			elif model.choose_ai_workshop(upgrade_actor).is_empty():_finish_upgrade_actor()
			else:_choose_upgrade(_ai_upgrade_index())
		return
	var state:Dictionary=camera_state
	for pawn in pawns:pawn.rotation.y=lerp_angle(pawn.rotation.y,0.0,1-exp(-delta*2.5))
	if state.serial!=serial_seen:_refresh()
	match str(state.phase):
		"prepare":
			if state.players[state.active].ai and wait_clock>1.0:_prepare(model.choose_ai_preparation(state.active))
		"moving":
			if wait_clock>.12:_advance(-1)
		"branch":
			if state.players[state.active].ai and wait_clock>.9:_advance(model.choose_ai_branch(state.active))
		"roll":
			if state.players[state.active].ai and wait_clock>1.25:
				var item:Dictionary=model.choose_ai_item(state.active)
				if not item.kind.is_empty():_use_item(item.kind,item.target)
				_roll()
		"landing":
			var options:Array=model.landing_options(state.active)
			if not state.landing_resolved and wait_clock>.9 and (options.size()==1 or state.players[state.active].ai):_land(model.choose_ai_landing(state.active))

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F10:_toggle_sound();get_viewport().set_input_as_handled();return
	if notebook.visible:
		if event.physical_keycode in [KEY_F1,KEY_ESCAPE]:notebook.close();get_viewport().set_input_as_handled()
		return
	if event.physical_keycode==KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN);return
	if presentation=="loading":return
	if arena!=null:return
	if event.physical_keycode==KEY_F1:_toggle_notebook();get_viewport().set_input_as_handled();return
	if event.physical_keycode==KEY_SPACE and presentation=="idle" and model.state.phase=="roll" and not model.state.players[model.state.active].ai:_roll()
	if event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
		var index:int=event.physical_keycode-KEY_1
		if index<option_row.get_child_count():
			var button:=option_row.get_child(index) as Button
			if button!=null and not button.disabled:button.pressed.emit()

func _toggle_notebook()->void:
	if notebook.visible:notebook.close();return
	if arena!=null or presentation in ["dice","walk","landing_pause","loading"]:return
	camera_rig.enabled=false;notebook.show_page(model.state,builds)

func _toggle_sound()->void:
	sound_muted=not sound_muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),sound_muted)
	sound_button.text="声音：关 F10" if sound_muted else "声音：开 F10"

func _roll(forced:int=0)->Dictionary:
	if presentation!="idle" or arena!=null:return {"ok":false,"reason":"busy"}
	if forced!=0 and not qa_commands_enabled:return {"ok":false,"reason":"development_only"}
	var result:Dictionary=model.roll_dice(model.state.active,forced)
	if not result.ok:return result
	roll_face=result.facts.face;presentation="dice";wait_clock=0
	dice.position=pawns[model.state.active].position+Vector3(1.5,.9,.15);dice.throw_value(roll_face)
	board_audio.play("roll")
	last_result="%s 掷骰中…"%Map.PLAYER_NAMES[model.state.active];_refresh();return result

func _prepare(choice:int)->void:
	if presentation!="idle":return
	var result:Dictionary=model.choose_preparation(model.state.active,choice)
	if result.ok:
		wait_clock=0;last_result="补给已装好：本波生命 +12" if choice==0 else "已押3金币营业：本波伤害 +12%；胜返7，败返1"
		if choice==1:board_audio.play("purchase")
		_refresh()

func _open_loadout()->void:
	var state:Dictionary=model.state
	if presentation!="idle" or state.round!=1 or state.phase!="prepare" or state.players[state.active].ai:return
	presentation="loadout";_refresh()

func _select_loadout(style:int)->void:
	var state:Dictionary=model.state
	if presentation!="loadout" or state.round!=1 or state.phase!="prepare" or style<0 or style>2:return
	builds[state.active]=FurBuildCatalog.create(style);presentation="idle";last_result="选择了 "+FurBuildCatalog.NAMES[style];_refresh()

func _dice_settled(value:int)->void:
	if presentation!="dice" or model.state.phase not in ["moving","branch"]:return
	presentation="idle";wait_clock=0;last_result="掷出 %d 点%s"%[value," · 加骰道具 +2步" if model.state.roll>value else ""]
	_refresh()

func _advance(choice:int)->void:
	if presentation!="idle":return
	var actor:int=model.state.active;var result:Dictionary=model.advance(actor,choice)
	if not result.ok:return
	move_actor=actor;move_from=pawns[actor].position;move_to=_pawn_position(result.facts.to,actor);move_time=0;moves_seen+=1
	move_region_from=board_districts[board_tiles[result.facts.from].district].center;move_region_to=board_districts[board_tiles[result.facts.to].district].center
	sailing=bool(result.facts.get("ferry",false));move_duration=2.1 if sailing else clampf(move_from.distance_to(move_to)/7.5,.34,.68)
	board_audio.play("embark" if sailing else "step")
	presentation="walk";pawns[actor].walking=not sailing;dice.visible=false;wait_clock=0;_refresh()

func _land(choice:int)->void:
	if presentation!="idle":return
	var result:Dictionary=model.resolve_landing(model.state.active,choice)
	if not result.ok:last_result=result.reason;return
	var facts:Dictionary=result.facts
	last_result="%s · %s"%[Map.PLAYER_NAMES[result.actor],_landing_receipt(facts)]
	if facts.star_delta>0:board_audio.play("star")
	elif facts.cost>0:board_audio.play("purchase")
	elif facts.coin_delta>0:board_audio.play("coin")
	presentation="landing_pause";wait_clock=0;_refresh()

func _landing_receipt(facts:Dictionary)->String:
	if facts.star_delta>0:
		var travel:String=" · 花2金指定" if facts.get("migration_fee",0)>0 else " · 随机迁往"
		return "星铃 +1%s！下一颗%s%s"%[" · 用券省5金" if facts.get("star_discount_consumed",0)>0 else "",travel,board_districts[board_tiles[facts.star_node].district].name]
	var contract:Dictionary=facts.get("joint_contract",{})
	if not contract.is_empty():return "约好去%s！最迟第%d场；完成任务并守住才兑现"%[board_districts[contract.target_district].name,contract.expires_round]
	if facts.kind=="property":
		var estate:Dictionary=facts.property
		if facts.cost==8:return "开张啦！合作摊位 Lv.1 · 本岛参战生命 +2，道具减1金"
		if facts.cost==6:return "摊位升到 Lv.2 · 花6赚3；本岛参战生命 +4，道具减2金"
		if facts.partner_coin_delta>0:return "一起营业！自己 +1金，伙伴 +1金"
		return "帮忙摆摊 +2金" if estate.owner<0 else "自家摊位营业 · 金币 +%d"%facts.coin_delta
	if facts.protected:return "护符挡下损失，金币保住了"
	if not facts.item.is_empty():return "获得 "+{"boost":"加骰 +2步","shield":"保钱护符","swap":"换位卡"}.get(facts.item,facts.item)
	return "金币 %+d"%facts.coin_delta if facts.coin_delta!=0 else "准备下一程"

func _use_item(kind:String,target:int)->void:
	var result:Dictionary=model.use_item(model.state.active,kind,target)
	if result.ok:
		for i in 2:pawns[i].position=_pawn_position(model.state.players[i].node,i)
		last_result={"boost":"加骰已准备：这次多走2步","shield":"保钱护符已生效","swap":"交换了两人的棋盘位置"}.get(kind,kind);_refresh()

func _start_arena()->void:
	if arena!=null or presentation=="loading" or model.state.phase!="challenge":return
	battle_plan=model.battle_context()
	if not battle_plan.get("ok",false):return
	challenge_token=model.state.challenge_token;presentation="loading";camera_rig.enabled=false
	var generation:=scene_generation
	var token:=challenge_token
	_clear_options();roll_button.hide();transition.present(battle_plan)
	# Present an honest card before costly first GPU material compilation. The
	# model stays in challenge and the Arena does not tick behind this card.
	await _presented_frame()
	if generation!=scene_generation or presentation!="loading" or model.state.challenge_token!=token:return
	board_root.hide();environment.environment=null
	arena=Arena.new();arena.name="PartyArena";add_child(arena);arena.completed.connect(_arena_completed.bind(arena,challenge_token))
	arena.begin(model.state.seed+model.state.round*101,model.state.round,ai_enabled,builds,battle_plan,false)
	if not arena.restore_growth(run_growth):
		push_error("Party growth restore rejected; start a new game")
		arena.close();arena=null;board_root.show();_restore_environment();camera.current=true
		transition.hide();camera_rig.enabled=true;presentation="idle";_refresh()
		phase_title.text="成长记录无法恢复，请点右上角新的一局"
		return
	var source:Node=arena
	_clear_options();roll_button.hide();overview_button.hide();loadout_button.hide();notebook_button.hide();toast_backplate.hide();joint_panel.hide();mission_panel.show();round_label.text="%s · 第 %d / %d 波"%[battle_plan.district_name,model.state.round,model.state.max_rounds]
	phase_panel.offset_top=-98;phase_title.add_theme_font_size_override("font_size",20);phase_detail.add_theme_font_size_override("font_size",14)
	instruction.text="自动攻击 · 走位收集经验 · 靠近倒地队友可救援 · 有收账员的波次须击败后离场"
	transition.scene_ready()
	await _presented_frame()
	# Drain the first frame's physics catch-up while running is still false.
	await get_tree().process_frame
	if generation!=scene_generation or not is_instance_valid(source) or arena!=source or model.state.challenge_token!=token:return
	transition.hide();presentation="arena";arena.running=true;music.set_mode("battle")

func _presented_frame()->void:
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func _arena_completed(won:bool,earned_builds:Array,source:Node,expected_token:int)->void:
	if presentation=="result" and source==arena and expected_token==challenge_token:return
	if not is_instance_valid(source) or source!=arena or expected_token!=challenge_token:
		push_error("Party battle receipt rejected: stale_challenge");return
	var actual=source.model
	var proof:Dictionary={"version":FurPartyJointContract.VERSION,"token":expected_token,"round":source.round_number,"route":int(actual.route),"rule_id":int(actual.rule_state.id),"progress":float(actual.rule_state.progress),"target":float(actual.rule_state.target),"rewarded":bool(actual.rule_state.rewarded),"phase":str(actual.phase)}
	var result:Dictionary=model.settle_challenge([100,100] if won else [0,0],expected_token,proof)
	if not result.ok:push_error("Party battle receipt rejected: "+result.reason);return
	var rows:Array[String]=[]
	var player_rows:Array[Dictionary]=[]
	for actor in 2:
		rows.append("%s 击退%d / 伤害%.0f / 金币 +%d"%[Map.PLAYER_NAMES[actor],maxi(0,int(earned_builds[actor].kills)-int(builds[actor].kills)),maxf(0,float(earned_builds[actor].dealt)-float(builds[actor].dealt)),int(result.facts.receipt.coin_rewards[actor])])
		player_rows.append({"kills":maxi(0,int(earned_builds[actor].kills)-int(builds[actor].kills)),"damage":maxf(0,float(earned_builds[actor].dealt)-float(builds[actor].dealt)),"coins":int(result.facts.receipt.coin_rewards[actor])})
	run_growth=source.growth_snapshot()
	battle_recap={"won":won,"players":rows,"player_rows":player_rows,"objective":bool(arena.model.rule_state.rewarded),"district":battle_plan.district_name,"joint":result.facts.receipt.joint_result.duplicate(true),"old_level":int(builds[0].level),"level":int(earned_builds[0].level),"growth":run_growth.duplicate(true)}
	builds=earned_builds
	last_result="守住了！金币与营业收入已分别入账" if won else "这波没守住，基础2金与营业返还已入账；改装再出发"
	presentation="result";mission_panel.hide();_clear_options();phase_panel.offset_top=-126
	phase_title.text="这座岛守住了！" if won else "伙伴先撤退，下次再来"
	phase_detail.text="%s   |   %s"%[rows[0],rows[1]]
	instruction.text="本波收益已分别入账 · 正在返回棋盘"
	var generation:=scene_generation
	arena.present_outcome(won)
	board_audio.play("coin")
	await get_tree().create_timer(.75).timeout
	if generation!=scene_generation or not is_instance_valid(source) or source!=arena or expected_token!=challenge_token:return
	arena.close();arena=null;board_root.show();camera_rig.enabled=true;overview_button.show();_restore_environment();camera.current=true
	music.set_mode("board")
	if model.state.phase=="finished":presentation="idle";_refresh();return
	presentation="recap";wait_clock=0;_refresh()

func _open_workshop()->void:
	if presentation!="recap" or model.state.phase!="market":return
	upgrade_actor=int(model.state.market_actor);upgrade_free_done=false;presentation="upgrade";wait_clock=0;_prepare_upgrade()

func _joint_result_text(result:Dictionary)->String:
	match str(result.get("status","none")):
		"completed":return "合伙兑现：%s下颗星省5金；%s额外+%d金（已计入上方）"%[Map.PLAYER_NAMES[result.sponsor],Map.PLAYER_NAMES[result.partner],result.partner_coin_delta]
		"expired":return "合伙委托已到期：本次未兑现优惠或额外金币。"
		"pending":return "合伙仍可重试：去%s完成任务并守住，最迟第%d场。"%[board_districts[result.target_district].name,result.expires_round]
	return ""

func _restore_environment()->void:
	var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("697d9e")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b6c5e6");settings.ambient_light_energy=.48;settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.environment=settings

func _prepare_upgrade()->void:
	var seed_value:int=model.state.seed+model.state.round*177+upgrade_actor+(7919 if upgrade_free_done else 0)
	upgrade_options=Workshop.draft(builds[upgrade_actor],int(builds[1-upgrade_actor].style),seed_value,model.state.round in [4,6],upgrade_free_done,int(battle_plan.get("district",0)))
	_refresh()

func _choose_upgrade(choice:int)->void:
	if presentation!="upgrade" or model.state.phase!="market" or upgrade_actor!=model.state.market_actor or choice<0 or choice>=upgrade_options.size():return
	var updated:Dictionary=builds[upgrade_actor].duplicate(true)
	if not FurBuildCatalog.apply(updated,upgrade_options[choice].id):return
	if upgrade_free_done:
		var purchase:Dictionary=model.buy_workshop(upgrade_actor,upgrade_options[choice].id)
		if not purchase.ok:last_result=purchase.reason;_refresh();return
	builds[upgrade_actor]=updated
	board_audio.play("purchase")
	last_result=Map.PLAYER_NAMES[upgrade_actor]+" 装上了 "+upgrade_options[choice].name
	wait_clock=0
	if upgrade_free_done:_finish_upgrade_actor()
	else:upgrade_free_done=true;_prepare_upgrade()

func _finish_upgrade_actor()->void:
	if presentation!="upgrade" or not upgrade_free_done:return
	var result:Dictionary=model.finish_market(upgrade_actor)
	if not result.ok:return
	wait_clock=0
	if model.state.phase=="market":upgrade_actor=model.state.market_actor;upgrade_free_done=false;_prepare_upgrade()
	else:presentation="idle";_refresh()

func _ai_upgrade_index()->int:
	if not upgrade_free_done:
		var history:Array=model.state.challenge_history
		var lost_last:bool=not history.is_empty() and not bool(history.back().team_won)
		return WorkshopAI.choose(upgrade_options,builds[upgrade_actor],builds[1-upgrade_actor],lost_last)
	var preferred:String=model.choose_ai_workshop(upgrade_actor)
	for index in upgrade_options.size():
		if upgrade_options[index].id==preferred:return index
	return 0

func _make_ui()->void:
	canvas=CanvasLayer.new();add_child(canvas);hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(hud)
	hud.add_theme_font_override("font",FurVisualStyle.font())
	for i in 2:
		var panel:=PanelContainer.new();panel.position=Vector2(24+i*272,24);panel.size=Vector2(256,94);panel.add_theme_stylebox_override("panel",_style(Color("202c48"),Map.COLOURS[i],18));hud.add_child(panel);player_panels.append(panel)
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);panel.add_child(row)
		var portrait:=_portrait(i);portrait.custom_minimum_size=Vector2(70,70);row.add_child(portrait)
		var label:=_label("",16);row.add_child(label);player_labels.append(label)
	var heading:=PanelContainer.new();heading.position=Vector2(578,24);heading.size=Vector2(404,85);heading.add_theme_stylebox_override("panel",_style(Color("202c48"),Color("8193a8"),16));hud.add_child(heading)
	var heading_column:=VBoxContainer.new();heading.add_child(heading_column)
	var title:=_label("毛 球 岛",23);heading_column.add_child(title)
	round_label=_label("",16);heading_column.add_child(round_label)
	sound_muted=AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	sound_button=_button("声音：关 F10" if sound_muted else "声音：开 F10",_toggle_sound);sound_button.position=Vector2(1020,26);sound_button.size=Vector2(174,40);sound_button.add_theme_font_size_override("font_size",14);sound_button.tooltip_text="开启或关闭本游戏的音乐与音效";hud.add_child(sound_button)
	mode_picker=OptionButton.new();mode_picker.position=Vector2(1215,26);mode_picker.size=Vector2(198,40);mode_picker.add_item("新局：玩家 + 泡泡熊 AI");mode_picker.add_item("新局：双人同机");mode_picker.tooltip_text="选择下局模式，再按新的一局开始";mode_picker.add_theme_font_size_override("font_size",15);hud.add_child(mode_picker)
	var restart:=_button("新的一局",func():start_party(mode_picker.selected==0,randi_range(1,2147483647)));restart.position=Vector2(1425,26);restart.size=Vector2(142,40);hud.add_child(restart)
	overview_button=_button("群岛全览  Tab",camera_rig.toggle_overview);overview_button.position=Vector2(24,132);overview_button.size=Vector2(212,42);overview_button.tooltip_text="滚轮缩放 · 按住右键拖动 · Home 回到当前动物";hud.add_child(overview_button)
	loadout_button=_button("选择开局流派",_open_loadout);loadout_button.position=Vector2(248,132);loadout_button.size=Vector2(205,42);hud.add_child(loadout_button)
	notebook_button=_button("玩法与账本 F1",_toggle_notebook);notebook_button.position=Vector2(468,132);notebook_button.size=Vector2(190,42);hud.add_child(notebook_button)
	mission_panel=PanelContainer.new();mission_panel.position=Vector2(24,132);mission_panel.size=Vector2(212,224);mission_panel.add_theme_stylebox_override("panel",_style(Color(.09,.15,.23,.90),Color("7caa95"),14));hud.add_child(mission_panel)
	mission_label=_label("",16);mission_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;mission_panel.add_child(mission_label);mission_panel.hide()
	toast_backplate=PanelContainer.new();toast_backplate.position=Vector2(1010,78);toast_backplate.size=Vector2(560,38)
	var toast_style:=_style(Color(.035,.08,.13,.92),Color(.25,.39,.45,.6),8);toast_style.content_margin_top=6;toast_style.content_margin_bottom=6
	toast_backplate.add_theme_stylebox_override("panel",toast_style);hud.add_child(toast_backplate)
	toast=_label("",17);toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;toast_backplate.add_child(toast)
	joint_panel=PanelContainer.new();joint_panel.position=Vector2(1020,126);joint_panel.size=Vector2(550,72);joint_panel.add_theme_stylebox_override("panel",_style(Color(.12,.20,.26,.94),Color("c5a670"),12));hud.add_child(joint_panel)
	joint_label=_label("",15);joint_panel.add_child(joint_label);joint_panel.hide()
	var box:=PanelContainer.new();phase_panel=box;box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);box.offset_left=24;box.offset_right=-215;box.offset_top=-155;box.offset_bottom=-27
	box.add_theme_stylebox_override("panel",_style(Color(.09,.14,.24,.94),Color("687c98"),18));hud.add_child(box)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",5);box.add_child(column)
	phase_title=_label("",23);column.add_child(phase_title);phase_detail=_label("",15);column.add_child(phase_detail)
	option_row=HBoxContainer.new();option_row.add_theme_constant_override("separation",12);column.add_child(option_row)
	roll_button=_button("掷骰\nSPACE",_roll);roll_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);roll_button.offset_left=-187;roll_button.offset_right=-28;roll_button.offset_top=-180;roll_button.offset_bottom=-26;roll_button.add_theme_font_size_override("font_size",27);hud.add_child(roll_button)
	var footer:=ColorRect.new();footer.color=Color(.035,.08,.13,.94);footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.offset_top=-25;hud.add_child(footer)
	instruction=_label("",14);instruction.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);instruction.offset_left=36;instruction.offset_top=-22;instruction.offset_right=-20;instruction.offset_bottom=0;hud.add_child(instruction)
	notebook=Notebook.new();hud.add_child(notebook);notebook.closed.connect(func():camera_rig.enabled=arena==null)
	transition=Transition.new();hud.add_child(transition)

func _portrait(index:int)->TextureRect:
	var viewport:=SubViewport.new();viewport.size=Vector2i(256,256);viewport.msaa_3d=Viewport.MSAA_4X;viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;hud.add_child(viewport)
	var pawn:=Pawn.new();pawn.build(index);viewport.add_child(pawn)
	var portrait_camera:=Camera3D.new();viewport.add_child(portrait_camera);portrait_camera.position=Vector3(0,2.1,5.5);portrait_camera.look_at(Vector3(0,1.7,0));portrait_camera.fov=27;portrait_camera.current=true
	var light:=DirectionalLight3D.new();FurArtLighting.key(light);light.shadow_enabled=false;viewport.add_child(light)
	var env:=WorldEnvironment.new();var e:=Environment.new();FurArtLighting.apply(e);env.environment=e;viewport.add_child(env)
	var rect:=TextureRect.new();rect.texture=viewport.get_texture();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;return rect

func _style(fill:Color,border:Color,radius:int)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border;style.set_border_width_all(2);style.set_corner_radius_all(radius)
	style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=10;style.content_margin_bottom=10;style.shadow_color=Color(0,0,0,.25);style.shadow_size=5;return style

func _label(text:String,font_size:int)->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("fff0d7"));return label

func _button(text:String,callback:Callable)->Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(165,43);button.focus_mode=Control.FOCUS_NONE;button.add_theme_font_size_override("font_size",16)
	button.add_theme_stylebox_override("normal",_style(Color("294a65"),Color("7bacc5"),12));button.add_theme_stylebox_override("hover",_style(Color("38637d"),Color("ffda88"),12));button.add_theme_stylebox_override("pressed",_style(Color("20384f"),Color("ffda88"),12));button.pressed.connect(callback);return button

func _clear_options()->void:
	for child in option_row.get_children():option_row.remove_child(child);child.queue_free()

func _refresh()->void:
	if not is_instance_valid(hud):return
	if presentation in ["loading","result"]:return
	var state:Dictionary=model.state;serial_seen=state.serial
	world.set_star(state.star_node);world.set_active_tile(state.players[state.active].node);world.set_path(state.path)
	if world.has_method("set_properties"):world.set_properties(state.get("properties",[]))
	if world.has_method("set_contract"):world.set_contract(state.get("joint_contract",{}))
	for i in 2:
		player_labels[i].text="%s %s·%s\n金币 %d  星铃 %d"%[Map.PLAYER_NAMES[i],"AI" if state.players[i].ai else "P%d"%(i+1),["锅卫","齐射","诱饵"][builds[i].style],state.players[i].coins,state.players[i].stars]
		if state.star_discounts[i]>0:player_labels[i].text+="\n下颗星 15金币"
		if presentation!="walk" or i!=move_actor:pawns[i].position=_pawn_position(state.players[i].node,i)
		player_panels[i].modulate=Color.WHITE if i==state.active else Color(.8,.85,.92)
	round_label.text="第 %d / %d 轮 · 守住 %d / %d 波"%[state.round,state.max_rounds,state.team_successes,state.get("team_goal",4)]
	toast.text="星铃 · %s %02d格 · 当前%d金"%[board_districts[board_tiles[state.star_node].district].name,state.star_node,model.star_price(state.active)]
	phase_panel.offset_top=-155;phase_title.add_theme_font_size_override("font_size",23);phase_detail.add_theme_font_size_override("font_size",15)
	instruction.text="蓝 +3 · 金 +5 · 红 −3 · 当前星铃 %d金 · 风艇票 2金   |   滚轮缩放 · 右键拖动 · Tab全览 · Home回当前"%model.star_price(state.active)
	_clear_options();roll_button.visible=state.phase=="roll" and presentation=="idle";roll_button.disabled=state.players[state.active].ai
	loadout_button.visible=state.round==1 and state.phase=="prepare" and presentation=="idle" and not state.players[state.active].ai
	if arena==null:mission_panel.hide();overview_button.show();toast_backplate.show();notebook_button.show()
	notebook_button.disabled=presentation in ["dice","walk","landing_pause"]
	var contract:Dictionary=state.get("joint_contract",{})
	joint_panel.visible=not contract.is_empty() and arena==null
	if not contract.is_empty():joint_label.text="合伙 · 帮%s去%s · 最迟第%d场\n完成任务并守住：接单者下颗星15金，伙伴 +5金"%[Map.PLAYER_NAMES[contract.sponsor],board_districts[contract.target_district].name,contract.expires_round]
	phase_detail.text=last_result
	if presentation=="recap":
		phase_panel.offset_top=-203
		phase_title.text=("守住啦！" if battle_recap.won else "先撤回来，改装后再战")+" · "+str(battle_recap.district)
		phase_detail.text="%s   |   %s\n地区任务：%s；战斗成长已保留。工坊每人免费选一件，也可花6金币再装一件。"%[battle_recap.players[0],battle_recap.players[1],"奖励已兑现" if battle_recap.objective else "尚未完成"]
		phase_detail.text+="\n伙伴成长 Lv%d → Lv%d · 累计经验 %d/%d，带到下一波。"%[battle_recap.old_level,battle_recap.level,battle_recap.growth.experience,battle_recap.growth.next_level_experience]
		phase_panel.offset_top=-225
		var joint_text:String=_joint_result_text(battle_recap.get("joint",{}))
		if not joint_text.is_empty():phase_detail.text+="\n"+joint_text;phase_panel.offset_top=-250
		option_row.add_child(_button("带着收获去工坊",_open_workshop));roll_button.hide();return
	if presentation=="loadout":
		phase_panel.offset_top=-203;phase_title.text="%s · 这局怎样和伙伴配合？"%Map.PLAYER_NAMES[state.active]
		phase_detail.text="流派决定自动武器、技能和后续专属改装；只在开局准备前可以选择。"
		var details:=["挥锅近战、给队友减伤\nQ释放回收的锅能","自动射击、站定蓄能\n迈步齐射，Q爆发","投放诱饵聚怪后爆炸\nQ引爆饼群"]
		for style in 3:
			var b:=_button("%d  %s\n%s"%[style+1,FurBuildCatalog.NAMES[style],details[style]],_select_loadout.bind(style));b.custom_minimum_size=Vector2(365,76);option_row.add_child(b)
		roll_button.hide();return
	if presentation=="upgrade":
		phase_panel.offset_top=-203
		phase_title.text="%s · %s"%[Map.PLAYER_NAMES[upgrade_actor],"追加改装 6金币，还是存钱买星铃？" if upgrade_free_done else "免费选一件改装，下一波继续成长"]
		var current:Dictionary=builds[upgrade_actor]
		phase_detail.text="%s · 钱包%d金 · 永久：%d把 / 火力×%.2f / 生命%.0f / 速度×%.2f"%[Workshop.LOCAL_LABELS[int(battle_plan.get("district",0))],state.players[upgrade_actor].coins,current.weapons,current.damage,current.health,current.speed]
		for i in upgrade_options.size():
			var item:Dictionary=upgrade_options[i];var b:=_button("%d  %s%s%s\n%s"%[i+1,"本地·" if item.get("local_offer",false) else "",item.name," · 6金" if upgrade_free_done else "",item.detail],_choose_upgrade.bind(i));b.custom_minimum_size=Vector2(342 if upgrade_free_done else 365,76);b.add_theme_font_size_override("font_size",14);b.tooltip_text=item.detail;b.disabled=(upgrade_actor==1 and ai_enabled) or (upgrade_free_done and state.players[upgrade_actor].coins<6);option_row.add_child(b)
		if upgrade_free_done:
			var leave:=_button("4  留钱出发",_finish_upgrade_actor);leave.disabled=upgrade_actor==1 and ai_enabled;option_row.add_child(leave)
		roll_button.hide();return
	if presentation=="dice":phase_title.text="%s 抛出了骰子…"%Map.PLAYER_NAMES[state.active];return
	if presentation=="walk" or state.phase=="moving":phase_title.text=("%s 乘风艇跨岛 · 还剩 %d 步" if sailing else "%s · 还剩 %d 步")%[Map.PLAYER_NAMES[state.active],state.remaining];return
	if presentation=="landing_pause":phase_title.text=Map.PLAYER_NAMES[state.active]+" · 落点收获";return
	match str(state.phase):
		"prepare":
			phase_title.text="%s · 带补给，还是押注营业？"%Map.PLAYER_NAMES[state.active]
			phase_detail.text="本轮领队 %s；领队落点决定战区与工坊。共同守4波；个人星铃优先、同星比金币。"%Map.PLAYER_NAMES[(state.round-1)%2]
			for item in model.prepare_options(state.active):
				var b:=_button("%d  %s"%[item.choice+1,item.label],_prepare.bind(item.choice));b.disabled=not item.enabled or state.players[state.active].ai;b.custom_minimum_size.x=450;option_row.add_child(b)
		"roll":
			phase_title.text="%s 的回合%s"%[Map.PLAYER_NAMES[state.active]," · AI 思考中" if state.players[state.active].ai else " · 掷骰出发"]
			phase_detail.text="%s · %s；星铃、经营摊位和追加改装都用这袋金币。"%[board_districts[board_tiles[state.players[state.active].node].district].name,last_result]
			for item in state.players[state.active].items:
				var kind:String=item;var b:=_button("使用 "+{"boost":"加骰 +2","shield":"保钱护符","swap":"换位卡"}[kind],_use_item.bind(kind,1-state.active if kind=="swap" else state.active));b.disabled=state.item_used or state.players[state.active].ai;option_row.add_child(b)
		"branch":
			phase_panel.offset_top=-225
			phase_title.text="岔路口 · %s 选择去哪里"%Map.PLAYER_NAMES[state.active];phase_detail.text="还剩 %d 步；风艇2金／1步。本轮领队 %s，领队落点决定战区与工坊。"%[state.remaining,Map.PLAYER_NAMES[(state.round-1)%2]]
			for target in model.branch_options(state.active):
				var preview:Dictionary=branch_preview(target)
				var index:int=option_row.get_child_count()+1
				var b:=_button("%d  %s"%[index,preview.caption],_advance.bind(target));b.disabled=state.players[state.active].ai;b.custom_minimum_size=Vector2(390,104);b.add_theme_font_size_override("font_size",14);b.tooltip_text=preview.get("detail","")
				b.mouse_entered.connect(func():world.set_path(preview.path));b.mouse_exited.connect(func():world.set_path(model.state.path));option_row.add_child(b)
		"landing":
			var kind:String=board_tiles[state.players[state.active].node].kind
			var star_landing:bool=state.players[state.active].node==state.star_node
			phase_title.text="%s 抵达 · %s"%[Map.PLAYER_NAMES[state.active],"星铃驿站" if state.players[state.active].node==state.star_node else Map.LABELS.get(kind,kind)]
			if star_landing:
				phase_panel.offset_top=-208
				phase_detail.text="Tab全览查看两岛与伙伴位置。现在买1颗，可多花2金定下颗：%s在%02d格 · %s在%02d格。"%[Map.PLAYER_NAMES[0],state.players[0].node,Map.PLAYER_NAMES[1],state.players[1].node]
			for item in model.landing_options(state.active):
				var b:=_button("%d  %s"%[item.choice+1,item.label],_land.bind(item.choice));b.disabled=not item.enabled or state.players[state.active].ai
				if star_landing:
					b.custom_minimum_size=Vector2(250 if item.choice==0 else (165 if item.choice==1 else 400),76);b.add_theme_font_size_override("font_size",14)
					if item.choice==0:b.text="1  买当前星铃 · %d金\n下一颗随机迁往另一岛"%model.star_price(state.active)
					elif item.choice==1:b.text="2  留钱离开\n暂不买星铃"
					else:
						for quote in model.star_migration_options(state.active):
							if quote.choice==item.choice:
								var target_name:String=board_districts[board_tiles[quote.migration_node].district].name
								b.text="%d  买当前星铃 · 共%d金\n其中2金点亮下颗 → %s%02d格"%[item.choice+1,quote.total_price,target_name,quote.migration_node]
								if quote.reason=="last_round":b.text="%d  最后一轮\n不再收取指定下一岛的费用"%(item.choice+1)
								b.mouse_entered.connect(func():world.set_path([quote.migration_node]));b.mouse_exited.connect(func():world.set_path(model.state.path))
				elif kind=="event":
					phase_panel.offset_top=-234;b.custom_minimum_size=Vector2(330,100);b.add_theme_font_size_override("font_size",14)
					if item.choice==2:
						b.custom_minimum_size.x=570
						if item.enabled:
							var target_district:int=item.quote.target_district
							b.text+="\n"+str(FurRouteCatalog.entry(target_district).goal)+"，并守住终场"
							var first_steps:int=Map.district_steps(state.players[0].node,target_district,state.players[0].coins)
							var second_steps:int=Map.district_steps(state.players[1].node,target_district,state.players[1].coins)
							b.text+="\n当前最短 小柯%d步 / 泡泡%d步 · 渡船另付费，骰点不保底"%[first_steps,second_steps]
							b.tooltip_text="按两人当前位置和现有金币计算，逐段扣除渡船费用；实际仍要掷骰、选路并轮换领队。最短步数不代表期限内保证到达。"
						if not item.enabled:b.text="3  暂不能接合伙委托\n"+{"too_late":"第6轮起不接新委托，留出行程和买星时间","active_contract":"先完成或结束在途委托","unused_star_discount":"先用掉已有星铃优惠券","star_cap":"星铃已满"}.get(item.get("reason",""),"本次无法接单")
				option_row.add_child(b)
		"challenge":
			var context:Dictionary=model.battle_context()
			var task:Dictionary=FurRouteCatalog.entry(context.route)
			phase_panel.offset_top=-226
			phase_title.text="伙伴集合 · %s 领队去%s"%[Map.PLAYER_NAMES[context.leader],context.district_name]
			phase_detail.text="任务：%s → %s   ·   %s\n%s\n小柯 临时生命 +%.0f / 火力 +%.0f%%   ·   泡泡 临时生命 +%.0f / 火力 +%.0f%%   ·   胜利各%d金，营业合同另结"%[task.goal,task.reward,Workshop.LOCAL_LABELS[context.district],_task_rule(context.route),context.bonuses[0].health_bonus,context.bonuses[0].damage_bonus*100,context.bonuses[1].health_bonus,context.bonuses[1].damage_bonus*100,5+context.reward_bonus]
			if not contract.is_empty():phase_detail.text+="\n"+("合伙目标匹配：完成本场任务并守住即可兑现。" if contract.target_district==context.route else "合伙尚未到目标岛：本场不会兑现；最迟第%d场。"%contract.expires_round);phase_panel.offset_top=-250
			option_row.add_child(_button("开始第 %d 波"%state.round,_start_arena))
		"finished":
			phase_title.text="海岛守住了！" if state.team_won else "这次夜市没守住，再搭档来一局"
			var champion:String="两人并列" if state.winners.size()==2 else Map.PLAYER_NAMES[state.winners[0]]
			phase_detail.text="共同守住 %d / %d 波；目标 %d。星铃榜：%s！先比星铃，同星比剩余金币。"%[state.team_successes,state.max_rounds,state.get("team_goal",4),champion]
			option_row.add_child(_button("再来一局",func():start_party(mode_picker.selected==0,randi_range(1,2147483647))))

func branch_preview(target:int)->Dictionary:
	var state:Dictionary=model.state;var preview:Dictionary=model.preview_branch(state.active,target)
	if not preview.ok:return {"path":[],"caption":"路线暂不可用"}
	var tile:Dictionary=board_tiles[preview.node]
	var captions:={"start":"港口","blue":"金币 +3","coin":"金币 +5","red":"金币 −3","event":"奇遇 · 钱／加骰／合伙","shop":"道具铺","property":"经营摊位"}
	var destination:String=("星铃 · %d金"%model.star_price(state.active) if preview.node==state.star_node else captions[tile.kind]) if preview.landing else "再选岔路 · 剩%d步"%preview.remaining
	var transport:String="风艇2金 → " if preview.ferry_cost>0 else ""
	var strategic:String="下一岔路再决定终点"
	var detail:String="当前路线还会遇到岔路，最终落点和战区尚未确定。"
	if preview.landing:
		if state.active==(state.round-1)%2:
			var task:Dictionary=FurRouteCatalog.entry(tile.district)
			strategic="任务："+str(task.goal)
			var contract:Dictionary=state.get("joint_contract",{})
			if not contract.is_empty() and contract.target_district==tile.district:strategic+=" · 合伙目标"
			strategic+="\n"+["胜利各多2金 · 火力／弹射工坊","本场火力+12% · 武器／机动工坊","本场生命+12 · 合作／生命工坊"][tile.district]
			detail=_task_rule(tile.district)+"\n完成奖励："+str(task.reward)+"。还须守住战斗才能取得胜利收益。"
		else:
			strategic="本轮战区由%s的落点决定"%Map.PLAYER_NAMES[(state.round-1)%2]
			detail="你仍可争取星铃、经营摊位和道具；本轮由伙伴领队决定战斗地区。"
	return {"path":preview.path,"node":preview.node,"caption":transport+board_districts[tile.district].name+"\n"+destination+"\n"+strategic,"detail":detail}

func _task_rule(route:int)->String:
	if route==1 and builds[0].style!=0 and builds[1].style!=0:return "敌潮更密。当前搭配每次击败计1单。"
	return str(FurRouteCatalog.entry(route).rule)
