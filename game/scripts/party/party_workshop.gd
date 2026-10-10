class_name FurPartyWorkshop
extends RefCounted
## Party-facing offers share one eligibility path for both free and paid cards.
## This owns no wallet and consumes no board RNG; Model owns fixed-price receipts.
const LOCAL_PREFERENCES:=[["power","bounce"],["weapon","speed"],["link","heal"]]
const LOCAL_LABELS:=["港口工坊 · 火力／弹射","风车工坊 · 武器／机动","林间工坊 · 合作／生命"]
static func basic_pool(build:Dictionary,partner_style:int)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for original in FurBuildCatalog.UPGRADES:
		if original.id=="area" and build.style==1:continue
		if original.id=="link" and build.style!=0 and partner_style!=0:continue
		var copy:Dictionary=build.duplicate(true)
		if not FurBuildCatalog.apply(copy,original.id):continue
		if original.id=="crit" and is_equal_approx(copy.crit,build.crit):continue
		var item:Dictionary=original.duplicate(true)
		if item.id=="heal":item.detail="生命上限 +12；下一波满血出发"
		if item.id=="bounce":
			if build.style==0:item.name="回旋锅铲";item.detail="挥锅与锅能爆发伤害 +12%"
			elif build.style==2:item.name="饼屑加料";item.detail="诱饵爆炸伤害 +12%"
			else:item.detail="子弹多弹射 1 次；伤害 +12%"
		if item.id=="link":
			if build.style==0:item.detail="锅印多留 0.2 秒；每次锅印击败多回收 0.8 锅能"
			elif build.style==2:item.detail="诱饵多聚怪 0.06 秒；兑现队友锅印增伤 +20%"
			else:item.detail="兑现队友锅印时增伤 +20%"
		result.append(item)
	return result

static func draft(build:Dictionary,partner_style:int,seed_value:int,midpoint:bool=false,paid:bool=false,district:int=-1)->Array[Dictionary]:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var eligible:Array[Dictionary]=basic_pool(build,partner_style)
	if not paid:
		for signature in FurBuildCatalog.SIGNATURES:
			if signature.style==build.style and build.signature_count<2:eligible.append(signature.duplicate(true))
	var result:Array[Dictionary]=[]
	if midpoint and not paid and build.masterwork.is_empty():
		for masterwork in FurBuildCatalog.MASTERWORKS:
			if masterwork.style==build.style:result.append(masterwork.duplicate(true))
	# The leader's actual destination gives a predictable local build option.
	# This still uses the same eligibility rules, including caps and team style.
	if district>=0 and district<3:
		var local_indices:Array[int]=[]
		for index in eligible.size():
			if eligible[index].id in LOCAL_PREFERENCES[district]:local_indices.append(index)
		if not local_indices.is_empty() and result.size()<3:
			var local_index:int=local_indices[rng.randi_range(0,local_indices.size()-1)]
			var local:Dictionary=eligible[local_index];local["local_offer"]=true
			result.append(local);eligible.remove_at(local_index)
	while result.size()<3 and not eligible.is_empty():
		var index:=rng.randi_range(0,eligible.size()-1);result.append(eligible[index]);eligible.remove_at(index)
	return result
