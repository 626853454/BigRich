class_name ChapterCommissions
extends RefCounted

# Finite local-authority ledger. It never owns wallets, RNG, Nodes or combat state.
const OFFICES:=[4,18,32]
const FORGES:=[2,16,30]
const TARGETS:=[6,20,34]
const TERMS:={"delivery":{"cost":3,"reward":9,"window":8,"refund":1},"survey":{"cost":4,"reward":11,"window":12,"refund":0}}
var _chapter:=-1
var _pending:Array[Dictionary]=[{},{}]
var _used:Dictionary={}
var _history:Array[Dictionary]=[]
var _edges:Dictionary={}
var _next_id:=1
var _last_move_serial:=0

func _int(value:Variant,lo:int,hi:int)->bool:return typeof(value)==TYPE_INT and value>=lo and value<=hi
func _result(ok:bool,reason:String="",cost:int=0,receipt:Dictionary={})->Dictionary:
	return {"ok":ok,"reason":reason,"cost":cost,"receipt":receipt.duplicate(true)}
func configure(chapter:Variant,tiles:Variant)->bool:
	if not _int(chapter,0,2) or not tiles is Array or tiles.size()!=54:return false
	var edges:Dictionary={}
	for i in 54:
		if not tiles[i] is Dictionary or tiles[i].get("id",-1)!=i or not tiles[i].get("next",null) is Array:return false
		for target in tiles[i].next:
			if not _int(target,0,53):return false
			edges[Vector2i(i,target)]=true
	_chapter=chapter;_edges=edges;_pending=[{},{}];_used={};_history=[];_next_id=1;_last_move_serial=0
	return true
func snapshot()->Dictionary:return {"version":1,"chapter":_chapter,"active":_pending.duplicate(true),"history":_history.duplicate(true),"used_count":_used.size()}
func active(actor:Variant)->Dictionary:
	return _pending[actor].duplicate(true) if _int(actor,0,1) else {}
func _key(actor:int,origin:int,kind:String)->String:return "%d:%d:%s"%[actor,origin,kind]
func quote(actor:Variant,kind:Variant,origin:Variant,turn:Variant,coins:Variant)->Dictionary:
	var q:Dictionary={"enabled":false,"reason":"invalid_context","kind":"","cost":0,"reward":0,"refund":0,"origin":-1,"target":-1,"via":-1,"expires_turn":0,"minimum_steps":4}
	if _chapter<0 or not _int(actor,0,1) or typeof(kind)!=TYPE_STRING or not TERMS.has(kind) or not _int(origin,0,53) or origin not in OFFICES or not _int(turn,1,1000000) or not _int(coins,0,999):return q
	var terms:Dictionary=TERMS[kind];var district:int=(OFFICES.find(origin)+1)%3
	q.merge({"reason":"","kind":kind,"cost":terms.cost,"reward":terms.reward,"refund":terms.refund,"origin":origin,"target":OFFICES[district] if kind=="delivery" else TARGETS[district],"via":-1 if kind=="delivery" else FORGES[district],"expires_turn":turn+int(terms.window) },true)
	if not _pending[actor].is_empty():q.reason="already_carrying"
	elif _used.has(_key(actor,origin,kind)):q.reason="already_attempted_this_chapter"
	elif coins<int(terms.cost):q.reason="insufficient_coins"
	q.enabled=q.reason=="";return q
func accept(actor:Variant,kind:Variant,origin:Variant,turn:Variant,coins:Variant)->Dictionary:
	var q:Dictionary=quote(actor,kind,origin,turn,coins)
	if not q.enabled:return _result(false,q.reason)
	var record:Dictionary={"id":_next_id,"chapter":_chapter,"owner":actor,"helper":-1,"kind":kind,"origin":origin,"target":q.target,"via":q.via,"cost":q.cost,"reward":q.reward,"refund":q.refund,"accepted_turn":turn,"expires_turn":q.expires_turn,"steps":[0,0],"via_seen":[false,false],"status":"active"}
	_next_id+=1;_pending[actor]=record;_used[_key(actor,origin,kind)]=true
	return _result(true,"",q.cost,{"action":"accepted","contract":record})
func support(actor:Variant,turn:Variant,coins:Variant)->Dictionary:
	if not _int(actor,0,1) or not _int(turn,1,1000000) or not _int(coins,0,999):return _result(false,"invalid_context")
	var contract:Dictionary=_pending[1-actor]
	if contract.is_empty() or turn>contract.expires_turn or contract.helper!=-1:return _result(false,"no_supportable_contract")
	if coins<1:return _result(false,"insufficient_coins")
	contract.helper=actor;contract.steps[actor]=0;contract.via_seen[actor]=false;contract.expires_turn+=2
	return _result(true,"",1,{"action":"supported","contract":contract,"helper_reward":2,"extends_by":2,"new_deadline":int(contract.expires_turn)})
func _archive(record:Dictionary,status:String,turn:int,traveler:int=-1)->Dictionary:
	var receipt:Dictionary={"action":status,"id":int(record.id),"chapter":_chapter,"owner":int(record.owner),"helper":int(record.helper),"kind":str(record.kind),"origin":int(record.origin),"target":int(record.target),"via":int(record.via),"turn":turn,"traveler":traveler,"steps":record.steps.duplicate(),"via_seen":record.via_seen.duplicate(),"promised_coins":[0,0]}
	if status=="completed":
		receipt.promised_coins[record.owner]=int(record.reward)
		if traveler==record.helper:receipt.promised_coins[traveler]+=2
	elif status=="cancelled":receipt.promised_coins[record.owner]=int(record.refund)
	_history.append(receipt.duplicate(true))
	if _history.size()>24:_history.pop_front()
	_pending[record.owner]={};return receipt
func cancel(actor:Variant,turn:Variant)->Dictionary:
	if not _int(actor,0,1) or not _int(turn,1,1000000) or _pending[actor].is_empty():return _result(false,"no_contract")
	return _result(true,"",0,_archive(_pending[actor],"cancelled",turn))
func expire(turn:Variant)->Array[Dictionary]:
	var receipts:Array[Dictionary]=[]
	if not _int(turn,1,1000000):return receipts
	for owner in 2:
		if not _pending[owner].is_empty() and turn>int(_pending[owner].expires_turn):receipts.append(_archive(_pending[owner],"expired",turn))
	return receipts
func close_chapter(turn:int)->Array[Dictionary]:
	var receipts:Array[Dictionary]=[]
	for owner in 2:
		if not _pending[owner].is_empty():receipts.append(_archive(_pending[owner],"chapter_left",turn))
	return receipts
func observe_move(actor:Variant,origin:Variant,destination:Variant,turn:Variant,serial:Variant)->bool:
	if not _int(actor,0,1) or not _int(origin,0,53) or not _int(destination,0,53) or not _int(turn,1,1000000) or not _int(serial,1,2147483647) or serial<=_last_move_serial or not _edges.has(Vector2i(origin,destination)):return false
	_last_move_serial=serial
	for record in _pending:
		if record.is_empty() or turn>record.expires_turn or actor not in [record.owner,record.helper]:continue
		record.steps[actor]=mini(128,int(record.steps[actor])+1)
		if destination==record.via:record.via_seen[actor]=true
	return true
func arrive(actor:Variant,node:Variant,turn:Variant)->Array[Dictionary]:
	var receipts:Array[Dictionary]=[]
	if not _int(actor,0,1) or not _int(node,0,53) or not _int(turn,1,1000000):return receipts
	for owner in 2:
		var record:Dictionary=_pending[owner]
		if record.is_empty() or turn>record.expires_turn or actor not in [record.owner,record.helper] or node!=record.target or record.steps[actor]<4:continue
		if record.kind=="survey" and not record.via_seen[actor]:continue
		receipts.append(_archive(record,"completed",turn,actor))
	return receipts
func target_for(actor:Variant)->int:
	if not _int(actor,0,1):return -1
	var record:Dictionary=_pending[actor]
	if record.is_empty() and not _pending[1-actor].is_empty() and _pending[1-actor].helper==actor:record=_pending[1-actor]
	if record.is_empty():return -1
	return int(record.via) if record.kind=="survey" and not record.via_seen[actor] else int(record.target)
