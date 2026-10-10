class_name FurMahjongNightScore
extends RefCounted
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")

## Pure ledger. It cannot draw tiles, transfer coins, or recursively invoke itself.
static func meld(kind:String,tiles:Array,actor:int,night:Dictionary,context:Dictionary)->Dictionary:
	var ledger:Array=[]
	var level:int=night.build.levels[actor].get(kind,1)
	var chips:float={"chi":40,"pon":55,"kong":110}.get(kind,40)+(level-1)*25
	var ranks:int=0
	for id:int in tiles:ranks+=(int(id/4)%9+1) if id<108 else 5
	chips+=ranks*2
	ledger.append({"source":"实体牌 + %d级%s"%[level,{"chi":"顺子","pon":"刻子","kong":"杠"}.get(kind,kind)],"op":"base","value":chips})
	if context.get("river_bounty",false):chips+=80;ledger.append({"source":"河灯悬赏·本阶段首组新河牌","op":"add","value":80})
	if context.get("applause",0)>0:
		chips+=context.applause;ledger.append({"source":"亮灯喝彩 · 本桌成长","op":"add","value":context.applause})
	var factor:float=1.0
	if context.get("ensemble_factor",1.0)>1.0:
		factor=context.ensemble_factor;ledger.append({"source":"同桌合奏","op":"multiply","value":factor})
	if context.get("inspiration_factor",1.0)>1.0:
		factor*=context.inspiration_factor;ledger.append({"source":"催演 · 本回合押势","op":"multiply","value":context.inspiration_factor})
	var repeats:int=1
	if context.get("refrain",false):repeats+=1;ledger.append({"source":"双灯返场","op":"repeat","value":1})
	var money:int=0
	var stamped:Array=[]
	for id:int in tiles:
		var stamp:String=night.build.stamps.get(str(id),"")
		if stamp=="red" and "red" not in stamped:repeats+=1;stamped.append(stamp);ledger.append({"source":"赤封","op":"repeat","value":1})
		if stamp=="gold":money+=1
	var items:Array=night.build.items[actor].duplicate();items.append_array(night.build.shared)
	var first:int=int(tiles.min()/4) if not tiles.is_empty() else 0
	var previous:int=context.get("chi_count",0)
	var relay:bool=context.get("relay",false)
	var gained_heat:bool=false
	var used_heat:bool=false
	var heat_gain:int=0
	var growth:int=context.get("growth",0)
	if growth>0:chips+=growth;ledger.append({"source":"积火余温","op":"add","value":growth})
	for id:String in items:
		var add:float=0;var mult:float=1;var repeat:int=0;var chip_mult:float=1
		match id:
			"windbell":
				if kind=="chi":mult=pow(1.35,mini(previous,4))
			"bamboo":
				if kind=="chi":add=24;chip_mult=1.3 if first not in context.get("starts",[]) else 1.0
			"dew":
				if kind=="chi":add=context.get("tea",0)*6
			"silk":
				if kind=="chi":
					var suits:Array=context.get("suits",[]).duplicate();var suit:int=int(first/9)
					if suit not in suits:suits.append(suit)
					if suits.size()>=3:mult=2
			"coal":
				if kind=="kong":mult=2;gained_heat=true;heat_gain=2
				elif int(context.get("heat",0))>=2:repeat=1;used_heat=true
				elif kind=="pon":heat_gain=1
			"anvil":
				if kind in ["pon","kong"]:add=60
			"crucible":pass
			"ember":
				if kind=="kong":repeat=1
			"redthread":
				if relay:mult=2.4
			"teacup":
				if relay:add=80
			"chorus":
				if context.get("both_melded",false):mult=1.8
			"fellow":
				if kind in context.get("partner_kinds",[]):mult=1.6
		if add>0:chips+=add;ledger.append({"source":Catalog.name_of(id),"op":"add","value":add})
		if chip_mult>1:
			if night.get("boss",false) and not context.get("boss_unsealed",context.get("both_melded",false)):ledger.append({"source":"镜灯夜王·需要两人不同技艺" if night.get("venue","")=="prism" else "双声门神·等待伙伴开组","op":"locked","value":chip_mult})
			else:chips*=chip_mult;ledger.append({"source":Catalog.name_of(id),"op":"chip_mul","value":chip_mult})
		if mult>1:
			if night.get("boss",false) and not context.get("boss_unsealed",context.get("both_melded",false)):
				ledger.append({"source":"镜灯夜王·需要两人不同技艺" if night.get("venue","")=="prism" else "双声门神·等待伙伴开组","op":"locked","value":mult})
			else:factor*=mult;ledger.append({"source":Catalog.name_of(id),"op":"multiply","value":mult})
		if repeat>0:repeats+=repeat;ledger.append({"source":Catalog.name_of(id),"op":"repeat","value":repeat})
		if id=="coal" and (heat_gain>0 or used_heat):
			ledger.append({"source":Catalog.name_of(id),"op":"heat","value":mini(2,(0 if used_heat else int(context.get("heat",0)))+heat_gain),"spent":used_heat})
	repeats=mini(repeats,4)
	var total:int=roundi(chips*factor)*repeats
	trace_ledger(ledger,tiles)
	return {"kind":kind,"tiles":tiles.duplicate(),"actor":actor,"chips":chips,"factor":factor,"repeats":repeats,"total":total,"ledger":ledger,"replay_context":context.duplicate(true),"relay":relay,"gold_candidates":money,"river_bounty":context.get("river_bounty",false),"gained_heat":gained_heat,"heat_gain":heat_gain,"used_heat":used_heat,"growth":35 if kind=="kong" and "crucible" in items else 0,"tea_return":1 if relay and "teacup" in items else 0}

static func trace_ledger(ledger:Array,tiles:Array)->void:
	var chips:float=0;var factor:float=1;var repeats:int=1;var paid:int=0
	for row:Dictionary in ledger:
		match row.op:
			"base":chips=row.value
			"add":chips+=row.value
			"chip_mul":chips*=row.value
			"multiply":factor*=row.value
			"repeat":repeats=mini(4,repeats+int(row.value))
			"paid":paid+=int(row.value)
		row.after_chips=chips;row.after_factor=factor;row.after_repeats=repeats;row.after_total=maxi(0,roundi(chips*factor)*repeats-paid)
		row.tiles=tiles.duplicate()

## Extract physical groups for a proven legal winning hand; no fabricated tile IDs.
static func split_hand(hand:Array)->Array:
	var groups:Array=[]
	if hand.size()==14:
		var pairs:Array=[];var is_pairs:bool=true
		for kind in 34:
			var ids:Array=[]
			for id:int in hand:
				if int(id/4)==kind:ids.append(id)
			if ids.size()==2:pairs.append({"kind":"pair","tiles":ids})
			elif not ids.is_empty():is_pairs=false
		if is_pairs and pairs.size()==7:return pairs
	for kind in 34:
		var pair:Array=[]
		for id:int in hand:
			if int(id/4)==kind and pair.size()<2:pair.append(id)
		if pair.size()!=2:continue
		var rest:Array=hand.duplicate()
		for id:int in pair:rest.erase(id)
		var result:Variant=_split(rest)
		if result!=null:
			groups=result;groups.append({"kind":"pair","tiles":pair});return groups
	return []

## Enumerate the normal shape partitions, plus seven pairs. Equal faces retain
## stable physical-ID order within each partition; this never manufactures IDs.
static func hand_layouts(hand:Array)->Array:
	var layouts:Array=[]
	var preferred:Array=split_hand(hand)
	if preferred.size()==7:layouts.append(preferred)
	for kind in 34:
		var pair:Array=[]
		for id:int in hand:
			if int(id/4)==kind and pair.size()<2:pair.append(id)
		if pair.size()!=2:continue
		var rest:Array=hand.duplicate()
		for id:int in pair:rest.erase(id)
		for groups:Array in _all_splits(rest):
			groups.append({"kind":"pair","tiles":pair.duplicate()});layouts.append(groups)
	return layouts

static func _all_splits(hand:Array)->Array:
	if hand.is_empty():return [[]]
	hand.sort();var first:int=int(hand[0]/4);var result:Array=[];var same:Array=[]
	for id:int in hand:
		if int(id/4)==first:same.append(id)
	var choices:Array=[]
	if same.size()>=3:choices.append({"kind":"pon","tiles":same.slice(0,3)})
	if first<27 and first%9<=6:
		var sequence:Array=[hand[0]]
		for kind in [first+1,first+2]:
			for id:int in hand:
				if int(id/4)==kind:sequence.append(id);break
		if sequence.size()==3:choices.append({"kind":"chi","tiles":sequence})
	for choice:Dictionary in choices:
		var rest:Array=hand.duplicate()
		for id:int in choice.tiles:rest.erase(id)
		for tail:Array in _all_splits(rest):tail.push_front(choice.duplicate(true));result.append(tail)
	return result

static func _split(hand:Array)->Variant:
	if hand.is_empty():return []
	hand.sort();var first:int=int(hand[0]/4);var same:Array=[]
	for id:int in hand:
		if int(id/4)==first:same.append(id)
	if same.size()>=3:
		var rest:Array=hand.duplicate();var chosen:Array=same.slice(0,3)
		for id:int in chosen:rest.erase(id)
		var found:Variant=_split(rest)
		if found!=null:found.push_front({"kind":"pon","tiles":chosen});return found
	if first<27 and first%9<=6:
		var chosen:Array=[hand[0]]
		for kind in [first+1,first+2]:
			for id:int in hand:
				if int(id/4)==kind:chosen.append(id);break
		if chosen.size()==3:
			var rest:Array=hand.duplicate()
			for id:int in chosen:rest.erase(id)
			var found:Variant=_split(rest)
			if found!=null:found.push_front({"kind":"chi","tiles":chosen});return found
	return null
