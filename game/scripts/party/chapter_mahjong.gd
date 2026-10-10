class_name ChapterMahjong
extends RefCounted

## Public-information formation puzzle. No cash, dice, timers or combat RNG here.
const VERSION := 1
const MAX_CASTS := 3
const MAX_HISTORY := 32
const BASE_DECK := [1, 2, 3, 4, 4, 4, 7, 7, 8]
const RELICS := ["bridge", "echo", "thrift"]
const RELIC_NAMES := {"bridge": "搭桥：将眼同时开启风闸", "echo": "回声：将眼后的顺子同时破甲", "thrift": "留眼：首次将眼不消耗实体牌"}
const PATTERN_NAMES := {"sequence": "顺子·开闸", "triplet": "刻子·破甲", "pair": "将眼·护阵"}
var _s: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func start(seed_value: Variant, ai_enabled: Variant = true) -> Dictionary:
	if typeof(seed_value) != TYPE_INT or seed_value < 1 or seed_value > 2147483647 or typeof(ai_enabled) != TYPE_BOOL:
		return _reply(false, "invalid_start")
	_rng.seed = seed_value
	var deck: Array = BASE_DECK.duplicate()
	var suit_shift := int(_rng.randi_range(0, 2)) * 3
	for i in range(deck.size()):
		deck[i] = (int(deck[i]) - 1 + suit_shift) % 9 + 1
	_s = {"version": VERSION, "seed": seed_value, "ai_enabled": ai_enabled, "phase": "board", "actor": 0, "revision": 1, "deck": deck, "hand": [], "relics": [], "token": 0, "variant": 0, "casts": 0, "integrity": 3, "goals": {"gate": true, "armor": true, "trap": true}, "last_pattern": "", "wild": 0, "thrift_used": false, "offer_tiles": [], "pending_tile": 0, "page": 0, "history": [], "result": {}, "tea": {"token": 0, "accepted": false, "qualified": false, "protected_slot": -1, "patterns": []}}
	return _reply(true, "")

func state() -> Dictionary:
	return _s.duplicate(true)

func result() -> Dictionary:
	return _s.get("result", {}).duplicate(true)

func enter_station(kind: Variant, actor: Variant, token: Variant) -> Dictionary:
	if not _valid_board(actor, token) or typeof(kind) != TYPE_STRING or kind not in ["tiles", "reforge", "relic"]:
		return _reply(false, "invalid_station")
	_s.actor = actor
	_s.token = token
	_s.phase = "relic" if kind == "relic" else "tile_offer"
	_s.offer_tiles = []
	if kind != "relic":
		# Three distinct actual tile offers; seeded only once on station entry.
		var first := int(_rng.randi_range(1, 9))
		_s.offer_tiles = [first, (first + 2) % 9 + 1, (first + 5) % 9 + 1]
	_s.revision += 1
	return _reply(true, "")

func begin_challenge(actor: Variant, token: Variant, variant: Variant = 0, tea_enabled: Variant = false) -> Dictionary:
	if not _valid_board(actor, token) or typeof(variant) != TYPE_INT or variant < 0 or variant > 2 or typeof(tea_enabled) != TYPE_BOOL:
		return _reply(false, "invalid_challenge")
	_s.actor = actor
	_s.token = token
	_s.variant = variant
	_s.phase = "challenge"
	_s.hand = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	_s.casts = 0
	_s.integrity = 3
	_s.goals = {"gate": true, "armor": true, "trap": true}
	_s.last_pattern = ""
	_s.wild = 0
	_s.thrift_used = false
	_s.result = {}
	_s.tea = {"token": token, "accepted": tea_enabled, "qualified": false, "protected_slot": [0, 3, 6][variant] if tea_enabled else -1, "patterns": []}
	_s.revision += 1
	return _reply(true, "")

func choices() -> Array:
	if _s.is_empty():
		return []
	var out: Array = []
	match _s.phase:
		"tile_offer":
			for tile in _s.offer_tiles:
				out.append({"kind": "offer", "tile": tile, "label": "采牌·" + tile_name(tile), "detail": "下一步选择替换哪张牌；牌谱永久保留"})
		"replace":
			var offset := int(_s.page) * 3
			for index in range(offset, offset + 3):
				var trial: Array = _s.deck.duplicate()
				trial[index] = _s.pending_tile
				out.append({"kind": "replace", "index": index, "tile": _s.pending_tile, "label": "替换第%d张 %s → %s" % [index + 1, tile_name(_s.deck[index]), tile_name(_s.pending_tile)], "detail": _combination_delta(_s.deck, trial) + "；茶约护送位01/04/07", "before": combination_counts(_s.deck), "after": combination_counts(trial)})
			out.append({"kind": "page", "label": "查看另外三张", "detail": "共9张，可换页选择任意牌，不自动弃牌"})
		"relic":
			for id in RELICS:
				var old_name: String = str(RELIC_NAMES[_s.relics[0]]) if not _s.relics.is_empty() else "空槽"
				out.append({"kind": "relic", "id": id, "label": RELIC_NAMES[id], "detail": "仅一个规则槽；替换" + old_name.split("：")[0] + ("（当前规则）" if id in _s.relics else "；原规则失去")})
		"challenge":
			for pattern in ["sequence", "triplet", "pair"]:
				var candidates := _matches(pattern)
				if candidates.is_empty():
					continue
				var candidate: Dictionary = _best_match(candidates)
				var effect := _effect(pattern)
				var text: Array[String] = []
				for index in candidate.indices:
					text.append(tile_name(_s.deck[index]))
				if candidate.wild:
					text.append("万能")
				var tea_hint := ""
				if _s.tea.accepted:
					var kept: bool = _s.tea.protected_slot in _s.hand and (_s.tea.protected_slot not in candidate.indices or (pattern == "pair" and "thrift" in _s.relics and not _s.thrift_used))
					tea_hint = "；护送%02d%s" % [int(_s.tea.protected_slot) + 1, "保留" if kept else "将耗，可重抽找回"]
				out.append({"kind": "cast", "pattern": pattern, "indices": candidate.indices.duplicate(), "wild": candidate.wild, "label": PATTERN_NAMES[pattern] + " [" + "/".join(text) + "]", "detail": _effect_text(effect) + tea_hint, "effect": effect})
			out.append({"kind": "retreat", "label": "撤阵·保留牌谱", "detail": "本挑战失败；不发胜利收据，下次仍可重新组阵"})
	return out.duplicate(true)

func apply(choice: Variant, actor: Variant, expected_revision: Variant = -1) -> Dictionary:
	if not _valid_actor(actor) or actor != _s.get("actor", -1) or typeof(choice) != TYPE_INT or typeof(expected_revision) != TYPE_INT or (expected_revision != -1 and expected_revision != _s.revision):
		return _reply(false, "invalid_operation")
	var available := choices()
	if choice < 0 or choice >= available.size():
		return _reply(false, "unavailable_choice")
	var option: Dictionary = available[choice]
	match option.kind:
		"offer":
			_s.pending_tile = option.tile
			_s.page = 0
			_s.phase = "replace"
		"page":
			_s.page = (int(_s.page) + 1) % 3
		"replace":
			_s.deck[option.index] = option.tile
			_finish_station("tile", {"index": option.index, "tile": option.tile})
		"relic":
			_s.relics = [option.id]
			_finish_station("relic", {"id": option.id})
		"cast":
			_cast(option)
		"retreat":
			_finish(false, "retreated")
		_:
			return _reply(false, "invalid_operation")
	_s.revision += 1
	return _reply(true, "")

func can_resource(key: Variant, actor: Variant, expected_revision: Variant = -1) -> bool:
	if _s.is_empty() or _s.phase != "challenge" or not _valid_actor(actor) or actor != _s.actor or typeof(expected_revision) != TYPE_INT or (expected_revision != -1 and expected_revision != _s.revision) or typeof(key) != TYPE_STRING:
		return false
	if key == "wilds":
		return _s.wild == 0
	if key == "redraws":
		return _s.hand.size() < 9
	return false

func apply_resource(key: Variant, actor: Variant, expected_revision: Variant = -1) -> Dictionary:
	if not can_resource(key, actor, expected_revision):
		return _reply(false, "resource_unavailable")
	if key == "wilds":
		_s.wild = 1
	else:
		var added := 0
		for i in range(9):
			if i not in _s.hand:
				_s.hand.append(i)
				added += 1
				if added == 2:
					break
		_s.hand.sort()
	_s.revision += 1
	return _reply(true, "")

func ai_choice() -> int:
	var available := choices()
	if available.is_empty():
		return -1
	var best := 0
	var score := -INF
	for i in range(available.size()):
		var option: Dictionary = available[i]
		var value := -100.0
		match option.kind:
			"cast":
				value = float(option.effect.clears.size()) * 10.0 - float(option.effect.retaliation) * 4.0 - (2.0 if option.wild else 0.0)
			"offer":
				# Keep cards completing genuine pairs, triples and same-suit runs.
				value = _deck_value(_s.deck, option.tile)
			"replace":
				var trial: Array = _s.deck.duplicate()
				trial[option.index] = option.tile
				value = _deck_value(trial, 0)
			"page":
				# Evaluate all nine replacements; page toward the best, never loop.
				var global_best := -INF
				var best_index := 0
				for index in range(9):
					var trial: Array = _s.deck.duplicate()
					trial[index] = _s.pending_tile
					var trial_score := _deck_value(trial, 0)
					if trial_score > global_best:
						global_best = trial_score
						best_index = index
				value = global_best + 0.5 if int(best_index / 3) != _s.page else -100.0
			"relic":
				var conserve_pair: bool = _s.tea.accepted and not _s.tea.qualified and _s.tea.protected_slot == 6
				value = 20.0 if conserve_pair and option.id == "thrift" else (15.0 if option.id == "bridge" else (12.0 if option.id == "echo" else 8.0))
		if value > score:
			score = value
			best = i
	return best

func _matches(pattern: String) -> Array:
	var full: Array = []
	var wildcard: Array = []
	var hand: Array = _s.hand
	var length := 2 if pattern == "pair" else 3
	for a in range(hand.size()):
		for b in range(a + 1, hand.size()):
			if length == 2:
				if _s.deck[hand[a]] == _s.deck[hand[b]]:
					full.append({"indices": [hand[a], hand[b]], "wild": false})
			else:
				for c in range(b + 1, hand.size()):
					var values: Array = [_s.deck[hand[a]], _s.deck[hand[b]], _s.deck[hand[c]]]
					values.sort()
					if (pattern == "triplet" and values[0] == values[2]) or (pattern == "sequence" and int((int(values[0]) - 1) / 3) == int((int(values[2]) - 1) / 3) and values[1] == values[0] + 1 and values[2] == values[1] + 1):
						full.append({"indices": [hand[a], hand[b], hand[c]], "wild": false})
			if _s.wild == 1 and length == 3:
				var x: int = _s.deck[hand[a]]
				var y: int = _s.deck[hand[b]]
				if (pattern == "triplet" and x == y) or (pattern == "sequence" and x != y and int((x - 1) / 3) == int((y - 1) / 3)):
					wildcard.append({"indices": [hand[a], hand[b]], "wild": true})
	if _s.wild == 1 and length == 2:
		for index in hand:
			wildcard.append({"indices": [index], "wild": true})
	if _s.tea.accepted:
		# An intact meld can still be a bad tea delivery: let a wildcard spare its protected tile.
		return full + wildcard
	return full if not full.is_empty() else wildcard

func _best_match(candidates: Array) -> Dictionary:
	# Preserve distinct future combinations rather than blindly taking index zero.
	var best: Dictionary = candidates[0]
	var best_score := -INF
	for candidate in candidates:
		var remaining: Array = []
		for index in _s.hand:
			if index not in candidate.indices:
				remaining.append(_s.deck[index])
		var score := _deck_value(remaining, 0)
		if candidate.wild:
			score -= 2.0
		if _s.tea.accepted and _s.tea.protected_slot in _s.hand and _s.tea.protected_slot not in candidate.indices:
			score += 12.0
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _effect(pattern: String) -> Dictionary:
	var clears: Array = []
	var blocked := false
	var gates: Dictionary = _s.goals
	if pattern == "pair":
		if gates.trap:
			clears.append("trap")
		if "bridge" in _s.relics and gates.gate:
			clears.append("gate")
	elif pattern == "sequence":
		blocked = (int(_s.variant) == 1 and gates.armor) or (int(_s.variant) == 2 and gates.trap)
		if not blocked and gates.gate:
			clears.append("gate")
		if not blocked and "echo" in _s.relics and _s.last_pattern == "pair" and gates.armor:
			clears.append("armor")
	else:
		blocked = (int(_s.variant) == 0 and gates.gate) or (int(_s.variant) == 2 and gates.trap)
		if not blocked and gates.armor:
			clears.append("armor")
	var retaliation := 1 if gates.trap and "trap" not in clears else 0
	return {"clears": clears, "blocked": blocked, "retaliation": retaliation}

func _cast(option: Dictionary) -> void:
	var pattern: String = option.pattern
	var preserve: bool = pattern == "pair" and "thrift" in _s.relics and not _s.thrift_used
	if preserve:
		_s.thrift_used = true
	else:
		for index in option.indices:
			_s.hand.erase(index)
	if option.wild:
		_s.wild = 0
	for goal in option.effect.clears:
		_s.goals[goal] = false
	_s.integrity -= int(option.effect.retaliation)
	_s.casts += 1
	_s.last_pattern = pattern
	if pattern not in _s.tea.patterns:
		_s.tea.patterns.append(pattern)
	_s.actor = 1 - int(_s.actor)
	if not _s.goals.gate and not _s.goals.armor and not _s.goals.trap:
		_finish(true, "cleared")
	elif _s.integrity <= 0 or _s.casts >= MAX_CASTS:
		_finish(false, "integrity_lost" if _s.integrity <= 0 else "casts_exhausted")

func _finish(success: bool, reason: String) -> void:
	var cleared: Array = []
	for id in ["gate", "armor", "trap"]:
		if not _s.goals[id]:
			cleared.append(id)
	_s.tea.qualified = success and _s.tea.accepted and _s.tea.patterns.size() == 3 and _s.tea.protected_slot in _s.hand
	_s.result = {"token": _s.token, "success": success, "scores": [100, 100] if success else [0, 0], "cleared": cleared, "casts": _s.casts, "integrity": _s.integrity, "reason": reason, "tea": _s.tea.duplicate(true)}
	_s.history.append({"token": _s.token, "kind": "challenge", "success": success})
	_trim_history()
	_s.phase = "board"
	_s.hand = []
	_s.wild = 0

func _finish_station(kind: String, facts: Dictionary) -> void:
	_s.history.append({"token": _s.token, "kind": kind, "facts": facts})
	_trim_history()
	_s.phase = "board"
	_s.offer_tiles = []
	_s.pending_tile = 0

func _trim_history() -> void:
	while _s.history.size() > MAX_HISTORY:
		_s.history.pop_front()

func _valid_actor(actor: Variant) -> bool:
	return typeof(actor) == TYPE_INT and actor >= 0 and actor <= 1

func _valid_board(actor: Variant, token: Variant) -> bool:
	if _s.is_empty() or _s.phase != "board" or not _valid_actor(actor) or typeof(token) != TYPE_INT or token < 1 or token > 2147483647:
		return false
	# Tokens are monotonic activity serials, preventing reuse even after history cap.
	return token > int(_s.token)

func _reply(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason, "revision": int(_s.get("revision", 0)), "phase": str(_s.get("phase", "unstarted")), "actor": int(_s.get("actor", 0)), "result": result()}

func _effect_text(effect: Dictionary) -> String:
	var labels := {"gate": "风闸", "armor": "盾甲", "trap": "陷阱"}
	var names: Array[String] = []
	for id in effect.clears:
		names.append(labels[id])
	var action := "破解" + "/".join(names) if not names.is_empty() else "无目标收益"
	return action + ("；被机关阻挡" if effect.blocked else "") + ("；陷阱反击扣1护阵" if effect.retaliation else "；无反击")

static func tile_name(value: int) -> String:
	if value < 1 or value > 9:
		return "非法牌"
	return ["一", "二", "三"][(value - 1) % 3] + ["竹", "饼", "万"][int((value - 1) / 3)]

static func _deck_value(deck: Array, extra: int) -> float:
	var values: Array = deck.duplicate()
	if extra > 0:
		values.append(extra)
	var score := 0.0
	for tile in range(1, 10):
		var count := values.count(tile)
		if count >= 2:
			score += 2.0
		if count >= 3:
			score += 4.0
	for suit in range(3):
		if suit * 3 + 1 in values and suit * 3 + 2 in values and suit * 3 + 3 in values:
			score += 5.0
	return score

static func combination_counts(deck: Array) -> Dictionary:
	if deck.size() > 9:
		return {}
	for tile in deck:
		if typeof(tile) != TYPE_INT or tile < 1 or tile > 9:
			return {}
	var counts := {"sequence": 0, "triplet": 0, "pair": 0}
	for tile in range(1, 10):
		if deck.count(tile) >= 2:
			counts.pair += 1
		if deck.count(tile) >= 3:
			counts.triplet += 1
	for suit in range(3):
		if suit * 3 + 1 in deck and suit * 3 + 2 in deck and suit * 3 + 3 in deck:
			counts.sequence += 1
	return counts

static func _combination_delta(before: Array, after: Array) -> String:
	var a := combination_counts(before)
	var b := combination_counts(after)
	return "顺%d→%d / 刻%d→%d / 眼%d→%d" % [a.sequence, b.sequence, a.triplet, b.triplet, a.pair, b.pair]
