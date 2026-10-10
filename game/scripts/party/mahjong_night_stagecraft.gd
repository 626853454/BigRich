class_name FurMahjongNightStagecraft
extends Node3D

var _anchors:Array[Node3D]=[]
var _flames:Array[Node3D]=[]
var _pip_meshes:Array=[]
var _labels:Array[Label3D]=[]
var _glows:Array[OmniLight3D]=[]
var _materials:Array[StandardMaterial3D]=[]
var _pulses:Dictionary={}
var _state:Dictionary={}
var _phase:float=0.0
var _pending_rewards:Dictionary={}
var _flame_batches:Array[MultiMeshInstance3D]=[]

func _ready()->void:
	for actor in 2:
		var anchor:=Node3D.new();anchor.position=Vector3(-7.6 if actor==0 else 7.6,.23,7.46);anchor.scale=Vector3.ONE*.72;add_child(anchor);_anchors.append(anchor)
		var frame:Node3D=FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/show/lotus_lamp.glb");anchor.add_child(frame)
		var material:=StandardMaterial3D.new();material.albedo_color=Color("e8be75");material.metallic=.2;material.roughness=.23;material.emission_enabled=true;material.emission=Color("ffae43");material.emission_energy_multiplier=.14;_materials.append(material)
		var flame:Node3D=_flame(anchor,material);flame.position.y=.76;_flames.append(flame)
		var pips:Array=[]
		for i in 3:
			var pip:Node3D=_flame(anchor,material);pip.scale=Vector3.ONE*.30;pip.position=Vector3((i-1)*.28,.43,.38);pips.append(pip)
		_pip_meshes.append(pips)
		var flame_mesh:MeshInstance3D=flame.find_children("*","MeshInstance3D",true,false)[0]
		var batch:=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=flame_mesh.mesh;batch.multimesh.instance_count=4;batch.multimesh.visible_instance_count=0;batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;anchor.add_child(batch);_flame_batches.append(batch)
		for mesh:MeshInstance3D in anchor.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override==material:mesh.hide()
		var light:=OmniLight3D.new();light.position=Vector3(0,1.25,0);light.light_color=Color("ffd89d");light.light_energy=.2;light.omni_range=3.8;light.shadow_enabled=false;anchor.add_child(light);_glows.append(light)
		var label:=Label3D.new();label.font=FurChapterUITheme.font(true);label.font_size=40;label.pixel_size=.009;label.modulate=Color("ffe0a0");label.outline_modulate=Color("183b41");label.outline_size=6;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(0,-.18,.84);anchor.add_child(label);_labels.append(label)

func _flame(parent:Node3D,material:Material)->Node3D:
	var node:Node3D=load("res://assets/mahjong_night/show/flame_pearl.glb").instantiate();parent.add_child(node)
	for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func configure(n:Dictionary,viewer:int)->void:
	if not is_node_ready():return
	var next:Dictionary=n.direction.duplicate(true)
	if not _state.is_empty() and _state.seed==next.seed:
		for actor in 2:
			if (next.done[actor] and not _state.done[actor]) or (next.support_refunded[actor] and not _state.support_refunded[actor]):
				_pending_rewards[actor]={"done":next.done[actor],"inspiration":next.inspiration[actor],"support_refunded":next.support_refunded[actor]}
				next.done[actor]=_state.done[actor];next.inspiration[actor]=_state.inspiration[actor];next.support_refunded[actor]=_state.support_refunded[actor]
	else:_pending_rewards.clear()
	_state=next;rotation.y=PI if viewer==1 else 0.0
	_apply_state()

func _apply_state()->void:
	for actor in 2:
		var goal:Dictionary=FurMahjongNightDirection.GOALS[_state.selected[actor]]
		_labels[actor].text=["小柯","泡泡"][actor]+(" · 催演待发" if _state.boost[actor] else (" · 已亮灯" if _state.done[actor] else " · "+goal.name))
		_materials[actor].emission_energy_multiplier=1.8 if _state.boost[actor] else (1.1 if _state.done[actor] else .14)
		_glows[actor].light_energy=1.1 if _state.boost[actor] else (.7 if _state.done[actor] else .12)
		for i in 3:_pip_meshes[actor][i].visible=i<int(_state.inspiration[actor])

func commit_reward(actor:int)->void:
	if not _pending_rewards.has(actor):return
	for key:String in _pending_rewards[actor]:_state[key][actor]=_pending_rewards[actor][key]
	_pending_rewards.erase(actor);_apply_state()

func _process(delta:float)->void:
	_phase+=delta
	for actor in _flames.size():
		_flames[actor].position.y=.76+sin(_phase*1.8+actor)*.035
		_flames[actor].rotation.y=sin(_phase*.7+actor)*.15
		var batch:MultiMesh=_flame_batches[actor].multimesh;batch.set_instance_transform(0,_flames[actor].transform);var count:int=1
		for pip:Node3D in _pip_meshes[actor]:
			if pip.visible:batch.set_instance_transform(count,pip.transform);count+=1
		batch.visible_instance_count=count

func celebrate(actor:int)->void:
	if actor not in [0,1]:return
	if _pulses.has(actor) and is_instance_valid(_pulses[actor]):_pulses[actor].kill()
	var tween:=create_tween();_pulses[actor]=tween
	tween.tween_property(_flames[actor],"scale",Vector3.ONE*1.38,.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glows[actor],"light_energy",2.0,.13)
	tween.tween_property(_flames[actor],"scale",Vector3.ONE,.48).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_glows[actor],"light_energy",.7,.48)

func reset()->void:
	for actor in 2:commit_reward(actor)
	for tween:Tween in _pulses.values():
		if is_instance_valid(tween):tween.kill()
	for flame:Node3D in _flames:flame.scale=Vector3.ONE
