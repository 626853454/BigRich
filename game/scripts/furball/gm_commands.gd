class_name FurballGMCommands
extends RefCounted

# A fixed command vocabulary. This router never evaluates code or accesses files.
signal command_recorded(record: Dictionary)
const HISTORY_LIMIT := 32
const MAX_COMMAND_LENGTH := 160
const HELP := "F10 开发控制台；玩家编号 1/2。heal 玩家 [生命]；xp 数量；build 玩家 core|升级ID [次数]；pot 玩家 数量(不超过锅能上限)；charge 玩家 数量(0..2.5)；bait 玩家 数量(1..3)；spawn 类型(0..4) 数量 [x z]；clear all|enemies|shots|pickups|baits；invuln 玩家 秒(最多5)；board help。所有修改使本局标记为GM调试局。"
var model: FurCombatModel
var enabled := false
var mode_provider: Callable
var board_handler: Callable
var history: Array[Dictionary] = []

static func development_requested() -> bool:
	return "--furball-dev" in OS.get_cmdline_user_args() or ProjectSettings.get_setting("furball/development/gm_enabled", false) == true

func configure(target: FurCombatModel, authority_mode: Callable, development_enabled: bool, board_command: Callable = Callable()) -> void:
	model = target; mode_provider = authority_mode; enabled = development_enabled; board_handler = board_command

func execute(command: String) -> Dictionary:
	var result := _execute(command)
	var record := {"command": command.left(MAX_COMMAND_LENGTH), "timestamp": Time.get_datetime_string_from_system(), "monotonic_msec": Time.get_ticks_msec(), "seed": model.seed_value if model != null else 0, "ok": result.get("ok", false), "intervention": result.get("intervention", false), "debug_run": result.get("intervention", false) or (model != null and model.get("debug_run") == true), "message": result.get("message", "")}
	if history.size() >= HISTORY_LIMIT: history.pop_front()
	history.append(record)
	command_recorded.emit(record.duplicate(true))
	print("FURBALL_GM ", JSON.stringify(record))
	return result

func _execute(command: String) -> Dictionary:
	if not enabled: return _error("GM未启用：使用显式开发启动开关。")
	if not mode_provider.is_valid() or str(mode_provider.call()) not in ["solo", "local", "host"]: return _error("仅房主、单人或本地合作权威可执行GM。")
	if model == null: return _error("未绑定游戏模型。")
	if command.length() > MAX_COMMAND_LENGTH or "\n" in command or "\r" in command: return _error("命令过长或包含换行。")
	var parts := command.strip_edges().split(" ", false)
	if parts.is_empty(): return _error("请输入help查看命令。")
	var verb := parts[0].to_lower()
	if verb == "help":
		return _success(HELP, false) if parts.size() == 1 else _error("help不接受参数。")
	if verb == "board":
		if not board_handler.is_valid(): return _error("棋盘GM接口尚未绑定。")
		var response: Variant = board_handler.call(parts.slice(1))
		if response is not Dictionary or not response.has("ok"): return _error("棋盘接口返回不合法。")
		return response
	if model.phase != "battle" or model.players.is_empty(): return _error("战斗GM仅在已开始的战斗中使用。")
	match verb:
		"heal": return _heal(parts)
		"xp": return _xp(parts)
		"build": return _build(parts)
		"spawn": return _spawn(parts)
		"clear": return _clear(parts)
		"invuln": return _invuln(parts)
		"pot", "charge": return _prepare_resource(parts, verb)
		"bait": return _prepare_baits(parts)
	return _error("未知命令；输入help。")

func _heal(parts: PackedStringArray) -> Dictionary:
	if parts.size() not in [2, 3]: return _error("用法：heal 玩家(1/2) [生命(1..1000)]")
	var index := _player(parts[1])
	if index < 0: return _error("玩家编号无效。")
	var amount := 1000.0 if parts.size() == 2 else _number(parts[2], 1.0, 1000.0)
	if not is_finite(amount): return _error("生命必须为1..1000内的有限数。")
	var p: Dictionary = model.players[index]
	if p.down: return _error("倒地角色不能通过heal复活。")
	p.hp = minf(p.build.health, p.hp + amount)
	return _success("玩家%d生命 %.1f / %.1f" % [index + 1, p.hp, p.build.health])

func _xp(parts: PackedStringArray) -> Dictionary:
	if parts.size() != 2: return _error("用法：xp 数量(1..10000)")
	var amount := _integer(parts[1], 1, 10000)
	if amount < 0 or model.experience > 1000000 - amount: return _error("经验参数非法或超出调试预算。")
	model.experience += amount
	return _success("经验增加%d；下一正常战斗tick结算升级。" % amount)

func _build(parts: PackedStringArray) -> Dictionary:
	if parts.size() not in [3, 4]: return _error("用法：build 玩家 core|升级ID [次数(1..8)]")
	var index := _player(parts[1])
	if index < 0: return _error("玩家编号无效。")
	var count := 1 if parts.size() == 3 else _integer(parts[3], 1, 8)
	if count < 0: return _error("升级次数必须为1..8的整数。")
	var original: Dictionary = model.players[index].build
	var staged := original.duplicate(true)
	var cards: Array[String] = []
	if parts[2] == "core":
		if parts.size() != 3: return _error("core预设不接受重复次数。")
		for i in maxi(0, 6 - int(staged.weapons)): cards.append("weapon")
		cards.append_array(["power", "power", "power", "crit", "crit", "crit"])
		if str(staged.masterwork).is_empty(): cards.append(["verdict", "assembly", "chain"][int(staged.style)])
		for i in maxi(0, 2 - int(staged.signature_count)): cards.append(["bank", "nap", "promise"][int(staged.style)])
	else:
		for i in count: cards.append(parts[2])
	if staged.chosen.size() + cards.size() > 64: return _error("本局GM升级记录已达64条预算。")
	for id in cards:
		if id == "crit" and staged.crit >= 1.0: return _error("暴击率已达上限；未应用任何升级。")
		if not FurBuildCatalog.apply(staged, id): return _error("升级%s不适用或超过上限；未应用任何升级。" % id)
	model.players[index].build = staged
	model.players[index].hp = minf(model.players[index].hp, staged.health)
	return _success("玩家%d按合法目录应用%d项升级；武器%d，暴击%.0f%%。" % [index + 1, cards.size(), staged.weapons, staged.crit * 100])

func _spawn(parts: PackedStringArray) -> Dictionary:
	if parts.size() not in [3, 5]: return _error("用法：spawn 类型(0..4) 数量(1..64) [x z]")
	var kind := _integer(parts[1], 0, 4)
	var count := _integer(parts[2], 1, 64)
	if kind < 0 or count < 0 or (kind == 2 and count > 2): return _error("类型/数量越界；每次最多2名Boss。")
	var point := Vector2.INF
	if parts.size() == 5:
		point = Vector2(_number(parts[3], -12.8, 12.8), _number(parts[4], -8.2, 8.2))
		if not point.is_finite(): return _error("位置必须在场内且为有限数。")
	var available := mini(model.max_enemies - model.enemies.active.size(), model.enemies.free_slots.size())
	if count > available: return _error("敌人池剩余%d个槽位；未生成。" % available)
	var spawned := 0
	for i in count:
		if model.spawn_enemy(kind, point) < 0: break
		spawned += 1
	if spawned == 0: return _error("申请%d名类型%d敌人，实际生成0；当前规则/特殊敌容量拒绝。" % [count, kind])
	model.grid.rebuild(model.enemies)
	var result := _success("申请%d名类型%d敌人，实际生成%d；总数%d。" % [count, kind, spawned, model.enemies.active.size()])
	result["requested"] = count; result["spawned"] = spawned
	return result

func _clear(parts: PackedStringArray) -> Dictionary:
	if parts.size() != 2 or parts[1] not in ["all", "enemies", "shots", "pickups", "baits"]: return _error("用法：clear all|enemies|shots|pickups|baits")
	var target := parts[1]
	if target in ["all", "enemies"]: model.enemies.clear(); model.grid.rebuild(model.enemies)
	if target in ["all", "shots"]: model.shots.clear()
	if target in ["all", "pickups"]: model.pickups.clear()
	if target in ["all", "baits"]: model.baits.clear()
	return _success("已清理%s；不会发放击杀或奖励。" % target)

func _invuln(parts: PackedStringArray) -> Dictionary:
	if parts.size() != 3: return _error("用法：invuln 玩家 秒(0.1..5)")
	var index := _player(parts[1])
	var seconds := _number(parts[2], 0.1, 5.0)
	if index < 0 or not is_finite(seconds): return _error("玩家或短时无敌参数无效。")
	if model.players[index].down: return _error("倒地角色不能使用短时无敌。")
	model.players[index].invuln = seconds
	return _success("玩家%d调试无敌%.1f秒；按正常tick倒计时。" % [index + 1, seconds])

func _player(value: String) -> int:
	var human_index := _integer(value, 1, model.players.size())
	return human_index - 1 if human_index > 0 else -1

func _prepare_resource(parts: PackedStringArray, resource: String) -> Dictionary:
	if parts.size() != 3: return _error("用法：%s 玩家 数量" % resource)
	var index := _player(parts[1])
	if index < 0: return _error("玩家编号无效。")
	var player: Dictionary = model.players[index]
	var style := 0 if resource == "pot" else 1
	if player.down or int(player.build.style) != style: return _error("资源准备仅适用于活着的对应职业。")
	var cap: float = player.build.pot_cap if resource == "pot" else 2.5
	var amount := _number(parts[2], 0.0, cap)
	if not is_finite(amount): return _error("资源必须是0..%.1f内的有限十进制数。" % cap)
	# Only the prepared resource changes. Normal set_input/Q/attacks must consume
	# it; this command cannot create waves, damage, kills, or force a result.
	player[resource] = amount
	return _success("GM资源准备：玩家%d %s=%.1f；通过正常输入触发。" % [index + 1, resource, amount])

func _prepare_baits(parts: PackedStringArray) -> Dictionary:
	if parts.size() != 3: return _error("用法：bait 玩家 数量(1..3)")
	var index := _player(parts[1])
	var count := _integer(parts[2], 1, 3)
	if index < 0 or count < 0: return _error("玩家或诱饵准备数量无效。")
	var player: Dictionary = model.players[index]
	if player.down or int(player.build.style) != 2: return _error("仅活着的画饼职业可准备诱饵。")
	if model.baits.size() + count > 12: return _error("诱饵池容量12，剩余不足；未放置。")
	for i in count: model.place_bait(index, false)
	return _success("GM资源准备：通过正常放置规则准备%d个诱饵；正常Q可排队连爆。" % count)

func _integer(value: String, minimum: int, maximum: int) -> int:
	if not value.is_valid_int() or value.length() > 10: return -1
	var number := value.to_int()
	return number if number >= minimum and number <= maximum else -1

func _number(value: String, minimum: float, maximum: float) -> float:
	# Plain decimal notation avoids the engine emitting overflow warnings while
	# converting malformed exponents (e.g. 1e999) before we can reject them.
	if "e" in value.to_lower() or not value.is_valid_float() or value.length() > 24: return NAN
	var number := value.to_float()
	return number if is_finite(number) and number >= minimum and number <= maximum else NAN

func _success(message: String, intervention: bool = true) -> Dictionary:
	return {"ok": true, "message": message, "intervention": intervention}

func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message, "intervention": false}
