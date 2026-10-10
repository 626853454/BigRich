class_name FurMahjongNightTeaService
extends Node

# Visuals consume the canonical shared resource. They never grant/spend tea.
signal sound(kind:String)
var _liquids:Array[Node3D]=[]
var _liquid_origins:Array[Vector3]=[]
var _beads:Array[MeshInstance3D]=[]
var _kettle:Node3D
var _full:StandardMaterial3D
var _empty:StandardMaterial3D
var _last:int=-1
var _shown:float=0
var _motion:Tween
var _pour:Tween
var _bead_batches:Array[MultiMeshInstance3D]=[]

func install(tableware:Node3D)->void:
	_kettle=tableware.get_node_or_null("Teapot")
	var tea:=StandardMaterial3D.new();tea.albedo_color=Color("9d561e");tea.roughness=.14;tea.metallic=.05;tea.clearcoat_enabled=true;tea.clearcoat=.85;tea.clearcoat_roughness=.08
	_full=StandardMaterial3D.new();_full.albedo_color=Color("63beaa");_full.roughness=.23;_full.metallic=.28;_full.emission_enabled=true;_full.emission=Color("4ebd9d");_full.emission_energy_multiplier=.42
	_empty=StandardMaterial3D.new();_empty.albedo_color=Color("4e5041");_empty.roughness=.55;_empty.metallic=.18
	for i in 3:
		var liquid:MeshInstance3D=tableware.get_node_or_null("TeaSurface"+str(i))
		if liquid==null:continue
		# The preserved original lathe cap points downward. Correct only this
		# runtime copy's winding/normals; the original shared GLB stays intact.
		var corrected:=ArrayMesh.new()
		for surface in liquid.mesh.get_surface_count():
			var arrays:Array=liquid.mesh.surface_get_arrays(surface)
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for n in normals.size():normals[n]=-normals[n]
			arrays[Mesh.ARRAY_NORMAL]=normals
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for n in range(0,indices.size(),3):var first:int=indices[n];indices[n]=indices[n+2];indices[n+2]=first
			arrays[Mesh.ARRAY_INDEX]=indices;corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		liquid.mesh=corrected
		liquid.material_override=tea;liquid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_liquids.append(liquid);_liquid_origins.append(liquid.position)
	for i in 9:
		var bead:MeshInstance3D=tableware.get_node_or_null("TeaEnergyBead"+str(i))
		if bead!=null:bead.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_beads.append(bead)
	if not _beads.is_empty():
		for material:Material in [_full,_empty]:
			var batch:=MultiMeshInstance3D.new();batch.name="TeaChargePBRBatch";batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=_beads[0].mesh;batch.multimesh.instance_count=_beads.size();batch.multimesh.visible_instance_count=0;batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tableware.add_child(batch);_bead_batches.append(batch)
		for bead:MeshInstance3D in _beads:bead.hide()
	# Dynamic kettle retains its original authored pivot; cups/tray are rigid.
	if is_instance_valid(_kettle):FurMahjongNightMeshBatch.combine_children(_kettle)
	var static_set:=Node3D.new();static_set.name="RigidTeaService";tableware.add_child(static_set)
	for child in tableware.get_children():
		if child is MeshInstance3D and not str(child.name).begins_with("TeaSurface") and not str(child.name).begins_with("TeaEnergyBead"):child.reparent(static_set,true)
	FurMahjongNightMeshBatch.combine_children(static_set)

func configure(charge:int,speed:float,initial:bool=false)->void:
	charge=clampi(charge,0,9)
	if charge==_last and not initial:return
	if is_instance_valid(_motion):_motion.kill()
	if _last<0 or initial:_last=charge;_show(float(charge));return
	var spent:bool=charge<_last;_last=charge
	_motion=create_tween().set_speed_scale(speed);_motion.tween_method(_show,_shown,float(charge),.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sound.emit("tea_pour" if spent else "tea_fill")
	if spent and is_instance_valid(_kettle):
		if is_instance_valid(_pour):_pour.kill()
		_pour=create_tween().set_speed_scale(speed);_pour.tween_property(_kettle,"rotation:z",-.20,.18).set_trans(Tween.TRANS_SINE)
		_pour.tween_property(_kettle,"rotation:z",0.0,.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show(value:float)->void:
	_shown=value
	for i in _liquids.size():
		var fullness:float=clampf((value-float(i)*3.0)/3.0,0,1)
		_liquids[i].visible=fullness>.025;_liquids[i].position=_liquid_origins[i]-Vector3(0,(1.0-fullness)*.21,0)
	if _bead_batches.size()==2:
		var counts:Array=[0,0]
		for i in _beads.size():
			var bucket:int=0 if float(i)+.5<=value else 1
			_bead_batches[bucket].multimesh.set_instance_transform(counts[bucket],_beads[i].transform);counts[bucket]+=1
		for i in 2:_bead_batches[i].multimesh.visible_instance_count=counts[i]

func settle()->void:
	if is_instance_valid(_motion):_motion.kill()
	if is_instance_valid(_pour):_pour.kill()
	if is_instance_valid(_kettle):_kettle.rotation.z=0
	_show(float(maxi(0,_last)))
