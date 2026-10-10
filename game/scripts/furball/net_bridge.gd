class_name FurNetBridge
extends Node

signal guest_connected(peer: int)
signal frame_received(payload: Dictionary)
signal input_received(direction: Vector2, dash: bool, skill: bool)
signal choice_received(kind: String, choice: int)
signal event_choice_received(choice:int,event_serial:int)
signal connection_problem(message: String)
signal begin_received(seed_value: int, styles: Array[int],run_token:int)
signal route_suggestion_received(request:Dictionary)
signal draft_choice_received(choice:int,run_token:int,wave:int,revision:int)
signal order_pickup_received(choice:int,run_token:int,wave:int,cargo_id:int,revision:int)
const PORT := 27842
var guest := 0
var last_dash := 0
var last_skill := 0
var send_clock := 0.0
var local_dash := 0
var local_skill := 0
var frame_sequence:=0
var received_sequence:=0
var assemblies: Dictionary={}
var run_token:=0
const Budget=preload("res://scripts/furball/network_snapshot_budget.gd")
const CHUNK_BYTES:=Budget.CHUNK_BYTES
var budget_drops:=0

func _ready() -> void:
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.connection_failed.connect(func(): connection_problem.emit("连接失败，请确认地址及局域网防火墙设置"))
	multiplayer.server_disconnected.connect(func(): connection_problem.emit("房主已断开连接"))

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()
	for sequence in assemblies.keys():
		if now-assemblies[sequence].created>500:assemblies.erase(sequence)

func host() -> Error:
	close()
	var peer:=ENetMultiplayerPeer.new();var error:=peer.create_server(PORT,1)
	if error==OK:multiplayer.multiplayer_peer=peer
	return error

func join(address: String) -> Error:
	close()
	var peer:=ENetMultiplayerPeer.new();var error:=peer.create_client(address,PORT)
	if error==OK:multiplayer.multiplayer_peer=peer
	return error

func close() -> void:
	if multiplayer.multiplayer_peer!=null:multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	guest=0;last_dash=0;last_skill=0;local_dash=0;local_skill=0
	frame_sequence=0;received_sequence=0;assemblies.clear()
	run_token=0
	budget_drops=0

func close_if_current(peer:MultiplayerPeer) -> void:
	# A new room can replace this peer before queued disconnect cleanup runs.
	if multiplayer.multiplayer_peer==peer:close()

func _connected(peer: int) -> void:
	if multiplayer.is_server():guest=peer;guest_connected.emit(peer)

func _disconnected(_peer: int) -> void:
	connection_problem.emit("队友已断开，本次联机结束")

func begin(seed_value: int, styles: Array[int] = [0,1],provided_run_token:int=0) -> void:
	var token:int=provided_run_token if provided_run_token>0 else run_token
	if guest!=0 and token>0:_begin.rpc_id(guest,seed_value,styles,token)

func publish(frame: Dictionary) -> void:
	if guest==0:return
	var raw:=var_to_bytes(frame)
	if raw.size()>Budget.MAX_RAW_BYTES:
		budget_drops=mini(1000000000,budget_drops+1);return
	var compressed:=raw.compress(FileAccess.COMPRESSION_ZSTD)
	if not Budget.fits_encoded(raw.size(),compressed.size()):
		budget_drops=mini(1000000000,budget_drops+1);return
	frame_sequence+=1
	var count:=ceili(float(compressed.size())/CHUNK_BYTES)
	for index in count:
		_frame_part.rpc_id(guest,frame_sequence,index,count,raw.size(),compressed.slice(index*CHUNK_BYTES,mini(compressed.size(),(index+1)*CHUNK_BYTES)))

func send_input(direction: Vector2, dash: bool, skill: bool) -> void:
	if dash:local_dash+=1
	if skill:local_skill+=1
	_receive_input.rpc_id(1,direction,local_dash,local_skill)

func send_choice(kind: String, choice: int) -> void:
	_choice.rpc_id(1,kind,choice)

func send_order_pickup(choice:int,token:int,wave:int,cargo_id:int,revision:int)->void:
	_order_pickup.rpc_id(1,choice,token,wave,cargo_id,revision)

func send_draft_choice(choice:int,token:int,wave:int,revision:int)->void:
	_draft_choice.rpc_id(1,choice,token,wave,revision)

func send_board_event(choice:int,event_serial:int)->void:
	_board_event.rpc_id(1,choice,event_serial)

func send_route_suggestion(request:Dictionary)->void:
	if not request.has_all(["run_token","round_token","adjustment","expected_revision"]) or request.size()!=4:return
	for key in request:
		if not request[key] is int:return
	_suggest.rpc_id(1,request.run_token,request.round_token,request.adjustment,request.expected_revision)

@rpc("authority","call_remote","reliable",0)
func _begin(seed_value: int, styles: Array[int],token:int) -> void:
	if styles.size()!=2 or styles[0]!=0 or styles[1] not in [1,2]: return
	if token<1 or token>2147483647:return
	run_token=token;begin_received.emit(seed_value,styles,token)

@rpc("authority","call_remote","unreliable",1)
func _frame_part(sequence: int, index: int, count: int, raw_size: int, payload: PackedByteArray) -> void:
	# Assemble bounded datagrams; discard incomplete snapshots instead of fragmenting UDP.
	if not Budget.accepts_fragment(sequence,received_sequence,index,count,raw_size,payload.size()):return
	if not assemblies.has(sequence):
		if assemblies.size()>=Budget.MAX_ASSEMBLIES:
			var keys:=assemblies.keys();keys.sort();assemblies.erase(keys[0])
		assemblies[sequence]={"parts":{},"count":count,"raw_size":raw_size,"created":Time.get_ticks_msec()}
	var entry: Dictionary=assemblies[sequence]
	if entry.count!=count or entry.raw_size!=raw_size:return
	entry.parts[index]=payload
	if entry.parts.size()!=count:return
	var joined:=PackedByteArray()
	for part in count:joined.append_array(entry.parts[part])
	var raw:=joined.decompress(raw_size,FileAccess.COMPRESSION_ZSTD)
	if raw.size()!=raw_size:return
	var frame: Variant=bytes_to_var(raw)
	if not frame is Dictionary:return
	received_sequence=sequence
	for old in assemblies.keys():
		if old<=sequence:assemblies.erase(old)
	frame_received.emit(frame)

@rpc("any_peer","call_remote","unreliable_ordered",0)
func _receive_input(direction: Vector2, dash_sequence: int, skill_sequence: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest or not direction.is_finite():return
	var dash:=dash_sequence>last_dash;var skill:=skill_sequence>last_skill
	last_dash=maxi(last_dash,dash_sequence);last_skill=maxi(last_skill,skill_sequence)
	input_received.emit(direction.limit_length(1),dash,skill)

@rpc("any_peer","call_remote","reliable",0)
func _choice(kind: String, choice: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest:return
	if kind in ["route","board_roll","board_move","board_business","board_invest","board_supply"] and choice>=0 and choice<=2:choice_received.emit(kind,choice)

@rpc("any_peer","call_remote","reliable",0)
func _board_event(choice:int,event_serial:int)->void:
	# A separate token-bearing RPC prevents a delayed event choice crossing rounds.
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest:return
	if choice<0 or choice>2 or event_serial<1 or event_serial>6:return
	event_choice_received.emit(choice,event_serial)

@rpc("any_peer","call_remote","reliable",0)
func _suggest(token:int,round_token:int,adjustment:int,expected_revision:int)->void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest:return
	if token<1 or token>2147483647 or round_token<1 or round_token>6 or adjustment not in [-1,0,1] or expected_revision<0 or expected_revision>3:return
	route_suggestion_received.emit({"run_token":token,"round_token":round_token,"adjustment":adjustment,"expected_revision":expected_revision})

@rpc("any_peer","call_remote","reliable",0)
func _draft_choice(choice:int,token:int,wave:int,revision:int)->void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest:return
	if choice<0 or choice>2 or token<1 or token>2147483647 or wave<1 or wave>5 or revision<0 or revision>2:return
	draft_choice_received.emit(choice,token,wave,revision)

@rpc("any_peer","call_remote","reliable",0)
func _order_pickup(choice:int,token:int,wave:int,cargo_id:int,revision:int)->void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=guest:return
	if choice not in [0,1] or token<1 or token>2147483647 or wave<1 or wave>6 or cargo_id<1 or cargo_id>6 or revision<0 or revision>256:return
	order_pickup_received.emit(choice,token,wave,cargo_id,revision)
