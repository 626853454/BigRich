class_name FurBuildCatalog
extends RefCounted

const NAMES := ["甩锅 · 护盾标记", "摸鱼 · 蓄能齐射", "画饼 · 诱饵连爆"]
const DESCRIPTIONS := [
	"近战自动挥锅并标记敌人。Q 释放吸收的伤害；靠近队友提供减伤。",
	"自动射击。停下移动蓄能，重新移动触发强化齐射。攻击被标记的敌人有伤害加成。",
	"自动投放诱饵饼聚怪，延时爆炸。被标记的敌人会引发更大范围的爆炸。",
]
const UPGRADES := [
	{"id":"weapon", "name":"再来一把", "detail":"武器 +1（最多 6）；攻击间隔 +8%", "stat":"weapons", "value":1.0},
	{"id":"power", "name":"加大火力", "detail":"伤害 +22%；移动速度 -4%", "stat":"damage", "value":0.22},
	{"id":"speed", "name":"小短腿加速", "detail":"移动速度 +12%；生命上限 +8", "stat":"speed", "value":0.12},
	{"id":"area", "name":"锅大饼也大", "detail":"范围 +18%；攻击间隔 +6%", "stat":"area", "value":0.18},
	{"id":"crit", "name":"暴击也要讲礼貌", "detail":"暴击率 +12%；暴击伤害为 2 倍", "stat":"crit", "value":0.12},
	{"id":"link", "name":"贴贴协议", "detail":"合作标记增伤 +20%；标记/诱饵持续时间增强", "stat":"synergy", "value":0.20},
	{"id":"heal", "name":"奶茶续命", "detail":"恢复 35 生命，生命上限 +12", "stat":"health", "value":12.0},
	{"id":"bounce", "name":"反弹你的反弹", "detail":"子弹多弹射 1 次；近战与诱饵伤害 +12%", "stat":"bounce", "value":1.0},
]
const SIGNATURES := [
	{"id":"bank", "name":"接锅许可证", "detail":"锅能上限 +25；Q 冷却 +1 秒（最多 2 次）", "style":0},
	{"id":"nap", "name":"一分钟也算午休", "detail":"站定蓄能快 45%；生命上限 -10（最多 2 次）", "style":1},
	{"id":"promise", "name":"这饼保质期很长", "detail":"诱饵爆炸范围 +20%；普通诱饵延时 +0.6 秒（最多 2 次）", "style":2}
]
const MASTERWORKS := [
	{"id":"shelter","name":"共担合同","detail":"护盾距离 3.5→5 米，减伤 45%→55%；Q 伤害 -15%","style":0,"masterwork":true},
	{"id":"verdict","name":"一锅拍板","detail":"锅气≥35时Q放出穿群锅浪；爆发+35%，冷却+1秒\n锅浪命中可打断冲锋/齐射蓄势；Boss不受影响","style":0,"masterwork":true},
	{"id":"piercing","name":"静音狙击","detail":"满蓄能追加1轮齐射，穿透+1；攻击间隔+10%\n追加轮命中可打断冲锋/齐射蓄势；Boss不受影响","style":1,"masterwork":true},
	{"id":"assembly","name":"流水线办公","detail":"满蓄迈步：前方120°接档2轮，优先蓄势敌\n间隔-22%/蓄速-35%；Boss不接档、不打断","style":1,"masterwork":true},
	{"id":"chain","name":"信誉连锁","detail":"Q连兑8米内最多6饼；锅印/3敌触发4米连爆，伤害-15%\n参与连兑的爆炸可打断冲锋/齐射蓄势；Boss不受影响","style":2,"masterwork":true},
	{"id":"express","name":"到期速兑","detail":"普通诱饵延时 -0.8 秒；爆炸范围 -15%","style":2,"masterwork":true},
]

static func create(style: int) -> Dictionary:
	return {"style":clampi(style,0,2), "weapons":3, "damage":1.0, "speed":1.0,
		"area":1.0, "crit":0.08, "synergy":0.35, "health":100.0, "bounce":0,
		"interval":1.0, "level":1, "dealt":0.0, "kills":0, "triggers":0,"payoff_waves":0,"payoff_volleys":0,"payoff_baits":0,
		"pot_cap":50.0,"skill_delay":0.0,"charge_rate":1.0,"bait_area":1.0,"bait_delay":0.0,"signature_count":0,"chosen":[],"saved_damage":0.0,"self_saved_damage":0.0,"ally_saved_damage":0.0,"rescues":0,"link_receipts":0,
		"masterwork":"","guard_radius":3.5,"shield_reduction":.45,"burst_damage":1.0,"charged_pierce":0,"bait_damage":1.0,"bait_chain":false}

static func apply(build: Dictionary, id: String) -> bool:
	for item in MASTERWORKS:
		if item.id!=id:continue
		if item.style!=build.style or not build.masterwork.is_empty():return false
		match id:
			"shelter":build.guard_radius=5.0;build.shield_reduction=.55;build.burst_damage=.85
			"verdict":build.burst_damage=1.35;build.skill_delay+=1
			"piercing":build.charged_pierce=1;build.interval*=1.10
			"assembly":build.interval*=.78;build.charge_rate*=.65
			"chain":build.bait_chain=true;build.bait_damage=.85
			"express":build.bait_delay-=.8;build.bait_area*=.85
		build.masterwork=id;build.chosen.append(item.name);return true
	for item in SIGNATURES:
		if item.id != id: continue
		if build.style != item.style or build.signature_count >= 2: return false
		match id:
			"bank": build.pot_cap += 25; build.skill_delay += 1
			"nap": build.charge_rate += .45; build.health = maxf(30,build.health-10)
			"promise": build.bait_area += .20; build.bait_delay += .6
		build.signature_count += 1;build.chosen.append(item.name)
		return true
	for item in UPGRADES:
		if item.id != id: continue
		if item.stat == "weapons":
			if build.weapons >= 6: return false
			build.weapons += 1; build.interval *= 1.08
		elif item.stat == "bounce": build.bounce += 1; build.damage += .12
		elif item.stat == "crit": build.crit = minf(1.0, build.crit + item.value)
		else: build[item.stat] += item.value
		if id == "power": build.speed = maxf(.65, build.speed-.04)
		if id == "speed": build.health += 8
		if id == "area": build.interval *= 1.06
		build.chosen.append(("回旋锅铲" if build.style==0 else "饼屑加料") if id=="bounce" and build.style!=1 else item.name)
		return true
	return false

static func draft(rng: RandomNumberGenerator, build: Dictionary, has_partner: bool = true, midpoint: bool = false) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for item in UPGRADES:
		if item.id == "weapon" and build.weapons >= 6: continue
		if item.id == "crit" and build.crit >= 1.0: continue
		if item.id == "area" and build.style == 1: continue
		if item.id == "link" and build.style == 1 and not has_partner: continue
		var offer: Dictionary = item.duplicate()
		if item.id == "bounce":
			if build.style == 1: offer.detail = "子弹多弹射 1 次；伤害 +12%"
			elif build.style == 0: offer.name = "回旋锅铲"; offer.detail = "挥锅与锅能爆发伤害 +12%"
			else: offer.name = "饼屑加料"; offer.detail = "诱饵爆炸伤害 +12%"
		if item.id == "link" and build.style == 0: offer.detail = "锅印多留 0.2 秒；每次锅印击败多回收 0.8 锅能；队友兑现增伤 +20%"
		if item.id == "link" and build.style == 2: offer.detail = "普通诱饵多聚怪 0.06 秒；兑现锅印增伤 +20%"
		eligible.append(offer)
	for item in SIGNATURES:
		if item.style==build.style and build.signature_count<2: eligible.append(item)
	var picks: Array[Dictionary] = []
	if midpoint and build.masterwork.is_empty():
		for item in MASTERWORKS:
			if item.style==build.style:picks.append(item.duplicate())
	for i in 3:
		if picks.size()>=3:break
		var index := rng.randi_range(0, eligible.size()-1)
		picks.append(eligible[index].duplicate())
		eligible.remove_at(index)
	return picks
