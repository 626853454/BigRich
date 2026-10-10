class_name FurMahjongNightRelics
extends Node3D
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
var _signature:String=""
var _models:Dictionary={}
var _motion:Dictionary={}
var _paths:Array=[]
var _thermal:Dictionary={}
var _heat_drawn:Array=[0,0]
var _heat_pending:Dictionary={}
var _heat_seed:int=-1
var _heat_events:int=0
var _thermal_time:float=0.0

func configure(night:Dictionary)->void:
	var signature:String=JSON.stringify([night.build.items,night.build.shared])
	if signature==_signature:_sync_heat(night);return
	_signature=signature
	for tween:Tween in _motion.values():
		if is_instance_valid(tween):tween.kill()
	_motion.clear();_models.clear();_thermal.clear()
	for node in get_children():remove_child(node);node.queue_free()
	var ids:Array=["","","","",""]
	for actor in 2:
		for i in night.build.items[actor].size():ids[(0 if actor==0 else 3)+i]=night.build.items[actor][i]
	if not night.build.shared.is_empty():ids[2]=night.build.shared[0]
	for slot in 5:
		var anchor:=Node3D.new();anchor.position=Vector3((slot-2)*1.74,.19,7.40);add_child(anchor)
		var id:String=ids[slot]
		if id!="":
			var model:Node3D=FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/"+id+".glb")
			model.scale=Vector3.ONE*.78;anchor.add_child(model);_models[str(slot)]=model;model.set_meta("relic",id)
			if id=="coal":_make_thermal(model,0 if slot<2 else 1)
		else:
			var mesh:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.29;ring.outer_radius=.34;ring.rings=24;ring.ring_segments=8;mesh.mesh=ring
			var mat:=StandardMaterial3D.new();mat.albedo_color=Color("8b805f");mat.metallic=.3;mat.roughness=.65;mesh.material_override=mat;mesh.scale.y=.32;anchor.add_child(mesh)
	# Name the three ownership groups once; item order is explained in the build rail.
	for group in 3:
		var label:=Label3D.new();label.text=["小柯挂件","同桌共享","泡泡挂件"][group];label.font=FurChapterUITheme.font(false);label.font_size=44;label.pixel_size=.007;label.modulate=Color("fff0cf");label.outline_size=0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3([-2.61,0.0,2.61][group],.09,8.0);add_child(label)
	_sync_heat(night)

func _make_thermal(model:Node3D,actor:int)->void:
	var pearl:Node3D=load("res://assets/mahjong_night/show/flame_pearl.glb").instantiate()
	var source:MeshInstance3D=pearl.find_children("*","MeshInstance3D",true,false)[0]
	var batch:=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=source.mesh;batch.multimesh.instance_count=2
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("ffbb56");mat.emission_enabled=true;mat.emission=Color("ff8728");mat.emission_energy_multiplier=1.2;mat.roughness=.3
	batch.material_override=mat;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;model.add_child(batch);pearl.free()
	var label:=Label3D.new();label.font=FurChapterUITheme.font(true);label.font_size=40;label.pixel_size=.010;label.modulate=Color("ffd995");label.outline_size=5;label.outline_modulate=Color("3c201e");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(0,-.42,1.08);label.no_depth_test=true;model.add_child(label)
	_thermal[actor]={"batch":batch,"label":label,"mat":mat,"pulse":0.0}

func _sync_heat(n:Dictionary)->void:
	var seed_value:int=n.direction.seed;var count:int=n.events.size()
	if seed_value!=_heat_seed or count<_heat_events:
		_heat_pending.clear();_heat_drawn=[int(n.contexts[0].heat),int(n.contexts[1].heat)]
	else:
		for actor in 2:
			var deferred:bool=false
			for event:Dictionary in n.events.slice(_heat_events):
				if event.actor!=actor:continue
				for row:Dictionary in event.ledger:
					if row.op=="heat":deferred=true
			if deferred:_heat_pending[actor]=int(n.contexts[actor].heat)
			elif not _heat_pending.has(actor):
				if _heat_drawn[actor]!=int(n.contexts[actor].heat) and _thermal.has(actor):_thermal[actor].pulse=.6
				_heat_drawn[actor]=int(n.contexts[actor].heat)
	_heat_seed=seed_value;_heat_events=count;_paint_thermal()

func commit_heat(actor:int,value:int,animate:bool=true)->void:
	_heat_drawn[actor]=clampi(value,0,2);_heat_pending.erase(actor)
	if animate and _thermal.has(actor):_thermal[actor].pulse=.65
	_paint_thermal()

func _paint_thermal()->void:
	for actor:int in _thermal:
		var part:Dictionary=_thermal[actor];var heat:int=_heat_drawn[actor]
		part.label.text="满炉 · 下组再计" if heat==2 else "炉温 %d/2"%heat
		part.batch.multimesh.visible_instance_count=heat

func _process(delta:float)->void:
	_thermal_time+=delta
	for actor:int in _thermal:
		var part:Dictionary=_thermal[actor];part.pulse=maxf(0,part.pulse-delta)
		var lift:float=sin((1.0-part.pulse/.65)*PI)*.35 if part.pulse>0 else 0.0
		for i in 2:
			var scale_value:=Vector3(.55,.95+sin(_thermal_time*5+i)*.09,.55)
			part.batch.multimesh.set_instance_transform(i,Transform3D(Basis().scaled(scale_value),Vector3((i-.5)*.48,1.0+lift,0)))
		part.mat.emission_energy_multiplier=2.4+part.pulse*3.0

func pulse(source:String,actor:int)->void:
	for slot:String in _models:
		var model:Node3D=_models[slot]
		if (int(slot)<2 and actor!=0) or (int(slot)>2 and actor!=1):continue
		var id:String=model.get_meta("relic","")
		if Catalog.name_of(id)!=source and not (id=="crucible" and source=="积火余温"):continue
		if _motion.has(slot) and is_instance_valid(_motion[slot]):_motion[slot].kill()
		var tween:=create_tween();_motion[slot]=tween
		tween.tween_property(model,"scale",Vector3.ONE*.88,.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(model,"scale",Vector3.ONE*.78,.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func activation(source:String,actor:int)->Dictionary:
	for slot:String in _models:
		if (int(slot)<2 and actor!=0) or (int(slot)>2 and actor!=1):continue
		var model:Node3D=_models[slot];var id:String=model.get_meta("relic","")
		if Catalog.name_of(id)==source or (id=="crucible" and source=="积火余温"):return {"point":model.global_position+Vector3.UP*.8,"route":Catalog.ITEMS[id].route}
	return {}

func reset_pulses()->void:
	for actor:int in _heat_pending.keys():commit_heat(actor,_heat_pending[actor],false)
	for part:Dictionary in _thermal.values():part.pulse=0.0
	for tween:Tween in _motion.values():
		if is_instance_valid(tween):tween.kill()
	for model:Node3D in _models.values():model.scale=Vector3.ONE*.78
