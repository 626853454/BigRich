class_name FurEncounterDirector
extends RefCounted
# Seeded formations create pressure/release independently of combat critical RNG.
var rng:=RandomNumberGenerator.new()
var clock:=.2
var serial:=0
var district_id:=0
var wave:=1
var challenge:=false
var elapsed:=0.0
var chapter:="opening"
var lane_offset:=0
var side_sign:=1.0
var ring_offset:=0.0
var event_pressure_add:=0.0
var spawn_multiplier:=1.0
func configure(district:int,round_number:int,seed:int,risky:bool,event_pressure:float=0.0) -> void:
	district_id=clampi(district,0,2);wave=clampi(round_number,1,6);challenge=risky
	event_pressure_add=.25 if is_finite(event_pressure) and event_pressure==.25 else 0.0
	spawn_multiplier=1.0+event_pressure_add+(.5 if challenge else 0.0)
	rng.seed=seed ^ (wave*7919+district_id*104729);clock=.2;serial=0;elapsed=0;chapter="opening"
	lane_offset=rng.randi_range(0,2);side_sign=-1.0 if rng.randi_range(0,1)==0 else 1.0;ring_offset=rng.randf_range(0,TAU)
func tick(delta:float,remaining:float) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if not is_finite(delta) or delta<=0 or not is_finite(remaining) or remaining<=0:return result
	elapsed+=minf(delta,.05);clock-=minf(delta,.05)
	chapter="opening" if elapsed<6 else ("pressure" if elapsed<15 else ("surge" if elapsed<24 else ("breath" if elapsed<28 else "closing")))
	if clock>0:return result
	var interval:=2.0 if chapter=="opening" else (1.7 if chapter=="pressure" else (1.25 if chapter=="surge" else (4.0 if chapter=="breath" else 1.6)))
	clock=interval/spawn_multiplier;serial+=1
	var count:int=2 if chapter=="opening" else (1 if chapter=="breath" else mini(5,2+int(ceil(wave*.5))))
	var side:float=(-1.0 if serial%2==0 else 1.0)*side_sign
	var lane:float=float(((serial+lane_offset)%3)-1)*5.0
	for index in count:
		var kind:=0
		if index==0 and chapter not in ["opening","breath"]:
			if wave>=2 and district_id==0 and serial%2==0:kind=3
			elif wave>=2 and district_id==1 and serial%2==0:kind=4
			elif wave>=3 and district_id==2 and serial%3==0:kind=3 if serial%2==0 else 4
			elif wave>=4 and serial%3==0:kind=4 if serial%2==0 else 3
			elif wave>=2 and serial%3==0:kind=1
		var point:=Vector2.ZERO
		match district_id:
			0:point=Vector2(side*13.5,(-5.5 if serial%3==0 else 5.5)+float(index-count/2)*.75)
			1:point=Vector2(side*13.5,lane+float(index-count/2)*.65)
			2:
				var angle:float=serial*1.2+index*.3+ring_offset
				point=Vector2(cos(angle)*13.2,sin(angle)*7.8)
		point.y+=rng.randf_range(-.18,.18)
		point.y=clampf(point.y,-8.4,8.4)
		result.append({"kind":kind,"pos":point})
	return result
