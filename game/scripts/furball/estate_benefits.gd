class_name FurEstateBenefits
extends RefCounted

# Per-wave support. Derived benefits never compound permanent build attributes.
var state:Dictionary={"district_id":0,"level":0,"boost_remaining":0.0,"activations":0}
func enter(model:FurCombatModel,district_id:int,level:int) -> void:
	state={"district_id":clampi(district_id,0,2),"level":clampi(level,0,2),"boost_remaining":0.0,"activations":0}
	if state.level==0:return
	for index in model.players.size():
		var player:Dictionary=model.players[index]
		if player.down:continue
		player.hp=minf(player.build.health,player.hp+6)
		_resource(model,index,15 if state.level==1 else 22)
		model.emit("estate_open",player.pos,state.level,index,true)
func _resource(model:FurCombatModel,index:int,amount:float) -> void:
	var player:Dictionary=model.players[index]
	match int(player.build.style):
		0:player.pot=minf(player.build.pot_cap,player.pot+amount)
		1:player.charge=minf(2.5,player.charge+amount/15.0)
		2:
			if model.baits.size()<12:model.place_bait(index,false)
func on_event(model:FurCombatModel,event:Dictionary) -> void:
	if state.level<2:return
	var trigger:bool=(state.district_id==0 and event.kind=="district_checkpoint") or (state.district_id==1 and event.kind=="district_parcel") or (state.district_id==2 and event.kind=="district_complete")
	if not trigger:return
	state.activations+=1;state.boost_remaining=3.0
	for index in model.players.size():
		var player:Dictionary=model.players[index]
		if player.down:continue
		player.skill_cd=maxf(0,player.skill_cd-1.5)
		_resource(model,index,12)
		model.emit("estate_boost",player.pos,3,index,true)
func tick(delta:float) -> void:
	if delta>0 and is_finite(delta):state.boost_remaining=maxf(0,float(state.boost_remaining)-delta)
func attack_interval() -> float:return .72 if float(state.boost_remaining)>0 else 1.0
