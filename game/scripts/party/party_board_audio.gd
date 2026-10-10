class_name FurPartyBoardAudio
extends Node

const STREAMS:={
	"roll":preload("res://assets/party/audio/party_roll.wav"),
	"step":preload("res://assets/party/audio/party_step.wav"),
	"coin":preload("res://assets/party/audio/party_coin.wav"),
	"purchase":preload("res://assets/party/audio/party_purchase.wav"),
	"star":preload("res://assets/party/audio/party_star.wav"),
	"embark":preload("res://assets/party/audio/party_embark.wav")}
const COOLDOWN_MS:={"roll":80,"step":95,"coin":100,"purchase":150,"star":250,"embark":300}
const PRIORITY:={"roll":1,"step":0,"coin":1,"purchase":2,"star":3,"embark":2}
const VOICE_LIMIT:=3
const GLOBAL_GAP_MS:=35
var _voices:Array[AudioStreamPlayer]=[]
var _priorities:Array[int]=[-1,-1,-1]
var _started:Array[int]=[-1,-1,-1]
var _last_kind:Dictionary={}
var _last_global:=-10000
var _accepted:=0
var _closed:=false

func _ready()->void:
	if not _voices.is_empty():return
	for index in VOICE_LIMIT:
		var voice:=AudioStreamPlayer.new();voice.name="BoardVoice%d"%index;voice.volume_db=-8.0;voice.max_polyphony=1
		add_child(voice);_voices.append(voice)

func play(kind:String)->bool:
	if _closed or not is_inside_tree() or _voices.size()!=VOICE_LIMIT or not STREAMS.has(kind):return false
	var now:int=Time.get_ticks_msec()
	if now-_last_global<GLOBAL_GAP_MS or now-int(_last_kind.get(kind,-10000))<int(COOLDOWN_MS[kind]):return false
	var selected:=-1;var oldest:=9223372036854775807
	for index in VOICE_LIMIT:
		if not _voices[index].playing:selected=index;break
		if _priorities[index]<=int(PRIORITY[kind]) and _started[index]<oldest:oldest=_started[index];selected=index
	if selected<0:return false
	var voice:AudioStreamPlayer=_voices[selected];voice.stop();voice.stream=STREAMS[kind];voice.play()
	_priorities[selected]=int(PRIORITY[kind]);_started[selected]=now;_last_kind[kind]=now;_last_global=now;_accepted+=1
	return true

func diagnostics()->Dictionary:
	var playing:=0
	for voice in _voices:
		if voice.playing:playing+=1
	return {"nodes":1+_voices.size(),"voices":_voices.size(),"playing":playing,"accepted":_accepted,"closed":_closed,"kinds":STREAMS.keys()}

func close()->void:
	if _closed:return
	_closed=true
	for voice in _voices:voice.stop();voice.stream=null
	_last_kind.clear();_priorities.fill(-1);_started.fill(-1)

func _exit_tree()->void:close()
