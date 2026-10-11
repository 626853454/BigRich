class_name FurMahjongNightAudio
extends Node

# Bounded effects and synchronized original music. No input-device access.
signal sounded(kind:String,ticks:int,pitch:float,volume:float)
const ROOT:="res://assets/mahjong_night/show/audio/"
const KINDS:=["tile_pick","tile_land","chip","group_land","reveal","lamp","multiply","repeat","total","hu","overkill","loss","purchase","charge","select","recall","relay","wind_score","coal_score","relay_score","tea_pour","tea_fill","encore_accept","encore_clear","furnace_charge","breakthrough"]
var _voices:Array[AudioStreamPlayer]=[]
var _music:Array[AudioStreamPlayer]=[]
var _started:Array[int]=[]
var _priorities:Array[int]=[]
var _streams:Dictionary={}
var _last:Dictionary={}
var _closed:bool=false
var _duck:float=0.0
var _intensity:float=0.0
var enabled:bool=true
var music_volume:float=.8
var effects_volume:float=1.0

func _ready()->void:
	for id:String in KINDS+["reshape_open","reshape_land","chain_land","build_wind_finish","build_fire_first","build_fire_finish"]:_streams[id]=load(ROOT+id+".wav")
	for i in 6:
		var player:=AudioStreamPlayer.new();player.max_polyphony=1;add_child(player);_voices.append(player);_started.append(-1);_priorities.append(0)
	for id:String in ["music_calm","music_groove"]:
		var player:=AudioStreamPlayer.new();player.stream=load(ROOT+id+".res");player.volume_db=-25 if id=="music_calm" else -40;add_child(player);_music.append(player);player.play()

func set_mood(street:int,ensemble:int,risk:bool=false)->void:_intensity=clampf(maxf(.65 if risk else 0.0,float(maxi(0,street-1))*.18+float(ensemble)*.12),0,1)

func _process(delta:float)->void:
	if _closed:return
	_duck=maxf(0,_duck-delta)
	for i in _music.size():
		var target:float=(-24.0 if i==0 else lerpf(-38,-23,_intensity))-(6.0 if _duck>0 else 0.0)
		target+=linear_to_db(maxf(.0001,music_volume))
		if not enabled:target=-80
		_music[i].volume_db=lerpf(_music[i].volume_db,target,1.0-exp(-delta*(16 if _duck>0 else 3)))

func cue(kind:String,pitch:float=1.0)->void:
	if _closed or not enabled or not _streams.has(kind):return
	var now:int=Time.get_ticks_msec()
	if now-int(_last.get(kind,-10000))<(80 if kind in ["hu","overkill","lamp"] else 35):return
	var finish:bool=kind in ["build_wind_finish","build_fire_finish"]
	var first_hit:bool=kind=="build_fire_first"
	var priority:int=3 if finish or kind in ["hu","overkill","lamp","encore_clear","breakthrough"] else (2 if first_hit or kind in ["group_land","charge","total","reveal","encore_accept","chain_land"] else 1)
	var slot:int=-1;var oldest:int=9223372036854775807
	for i in _voices.size():
		if not _voices[i].playing:slot=i;break
		if _priorities[i]<=priority and _started[i]<oldest:slot=i;oldest=_started[i]
	if slot<0:return
	_last[kind]=now;_started[slot]=now;_priorities[slot]=priority
	var player:AudioStreamPlayer=_voices[slot];player.stop();player.stream=_streams[kind];player.pitch_scale=pitch
	player.volume_db=-10 if priority==3 else (-13 if priority==2 else -17)
	if finish:player.volume_db=-12
	elif first_hit:player.volume_db=-15
	if kind=="select":player.volume_db=-21
	player.volume_db+=linear_to_db(maxf(.0001,effects_volume))
	if kind in ["hu","overkill","lamp","group_land","chain_land","encore_clear","encore_accept","breakthrough"]:_duck=maxf(_duck,.9 if priority==3 else .24)
	if finish or first_hit:_duck=maxf(_duck,.72 if finish else .30)
	player.play();sounded.emit(kind,Time.get_ticks_usec(),pitch,player.volume_db)

func beat(operation:String,step:int)->void:
	if operation.begins_with("build_"):cue(operation);return
	if ":" in operation:
		var route:String=operation.get_slice(":",0)
		cue({"连顺":"wind_score","爆杠":"coal_score","接力":"relay_score"}.get(route,"multiply"),pow(2.0,float([0,2,3,5,7][mini(step,4)])/12.0));return
	var key:String={"base":"chip","add":"chip","paid":"chip","multiply":"multiply","chip_mul":"multiply","repeat":"repeat","coin":"purchase","lamp":"lamp","refrain_gain":"repeat","refund":"purchase","support":"relay","heat":"furnace_charge","heat_spent":"coal_score","total":"total","breakthrough":"breakthrough","hu":"hu","overkill":"overkill"}.get(operation,"")
	if key.is_empty():return
	var pitch:float=pow(2.0,float([0,2,3,5,7][mini(step,4)])/12.0) if key in ["chip","multiply","repeat"] else 1.0
	cue(key,pitch)

func skip()->void:
	for player:AudioStreamPlayer in _voices:player.stop()
	_duck=0

func close()->void:
	if _closed:return
	_closed=true
	for player:AudioStreamPlayer in _voices:player.stop();player.stream=null
	for player:AudioStreamPlayer in _music:player.stop();player.stream=null
	_streams.clear()
func _exit_tree()->void:close()
