class_name FurCombatBuildCaption
extends RefCounted
## Read-only view adapter: name and activation timing from real current actor.
static func describe(player:Dictionary)->Dictionary:
	var build:Dictionary=player.build
	var core:String=str(build.get("masterwork",""))
	var name:String="基础构筑"
	for card in FurBuildCatalog.MASTERWORKS:
		if card.id==core:name=card.name;break
	var hint:String="WASD移动 · 空格冲刺 · Q技能"
	match int(build.style):
		0:
			if core=="verdict":
				hint="锅气 %.0f · 门槛35 · %s"%[player.pot,"Q放锅浪" if player.pot>=35 and player.skill_cd<=0 else ("Q冷却 %.1f秒"%player.skill_cd if player.skill_cd>0 else "击败标记敌人攒锅气")]
			else:hint="锅气 %.0f · Q释放 / 贴近伙伴减伤"%player.pot
		1:
			hint="蓄能 %.1f/2.0 · %s"%[player.charge,"迈步追加齐射" if player.charge>=2 and core in ["piercing","assembly"] else ("迈步强化齐射" if player.charge>=1 else "站定蓄能")]
		2:
			hint="Q连兑诱饵饼 · 锅印聚怪触发连爆" if core=="chain" else "自动投饼聚怪 · Q迅速兑现"
	return {"name":name,"hint":hint}
