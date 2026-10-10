class_name FurMahjongNightCatalog
extends RefCounted

const ITEMS := {
	"windbell":{"name":"逐浪风铃","route":"连顺","price":6,"shared":false,"text":"顺子按本桌此前顺子数 ×1.35，最多4层。先亮小顺，再做大顺。"},
	"bamboo":{"name":"竹节算盘","route":"连顺","price":5,"shared":false,"text":"顺子 +24筹码；新起点的当前筹码 ×1.3。把它放在加筹码挂件后收益更高。"},
	"dew":{"name":"满露青盏","route":"连顺","price":6,"shared":false,"text":"顺子每剩余1茶气 +6筹码。换牌速度与保留茶气要取舍。"},
	"silk":{"name":"三色锦囊","route":"连顺","price":7,"shared":false,"text":"自己的万筒索三类顺子集齐后，顺子 ×2。"},
	"coal":{"name":"爆鸣茶炉","route":"爆杠","price":6,"shared":false,"text":"刻子蓄1炉温；也可花1灵感添火，跨回合保留。满2炉温后下一组非杠再计一次。杠 ×2并立刻蓄满。"},
	"anvil":{"name":"玉石镇纸","route":"爆杠","price":5,"shared":false,"text":"刻子与杠 +60筹码。先碰拿分，还是留到第四张？"},
	"crucible":{"name":"积火铜鼎","route":"爆杠","price":6,"shared":false,"text":"每完成一次杠，本桌后续面子永久 +35筹码。"},
	"ember":{"name":"双响火签","route":"爆杠","price":7,"shared":false,"text":"杠额外计分一次；不额外补牌、不递归触发。"},
	"redthread":{"name":"牵手红绳","route":"接力","price":6,"shared":false,"text":"用伙伴曾换出到河牌的实体牌组成面子，该组 ×2.4。每张实体只认一次接力。"},
	"teacup":{"name":"回甘双杯","route":"接力","price":5,"shared":false,"text":"接力面子 +80筹码、返1茶气；重复计分不重复返茶。"},
	"chorus":{"name":"双声小鼓","route":"接力","price":8,"shared":true,"text":"双方都形成过有效面子后，后续面子 ×1.8。占共享槽。"},
	"fellow":{"name":"照面铜镜","route":"接力","price":7,"shared":true,"text":"伙伴已亮过相同种类的面子，本次 ×1.6。占共享槽。"}
}
const CONTRACTS := {
	"sequence":{"name":"三顺成章","text":"本人本桌3组顺子（含胡牌时合法拆出的暗顺）"},
	"triplet":{"name":"双刻鸣金","text":"本人本桌2组刻/杠（含胡牌时合法拆出的暗刻）"},
	"suit":{"name":"同门九响","text":"本人合法胡牌且至少9张属于同一数牌花色"}
}
const STARTERS := ["windbell","coal","redthread"]
const TARGETS := [350,1800,6000]
const STAKES := [0,2,5]
const STAKE_MULT := [1.0,1.3,1.5]
const SHORTS := {
	"windbell":"此前每组顺子 ×1.35\n最多4层，越连越响",
	"bamboo":"顺子 +24筹码\n新起点再令筹码 ×1.3",
	"dew":"每剩1茶气，顺子 +6筹码\n交换还是蓄气？",
	"silk":"自己的顺子集齐万筒索\n之后顺子 ×2",
	"coal":"刻子 / 1灵感积火，满2再计\n杠 ×2 且立刻蓄满",
	"anvil":"刻 / 杠 +60筹码\n稳定起步的硬底子",
	"crucible":"每杠一次，后续 +35筹码\n本桌越打越热",
	"ember":"杠额外计分一次\n不再补牌，不递归",
	"redthread":"伙伴换出的牌成组 ×2.4\n每张实体只认一次",
	"teacup":"接力面子 +80筹码\n并返还1茶气",
	"chorus":"双方都有面子后 ×1.8\n全队共享",
	"fellow":"伙伴亮过同种面子 ×1.6\n全队共享"
}

static func item(id:String)->Dictionary:return ITEMS.get(id,{}).duplicate(true)
static func name_of(id:String)->String:return ITEMS.get(id,{}).get("name",id)
static func loadout(starter:String)->Dictionary:
	return {"techniques":["",""],"items":[[starter],["teacup"]],"shared":[],"levels":[{"chi":1,"pon":1,"kong":1},{"chi":1,"pon":1,"kong":1}],"stamps":{},"heirlooms":[-1,-1],"keepsakes":[[],[]],"carry_slots":[1,1]}


const TECHNIQUES := {
	"rewind":{"name":"回潮手","icon":"windbell","text":"回手后，本回合还可用一次其他技艺，仍需再付1灵感。每回合最多两次技艺，回手仅一次。","decision":"先救回缺张，再押上催演；两点灵感换一次准备好的爆发。"},
	"spotlight":{"name":"压轴一击","icon":"coal","text":"催演升至 ×2.6，但额外押1金币。新亮组成功退本金、返1茶气；弃牌或提前胡牌都不会返还。","decision":"确定能亮组时爆发；如果先催演再改牌失败，会同时损失灵感与金币。"},
	"encore":{"name":"连台好戏","icon":"silk","text":"催演改为 ×1.5，连续强化两组，可跨个人回合保留到本街结束。新街未用完就消散。","decision":"为两次亮牌安排节奏；这一手少赚一点，把爆发延续到下一手。"},
	"partner":{"name":"接棒师","icon":"redthread","text":"伙伴用你递出的实体牌新亮接力组时，你返1灵感。每街最多一次，自己拿回不返。","decision":"把自己暂时不要的牌变成伙伴的高分，再把回来的灵感投入下一次救牌。"}
}
static func techniques_for(build:Dictionary,actor:int)->Array:
	if actor==1 or "redthread" in build.items[actor] or "teacup" in build.items[actor]:return ["partner","rewind"]
	if "coal" in build.items[actor] or "anvil" in build.items[actor]:return ["spotlight","encore"]
	return ["rewind","encore"]


const VENUES := {
	"river":{"name":"河灯悬赏","table":2,"text":"每街第一个用新揭河牌亮出的面子 +80筹码。","choice":"自己先完成可靠的小组；适合回手、河牌交换和稳定拿分。"},
	"refrain":{"name":"双灯返场","table":2,"text":"同一街两人都亮灯，各获得一次「下一组新亮面子再计」。可留到后街，最多存2次。","choice":"先帮伙伴完成目标，再把返场留给高筹码大组。个人抢分不一定最划算。"},
	"duet":{"name":"双声门神","table":3,"text":"两人都亮过面子，才解除挂件倍率护印；基础筹码照常计算。","choice":"先用小组开门，再让核心构筑爆发。"},
	"prism":{"name":"镜灯夜王","table":3,"text":"两人各用过灵感技艺，且全队用过至少两种不同技艺，才解除挂件倍率护印。","choice":"先商量谁回手、谁催演或递彩；同用催演不能开门。"}
}
static func venues_for(number:int)->Array:return ["river","refrain"] if number==2 else ["duet","prism"]
