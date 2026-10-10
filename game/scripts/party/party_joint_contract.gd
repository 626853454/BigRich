class_name FurPartyJointContract
extends RefCounted

## Pure schema/qualification only. PartyModel owns wallets and the sole writer.
## Proof is source-trusted by Session; this does not authenticate real kills.
const VERSION:=2
const Map=preload("res://scripts/party/party_map.gd")
const Economy=preload("res://scripts/party/party_economy.gd")
const Routes=preload("res://scripts/furball/route_catalog.gd")
const CONTRACT_KEYS:=["version","id","accepted_round","first_round","expires_round","sponsor","partner","origin_node","target_district"]
const PROOF_KEYS:=["version","token","round","route","rule_id","progress","target","rewarded","phase"]

static func _int(value:Variant,lo:int,hi:int)->bool:
	return typeof(value)==TYPE_INT and value>=lo and value<=hi

static func valid_contract(value:Variant)->bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.size()!=CONTRACT_KEYS.size():return false
	for key in CONTRACT_KEYS:
		if not value.has(key):return false
	if not _int(value.version,VERSION,VERSION) or not _int(value.id,1,2147483647):return false
	if not _int(value.accepted_round,1,Economy.JOINT_LAST_ACCEPT_ROUND) or value.first_round!=value.accepted_round or not _int(value.first_round,1,Economy.JOINT_LAST_ACCEPT_ROUND):return false
	if not _int(value.expires_round,Economy.JOINT_WINDOW_ROUNDS,Economy.JOINT_LAST_ACCEPT_ROUND+Economy.JOINT_WINDOW_ROUNDS-1) or value.expires_round!=value.accepted_round+Economy.JOINT_WINDOW_ROUNDS-1:return false
	if not _int(value.sponsor,0,1) or not _int(value.partner,0,1) or value.partner!=1-value.sponsor:return false
	var tiles:Array[Dictionary]=Map.nodes()
	if not _int(value.origin_node,0,tiles.size()-1) or tiles[value.origin_node].kind!="event":return false
	return _int(value.target_district,0,2) and value.target_district==(int(tiles[value.origin_node].district)+1)%3

static func create(id:int,round_number:int,sponsor:int,origin_node:int)->Dictionary:
	var tiles:Array[Dictionary]=Map.nodes()
	if not _int(origin_node,0,tiles.size()-1):return {}
	var contract:Dictionary={"version":VERSION,"id":id,"accepted_round":round_number,"first_round":round_number,"expires_round":round_number+Economy.JOINT_WINDOW_ROUNDS-1,"sponsor":sponsor,"partner":1-sponsor,"origin_node":origin_node,"target_district":(int(tiles[origin_node].district)+1)%3}
	return contract if valid_contract(contract) else {}

static func validate_proof(proof:Variant,token:int,round_number:int,route:int,won:bool)->Dictionary:
	var rejected:Dictionary={"ok":false,"present":false,"completed":false,"reason":"invalid_joint_proof"}
	if not proof is Dictionary:return rejected
	if proof.is_empty():return {"ok":true,"present":false,"completed":false,"reason":"missing_proof"}
	if proof.size()!=PROOF_KEYS.size():return rejected
	for key in PROOF_KEYS:
		if not proof.has(key):return rejected
	if not _int(proof.version,VERSION,VERSION) or not _int(proof.token,1,2147483647) or proof.token!=token:return rejected
	if not _int(proof.round,1,8) or proof.round!=round_number:return rejected
	if not _int(proof.route,0,2) or proof.route!=route or not _int(proof.rule_id,0,2) or proof.rule_id!=route:return rejected
	# Actual Model initialized/progress/targets are floats. Bool/string/coercion
	# cannot become progress. Compare completion exactly to the actual capped rule.
	if typeof(proof.progress)!=TYPE_FLOAT or typeof(proof.target)!=TYPE_FLOAT or not is_finite(proof.progress) or not is_finite(proof.target):return rejected
	var target:float=Routes.entry(route).target
	if proof.target!=target or proof.progress<0.0 or proof.progress>target:return rejected
	if typeof(proof.rewarded)!=TYPE_BOOL or proof.rewarded!=(proof.progress>=target):return rejected
	if typeof(proof.phase)!=TYPE_STRING or proof.phase not in ["draft","victory","defeat"]:return rejected
	if won!=(proof.phase!="defeat"):return rejected
	return {"ok":true,"present":true,"completed":bool(proof.rewarded),"reason":""}

static func result(contract:Dictionary,round_number:int,route:int,won:bool,proof_status:Dictionary)->Dictionary:
	var answer:Dictionary={"id":0,"status":"none","reason":"no_active_contract","round":round_number,"sponsor":-1,"partner":-1,"target_district":-1,"star_discount":0,"partner_coin_delta":0,"expires_round":0}
	if not valid_contract(contract):answer.reason="invalid_contract";return answer
	if contract.is_empty():return answer
	answer.id=contract.id;answer.sponsor=contract.sponsor;answer.partner=contract.partner
	answer.target_district=contract.target_district;answer.expires_round=contract.expires_round
	var eligible:bool=round_number>=int(contract.first_round) and round_number<=int(contract.expires_round) and route==int(contract.target_district) and won and bool(proof_status.present) and bool(proof_status.completed)
	if eligible:answer.status="completed";answer.reason="fulfilled"
	else:
		answer.status="expired" if round_number>=int(contract.expires_round) else "pending"
		answer.reason="missing_proof" if not proof_status.present else ("wrong_district" if route!=int(contract.target_district) else ("battle_lost" if not won else "objective_incomplete"))
	return answer
