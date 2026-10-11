class_name FurMahjongNightWelcomePayoff
extends RefCounted

## Presentation slices of one already-authorized score event. These slices
## never call the rules or award a second payment. Their sum is exactly total.
static func eligible(event:Dictionary)->bool:
	if event.get("kind","") not in ["chi","pon","kong"] or int(event.get("repeats",1))<=1 or int(event.get("total",0))<=0:return false
	# An added kong/hu can include subtraction of already-paid groups. Keep its
	# net-payment receipt intact instead of implying equal fresh repeated awards.
	for row:Dictionary in event.get("ledger",[]):
		if row.get("op","")=="paid":return false
	return true

static func slices(event:Dictionary,before:float)->Array:
	var result:Array=[];var count:int=clampi(int(event.get("repeats",1)),1,4)
	var source:String=""
	var base:int=int(event.get("welcome_base",-1))
	for row:Dictionary in event.get("ledger",[]):
		if row.get("op","")=="repeat":source=row.get("source","")
		if base<0 and row.get("op","")=="base":base=int(row.value)
	var subtotal:float=before;var assigned:int=0
	for i in count:
		var amount:int=int(event.total/count) if i<count-1 else int(event.total)-assigned
		assigned+=amount
		result.append({"type":"gain","amount":amount,"actor":event.actor,"kind":event.kind,"tiles":event.tiles.duplicate(),"plain_base":event.get("welcome_base",-1),"before":subtotal,"after":subtotal+amount,"repeat_index":i+1,"repeat_count":count,"event_total":event.total,"event_so_far":assigned,"pause":.88 if i==count-1 else .42})
		result.back().repeat_source=source
		result.back().impact_base=base
		subtotal+=amount
	return result

static func present(p:Variant,entry:Dictionary)->void:
	var actor_name:String=["小柯","泡泡"][entry.actor]
	p._gain.hide();p._combo.gain(entry.amount,entry.kind,actor_name)
	var icon:String="ember"
	for id:String in FurMahjongNightCatalog.ITEMS:
		if FurMahjongNightCatalog.name_of(id)==entry.get("repeat_source",""):icon=id;break
	p._combo._icon.texture=load("res://assets/mahjong_night/"+icon+"_icon.png")
	if entry.get("repeat_source","")=="赤封":p._combo._icon.texture=load("res://assets/mahjong_night/show/seal_icon.png")
	p._combo._source.text="第 %d / %d 响 · 本组已入账 %d / %d"%[entry.repeat_index,entry.repeat_count,entry.event_so_far,entry.event_total]
	p._combo._formula.text="+%d 分"%entry.amount if entry.repeat_index==1 else "再响！ +%d 分"%entry.amount
	if entry.repeat_index==entry.repeat_count:
		p._combo._source.text=("这组牌 %d → %d 分"%[entry.plain_base,entry.event_total] if entry.plain_base>0 else "%s 本组共 %d 分"%[actor_name,entry.event_total])+" · %d 响都到手"%entry.repeat_count
	p._score_lines.append("[color=#ffd18a]%s 第%d响 +%d · 本组累计 %d[/color]"%[actor_name,entry.repeat_index,entry.amount,entry.event_so_far]);p._ledger.text="\n".join(p._score_lines)
	if p._skipping_score:return
	var view:Variant=p.table_view
	var origin:=Vector3.ZERO;var found:int=0
	for id:int in entry.tiles:
		if view.transforms.has(id):origin+=view.transforms[id].origin;found+=1
	if found>0:origin=origin/float(found)+Vector3.UP*.35
	if entry.repeat_index>1:view.echo_score_tiles(entry.tiles,1.8)
	var target:int=int(p.snapshot.night.target)
	var crossed:bool=entry.plain_base<0 and entry.before<target and entry.after>=target
	if is_instance_valid(view.night_feedback):
		view.night_feedback.burst(entry.amount,target,roundi(entry.before),origin,view.presentation_speed,entry.impact_base,entry.plain_base<0)
		view.night_feedback._title.text=(("第一响 · +%d" if entry.repeat_index==1 else "再响！ +%d")%entry.amount)+(" · 达标！" if crossed else "")
		view.night_feedback._title.show()
	view.celebrate_score(entry.actor,.38 if entry.repeat_index==1 else .72)
	p.score_beat.emit("build_fire_first" if entry.repeat_index==1 else "build_fire_finish",0)
