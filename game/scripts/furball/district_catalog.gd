class_name FurDistrictCatalog
extends RefCounted

# Bounded content data. Collision, progress, damage and reward live in runtime.
const BOUNDS := Rect2(Vector2(-14.2,-9.2),Vector2(28.4,18.4))
const DISTRICTS := [
	{"name":"串串巷 · 开路营业","goal":"换道前进，点亮任意 2 个账台","target":2,"colour":"ffc374"},
	{"name":"物流街 · 横穿截货","goal":"引普通敌入车道侧闪，接住 3 件包裹","target":3,"colour":"75e0ed"},
	{"name":"夜奶广场 · 分工开席","goal":"充满两座奶站，再到合流点开席","target":2,"colour":"a2e694"}
]
const LOGISTICS_LANES := [-5.0,0.0,5.0]
const PACKAGE_LIMIT := 4
const EVENT_LIMIT := 12
const VARIANT_TITLES := [
	["错位穿巷","两翼绕摊","夹道取账"],
	["横穿车流","纵线截货","交叉抢单"],
	["对角双站","两翼前席","后站远席"]
]

static func entry(district_id:int) -> Dictionary:
	return DISTRICTS[clampi(district_id,0,2)].duplicate(true)

static func variant_id(wave:int,seed:int) -> int:
	# Input-only selection: no combat RNG, and the model's wave*101 salt does not cancel.
	return posmod((maxi(1,seed)%3)*2+clampi(wave,1,6)-1,3)

static func layout(district_id:int,wave:int,seed:int) -> Dictionary:
	var id:=clampi(district_id,0,2);var variant:=variant_id(wave,seed)
	var title:String=VARIANT_TITLES[id][variant]
	return {"variant_id":variant,"variant_title":title,"points":points(id,variant),"obstacles":obstacles(id,variant),"logistics_routes":logistics_routes(variant)}

static func obstacles(district_id:int,variant:int=0) -> Array[Rect2]:
	var result:Array[Rect2]=[]
	if district_id==0:
		match clampi(variant,0,2):
			0:
				result.append(Rect2(Vector2(-8.0,-2.35),Vector2(6.0,.7)))
				result.append(Rect2(Vector2(2.0,1.65),Vector2(6.0,.7)))
			1:
				result.append(Rect2(Vector2(-2.35,-6.0),Vector2(.7,4.0)))
				result.append(Rect2(Vector2(1.65,2.0),Vector2(.7,4.0)))
			2:
				result.append(Rect2(Vector2(-3.0,-3.35),Vector2(6.0,.7)))
				result.append(Rect2(Vector2(-3.0,2.65),Vector2(6.0,.7)))
	return result

static func points(district_id:int,variant:int=0) -> Array[Vector2]:
	if district_id==0:
		match clampi(variant,0,2):
			0:return [Vector2(-10,-4.7),Vector2(0,0),Vector2(10,4.7)]
			1:return [Vector2(-8,3),Vector2(0,-5),Vector2(8,-3)]
			2:return [Vector2(-9,0),Vector2(9,0),Vector2(0,6)]
	if district_id==2:
		match clampi(variant,0,2):
			0:return [Vector2(-5,-2),Vector2(5,2),Vector2.ZERO]
			1:return [Vector2(-8,3),Vector2(8,3),Vector2(0,-4)]
			2:return [Vector2(-3,-6),Vector2(3,-6),Vector2(0,5)]
	return [Vector2(-12,-5),Vector2(-12,0),Vector2(-12,5)]

static func logistics_routes(variant:int=0) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	match clampi(variant,0,2):
		0:
			for z in LOGISTICS_LANES:result.append({"from":Vector2(-13.8,z),"to":Vector2(13.8,z)})
		1:
			for x in [-8.0,0.0,8.0]:result.append({"from":Vector2(x,-8.8),"to":Vector2(x,8.8)})
		2:
			result=[{"from":Vector2(-13,-7),"to":Vector2(13,5)},{"from":Vector2(-13,0),"to":Vector2(13,0)},{"from":Vector2(-13,7),"to":Vector2(13,-5)}]
	return result
