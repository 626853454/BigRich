class_name FurMahjongNightFixtures
extends Node3D

var _table:int=-1
var _venue:String=""
var _status:String=""
var _objects:Array[Node3D]=[]
var _labels:Array[Label3D]=[]
var _lamps:Array[OmniLight3D]=[]
var _motion:Tween

func _model(id:String,parent:Node3D)->Node3D:
	var model:Node3D=FurMahjongNightMeshBatch.instantiate("res://assets/mahjong_night/fixtures/"+id+".glb");parent.add_child(model);return model

func _label(parent:Node3D,text:String,position_value:Vector3)->Label3D:
	var label:=Label3D.new();label.text=text;label.font=FurChapterUITheme.font(true);label.font_size=42;label.pixel_size=.009
	label.modulate=Color("ffe6a9");label.outline_modulate=Color("133c38");label.outline_size=6
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=position_value;parent.add_child(label);_labels.append(label);return label

func configure(n:Dictionary)->void:
	visible=not n.has("welcome")
	if not visible:return
	if _table!=int(n.table) or _venue!=n.get("venue",""):
		if is_instance_valid(_motion):_motion.kill()
		for node in get_children():remove_child(node);node.queue_free()
		_objects.clear();_labels.clear();_lamps.clear();_status="";_table=n.table;_venue=n.get("venue","")
		if _table==2:
			var anchor:=Node3D.new();anchor.position=Vector3(-4.8,.23,-1.5);anchor.scale=Vector3.ONE*1.25;add_child(anchor)
			_objects.append(_model("river_lantern",anchor));_label(anchor,"河灯悬赏",Vector3(0,2.34,0))
			var glow:=OmniLight3D.new();glow.position.y=.9;glow.light_color=Color("ffd58f");glow.omni_range=3;glow.light_energy=.7;glow.shadow_enabled=false;anchor.add_child(glow);_lamps.append(glow)
		if _table==3:
			for a in 2:
				var anchor:=Node3D.new();anchor.position=Vector3(-2.2 if a==0 else 2.2,1.05,-8.05);anchor.scale=Vector3.ONE*1.15;add_child(anchor)
				_model("gate_arch",anchor)
				var seal:=_model("gate_seal",anchor);seal.position.y=.95;seal.rotation.x=PI/2;_objects.append(seal)
				_label(anchor,("小柯" if a==0 else "泡泡")+" · 待开组",Vector3(0,2.08,0))
	var status:String=JSON.stringify([n.stage,n.bounty_claimed,n.contexts[0].kinds,n.contexts[1].kinds,n.direction.done,n.direction.refrain,n.direction.trick_history])
	if status==_status:return
	_status=status
	if _table not in [2,3]:return
	if is_instance_valid(_motion):_motion.kill()
	_motion=create_tween().set_parallel(true)
	if _table==2:
		var lit:bool=n.stage>0 and not n.bounty_claimed
		if _venue=="refrain":lit=n.direction.done[0] and n.direction.done[1]
		_labels[0].text="本段新河牌 +80" if lit else ("本段已领取" if n.bounty_claimed else "揭牌后点灯")
		if _venue=="refrain":_labels[0].text="双灯齐亮 · 返场已到手" if lit else "双灯返场 · %d / 2人亮灯"%(int(n.direction.done[0])+int(n.direction.done[1]))
		_labels[0].modulate=Color("ffe5a2") if lit else Color("a7bdb0")
		_motion.tween_property(_lamps[0],"light_energy",.9 if lit else .05,.35)
		_motion.tween_property(_objects[0],"rotation:y",float(n.stage)*.12,.45).set_trans(Tween.TRANS_SINE)
	if _table==3:
		var both:bool=not n.contexts[0].kinds.is_empty() and not n.contexts[1].kinds.is_empty()
		var used_actors:Array=[];var used_kinds:Array=[]
		for entry:Dictionary in n.direction.trick_history:
			if entry.actor not in used_actors:used_actors.append(entry.actor)
			if entry.id not in used_kinds:used_kinds.append(entry.id)
		if _venue=="prism":both=used_actors.size()==2 and used_kinds.size()>=2
		for a in 2:
			var ready:bool=(a in used_actors) if _venue=="prism" else not n.contexts[a].kinds.is_empty()
			_labels[a].text=("小柯" if a==0 else "泡泡")+(" · 倍率解锁" if both else (" · 已开组" if ready else " · 待开组"))
			if _venue=="prism":_labels[a].text=("小柯" if a==0 else "泡泡")+(" · 镜灯已破" if both else (" · 还需不同技艺" if ready else " · 待用灵感技艺"))
			_labels[a].modulate=Color("ffe5a2") if ready else Color("a7bdb0")
			_motion.tween_property(_objects[a],"rotation:y",(-1 if a==0 else 1)*1.05 if both else (0.20 if ready else 0.0),.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func pulse(source:String)->void:
	if _table!=2 or not source.begins_with("河灯悬赏"):return
	var tween:=create_tween();tween.tween_property(_objects[0],"scale",Vector3.ONE*1.16,.11).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_objects[0],"scale",Vector3.ONE,.35).set_trans(Tween.TRANS_SINE)
