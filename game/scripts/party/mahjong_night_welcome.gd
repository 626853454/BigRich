class_name FurMahjongNightWelcome
extends FurMahjongNightTable

## Authored single-player learning encounters. The ordinary random journey does
## not use this subclass. Tiles and scoring remain the normal authoritative ones.
var allowed_groups:Array=[]

func begin_welcome(kind:String,number:int,route:String="wind",extra:String="",seed_value:int=73011)->Dictionary:
	assert(kind in ["tutorial","small"] and number>=1 and number<=3)
	assert(route in ["wind","fire"])
	var build:Dictionary=Catalog.loadout("windbell")
	build.items=[[],[]]
	if kind=="tutorial":
		if number>=2:build.items[0]=["bamboo"]
		if number==3:build.items[0]=["bamboo","windbell"]
	elif number>=2:
		build.items[0]=["windbell" if route=="wind" else "coal"]
		if number==3 and extra in reward_options(route):build.items[0].append(extra)
	super.begin_night({"seed":seed_value,"ai":false,"table":number,"target":1,"coins":[0,0],"build":build,"boss":false,"venue":"welcome"})
	var triples:bool=kind=="small" and number>=2 and route=="fire"
	allowed_groups=[[0,1,2],[52,53,54],[104,105,106]] if triples else [[0,4,8],[48,52,56],[96,100,104]]
	if triples and number==3:allowed_groups[2]=[104,105,106,107]
	if kind=="small":
		# Three readable hands rotate the large/small groups between suits. A
		# retry keeps its seed; a new run changes the hand, not the score rules.
		var variant:int=posmod(seed_value,3)
		var starts:Array=[[0,3,6],[6,0,3],[3,6,0]][variant]
		if triples:
			var faces:Array=[[0,13,26],[2,12,25],[1,14,24]][variant]
			allowed_groups.clear()
			for i in 3:
				var group:Array=[]
				for copy_index in (4 if number==3 and i==2 else 3):group.append(int(faces[i])*4+copy_index)
				allowed_groups.append(group)
		else:
			allowed_groups.clear()
			for suit in 3:
				var first:int=(suit*9+int(starts[suit]))*4
				allowed_groups.append([first,first+4,first+8])
	var hand:Array=[]
	for group:Array in allowed_groups:hand.append_array(group)
	for tile in [108,112,116,120,124]:
		if hand.size()<14:hand.append(tile)
	var rest:Array=[]
	for tile in 136:
		if tile not in hand:rest.append(tile)
	var random:=RandomNumberGenerator.new();random.seed=seed_value
	for i in range(rest.size()-1,0,-1):
		var j:int=random.randi_range(0,i);var tmp:int=rest[i];rest[i]=rest[j];rest[j]=tmp
	_s.hands=[hand,rest.slice(0,13)];_s.hands[1].sort()
	_s.tea.tray=rest.slice(13,18);_s.wall=rest.slice(18)
	_s.discards=[[],[]];_s.melds=[[],[]];_s.actor=0;_s.phase="discard";_s.drawn_tile=hand.back();_s.discard_count=0
	var n:Dictionary=_s.night
	n.stage=1;n.revealed=0;n.direction.done=[false,false];n.direction.applause=[0,0]
	var cap:int=1 if kind=="tutorial" and number<3 else (2 if kind=="small" and number==1 else 3)
	if kind=="tutorial" and number<3:allowed_groups=[allowed_groups[0]]
	n.welcome={"kind":kind,"number":number,"route":route,"extra":extra,"cap":cap,"formed":0,"allowed":allowed_groups.duplicate(true),"complete":false,"seed":seed_value}
	n.target=cap
	_s.table_event={"kind":"deal","actor":0,"tiles":[]};_s.revision+=1
	return _reply(true,"")

static func reward_options(route:String)->Array:
	return ["bamboo","silk"] if route=="wind" else ["anvil","ember"]

func choices()->Array:
	var options:Array=super.choices()
	if not _s.get("night",{}).has("welcome"):return options
	if _s.phase!="discard" or _s.night.welcome.complete:return []
	var result:Array=[]
	for option:Dictionary in options:
		if option.kind not in ["self_chi","self_pon","closed_kong"]:continue
		var ordered:Array=option.tiles.duplicate();ordered.sort()
		if ordered in _s.night.welcome.allowed:result.append(option)
	return result

func presented_choices()->Array:
	return choices() if _s.get("night",{}).has("welcome") else super.presented_choices()

func apply(choice:Variant,actor:Variant,revision:Variant)->Dictionary:
	if not _s.get("night",{}).has("welcome"):return super.apply(choice,actor,revision)
	if actor!=0 or typeof(choice)!=TYPE_INT or choice<0 or choice>=choices().size():return _reply(false,"welcome_choose_group")
	var before:int=_s.melds[0].size()
	var reply:Dictionary=super.apply(choice,actor,revision)
	if not reply.ok:return reply
	assert(_s.melds[0].size()==before+1)
	var n:Dictionary=_s.night
	n.welcome.formed=_s.melds[0].size()
	# Small-table rule, displayed on screen: play up to three groups freely;
	# no discard/round timer/inspiration cost. Normal night rules are unchanged.
	n.self_used[0]=false
	n.welcome.complete=n.welcome.formed>=n.welcome.cap
	if n.welcome.complete:_s.phase="welcome_complete"
	var event:Dictionary=n.events.back()
	var plain_night:Dictionary=n.duplicate(true);plain_night.build=Catalog.loadout("windbell");plain_night.build.items=[[],[]]
	var plain:Dictionary=Score.meld(event.kind,event.tiles,0,plain_night,_empty_context())
	event.welcome_base=plain.total;event.welcome_number=n.welcome.number
	n.last_score=event.duplicate(true)
	_s.revision+=1
	return _reply(true,"")

func receipt()->Dictionary:
	var n:Dictionary=_s.night;var base:int=0;var peak:int=0
	for event:Dictionary in n.events:
		base+=int(event.get("welcome_base",event.total));peak=maxi(peak,int(event.total))
	return {"total":int(n.scores[0]),"base":base,"gain":int(n.scores[0])-base,"peak":peak,"groups":n.events.duplicate(true),"complete":n.welcome.complete}
