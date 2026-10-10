class_name ChapterMahjongTable
extends RefCounted

## Two-player, no-flower 136-tile Mahjong. Physical tile IDs never duplicate.
## Endgame setups are labelled puzzles; the remainder is an actual seeded wall.
const VERSION := 2
const Tea = preload("res://scripts/party/mahjong_teahouse_rules.gd")
const MAX_DISCARDS := 64
const STYLES := ["closed", "triplet", "sequence"]
const STYLE_NAMES := {"closed": "门清·观潮", "triplet": "刻派·换骨", "sequence": "连序·接龙"}
const PERMUTATIONS := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
var _s: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func start(seed_value: Variant, ai_enabled: Variant = true) -> Dictionary:
	if typeof(seed_value) != TYPE_INT or seed_value < 1 or seed_value > 2147483647 or typeof(ai_enabled) != TYPE_BOOL:
		return _reply(false, "invalid_start")
	_rng.seed = seed_value
	_s = {"version": VERSION, "seed": seed_value, "ai_enabled": ai_enabled, "phase": "board", "actor": 0, "revision": 1, "token": 0, "variant": 0, "mode": "endgame", "hands": [[], []], "wall": [], "discards": [[], []], "melds": [[], []], "drawn_tile": -1, "last_discard": {}, "pending_kong": {}, "discard_count": 0, "styles": ["closed", "closed"], "skill_used": [false, false], "resources_used": [{"wilds": 0, "redraws": 0}, {"wilds": 0, "redraws": 0}], "peek": [], "scenario": {}, "history": [], "result": {}}
	return _reply(true, "")

func state() -> Dictionary:
	return _s.duplicate(true)

func result() -> Dictionary:
	return _s.get("result", {}).duplicate(true)

func set_style_station(actor: Variant, id: Variant, token: Variant) -> Dictionary:
	if not _board_actor_token(actor, token) or typeof(id) != TYPE_STRING or id not in STYLES:
		return _reply(false, "invalid_style")
	_s.styles[actor] = id
	_s.token = token
	_s.revision += 1
	return _reply(true, "")

func begin_challenge(actor: Variant, token: Variant, variant: Variant = 0, endgame: Variant = true) -> Dictionary:
	if not _board_actor_token(actor, token) or typeof(variant) != TYPE_INT or variant < 0 or variant > 2 or typeof(endgame) != TYPE_BOOL:
		return _reply(false, "invalid_challenge")
	var pool: Array = []
	for id in range(136):
		pool.append(id)
	var hands: Array = [[], []]
	var prefix: Array = []
	if endgame:
		var setups := [
			[0, 1, 2, 3, 4, 5, 9, 10, 11, 18, 19, 27, 27],
			[0, 0, 0, 9, 9, 9, 18, 18, 27, 27, 27, 31, 31],
			[0, 0, 3, 3, 9, 9, 12, 12, 18, 18, 21, 21, 32]]
		var partner := [1, 2, 4, 5, 10, 11, 13, 14, 19, 20, 22, 23, 30]
		for kind in setups[variant]:
			hands[actor].append(_remove_type(pool, kind))
		for kind in partner:
			hands[1 - actor].append(_remove_type(pool, kind))
		# The triplet puzzle exposes a genuine four-of-a-kind and discard claim.
		for kind in [0 if variant == 1 else 30, 27 if variant == 1 else 28, [20, 18, 32][variant]]:
			prefix.append(_remove_type(pool, kind))
	_shuffle(pool)
	if not endgame:
		for a in range(2):
			for i in range(13):
				hands[a].append(pool.pop_front())
	for hand in hands:
		hand.sort()
	_s.actor = actor
	_s.token = token
	_s.variant = variant
	_s.mode = "endgame" if endgame else "random"
	_s.hands = hands
	_s.wall = prefix + pool
	_s.discards = [[], []]
	_s.melds = [[], []]
	_s.drawn_tile = -1
	_s.last_discard = {}
	_s.pending_kong = {}
	_s.discard_count = 0
	_s.skill_used = [false, false]
	_s.resources_used = [{"wilds": 0, "redraws": 0}, {"wilds": 0, "redraws": 0}]
	_s.peek = []
	_s.result = {}
	_s.scenario = {"title": ["顺子残局", "碰刻残局", "七对残局"][variant] if endgame else "随机双人麻将", "condition": ("预设13张起手；真实墙首一万、东、一索，其余洗牌；可暗杠，也可留三张等补形" if variant == 1 else "预设13张起手；真实墙首北、南、补形牌，其余洗牌；吃碰会改变摸牌时机") if endgame else "136张真实洗牌；无花牌；不预设赢家", "target": "任一动物合法胡牌即可共同过站；流派积分只奖励真实牌型"}
	_s.phase = "discard"
	Tea.begin(_s)
	_draw(actor, false)
	_s.revision += 1
	return _reply(true, "")

func legal_discards() -> Array:
	if _s.is_empty() or _s.phase != "discard":
		return []
	var out: Array = []
	for i in range(_s.hands[_s.actor].size()):
		out.append(i)
	return out

func discard(index: Variant, actor: Variant, revision: Variant) -> Dictionary:
	if not _operation(actor, revision, ["discard"]) or typeof(index) != TYPE_INT or index not in legal_discards():
		return _reply(false, "invalid_discard")
	var id: int = _s.hands[actor].pop_at(index)
	_s.discards[actor].append(id)
	_s.last_discard = {"tile": id, "actor": actor}
	_s.drawn_tile = -1
	_s.discard_count += 1
	_s.table_event = {"kind":"discard", "actor":actor, "tiles":[id]}
	Tea.after_discard(_s,actor,id)
	_s.actor = 1 - actor
	_s.phase = "claim"
	_s.revision += 1
	return _reply(true, "")

func choices() -> Array:
	if _s.is_empty():
		return []
	var out: Array = []
	var actor: int = _s.actor
	var hand: Array = _s.hands[actor]
	if _s.phase == "peek":
		for permutation in PERMUTATIONS:
			var order: Array = []
			var labels: Array[String] = []
			for i in permutation:
				order.append(_s.peek[i])
				labels.append(tile_name(_s.peek[i]))
			out.append({"kind": "peek_order", "tiles": order, "label": "墙顶 " + " → ".join(labels), "detail": "只重排这三张真实牌；下一次正常摸牌由当前回合规则决定"})
	elif _s.phase == "claim":
		var tile: int = _s.last_discard.tile
		var kind := tile_type(tile)
		var trial: Array = hand.duplicate()
		trial.append(tile)
		if _analysis(trial, _s.melds[actor], _s.styles[actor]).valid:
			out.append({"kind": "ron", "tiles": [tile], "label": ("抢杠胡·" if not _s.pending_kong.is_empty() else "荣和·") + tile_name(tile), "detail": "对方实际加杠的第四张完成合法胡；原碰保留" if not _s.pending_kong.is_empty() else "对方真实弃牌完成合法胡牌；共同过站"})
		if not _s.pending_kong.is_empty():
			out.append({"kind": "pass", "tiles": [], "label": "过·让对方补牌", "detail": "不抢杠，对方把真实第四张加入原碰，再从墙尾补一张"})
			return out.duplicate(true)
		var same := _ids_of_type(hand, kind)
		if same.size() >= 3 and _s.melds[actor].size() < 4 and not _s.wall.is_empty():
			out.append({"kind": "kong", "tiles": same.slice(0, 3), "label": "明杠·" + tile_name(tile), "detail": "收弃牌与三张同牌，墙尾补一张；保留四张实体"})
		if same.size() >= 2 and _s.melds[actor].size() < 4:
			out.append({"kind": "pon", "tiles": same.slice(0, 2), "label": "碰·" + tile_name(tile), "detail": "使用两张同牌收弃牌；不摸牌，随后必须打牌"})
		if kind < 27 and _s.melds[actor].size() < 4:
			for first in range(maxi(kind - 2, int(kind / 9) * 9), mini(kind, int(kind / 9) * 9 + 6) + 1):
				var needed: Array = []
				for t in range(first, first + 3):
					if t != kind:
						var ids := _ids_of_type(hand, t)
						if not ids.is_empty():
							needed.append(ids[0])
				if needed.size() == 2:
					out.append({"kind": "chi", "tiles": needed, "label": "吃·" + type_name(first) + "/" + type_name(first + 1) + "/" + type_name(first + 2), "detail": "只用同花色连续三张；不摸牌，随后必须打牌"})
		out.append({"kind": "pass", "tiles": [], "label": "过·正常摸牌", "detail": "不抢这张弃牌，按墙顶摸入一张"})
	elif _s.phase == "discard":
		if _analysis(hand, _s.melds[actor], _s.styles[actor]).valid:
			out.append({"kind": "tsumo", "tiles": [], "label": "自摸·胡牌", "detail": "真实四面子一将或门清七对；共同过站"})
		if not _s.wall.is_empty():
			for kind in range(34):
				var ids := _ids_of_type(hand, kind)
				if ids.size() == 4:
					out.append({"kind": "closed_kong", "tiles": ids, "label": "暗杠·" + type_name(kind), "detail": "四张实体放入暗杠；墙尾补一张，门清不失去"})
			for i in range(_s.melds[actor].size()):
				var meld: Dictionary = _s.melds[actor][i]
				if meld.kind != "pon":
					continue
				var extra := _ids_of_type(hand, tile_type(meld.tiles[0]))
				if not extra.is_empty():
					out.append({"kind": "added_kong", "tiles": [extra[0]], "meld_index": i, "label": "加杠·" + tile_name(extra[0]), "detail": "第四张真实牌加入原碰；对方有一次抢杠胡机会，过后墙尾补牌"})
		var skill := _skill_key(actor)
		if not skill.is_empty():
			out.append({"kind": "skill", "key": skill, "tiles": [], "label": STYLE_NAMES[_s.styles[actor]] + "（本场一次）", "detail": "窥真实墙前三张并自行排序" if skill == "wilds" else "将实际摸入牌退到墙尾，再摸下一张"})
	return out.duplicate(true)

func apply(choice: Variant, actor: Variant, revision: Variant) -> Dictionary:
	if not _operation(actor, revision, ["claim", "discard", "peek"]) or typeof(choice) != TYPE_INT:
		return _reply(false, "invalid_operation")
	var options := choices()
	if choice < 0 or choice >= options.size():
		return _reply(false, "unavailable_choice")
	var option: Dictionary = options[choice]
	_s.table_event = {"kind":option.kind, "actor":actor, "tiles":option.get("tiles",[]).duplicate()}
	match option.kind:
		"peek_order":
			for i in range(3):
				_s.wall[i] = option.tiles[i]
			_s.peek = []
			_s.phase = "discard"
		"skill":
			_s.skill_used[actor] = true
			_resource(option.key, actor)
		"tsumo":
			_finish(true, "tsumo", actor)
		"ron":
			var robbed: bool = not _s.pending_kong.is_empty()
			_s.discards[_s.last_discard.actor].erase(_s.last_discard.tile)
			_s.hands[actor].append(_s.last_discard.tile)
			_s.hands[actor].sort()
			_s.last_discard = {}
			_s.pending_kong = {}
			_finish(true, "rob_kong" if robbed else "ron", actor)
		"pass":
			if not _s.pending_kong.is_empty():
				var pending: Dictionary = _s.pending_kong
				_s.discards[pending.actor].erase(pending.tile)
				_s.melds[pending.actor][pending.meld_index].tiles.append(pending.tile)
				_s.melds[pending.actor][pending.meld_index].tiles.sort()
				_s.melds[pending.actor][pending.meld_index].kind = "kong"
				Tea.after_meld(_s,pending.actor,"added_kong")
				_s.pending_kong = {}
				_s.last_discard = {}
				_s.actor = pending.actor
				_s.phase = "discard"
				_draw(pending.actor, true)
			elif _s.discard_count >= MAX_DISCARDS:
				_s.last_discard = {}
				_finish(false, "discard_limit")
			else:
				_s.last_discard = {}
				_s.phase = "discard"
				_draw(actor, false)
		"chi", "pon", "kong":
			var tiles: Array = option.tiles.duplicate()
			for id in option.tiles:
				_s.hands[actor].erase(id)
			_s.discards[_s.last_discard.actor].erase(_s.last_discard.tile)
			tiles.append(_s.last_discard.tile)
			tiles.sort()
			_s.melds[actor].append({"kind": option.kind, "tiles": tiles, "from": _s.last_discard.actor, "concealed": false})
			Tea.after_meld(_s,actor,option.kind)
			_s.last_discard = {}
			_s.phase = "discard"
			_s.drawn_tile = -1
			if option.kind == "kong":
				_draw(actor, true)
		"closed_kong":
			for id in option.tiles:
				_s.hands[actor].erase(id)
			_s.melds[actor].append({"kind": "kong", "tiles": option.tiles.duplicate(), "from": actor, "concealed": true})
			Tea.after_meld(_s,actor,"closed_kong")
			_s.drawn_tile = -1
			_draw(actor, true)
		"added_kong":
			var id: int = option.tiles[0]
			_s.hands[actor].erase(id)
			_s.discards[actor].append(id)
			_s.last_discard = {"tile": id, "actor": actor}
			_s.pending_kong = {"actor": actor, "tile": id, "meld_index": option.meld_index}
			_s.drawn_tile = -1
			_s.actor = 1 - actor
			_s.phase = "claim"
	_s.revision += 1
	return _reply(true, "")

func choose_tea(recipe: Variant, actor: Variant, revision: Variant) -> Dictionary:
	if not _operation(actor,revision,["discard"]) or typeof(recipe)!=TYPE_STRING or not Tea.choose(_s,recipe):return _reply(false,"tea_locked")
	_s.revision+=1
	_s.table_event={"kind":"recipe","actor":actor,"tiles":[]}
	return _reply(true,"")

func exchange_tea(index: Variant, slot: Variant, actor: Variant, revision: Variant) -> Dictionary:
	if not _operation(actor,revision,["discard"]) or typeof(index)!=TYPE_INT or typeof(slot)!=TYPE_INT or not Tea.swap(_s,index,slot,actor):return _reply(false,"tea_exchange_unavailable")
	_s.revision+=1
	return _reply(true,"")

func ai_exchange() -> Array:
	if _s.is_empty() or _s.phase!="discard" or not _s.has("tea"):return []
	var actor:int=_s.actor;var hand:Array=_s.hands[actor]
	var best:Array=[];var gain:float=1.4
	var before:float=_shape_value(hand,_s.styles[actor])
	for i in hand.size():
		for slot in _s.tea.tray.size():
			if not Tea.can_swap(_s,i,slot,actor):continue
			var trial:Array=hand.duplicate();trial[i]=_s.tea.tray[slot]
			var delta:float=_shape_value(trial,_s.styles[actor])-before
			if _analysis(trial,_s.melds[actor],_s.styles[actor]).valid:delta+=100
			if delta>gain:gain=delta;best=[i,slot]
	return best

func can_resource(key: Variant, actor: Variant, revision: Variant = -1) -> bool:
	if not _operation(actor, revision, ["discard"]) or typeof(key) != TYPE_STRING:
		return false
	if key == "wilds":
		return _s.wall.size() >= 3
	if key == "redraws":
		return not _s.wall.is_empty() and _s.drawn_tile in _s.hands[actor]
	return false

func apply_resource(key: Variant, actor: Variant, revision: Variant = -1) -> Dictionary:
	if not can_resource(key, actor, revision):
		return _reply(false, "resource_unavailable")
	_s.resources_used[actor][key] += 1
	_resource(key, actor)
	_s.revision += 1
	return _reply(true, "")

func retreat(actor: Variant, revision: Variant) -> Dictionary:
	if not _operation(actor, revision, ["discard", "claim", "peek"]):
		return _reply(false, "invalid_retreat")
	_finish(false, "retreated")
	_s.revision += 1
	return _reply(true, "")

func ai_discard() -> int:
	if _s.is_empty() or _s.phase != "discard":
		return -1
	var hand: Array = _s.hands[_s.actor]
	var best := -1
	var score := -INF
	for i in range(hand.size()):
		var trial: Array = hand.duplicate()
		trial.remove_at(i)
		var value := _shape_value(trial, _s.styles[_s.actor])
		if value > score:
			score = value
			best = i
	return best

func ai_choice() -> int:
	var options := choices()
	if options.is_empty():
		return -1
	for i in range(options.size()):
		if options[i].kind in ["ron", "tsumo"]:
			return i
	if _s.phase == "peek":
		# Current actor already drew: next normal draw is the other animal's.
		# Prefer our useful tile second; information is exactly the exposed peek.
		var best := 0
		var value := -INF
		for i in range(options.size()):
			var trial: Array = _s.hands[_s.actor].duplicate()
			trial.append(options[i].tiles[1])
			var score := _shape_value(trial, _s.styles[_s.actor])
			if score > value:
				value = score
				best = i
		return best
	var pass_index := -1
	for i in range(options.size()):
		if options[i].kind == "pass":
			pass_index = i
		elif options[i].kind in ["kong", "closed_kong", "added_kong"]:
			return i
	if _s.phase == "claim":
		for i in range(options.size()):
			var option: Dictionary = options[i]
			if option.kind == "pon" and (_s.styles[_s.actor] == "triplet" or _s.get("tea",{}).get("recipe","")=="ember"):
				return i
			if option.kind == "chi" and (_s.styles[_s.actor] == "sequence" or _s.get("tea",{}).get("recipe","")=="vine"):
				return i
		return pass_index
	# Skill is a real option, not an unconditional action before every discard.
	for i in range(options.size()):
		if options[i].kind == "skill" and options[i].key == "wilds":
			return i
		if options[i].kind == "skill" and options[i].key == "redraws":
			var before: Array = _s.hands[_s.actor]
			var without_draw: Array = before.duplicate()
			without_draw.erase(_s.drawn_tile)
			if _shape_value(before, _s.styles[_s.actor]) - _shape_value(without_draw, _s.styles[_s.actor]) < 1.0:
				return i
	return -1

func _resource(key: String, actor: int) -> void:
	if key == "wilds":
		_s.peek = _s.wall.slice(0, 3)
		_s.phase = "peek"
	else:
		var returned: int = _s.drawn_tile
		_s.hands[actor].erase(returned)
		_s.wall.append(returned)
		_draw(actor, false)

func _skill_key(actor: int) -> String:
	if _s.skill_used[actor]:
		return ""
	var style: String = _s.styles[actor]
	var has_chi := false
	var has_triplet := false
	var closed := true
	for meld in _s.melds[actor]:
		has_chi = has_chi or meld.kind == "chi"
		has_triplet = has_triplet or meld.kind in ["pon", "kong"]
		closed = closed and meld.concealed
	if ((style == "closed" and closed) or (style == "sequence" and has_chi)) and _s.wall.size() >= 3:
		return "wilds"
	if style == "triplet" and has_triplet and not _s.wall.is_empty() and _s.drawn_tile in _s.hands[actor]:
		return "redraws"
	return ""

func _draw(actor: int, back: bool) -> void:
	if _s.wall.is_empty():
		_finish(false, "wall_empty")
		return
	var id: int = _s.wall.pop_back() if back else _s.wall.pop_front()
	_s.hands[actor].append(id)
	_s.hands[actor].sort()
	_s.drawn_tile = id

func _finish(success: bool, reason: String, winner: int = -1) -> void:
	var qualified := false
	var style := ""
	var points := 0
	var winning_hand: Array = []
	var winning_melds: Array = []
	if success:
		style = _s.styles[winner]
		qualified = _analysis(_s.hands[winner], _s.melds[winner], style).qualified
		points = 5 + (2 if reason == "tsumo" else 0) + (3 if qualified else 0)
		winning_hand = _s.hands[winner].duplicate()
		winning_melds = _s.melds[winner].duplicate(true)
	_s.table_event={"kind":"win" if success else "finish", "actor":maxi(winner,0), "tiles":winning_hand.duplicate()}
	_s.peek = []
	_s.pending_kong = {}
	_s.result = {"token": _s.token, "success": success, "scores": [100, 100] if success else [0, 0], "reason": reason, "winner": winner, "win_kind": reason if success else "", "points": points, "style": style, "style_qualified": qualified, "discard_count": _s.discard_count, "mode": _s.mode, "variant": _s.variant, "winning_hand": winning_hand, "winning_melds": winning_melds}
	_s.history.append({"token": _s.token, "winner": winner, "success": success})
	while _s.history.size() > 32:
		_s.history.pop_front()
	_s.phase = "finished"

func _operation(actor: Variant, revision: Variant, phases: Array) -> bool:
	return not _s.is_empty() and typeof(actor) == TYPE_INT and actor in [0, 1] and actor == _s.actor and typeof(revision) == TYPE_INT and revision == _s.revision and _s.phase in phases

func _board_actor_token(actor: Variant, token: Variant) -> bool:
	return not _s.is_empty() and _s.phase in ["board", "finished"] and typeof(actor) == TYPE_INT and actor in [0, 1] and typeof(token) == TYPE_INT and token > _s.token and token <= 2147483647

func _reply(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason, "revision": int(_s.get("revision", 0)), "phase": str(_s.get("phase", "unstarted")), "actor": int(_s.get("actor", 0)), "result": result()}

func _shuffle(pool: Array) -> void:
	for i in range(pool.size() - 1, 0, -1):
		var j := int(_rng.randi_range(0, i))
		var temp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = temp

static func _remove_type(pool: Array, kind: int) -> int:
	for i in range(pool.size()):
		if tile_type(pool[i]) == kind:
			return pool.pop_at(i)
	return -1

static func tile_type(id: int) -> int:
	return int(id / 4) if id >= 0 and id < 136 else -1

static func tile_name(id: int) -> String:
	return type_name(tile_type(id))

static func type_name(kind: int) -> String:
	if kind < 0 or kind >= 34:
		return "非法牌"
	if kind >= 27:
		return ["东", "南", "西", "北", "中", "发", "白"][kind - 27]
	return ["一", "二", "三", "四", "五", "六", "七", "八", "九"][kind % 9] + ["万", "筒", "索"][int(kind / 9)]

static func _ids_of_type(hand: Array, kind: int) -> Array:
	var out: Array = []
	for id in hand:
		if tile_type(id) == kind:
			out.append(id)
	return out

## Public structural hand validator; does not claim authentication of a live game.
static func winning_hand(tile_ids: Variant, melds: Variant = [], style: Variant = "closed") -> Dictionary:
	if typeof(tile_ids) != TYPE_ARRAY or typeof(melds) != TYPE_ARRAY or typeof(style) != TYPE_STRING or style not in STYLES or melds.size() > 4:
		return {"valid": false, "qualified": false, "seven_pairs": false}
	var seen: Dictionary = {}
	for id in tile_ids:
		if typeof(id) != TYPE_INT or tile_type(id) == -1 or seen.has(id):
			return {"valid": false, "qualified": false, "seven_pairs": false}
		seen[id] = true
	for meld in melds:
		if typeof(meld) != TYPE_DICTIONARY or meld.size() != 4 or not meld.has_all(["kind", "tiles", "from", "concealed"]) or typeof(meld.kind) != TYPE_STRING or meld.kind not in ["chi", "pon", "kong"] or typeof(meld.tiles) != TYPE_ARRAY or typeof(meld.from) != TYPE_INT or meld.from not in [0, 1] or typeof(meld.concealed) != TYPE_BOOL or meld.tiles.size() != (4 if meld.kind == "kong" else 3) or (meld.concealed and meld.kind != "kong"):
			return {"valid": false, "qualified": false, "seven_pairs": false}
		var types: Array = []
		for id in meld.tiles:
			if typeof(id) != TYPE_INT or tile_type(id) == -1 or seen.has(id):
				return {"valid": false, "qualified": false, "seven_pairs": false}
			seen[id] = true
			types.append(tile_type(id))
		types.sort()
		if meld.kind == "chi":
			if types[0] >= 27 or int(types[0] / 9) != int(types[2] / 9) or types[1] != types[0] + 1 or types[2] != types[1] + 1:
				return {"valid": false, "qualified": false, "seven_pairs": false}
		elif types[0] != types[-1]:
			return {"valid": false, "qualified": false, "seven_pairs": false}
	return _analysis(tile_ids, melds, style)

static func _analysis(hand: Array, melds: Array, style: String) -> Dictionary:
	var out := {"valid": false, "qualified": false, "seven_pairs": false}
	if hand.size() != 14 - 3 * melds.size():
		return out
	var counts: Array = []
	counts.resize(34)
	counts.fill(0)
	for id in hand:
		var kind := tile_type(id)
		if kind < 0:
			return out
		counts[kind] += 1
	var closed := true
	var open_triplets := 0
	var open_sequences := 0
	for meld in melds:
		closed = closed and meld.concealed
		open_triplets += 1 if meld.kind in ["pon", "kong"] else 0
		open_sequences += 1 if meld.kind == "chi" else 0
	if melds.is_empty():
		var pairs := 0
		var even := true
		for count in counts:
			even = even and int(count) % 2 == 0
			pairs += int(count / 2)
		if even and pairs == 7:
			return {"valid": true, "qualified": style == "closed", "seven_pairs": true}
	for pair in range(34):
		if counts[pair] < 2:
			continue
		counts[pair] -= 2
		var formations := _split_melds(counts, 4 - melds.size())
		counts[pair] += 2
		for formation in formations:
			out.valid = true
			out.qualified = out.qualified or (style == "closed" and closed) or (style == "triplet" and int(formation[0]) + open_triplets >= 3) or (style == "sequence" and int(formation[1]) + open_sequences >= 3)
	return out

static func _split_melds(counts: Array, needed: int) -> Array:
	var first := -1
	for i in range(34):
		if counts[i] > 0:
			first = i
			break
	if first == -1:
		return [[0, 0]] if needed == 0 else []
	if needed <= 0:
		return []
	var out: Array = []
	if counts[first] >= 3:
		counts[first] -= 3
		for split in _split_melds(counts, needed - 1):
			out.append([int(split[0]) + 1, split[1]])
		counts[first] += 3
	if first < 27 and first % 9 <= 6 and counts[first + 1] > 0 and counts[first + 2] > 0:
		for i in range(first, first + 3):
			counts[i] -= 1
		for split in _split_melds(counts, needed - 1):
			out.append([split[0], int(split[1]) + 1])
		for i in range(first, first + 3):
			counts[i] += 1
	return out

static func _shape_value(hand: Array, style: String) -> float:
	var counts: Array = []
	counts.resize(34)
	counts.fill(0)
	for id in hand:
		counts[tile_type(id)] += 1
	var value := 0.0
	for kind in range(34):
		if counts[kind] >= 3:
			value += 9.0 if style == "triplet" else 6.0
		elif counts[kind] == 2:
			value += 4.0
		if kind < 27 and counts[kind] > 0:
			if kind % 9 <= 7 and counts[kind + 1] > 0:
				value += 2.0 if style == "sequence" else 1.4
			if kind % 9 <= 6 and counts[kind + 2] > 0:
				value += 1.0
			if kind % 9 <= 6 and counts[kind + 1] > 0 and counts[kind + 2] > 0:
				value += 5.0 if style == "sequence" else 3.0
	return value
