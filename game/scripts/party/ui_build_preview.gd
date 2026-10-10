class_name FurUIBuildPreview
extends RefCounted
## Derive comparison labels by applying the authoritative catalog to a copy.
const FIELDS:=["weapons","damage","speed","health","area","crit","synergy","bounce","pot_cap","skill_delay","charge_rate","bait_area","bait_delay","guard_radius","shield_reduction","burst_damage","charged_pierce","bait_damage","interval"]
const LABELS:={"weapons":"武器数","damage":"火力","speed":"移速","health":"生命上限","area":"攻击范围","crit":"暴击率","synergy":"合作增伤","bounce":"弹射次数","pot_cap":"锅气容量","skill_delay":"技能冷却","charge_rate":"蓄能速度","bait_area":"诱饵范围","bait_delay":"诱饵延时","guard_radius":"守护距离","shield_reduction":"伙伴减伤","burst_damage":"爆发伤害","charged_pierce":"蓄能穿透","bait_damage":"爆炸伤害","interval":"攻击间隔"}
static func changes(build:Dictionary,id:String)->Array[Dictionary]:
	var result:Array[Dictionary]=[];var after:Dictionary=build.duplicate(true)
	if not FurBuildCatalog.apply(after,id):return result
	for field:String in FIELDS:
		if is_equal_approx(float(build.get(field,0)),float(after.get(field,0))):continue
		if field=="bounce" and build.style!=1:continue
		var improved:bool=float(after[field])>float(build[field])
		if field in ["skill_delay","bait_delay","interval"]:improved=not improved
		result.append({"label":LABELS[field],"before":_format(field,build[field]),"after":_format(field,after[field]),"improved":improved})
	return result
static func _format(field:String,value:Variant)->String:
	var n:float=float(value)
	if field in ["weapons","health","bounce","pot_cap","charged_pierce"]:return "%.0f"%n
	if field in ["crit","synergy","shield_reduction"]:return "%.0f%%"%(n*100)
	if field=="guard_radius":return "%.1fm"%n
	if field=="skill_delay":return "%.1fs"%(5+n)
	if field=="bait_delay":return "%+.1fs"%n
	return "×%.2f"%n
static func icon_for(id:String)->String:
	return {"weapon":"bag","power":"forge","speed":"route","area":"compass","crit":"star","link":"heart","heal":"heart","bounce":"route","bank":"shield","nap":"clock","promise":"clock","shelter":"shield","verdict":"forge","piercing":"star","assembly":"settings","chain":"route","express":"clock"}.get(id,"forge")

