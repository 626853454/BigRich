class_name FurMahjongNightRun
extends RefCounted
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
var data:Dictionary={}
var _rng:=RandomNumberGenerator.new()

func start(seed_value:int,starter:String,ai:bool)->void:
	_rng.seed=seed_value
	if starter not in Catalog.STARTERS:starter="windbell"
	data={"promised_tiles":[-1,-1],"planned_requests":[-1,-1],"venues":{"2":"river","3":"duet"},"venue_confirmed":{},"seed":seed_value,"ai":ai,"table":1,"stamina":3,"coins":[8,8],"build":Catalog.loadout(starter),"phase":"table","shops":[],"history":[],"selected_heirlooms":[false,false],"ready":[false,false],"victory":false,"advance_after_shop":false}

func table_config()->Dictionary:
	return {"promised_tiles":data.get("promised_tiles",[-1,-1]).duplicate(),"planned_requests":data.get("planned_requests",[-1,-1]).duplicate(),"venue":data.venues.get(str(data.table),"opening"),"seed":int(_rng.randi_range(1,2147483646)),"ai":data.ai,"table":data.table,"target":Catalog.TARGETS[data.table-1],"coins":data.coins.duplicate(),"build":data.build.duplicate(true),"boss":data.table==3,"stamina":data.stamina}

func settle(result:Dictionary)->bool:
	if data.phase!="table":return false
	data.coins=result.wallets.duplicate()
	data.history.append(result.duplicate(true))
	if not result.success:data.stamina-=1
	for actor in 2:data.coins[actor]+=4+(3 if result.success else 0)+mini(int(result.total/maxi(result.target,1)),3)+(int(result.get("encore_bonus",0)) if result.success else 0)
	data.victory=result.success and data.table==3
	if data.stamina<=0 or data.victory:data.phase="complete";return true
	data.advance_after_shop=result.success
	data.phase="shop";data.selected_heirlooms=[false,false];data.ready=[false,false]
	for actor in 2:
		data.build.keepsakes[actor]=data.build.keepsakes[actor].filter(func(id:int)->bool:return id in result.owned_tiles[actor])
		data.build.heirlooms[actor]=data.build.keepsakes[actor][0] if not data.build.keepsakes[actor].is_empty() else -1
	var ids:Array=Catalog.ITEMS.keys()
	for i in range(ids.size()-1,0,-1):var j:int=_rng.randi_range(0,i);var v:Variant=ids[i];ids[i]=ids[j];ids[j]=v
	# One complement per seat, one cooperative discovery, then two rotating offers.
	# Uses the existing build only; never looks at the next shuffled wall.
	data.planned_requests=[-1,-1];data.promised_tiles=[-1,-1];data.shops=[]
	for actor in 2:
		var route:String=route_of(actor)
		var order:Array={"连顺":["bamboo","dew","silk","windbell"],"爆杠":["anvil","crucible","ember","coal"],"接力":["teacup","redthread","fellow","chorus"]}[route]
		for id:String in order:
			if id not in data.build.items[actor] and id not in data.build.shared and id not in data.shops:data.shops.append(id);break
	for id:String in ids:
		if Catalog.ITEMS[id].shared and id not in data.build.shared and id not in data.shops:data.shops.append(id);break
	for id:String in ids:
		if id not in data.shops:data.shops.append(id)
		if data.shops.size()>=5:break
	return true

func buy(id:String,actor:int,replace_slot:int=-1)->Dictionary:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or id not in data.shops:return {"ok":false,"reason":"当前无法购买"}
	var item:Dictionary=Catalog.ITEMS[id];var slots:Array=data.build.shared if item.shared else data.build.items[actor]
	var cap:int=1 if item.shared else 2
	if id in slots:return {"ok":false,"reason":"已有同名挂件"}
	if data.coins[actor]<item.price:return {"ok":false,"reason":"金币不足"}
	if slots.size()>=cap and (replace_slot<0 or replace_slot>=slots.size()):return {"ok":false,"reason":"请选择要替换的挂件槽"}
	data.coins[actor]-=item.price
	if slots.size()>=cap:slots[replace_slot]=id
	else:slots.append(id)
	return {"ok":true,"reason":"已装入 "+item.name}

func upgrade(kind:String,actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or kind not in ["chi","pon","kong"] or data.coins[actor]<4:return false
	data.coins[actor]-=4;data.build.levels[actor][kind]+=1;return true

func preview_purchase(id:String,actor:int,replace_slot:int)->Dictionary:
	# Re-score a real prior group at its recorded conditions; no next-wall prediction.
	var candidate=get_script().new();candidate.data=data.duplicate(true)
	var reply:Dictionary=candidate.buy(id,actor,replace_slot)
	if not reply.ok:return {"ok":false,"text":reply.reason}
	var result:Dictionary=data.history.back();var examples:Array=[]
	for event:Dictionary in result.get("ledger",[]):
		if event.actor!=actor:continue
		if event.has("replay_context"):examples.append(event)
		for row:Dictionary in event.ledger:
			if row.has("replay_sample"):examples.append(row.replay_sample)
	var best:Dictionary={};var gain:int=-2147483648
	for sample:Dictionary in examples:
		var before:Dictionary=FurMahjongNightScore.meld(sample.kind,sample.tiles,actor,{"build":data.build,"boss":result.get("table",1)==3},sample.replay_context)
		var after:Dictionary=FurMahjongNightScore.meld(sample.kind,sample.tiles,actor,{"build":candidate.data.build,"boss":result.get("table",1)==3},sample.replay_context)
		if after.total-before.total>gain:
			gain=after.total-before.total;best={"before":before.total,"after":after.total,"tiles":sample.tiles.duplicate(),"context":sample.replay_context.duplicate(true)}
	if best.is_empty():return {"ok":true,"text":"本桌还没有你的计分面子；先看挂件条件选择路线。"}
	var names:Array[String]=[]
	for tile:int in best.tiles:names.append(ChapterMahjongTable.tile_name(tile))
	best.ok=true;best.text="上桌同条件重算 · "+"/".join(names)+"：%d → %d分。仅该组样例，不预测下一桌。"%[best.before,best.after]
	return best

func stamp(id:int,stamp_kind:String,actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or stamp_kind not in ["red","gold"] or data.coins[actor]<3:return false
	var owned:Array=data.history.back().owned_tiles[actor]
	if id not in owned or data.build.stamps.get(str(id),"")==stamp_kind:return false
	data.coins[actor]-=3;data.build.stamps[str(id)]=stamp_kind;return true

func heirloom(id:int,actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or id not in data.history.back().owned_tiles[actor]:return false
	if id in data.build.keepsakes[1-actor]:return false
	var carried:Array=data.build.keepsakes[actor]
	if id in carried:carried.erase(id)
	elif data.build.carry_slots[actor]==1:carried.clear();carried.append(id)
	elif carried.size()<data.build.carry_slots[actor]:carried.append(id)
	else:return false
	data.build.heirlooms[actor]=carried[0] if not carried.is_empty() else -1
	data.selected_heirlooms[actor]=true;_validate_carry_request(actor);return true

func pack_slot(actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or data.build.carry_slots[actor]>=3 or data.coins[actor]<3:return false
	data.coins[actor]-=3;data.build.carry_slots[actor]+=1;return true

func next_table()->int:return data.table+(1 if data.advance_after_shop else 0)

func recommended_keepsakes(actor:int)->Array:
	if data.phase!="shop" or actor not in [0,1]:return []
	var owned:Array=data.history.back().owned_tiles[actor].duplicate();owned.sort()
	var count:int=mini(data.build.carry_slots[actor],owned.size());var best:Array=[];var best_value:float=-INF
	var route:String=route_of(actor)
	for i in owned.size():
		for j in range(i if count==1 else i+1,owned.size()):
			for k in range(j if count<=2 else j+1,owned.size()):
				var group:Array=[owned[i]]
				if count>=2:group.append(owned[j])
				if count>=3:group.append(owned[k])
				var value:float=0;var types:Array=[]
				for id:int in group:
					types.append(int(id/4));value+=3 if data.build.stamps.has(str(id)) else 0
				for x in types.size():
					for y in range(x+1,types.size()):
						if types[x]==types[y]:value+=5 if route=="爆杠" else 2
						elif types[x]<27 and types[y]<27 and int(types[x]/9)==int(types[y]/9) and absi(types[x]-types[y])<=2:value+=4 if route=="连顺" else 2
				if types.size()==3:
					if types[0]==types[2]:value+=(26 if route=="爆杠" else (8 if route=="连顺" else 16))+mini(data.build.levels[actor].pon,6)
					elif types[0]<27 and int(types[0]/9)==int(types[2]/9) and types[1]==types[0]+1 and types[2]==types[0]+2:value+=(24 if route=="连顺" else 14)+mini(data.build.levels[actor].chi,6)
				if value>best_value:best_value=value;best=group
				if count<=2:break
			if count==1:break
	return best

func use_recommended_keepsakes(actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor]:return false
	data.build.keepsakes[actor]=recommended_keepsakes(actor)
	data.build.heirlooms[actor]=data.build.keepsakes[actor][0] if not data.build.keepsakes[actor].is_empty() else -1
	_validate_carry_request(actor)
	return true

func reorder(actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or data.build.items[actor].size()!=2:return false
	data.build.items[actor].reverse();return true

func prepare(actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1]:return false
	data.ready[actor]=true
	if data.ready[0] and data.ready[1]:data.table=next_table();data.phase="table"
	return true


func choose_technique(id:String,actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor] or not data.build.techniques[actor].is_empty() or id not in Catalog.techniques_for(data.build,actor):return false
	data.build.techniques[actor]=id;return true


func choose_venue(id:String)->bool:
	if data.phase!="shop" or data.ready[0] or data.ready[1] or next_table() not in [2,3] or id not in Catalog.venues_for(next_table()):return false
	var key:String=str(next_table())
	if data.venue_confirmed.get(key,false):return false
	data.venues[key]=id;data.venue_confirmed[key]=true;return true


func route_of(actor:int)->String:
	var totals:Dictionary={"连顺":0,"爆杠":0,"接力":0};var selected:String="接力";var most:int=0
	for id:String in data.build.items[actor]:
		var route:String=Catalog.ITEMS[id].route;totals[route]+=1
		if totals[route]>most:most=totals[route];selected=route
	return selected

func carry_requests_for(actor:int)->Array:
	if data.phase!="shop" or actor not in [0,1]:return []
	var kept:Array=data.build.keepsakes[actor];var faces:Array=[];var candidates:Array=[]
	for id:int in kept:faces.append(int(id/4))
	for i in faces.size():
		for j in range(i+1,faces.size()):
			var a:int=mini(faces[i],faces[j]);var b:int=maxi(faces[i],faces[j]);var possible:Array=[]
			if a==b:possible.append(a)
			elif a<27 and b<27 and int(a/9)==int(b/9):
				if b-a==2:possible.append(a+1)
				elif b-a==1:
					if a%9>0:possible.append(a-1)
					if b%9<8:possible.append(b+1)
			for face:int in possible:
				if face not in candidates and (face not in faces or (a==b and faces.count(face)==2)):candidates.append(face)
	candidates.sort();return candidates

func plan_carry_request(face:int,actor:int)->bool:
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor]:return false
	if face!=-1 and face not in carry_requests_for(actor):return false
	data.planned_requests[actor]=face;return true

func _validate_carry_request(actor:int)->void:
	if data.get("promised_tiles",[-1,-1])[actor] not in data.build.keepsakes[actor]:data.promised_tiles[actor]=-1
	if data.get("planned_requests",[-1,-1])[actor] not in carry_requests_for(actor):data.planned_requests[actor]=-1

func pack_public_request(actor:int)->int:
	# Publicly agreed face + this seat's existing owned IDs. No wall/other hand access.
	if data.phase!="shop" or actor not in [0,1] or data.ready[actor]:return -1
	var face:int=data.planned_requests[1-actor]
	if face<0:return -1
	var selected:int=-1
	for id:int in data.history.back().owned_tiles[actor]:
		if int(id/4)==face and id not in data.build.keepsakes[1-actor]:selected=id;break
	if selected<0:return -1
	var kept:Array=data.build.keepsakes[actor]
	kept.erase(selected)
	while kept.size()>=int(data.build.carry_slots[actor]):kept.pop_back()
	kept.push_front(selected);data.promised_tiles[actor]=selected;data.build.heirlooms[actor]=kept[0];_validate_carry_request(actor)
	return selected
