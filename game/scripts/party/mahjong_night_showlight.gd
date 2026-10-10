class_name FurMahjongNightShowlight
extends RefCounted
# Brief show lighting operates on this isolated table only. Baselines are read
# from the real scene and restored on skip/exit; no duplicate world or post FX.
var _lights:Array=[]
var _levels:Array=[]
var _ambient:Environment
var _ambient_energy:float=0
var _pool:SpotLight3D
var _pool_energy:float=0
var _initialized:bool=false
func configure(stage:Node3D)->void:
	if _initialized:return
	for child in stage.get_children():
		if child is DirectionalLight3D:_lights.append(child);_levels.append(child.light_energy)
		elif child is WorldEnvironment:_ambient=child.environment;_ambient_energy=_ambient.ambient_light_energy
		elif child is SpotLight3D and child.name=="WarmTablePool":_pool=child;_pool_energy=child.light_energy
	_initialized=is_instance_valid(_pool)
func sample(weight:float)->void:
	if not _initialized:return
	var v:float=clampf(weight,0,1)
	for i in _lights.size():
		if is_instance_valid(_lights[i]):_lights[i].light_energy=_levels[i]*lerpf(1.0,.72,v)
	if is_instance_valid(_ambient):_ambient.ambient_light_energy=_ambient_energy*lerpf(1.0,.75,v)
	if is_instance_valid(_pool):_pool.light_energy=_pool_energy+v*1.15
func reset()->void:sample(0.0)
