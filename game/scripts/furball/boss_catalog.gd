class_name FurBossCatalog
extends RefCounted

# The final manager alternates a proximity slam with fixed-position notices.
# Attack data also feeds the view/HUD so warning size and simulation agree.
const SLAM := {"id":"slam","title":"收账员蓄力！","windup":.85,"radius":4.0,"damage":15.0,"period":4.0,"hint":"离开收账员身边的红圈"}
const NOTICE := {"id":"notice","title":"加班通知","windup":1.1,"radius":2.1,"damage":12.0,"period":4.0,"hint":"通知锁定旧落点，移动后不会追你"}

static func attack(wave: int, pattern: int) -> Dictionary:
	return NOTICE if wave==6 and pattern%2==1 else SLAM

static func name_for_wave(wave: int) -> String:
	return "关门经理" if wave==6 else "收账员"
