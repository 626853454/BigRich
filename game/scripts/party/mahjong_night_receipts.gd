class_name FurMahjongNightReceipts
extends RefCounted

## Read only: retain the actual paid first group even if that meld later changed.
static func best_pair(events:Array,actor:int)->Dictionary:
	var by_id:Dictionary={}
	for event:Dictionary in events:by_id[event.id]=event
	var best:Dictionary={}
	for event:Dictionary in events:
		if event.actor!=actor or not event.has("two_chimes"):continue
		var pair:Dictionary=event.two_chimes
		if not by_id.has(pair.first_event) or pair.second_event!=event.id:continue
		var first:Dictionary=by_id[pair.first_event]
		if first.actor!=actor or first.id>=event.id:continue
		if not first.get("self_formed",false) or not event.get("self_formed",false):continue
		if first.get("personal_turn",-1)!=event.get("personal_turn",-2):continue
		if int(pair.first)!=int(first.total) or int(pair.second)!=int(event.total) or int(pair.total)!=int(first.total)+int(event.total):continue
		if int(pair.total)>int(best.get("total",-1)):
			best={"total":pair.total,"first":first,"second":event,"method":pair.method}
	return best

static func tile_line(tiles:Array)->String:
	var names:Array[String]=[]
	for tile:int in tiles:names.append(ChapterMahjongTable.tile_name(tile))
	return "/".join(names)

static func pair_line(pair:Dictionary)->String:
	return "%s → %s"%[tile_line(pair.first.tiles),tile_line(pair.second.tiles)]

static func paid_line(pair:Dictionary)->String:
	return "%d + %d = %d 分 · %s"%[pair.first.total,pair.second.total,pair.total,"借形连响" if pair.method=="reshape" else "灵感续奏"]
