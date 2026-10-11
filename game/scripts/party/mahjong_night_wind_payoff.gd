class_name FurMahjongNightWindPayoff
extends RefCounted

## Describe a genuine amplified sequence. This only reads the paid event;
## it never scores again, replays a rule, or changes the physical tile groups.
static func profile(event:Dictionary)->Dictionary:
	if event.get("kind","")!="chi" or int(event.get("repeats",1))!=1:return {}
	var base:int=0;var bell:bool=false;var silk:bool=false
	for row:Dictionary in event.get("ledger",[]):
		if row.get("op","")=="paid":return {}
		if row.get("op","")=="base":base=int(row.value)
		if row.get("op","")=="multiply" and float(row.get("value",0))>1:
			if row.source==FurMahjongNightCatalog.name_of("windbell"):bell=true
			if row.source==FurMahjongNightCatalog.name_of("silk"):silk=true
	if base<=0 or int(event.get("total",0))<base*2 or not (bell or silk):return {}
	return {"base":base,"icon":"silk" if silk else "windbell","title":"三色齐奏" if silk else "风铃渐强","sources":(["windbell"] if bell else [])+(["silk"] if silk else [])}

static func present(p:Variant,profile:Dictionary,amount:int,actor:int,tiles:Array)->void:
	p._combo._source.text=["小柯","泡泡"][actor]+" · "+profile.title+" · 这一组真的放大了"
	p._combo._icon.texture=load("res://assets/mahjong_night/"+profile.icon+"_icon.png")
	p._combo._formula.text="+%d 分"%amount
	if p._skipping_score:return
	var view:Variant=p.table_view
	view.flourish_score_tiles(tiles)
	view.celebrate_score(actor,.78)
	for id:String in profile.sources:
		if is_instance_valid(view.night_relics):view.night_relics.pulse(FurMahjongNightCatalog.name_of(id),actor)
	if is_instance_valid(view.night_feedback):
		view.night_feedback._title.text=profile.title+"！ +%d"%amount;view.night_feedback._title.show()
