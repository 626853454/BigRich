class_name FurPartyMusic
extends Node

const STREAMS:={"board":preload("res://assets/party/audio/party_music_board.wav"),"battle":preload("res://assets/party/audio/party_music_battle.wav")}
const MODES:Array[String]=["board","battle"]
const VOLUMES:Array[float]=[-24.0,-26.0]
const FADE_SECONDS:=0.5
const FRAME_COUNT:=576000
var _voices:Array[AudioStreamPlayer]=[]
var _gain:Array[float]=[0.0,0.0]
var _target:Array[float]=[0.0,0.0]
var _mode:=""
var _closed:=false
var _accepted:=0

func _ready()->void:
	if not _voices.is_empty():return
	for index in 2:
		var voice:=AudioStreamPlayer.new();voice.name="PartyMusic%d"%index;voice.max_polyphony=1;voice.volume_db=-80.0
		add_child(voice);_voices.append(voice)

func set_mode(kind:String)->bool:
	if _closed or not is_inside_tree() or _voices.size()!=2 or kind not in MODES:return false
	if kind==_mode:return true
	var index:int=MODES.find(kind)
	if not _voices[index].playing:
		var stream:AudioStreamWAV=STREAMS[kind].duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=FRAME_COUNT
		_voices[index].stream=stream;_voices[index].play()
	_target[0]=1.0 if index==0 else 0.0;_target[1]=1.0 if index==1 else 0.0
	_mode=kind;_accepted+=1
	return true

func _process(delta:float)->void:
	if _closed or not is_finite(delta) or delta<=0:return
	for index in _voices.size():
		_gain[index]=move_toward(_gain[index],_target[index],minf(delta,FADE_SECONDS)/FADE_SECONDS)
		_voices[index].volume_db=VOLUMES[index]+linear_to_db(maxf(_gain[index],0.00001))
		if _gain[index]<=0.0 and _target[index]==0.0:
			_voices[index].stop();_voices[index].stream=null

func diagnostics()->Dictionary:
	var playing:=0;var loaded:=0
	for voice in _voices:
		if voice.playing:playing+=1
		if voice.stream!=null:loaded+=1
	return {"nodes":1+_voices.size(),"voices":_voices.size(),"playing":playing,"loaded":loaded,"mode":_mode,"closed":_closed,"accepted":_accepted,"gain":_gain.duplicate(),"target":_target.duplicate(),"volumes_db":VOLUMES.duplicate(),"fade_seconds":FADE_SECONDS}

func close()->void:
	if _closed:return
	_closed=true;_mode="";_gain.fill(0.0);_target.fill(0.0)
	for voice in _voices:voice.stop();voice.stream=null
	set_process(false)

func _exit_tree()->void:close()
