class_name FurCampaignEvaluation
extends RefCounted

# Pure factual summary. No rewards, saving, model writes or inferred playtests.
const MAX_ROUNDS:=6
const GOAL_IDS:=["all_districts","three_challenges","six_contracts"]
const SharedOrder=preload("res://scripts/furball/shared_order.gd")
const Challenge=preload("res://scripts/furball/challenge_contract.gd")

static func evaluate(facts:Dictionary) -> Dictionary:
	var notes:Array[String]=[]
	var outcome:String=str(facts.get("outcome","unknown"))
	if outcome not in ["victory","defeat","in_progress"]:notes.append("结局记录缺失或无效")
	var wave:int=_integer(facts.get("wave"),0,6,notes,"站数")
	var cash:int=_integer(facts.get("cash"),0,999,notes,"现金")
	var debug_known:bool=facts.get("debug_run") is bool
	if not debug_known:notes.append("调试分类记录缺失")
	var debug_run:bool=debug_known and bool(facts.get("debug_run",false))
	var licenses:Array=[0,0,0]
	if facts.get("licenses") is Array and facts.licenses.size()==3:
		for index in 3:licenses[index]=_integer(facts.licenses[index],0,2,notes,"执照")
	else:notes.append("三街区执照记录缺失")
	var visited:Array[int]=[]
	var completed:=0;var challenges:=0;var challenge_completed:=0
	var challenge_unavailable:=0;var challenge_failed:=0;var challenge_known:=true
	var seen_rounds:Array[int]=[]
	var challenge_versions:Array[int]=[]
	var battles_completed:=0
	if not facts.get("rounds") is Array:notes.append("街区委托历史缺失")
	else:
		if facts.rounds.size()>MAX_ROUNDS:notes.append("街区历史超出六站")
		for index in mini(facts.rounds.size(),MAX_ROUNDS):
			var entry:Variant=facts.rounds[index]
			if not entry is Dictionary or not entry.has_all(["round","district_id","objective_completed","challenge","battle_completed"]):
				notes.append("街区历史字段缺失");continue
			var round_number:int=_integer(entry.round,1,6,notes,"历史站数")
			var district_id:int=_integer(entry.district_id,0,2,notes,"街区编号")
			if round_number in seen_rounds:notes.append("重复街区回合未重复计分");continue
			if not entry.objective_completed is bool or not entry.challenge is bool or not entry.battle_completed is bool:
				notes.append("街区完成记录类型无效");continue
			seen_rounds.append(round_number)
			if entry.battle_completed:battles_completed+=1
			if district_id not in visited:visited.append(district_id)
			if entry.objective_completed:completed+=1
			if entry.challenge:
				challenges+=1
			if not entry.has_all(["challenge_rule_version","challenge_available","challenge_qualified","challenge_result"]):
				notes.append("旧规则挑战记录缺少新版资格证据");challenge_known=false;continue
			if not entry.challenge_rule_version is int or entry.challenge_rule_version not in [Challenge.LEGACY_VERSION,Challenge.CURRENT_VERSION] or not entry.challenge_available is bool or not entry.challenge_qualified is bool or not entry.challenge_result is Dictionary:
				notes.append("挑战资格记录类型或规则版本无效");challenge_known=false;continue
			if entry.challenge_rule_version not in challenge_versions:challenge_versions.append(entry.challenge_rule_version)
			if not entry.challenge:
				if entry.challenge_available or entry.challenge_qualified or not entry.challenge_result.is_empty():notes.append("未接挑战却记录资格");challenge_known=false
				continue
			if entry.challenge_result.is_empty():
				if entry.battle_completed or outcome in ["victory","defeat"] or entry.challenge_available or entry.challenge_qualified:
					notes.append("已结束挑战缺少资格回执");challenge_known=false
				continue
			if not facts.get("seed") is int or not facts.get("run_token") is int or entry.challenge_result.get("rule_version")!=entry.challenge_rule_version or not Challenge.valid_history_result(entry.challenge_result,facts.seed,facts.run_token,round_number,true,entry.objective_completed,entry.battle_completed):
				notes.append("挑战资格回执无效");challenge_known=false;continue
			if entry.challenge_available!=entry.challenge_result.available or entry.challenge_qualified!=entry.challenge_result.qualified:
				notes.append("挑战资格与回执不一致");challenge_known=false;continue
			if entry.challenge_qualified:challenge_completed+=1
			elif not entry.challenge_available:challenge_unavailable+=1
			else:challenge_failed+=1
	var rescues:=0;var receipts:=0;var ally_saved:=0.0
	if not facts.get("contributions") is Array:notes.append("合作贡献记录缺失")
	else:
		if facts.contributions.size()>2:notes.append("合作角色记录超出二人")
		for index in mini(facts.contributions.size(),2):
			var contribution:Variant=facts.contributions[index]
			if not contribution is Dictionary:notes.append("合作贡献类型无效");continue
			rescues+=_integer(contribution.get("rescues"),0,999999,notes,"救援")
			receipts+=_integer(contribution.get("link_receipts"),0,999999,notes,"锅印兑现")
			var saved:Variant=contribution.get("ally_saved_damage")
			if not (saved is float or saved is int) or not is_finite(float(saved)) or float(saved)<0:notes.append("搭档减伤记录无效")
			else:ally_saved+=minf(float(saved),999999.0)
	visited.sort()
	var won:bool=outcome=="victory" and wave==6
	if outcome=="victory" and wave!=6:notes.append("胜利与第六站记录不一致")
	if won and seen_rounds.size()!=6:notes.append("六站胜利缺少完整街区记录")
	if won and battles_completed!=6:notes.append("六站胜利与营业完成记录不一致")
	var valid:bool=notes.is_empty()
	var ordinary:bool=valid and debug_known and not debug_run
	var license_sum:int=int(licenses[0])+int(licenses[1])+int(licenses[2])
	var cooperation_points:int=mini(12,rescues*4)+mini(8,int(receipts/5.0))+mini(5,int(ally_saved/20.0))
	var parts:Dictionary={"闭店":100 if won else 0,"委托":completed*12,"地产":license_sum*5,"现金":mini(50,int(cash/5.0)),"挑战":challenge_completed*8,"合作":cooperation_points}
	var score:=0
	for value in parts.values():score+=int(value)
	var classification:String="gm_debug" if debug_run else ("ordinary" if ordinary else "incomplete")
	var rank:String="GM调试记录" if debug_run else ("记录不足，暂不评级" if not valid else ("继续开市" if not won else ("夜市金牌搭档" if score>=250 else ("满街开张" if score>=210 else ("经营熟手" if score>=170 else "准时打烊")))))
	var goals:Array[Dictionary]=[
		{"id":"all_districts","name":"逛遍三街区","detail":"走进三个不同街区，并完成第六站闭店。","progress":visited.size(),"target":3,"qualified":ordinary and won and visited.size()==3},
		{"id":"three_challenges","name":"风险营业","detail":"至少三站及时清掉抢档群、完成完整委托并存活闭站，再完成第六站闭店。","progress":challenge_completed,"target":3,"qualified":ordinary and won and challenge_completed>=3},
		{"id":"six_contracts","name":"六站不落单","detail":"六站本地委托全部完成，并完成第六站闭店。","progress":completed,"target":6,"qualified":ordinary and won and completed==6}
	]
	var next_goal:String="换一个种子或流派组合，再达成这三项目标。"
	for goal in goals:
		if not goal.qualified:next_goal=goal.name+"："+goal.detail;break
	var order_result:=_order_result(facts,ordinary,won)
	return {"classification":classification,"counts_as_ordinary":ordinary,"valid":valid,"won_six":won,
		"rank":rank,"score":score,"score_label":"GM经营诊断指数" if debug_run else ("本局经营指数" if valid else "记录诊断指数"),
		"parts":parts,"goals":goals,"next_goal":next_goal,"notes":notes,
		"order":order_result,
		"challenge":{"known":challenge_known,"rule_version":challenge_versions[0] if challenge_versions.size()==1 else 0,"current_rule_version":Challenge.CURRENT_VERSION,"versions":challenge_versions,"accepted":challenges,"qualified":challenge_completed,"unavailable":challenge_unavailable,"failed":challenge_failed},
		"metrics":{"completed_contracts":completed,"battles_completed":battles_completed,"visited_districts":visited,"license_levels":licenses,"license_total":license_sum,"cash":cash,"challenges_accepted":challenges,"challenges_completed":challenge_completed,"challenges_unavailable":challenge_unavailable,"challenges_failed":challenge_failed,"rescues":rescues,"link_receipts":receipts,"ally_saved_damage":ally_saved},
		"evidence_scope":"根据本局事实计算；自动评价不能证明真人已认可趣味或平衡。"}

static func _integer(value:Variant,minimum:int,maximum:int,notes:Array[String],label:String) -> int:
	if not value is int or int(value)<minimum or int(value)>maximum:
		notes.append(label+"记录无效");return clampi(int(value) if value is int else 0,minimum,maximum)
	return int(value)

static func _order_result(facts:Dictionary,ordinary:bool,won:bool)->Dictionary:
	var unknown:Dictionary={"known":false,"qualified":false,"label":"订单记录不足，暂不判定履约"}
	if not facts.get("seed") is int or not facts.get("run_token") is int or not facts.get("contributions") is Array:return unknown
	var state:Variant=facts.get("shared_order")
	if not SharedOrder.valid_state(state,facts.seed,facts.contributions.size(),facts.run_token):return unknown
	if state.last_wave!=facts.get("wave") or facts.get("outcome") in ["victory","defeat"] and not state.run_closed:return unknown
	var title:="尚未选单"
	for recipe in state.offers:
		if recipe.id==state.selected:title=recipe.title
	var needed:Array[String]=[];var received:Array[String]=[]
	for index in 3:
		if state.required_mask&(1<<index):needed.append(["串串","物流","奶站"][index])
		if state.collected_mask&(1<<index):received.append(["串串","物流","奶站"][index])
	var qualified:bool=ordinary and won and state.fulfilled
	var result:String="履约闭店成功" if qualified else ("已交付，尚未闭店" if state.fulfilled else ("闭店成功，联单未完" if won else "联单未完成"))
	if facts.get("debug_run",false):result="GM交付演示，不计普通履约" if state.fulfilled else "GM订单记录，不计普通履约"
	return {"known":true,"qualified":qualified,"fulfilled":state.fulfilled,"fulfilled_wave":state.fulfilled_wave,"title":title,"needed":needed,"received":received,
		"label":"合伙连单 · %s · 货物%d/2 · %s" % [title,received.size(),result],
		"next_goal":"下一局按骰路取齐%s，再把箱依次送到两个配送点并完成闭店。" % "与".join(needed)}
