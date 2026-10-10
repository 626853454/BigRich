class_name FurPartyWorkshopAI
extends RefCounted

const Catalog=preload("res://scripts/furball/build_catalog.gd")

# Three offered cards only; these are transparent priorities, not DPS estimates.
# The caller still applies its chosen card and owns all growth/wallet writes.
static func choose(offers:Array,build:Dictionary,partner:Dictionary,lost_last:bool)->int:
	if offers.is_empty() or offers.size()>3 or not _valid_build(build) or not _valid_build(partner):return -1
	var ids:Dictionary={}
	var scores:Array[int]=[]
	for offer in offers:
		if not offer is Dictionary or typeof(offer.get("id"))!=TYPE_STRING:return -1
		var id:String=offer.id
		if ids.has(id):return -1
		ids[id]=true
		if (id=="area" and build.style==1) or (id=="link" and build.style!=0 and partner.style!=0):return -1
		var copy:Dictionary=build.duplicate(true)
		if not Catalog.apply(copy,id) or (id=="crit" and is_equal_approx(copy.crit,build.crit)):return -1
		scores.append(_priority(id,build,partner,lost_last))
	var best:=-1;var best_score:=-1;var best_id:=""
	for index in offers.size():
		var id:String=offers[index].id
		if scores[index]>best_score or (scores[index]==best_score and id<best_id):
			best=index;best_score=scores[index];best_id=id
	return best

static func _valid_build(build:Dictionary)->bool:
	if typeof(build.get("style"))!=TYPE_INT or build.style<0 or build.style>2:return false
	var schema:Dictionary=Catalog.create(int(build.style))
	for key in schema:
		if not build.has(key):return false
		var expected:int=typeof(schema[key]);var actual:int=typeof(build[key])
		if expected==TYPE_FLOAT:
			if actual not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(build[key])):return false
		elif actual!=expected:return false
	if build.weapons<1 or build.weapons>6 or build.health<=0 or build.charge_rate<=0 or build.signature_count<0 or build.signature_count>2:return false
	if build.damage<=0 or build.speed<=0 or build.area<=0 or build.interval<=0 or build.crit<0 or build.crit>1 or build.level<1:return false
	if not build.masterwork.is_empty():
		var known:=false
		for item in Catalog.MASTERWORKS:
			if item.id==build.masterwork and item.style==build.style:known=true;break
		if not known:return false
	if build.chosen.size()>64:return false
	for name in build.chosen:
		if typeof(name)!=TYPE_STRING:return false
	return true

static func _priority(id:String,build:Dictionary,partner:Dictionary,lost:bool)->int:
	match id:
		"heal":return 12 if lost else (9 if build.health<80 else 2)
		"speed":return 10 if lost else 4
		"nap":return 0 if lost or build.health<90 else (7 if build.charge_rate<1.9 else 2)
		"assembly":return 9 if build.weapons>=4 and build.charge_rate>=1.4 else 3
		"piercing":return 8
		"shelter":return 11 if lost else 6
		"verdict":return 9 if build.pot_cap>=75 else 7
		"bank":return 7 if build.pot_cap<75 else 4
		"chain":return 9 if partner.style==0 else 5
		"express":return 8 if partner.style!=0 else 6
		"promise":return 7 if build.weapons>=4 else 5
		"weapon":return 6
		"power":return 5
		"area":return 5 if build.area<1.5 else 3
		"bounce":return 5 if build.style!=1 else 4
		"link":return 6 if partner.style==0 else 5
		"crit":return 3
	return 1
