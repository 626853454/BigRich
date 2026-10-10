class_name FurballGMBoardCommands
extends RefCounted

# Called only through the development/authority-gated GM router. Preparation
# changes only cash/starting position; progression uses normal board rules.
const HELP := "board status；board coins 0..999（共享钱袋）；board pos 0..11（仅掷骰前准备位置）；board order 0|1（仅首轮掷骰前）；board roll 1..6；board move -1|0|1（-1按骰点倒车花2券；0正向原骰点免费；1正向加一步花1券）；board event 0|1|2（两选项/仅无收益继续）；board business 0|1|2（经营/挑战/留钱）；board supply 0|1|2（奶/资源/路线券）。推进走正常棋盘结算，不伪造落点。"
var model: FurCombatModel

func configure(target: FurCombatModel) -> void: model = target

func execute(args: PackedStringArray) -> Dictionary:
	if model == null or model.board == null or model.board.state.is_empty(): return _error("棋盘尚未初始化。")
	if args.size() == 1 and args[0] == "help": return _success(HELP, false)
	if args.size() == 1 and args[0] == "status": return _success(JSON.stringify({"board":model.board.snapshot(),"patrol":model.patrol.snapshot(),"patrol_preview":model.patrol.preview(int(model.board.state.position))}), false)
	if args.size() != 2: return _error("输入board help查看固定命令。")
	if model.phase != "board": return _error("棋盘修改仅在棋盘阶段执行。")
	var board := model.board
	match args[0]:
		"coins":
			var cash := _integer(args[1], 0, 999)
			if cash < 0: return _error("共享现金必须为0..999的整数。")
			board.state.cash = cash
			return _success("调试钱袋设为%d。" % cash)
		"pos":
			var position := _integer(args[1], 0, 11)
			if position < 0 or board.state.stage != "roll": return _error("仅掷骰前可准备位置，格号须为0..11整数。")
			board.state.position = position
			return _success("调试起始位置%d：%s；尚未触发落点收益。" % [position, board.NAMES[position]])
		"order":
			var choice:=_integer(args[1],0,1)
			if choice<0 or not model.select_board_order(choice,int(board.state.active)):return _error("订单仅首轮掷骰前选0/1一次，不能重选已承诺订单。")
			return _success("合伙订单已承诺；尚未掷骰，不占经营。")
		"roll":
			var face := _integer(args[1], 1, 6)
			if face < 0 or not model.roll_board(face,0,int(board.state.active)): return _error("骰点须为1..6，且当前必须等待掷骰。")
			return _success("正常掷骰流程：骰点%d，下一步选择move。" % face)
		"move":
			var adjustment := _signed_adjustment(args[1])
			if adjustment == 99: return _error("骰路只接受-1/0/1：倒车原骰点花2券、正向原骰点免费、正向加一步花1券。")
			var projected:Dictionary=board.preview_details(adjustment)
			if not projected.ok: return _error(str(projected.reason))
			if not model.board_choose("board_move", adjustment + 1, int(board.state.active)): return _error("当前操骰者或移动阶段不允许承诺骰路。")
			return _success("正常骰路：%s；实际%d步、花%d券，落在%d：%s；余券%d，现金%d。" % [projected.caption,projected.steps,projected.ticket_cost,board.state.position,board.NAMES[int(board.state.position)],board.state.nudges,board.state.cash])
		"business":
			var choice := _integer(args[1], 0, 2)
			if choice < 0 or not model.board_choose("board_business", choice, int(board.state.active)): return _error("经营选择须为0/1/2，且当前落点/资金允许；当前必须等待经营。")
			return _success("正常经营结算完成，已进入第%d场营业。" % model.wave)
		"event":
			var choice:=_integer(args[1],0,2)
			if choice<0 or not model.board_choose("board_event",choice,int(board.state.active),int(board.state.event_serial)):return _error("事件编号须为0/1/2且等待本轮事件；2只用于两项都无收益的继续。")
			return _success("正常事件已承诺，本轮经营机会仍保留。")
		"supply":
			var choice:=_integer(args[1],0,2)
			if choice<0 or not model.board_choose("board_supply",choice,int(board.state.active)):return _error("补给选择须为0/1/2（奶/资源/路线券），且必须处于经营阶段、资金足够并有实际收益。")
			return _success("正常补给交易完成，已进入第%d场营业。" % model.wave)
	return _error("未知棋盘GM命令；不支持任意字段写入。")

func _integer(value: String, minimum: int, maximum: int) -> int:
	if value.length() > 10 or not value.is_valid_int(): return -1
	var number := value.to_int()
	return number if number >= minimum and number <= maximum else -1

func _signed_adjustment(value: String) -> int:
	if value.length() > 3 or not value.is_valid_int(): return 99
	var adjustment := value.to_int()
	return adjustment if adjustment in [-1, 0, 1] else 99

func _success(message: String, intervention: bool = true) -> Dictionary:
	return {"ok": true, "message": message, "intervention": intervention}

func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message, "intervention": false}
