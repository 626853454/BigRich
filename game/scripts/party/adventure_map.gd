class_name FurAdventureMap
extends RefCounted

const Base=preload("res://scripts/party/party_map.gd")
const COLOURS=Base.COLOURS
const PLAYER_NAMES=Base.PLAYER_NAMES
const STAR_CHOICES=Base.STAR_CHOICES
const CHALLENGES:=[6,20,34]
const EXITS:=[11,25,39]
const FORGES:=[2,16,30]
const ITEM_SHOPS:=[7,21,35]
const COMMISSION_STATIONS:=[4,18,32]
const CHAPTER_NAMES:=["海岛狂欢","牌阵山城","时光机关城"]
const ACTIVITY_KINDS:=["brotato","mahjong","time_relay"]
const ELEVATED_CLEARANCE:=3.4
const RECT_ROAD:=[Vector2(8,0),Vector2(8,14.0/3.0),Vector2(14.0/3.0,6),Vector2(0,6),Vector2(-14.0/3.0,6),Vector2(-8,14.0/3.0),Vector2(-8,0),Vector2(-8,-14.0/3.0),Vector2(-14.0/3.0,-6),Vector2(0,-6),Vector2(14.0/3.0,-6),Vector2(8,-14.0/3.0)]
const GEAR_ROAD:=[Vector2(8,0),Vector2(8,4),Vector2(4,7),Vector2(0,7),Vector2(-5,7),Vector2(-9,4),Vector2(-9,0),Vector2(-9,-4),Vector2(-5,-7),Vector2(0,-7),Vector2(4,-7),Vector2(8,-4)]

static func _layout_data(chapter:int)->Array[Dictionary]:
	if chapter==1:
		return [{"id":0,"name":"万字云台","center":Vector3(-15.5,2.6,8),"size":Vector2(20,16),"shape":"square","theme":"mahjong"},{"id":1,"name":"筒子茶城","center":Vector3(0,4,-11),"size":Vector2(16,20),"shape":"square","theme":"mahjong"},{"id":2,"name":"索子云园","center":Vector3(15.5,3,8),"size":Vector2(20,16),"shape":"square","theme":"mahjong"}]
	return [{"id":0,"name":"晨钟扇台","center":Vector3(-14,1.2,10),"size":Vector2(22,20),"shape":"gear","theme":"time_relay"},{"id":1,"name":"错层齿轮城","center":Vector3(0,4.6,-10),"size":Vector2(20,22),"shape":"gear","theme":"time_relay"},{"id":2,"name":"回声廊台","center":Vector3(17.5,2.7,4),"size":Vector2(22,20),"shape":"gear","theme":"time_relay"}]

static func _main_point(chapter:int,region:int,index:int)->Vector3:
	var road:Array=RECT_ROAD if chapter==1 else GEAR_ROAD
	var local:Vector2=road[index]
	if region==1:local=Vector2(-local.y,local.x)
	elif region==2:local=-local
	var center:Vector3=_layout_data(chapter)[region].center
	return center+Vector3(local.x,.22,local.y)

static func _apply_layout(tiles:Array[Dictionary],chapter:int)->void:
	for region in 3:
		for local in 12:tiles[region*14+local].pos=_main_point(chapter,region,local)
	for region in 3:
		var origin:Vector3=tiles[region*14+11].pos
		var destination:Vector3=tiles[((region+1)%3)*14].pos
		for segment in 2:
			var t:float=float(segment+1)/3.0
			tiles[region*14+12+segment].pos=origin.lerp(destination,t)+Vector3.UP*sin(t*PI)*.3
	var forks:Array=[[3,8],[17,22],[31,36],[34,38]]
	for route in 4:
		for segment in 3:
			var origin:Vector3=tiles[int(forks[route][0])].pos
			var destination:Vector3=tiles[int(forks[route][1])].pos
			tiles[42+route*3+segment].pos=origin.lerp(destination,float(segment+1)/4.0)
	if chapter==1:tiles[27].pos+=Vector3(-1.5,0,0)
	var upper:Array=[Vector2(21.2,8.5),Vector2(17,10.2),Vector2(12.7,11.5)] if chapter==1 else [Vector2(24,4.5),Vector2(19.2,6.5),Vector2(15,8.4)]
	var upper_height:float=float(_layout_data(chapter)[2].center.y)+.22+ELEVATED_CLEARANCE
	# These old graph chords interleave. Use a visible overpass instead of
	# pretending their X/Z crossing is a new branch or placing overlapping discs.
	for index in 3:
		var local:Vector2=upper[index]
		tiles[51+index].pos=Vector3(local.x,upper_height,local.y)
		tiles[51+index]["elevated"]=true


static func nodes(chapter:int=0)->Array[Dictionary]:
	var tiles:Array[Dictionary]=Base.nodes()
	for tile in tiles:tile["elevated"]=false
	if chapter in [1,2]:_apply_layout(tiles,chapter)
	for tile in tiles:
		tile["chapter"]=clampi(chapter,0,2)
		tile["activity"]="";tile["station"]=""
		if tile.id in CHALLENGES:tile.activity="challenge";tile.name="挑战站 · "+["港口","风车","遗迹"][tile.district]
		elif tile.id in EXITS:tile.activity="chapter_exit";tile.name="章节出口"
		elif tile.id in FORGES:tile.station="forge";tile.name="配方工坊"
		elif tile.id in ITEM_SHOPS:tile.station="item_shop";tile.name="道具补给站"
		elif tile.id in COMMISSION_STATIONS:tile.station="commission";tile.name=["港口货运所","风车勘探所","遗迹驿站"][tile.district]
	return tiles
static func districts(chapter:int=0)->Array[Dictionary]:
	if chapter==0:return Base.districts()
	var data:Array[Dictionary]=_layout_data(clampi(chapter,1,2))
	for region in data:
		region["height"]=region.center.y;region["radius"]=region.size*.5
		region["landmark"]=region.center+Vector3(-3,0,-1)
		var anchors:Array[Vector3]=[]
		for local in 12:anchors.append(_main_point(chapter,int(region.id),local))
		region["road_anchors"]=anchors
	return data
static func point(node:int,chapter:int=0)->Vector3:
	var tiles:Array[Dictionary]=nodes(chapter)
	return tiles[clampi(node,0,tiles.size()-1)].pos
static func is_ferry_edge(origin:int,destination:int)->bool:return Base.is_ferry_edge(origin,destination)
static func is_bridge_edge(origin:int,destination:int)->bool:return Base.is_bridge_edge(origin,destination)
static func edges()->Array:return Base.edges()
