class_name ChapterEcho
extends RefCounted
## Two live couriers record a route; the next loop replays real old positions.
## No wall clock, teleport-to-objective or direct score setters are exposed.
const SIZE:=5
const BEATS:=8
const MAX_LOOPS:=3
const STARTS:=[Vector2i(0,2),Vector2i(4,2)]
const DIRECTIONS:=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.ZERO]
const ACTION_NAMES:=["向上","向右","向下","向左","原地等一拍"]
var _s:Dictionary={}

func start(token:int,variant:int=0,ai_enabled:bool=true)->Dictionary:
	if token<=0 or variant<0 or variant>2:return _reply(false,"invalid_start")
	var plates:Array=[Vector2i(1,1),Vector2i(3,3)]
	var deliveries:Array=[Vector2i(2,2),Vector2i(2,2)]
	var walls:Array=[Vector2i(2,0),Vector2i(2,4)]
	if variant==1:
		plates=[Vector2i(0,4),Vector2i(4,0)];deliveries=[Vector2i(4,3),Vector2i(0,1)]
	elif variant==2:
		plates=[Vector2i(1,4),Vector2i(3,0)];deliveries=[Vector2i(4,4),Vector2i(0,0)];walls=[Vector2i(2,1),Vector2i(2,3)]
	_s={"token":token,"variant":variant,"ai_enabled":ai_enabled,"phase":"play","actor":0,"revision":1,"loop":0,"beat":0,"positions":STARTS.duplicate(),"plates":plates,"goal":Vector2i(2,2),"delivery_points":deliveries,"walls":walls,"record":[[],[]],"track":[[],[]],"rotation":0,"afterglow":0,"delivered":[false,false],"deliveries":0,"result":{},"history":[],"hint":"先录下两人站上踏板的路线；下一轮让回声留守，各自走到同色交付点。"}
	return _reply(true,"")

func state()->Dictionary:return _s.duplicate(true)
func result()->Dictionary:return _s.get("result",{}).duplicate(true)

func choices()->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	if _s.is_empty() or _s.phase!="play":return out
	for i in 5:
		var next:Vector2i=_s.positions[_s.actor]+DIRECTIONS[i]
		out.append({"id":i,"label":ACTION_NAMES[i],"detail":"到 (%d,%d)，两人都行动后推进一拍"%[next.x+1,next.y+1],"enabled":_legal(next)})
	return out

func apply(choice:int,actor:int,revision:int)->Dictionary:
	if not _active(actor,revision) or choice<0 or choice>=5:return _reply(false,"invalid_operation")
	var next:Vector2i=_s.positions[actor]+DIRECTIONS[choice]
	if not _legal(next):return _reply(false,"blocked")
	_s.positions[actor]=next
	if actor==0:_s.actor=1
	else:_finish_beat()
	_s.revision+=1
	return _reply(true,"")

func ghost_positions(beat:int=-1)->Array:
	if _s.is_empty():return []
	var at:int=int(_s.beat) if beat<0 else clampi(beat,0,BEATS-1)
	var out:Array=[]
	for actor in 2:
		if _s.track[actor].is_empty():continue
		out.append(_rotated(_s.track[actor][mini(at,_s.track[actor].size()-1)]))
	return out

func lit_plates(beat:int=-1)->Array:
	if _s.is_empty():return []
	var occupants:Array=_s.positions.duplicate()
	occupants.append_array(ghost_positions(beat))
	if _s.afterglow>0:
		var at:int=int(_s.beat) if beat<0 else beat
		for offset in range(1,int(_s.afterglow)+1):
			if at-offset>=0:occupants.append_array(ghost_positions(at-offset))
	return [_s.plates[0] in occupants,_s.plates[1] in occupants]

func seal_recording(actor:int,revision:int)->Dictionary:
	# Only at a shared-beat boundary with both actual couriers on their plates.
	if not _active(actor,revision) or actor!=0 or _s.loop>=MAX_LOOPS-1:return _reply(false,"cannot_seal")
	if _s.positions[0]!=_s.plates[0] or _s.positions[1]!=_s.plates[1]:return _reply(false,"stand_on_plates")
	for i in 2:
		while _s.record[i].size()<BEATS:_s.record[i].append(_s.positions[i])
	_next_loop();_s.revision+=1
	return _reply(true,"")

func can_resource(key:String,actor:int,revision:int)->bool:
	if not _active(actor,revision):return false
	if key=="rotate_tokens":return _s.loop>0 and not _s.track[0].is_empty()
	if key=="echo_bonus":return _s.afterglow<2
	return false

func apply_resource(key:String,actor:int,revision:int)->Dictionary:
	if not can_resource(key,actor,revision):return _reply(false,"resource_unavailable")
	if key=="rotate_tokens":_s.rotation=(int(_s.rotation)+1)%4;_s.hint="回声轨道旋转90°；看清踏板亮起的拍点再移动。"
	else:_s.afterglow+=1;_s.hint="回声离开踏板后，余辉仍能延长供电。"
	_s.revision+=1
	return _reply(true,"")

func retreat(actor:int,revision:int)->Dictionary:
	if not _active(actor,revision):return _reply(false,"invalid_operation")
	_finish(false,"retreated");_s.revision+=1;return _reply(true,"")

func ai_choice()->int:
	if _s.is_empty() or _s.phase!="play":return -1
	var actor:int=_s.actor
	var target:Vector2i=_s.plates[actor]
	if _s.loop>0 and not _s.delivered[actor]:target=_s.delivery_points[actor]
	if _s.delivered[actor]:target=_s.plates[actor]
	var from:Vector2i=_s.positions[actor]
	if from==target:return 4
	# A bounded BFS chooses a legal next move, rather than writing position.
	var queue:Array=[{"pos":from,"first":-1}];var seen:Dictionary={from:true};var cursor:=0
	while cursor<queue.size():
		var entry:Dictionary=queue[cursor];cursor+=1
		for direction in 4:
			var next:Vector2i=entry.pos+DIRECTIONS[direction]
			if not _legal(next) or seen.has(next):continue
			var first:int=direction if entry.first==-1 else entry.first
			if next==target:return first
			seen[next]=true;queue.append({"pos":next,"first":first})
	return 4

func _finish_beat()->void:
	for i in 2:_s.record[i].append(_s.positions[i])
	var lit:Array=lit_plates()
	if lit[0] and lit[1]:
		for i in 2:
			if _s.positions[i]==_s.delivery_points[i] and not _s.delivered[i]:_s.delivered[i]=true;_s.deliveries+=1
	_s.history.append({"loop":_s.loop,"beat":_s.beat,"positions":_s.positions.duplicate(),"ghosts":ghost_positions(),"lit":lit,"deliveries":_s.deliveries})
	_s.actor=0;_s.beat+=1
	if _s.deliveries==2:_finish(true,"both_delivered")
	elif _s.beat>=BEATS:
		if _s.loop>=MAX_LOOPS-1:_finish(false,"time_exhausted")
		else:_next_loop()
	else:_s.hint="双踏板同时亮起时，到各自同色交付点送能量；已送 %d/2。"%_s.deliveries

func _next_loop()->void:
	_s.track=_s.record.duplicate(true);_s.record=[[],[]];_s.positions=STARTS.duplicate();_s.loop+=1;_s.beat=0;_s.actor=0;_s.rotation=0
	_s.hint="上一轮的行动正在重放。看下方时间线，踩准回声点亮双踏板的时机！"

func _finish(success:bool,reason:String)->void:
	_s.phase="result";_s.result={"token":_s.token,"success":success,"scores":[100,100] if success else [0,0],"deliveries":_s.deliveries,"loops":int(_s.loop)+1,"beats":_s.history.size(),"reason":reason}

func _rotated(p:Vector2i)->Vector2i:
	var offset:=p-Vector2i(2,2)
	for i in int(_s.rotation):offset=Vector2i(-offset.y,offset.x)
	return offset+Vector2i(2,2)

func _legal(p:Vector2i)->bool:return p.x>=0 and p.y>=0 and p.x<SIZE and p.y<SIZE and p not in _s.walls
func _active(actor:int,revision:int)->bool:return not _s.is_empty() and _s.phase=="play" and actor==_s.actor and revision==_s.revision
func _reply(ok:bool,reason:String)->Dictionary:return {"ok":ok,"reason":reason,"revision":_s.get("revision",0)}
