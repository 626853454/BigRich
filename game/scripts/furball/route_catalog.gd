class_name FurRouteCatalog
extends RefCounted

# Content only. The model owns rule timing, progress, damage and rewards.
const STATIONS := ["宵夜入口", "甩锅小巷", "促销大街", "奶茶转角", "承诺仓库", "关门钟楼"]
const ROUTES := [
	{"name":"甩锅巷 · 代收压力", "rule":"每 9 秒收账红圈锁定落点。离开红圈，把追兵留在圈里。", "goal":"借收账圈消灭 3 只怪", "target":3.0, "reward":"队伍经验 +18", "xp":18},
	{"name":"促销街 · 越忙越赚", "rule":"敌潮更密。击败计 1 单，队友兑现锅印额外计 1 单。", "goal":"兑现 25 单", "target":25.0, "reward":"队伍经验 +30", "xp":30},
	{"name":"奶茶摊 · 轮流歇脚", "rule":"进站恢复 20 生命。绿圈内站定，队友负责清理追兵。", "goal":"安全站定累计 3 秒", "target":3.0, "reward":"每人恢复 14 生命，队伍经验 +10", "xp":10}
]

static func entry(route: int) -> Dictionary:
	return ROUTES[clampi(route, 0, 2)]

static func state(route: int, wave: int) -> Dictionary:
	var points := [Vector2(-5, 1), Vector2(5, -2), Vector2(0, 4)]
	return {"id":route, "progress":0.0, "target":entry(route).target, "rewarded":false, "point":points[(wave - 1) % points.size()], "clock":7.0}
