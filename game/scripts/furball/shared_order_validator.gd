class_name FurSharedOrderValidator
extends RefCounted

# Detached snapshot preflight: no live object, player writes or reward execution.
const Paths=preload("res://scripts/furball/shared_order_paths.gd")
const Catalog=preload("res://scripts/furball/district_catalog.gd")
const STATE_KEYS:=["seed","players","run_token","offers","selected","required_mask","collected_mask","receipts","fulfilled","fulfilled_wave","entitlement","attempts","cargo_serial","event_serial","last_wave","run_closed","battle","cargo"]
const BATTLE_KEYS:=["wave","district_id","seed","elapsed","points","obstacles","routes","variant_id","variant_title"]
const CARGO_KEYS:=["id","phase","point","origin","source_charges","spawn_kind","carrier","last_carrier","regrab_until","checkpoint","nodes","route_choice","pickup_revision"]
const ENTITLEMENT_RULE:="下一正常draft由正式BuildCatalog校验，每演员一次合法选择；不直接改build。"
const RECIPES:=[{"id":0,"title":"账单到货","mask":3},{"id":1,"title":"宵夜冷链","mask":6},{"id":2,"title":"奶摊赊账","mask":5}]

static func valid_state(value:Variant,expected_seed:int,expected_players:int,expected_run_token:int)->bool:
	if expected_seed<1 or expected_seed>2147483647 or expected_players<1 or expected_players>2 or expected_run_token<1 or expected_run_token>2147483647 or not _keys(value,STATE_KEYS):return false
	for key in ["seed","players","run_token","selected","required_mask","collected_mask","fulfilled_wave","attempts","cargo_serial","event_serial","last_wave"]:
		if not value[key] is int:return false
	if value.seed!=expected_seed or value.players!=expected_players or value.run_token!=expected_run_token or not value.fulfilled is bool or not value.run_closed is bool:return false
	if value.last_wave<0 or value.last_wave>6 or value.fulfilled_wave<0 or value.fulfilled_wave>value.last_wave or value.attempts<0 or value.attempts>6 or value.cargo_serial!=value.attempts or value.event_serial<0 or value.event_serial>2147483647:return false
	if value.attempts==0 and value.event_serial!=0:return false
	var first:int=posmod(expected_seed^0x3219ab,3);var second:int=(first+1+expected_seed%2)%3
	if not value.offers is Array or value.offers.size()!=2 or value.offers!=[RECIPES[first],RECIPES[second]]:return false
	for offer in value.offers:
		if not _keys(offer,["id","title","mask"]) or not offer.id is int or not offer.mask is int or not offer.title is String:return false
	var required:=0
	if value.selected!=-1:
		if value.selected not in [first,second]:return false
		required=RECIPES[value.selected].mask
	if value.required_mask!=required or value.collected_mask<0 or value.collected_mask>7 or (value.collected_mask&required)!=value.collected_mask:return false
	var receipts:=_receipt_history(value.receipts,required,value.last_wave)
	if not receipts.ok or value.collected_mask!=receipts.mask:return false
	if value.selected==-1 and (not value.receipts.is_empty() or value.fulfilled or value.attempts>0):return false
	if not value.battle is Dictionary or not value.cargo is Dictionary or not value.entitlement is Dictionary:return false
	if value.last_wave==0 and (not value.battle.is_empty() or not value.receipts.is_empty() or value.attempts>0 or value.event_serial>0 or value.run_closed):return false
	if value.run_closed and (value.last_wave<1 or not value.battle.is_empty() or not value.cargo.is_empty()):return false
	if value.battle.is_empty():
		if not value.cargo.is_empty() or (value.last_wave==6 and not value.run_closed):return false
	else:
		if value.run_closed or not _battle(value.battle,expected_seed,value.last_wave):return false
	var ready:bool=required>0 and value.collected_mask==required
	if not ready:
		if value.attempts!=0 or not value.cargo.is_empty() or value.fulfilled or value.fulfilled_wave!=0 or not value.entitlement.is_empty():return false
	else:
		if receipts.ready_wave<1:return false
		var last_attempt:int=value.fulfilled_wave if value.fulfilled else value.last_wave
		if last_attempt<receipts.ready_wave or value.attempts!=last_attempt-receipts.ready_wave+1:return false
		if not value.battle.is_empty() and not value.fulfilled and value.cargo.is_empty():return false
	if value.fulfilled:
		if not ready or value.fulfilled_wave<receipts.ready_wave or value.fulfilled_wave<2 or value.event_serial<4:return false
		if value.fulfilled_wave<=5:
			if not _entitlement(value.entitlement,value.fulfilled_wave,expected_players):return false
			if value.entitlement.claimed and not value.battle.is_empty() and value.last_wave==value.fulfilled_wave:return false
		elif not value.entitlement.is_empty():return false
	else:
		if value.fulfilled_wave!=0 or not value.entitlement.is_empty():return false
	if not value.cargo.is_empty() and not _cargo(value.cargo,value,receipts):return false
	return true

static func _receipt_history(value:Variant,required:int,last_wave:int)->Dictionary:
	if not value is Array or value.size()>6:return {"ok":false}
	var previous:=0;var mask:=0;var ready_wave:=0;var ready_district:=-1
	for receipt in value:
		if not _keys(receipt,["wave","district_id","sequence","received"]):return {"ok":false}
		for key in ["wave","district_id","sequence"]:
			if not receipt[key] is int:return {"ok":false}
		if not receipt.received is bool or receipt.wave<=previous or receipt.wave>last_wave or receipt.wave>6 or receipt.district_id<0 or receipt.district_id>2 or receipt.sequence<1 or receipt.sequence>2147483647:return {"ok":false}
		var bit:int=1<<int(receipt.district_id)
		var received:bool=(required&bit)!=0 and (mask&bit)==0
		if receipt.received!=received:return {"ok":false}
		if received:mask|=bit
		if ready_wave==0 and required>0 and mask==required:ready_wave=receipt.wave;ready_district=receipt.district_id
		previous=receipt.wave
	return {"ok":true,"mask":mask,"ready_wave":ready_wave,"ready_district":ready_district}

static func _battle(value:Variant,seed:int,wave:int)->bool:
	if not _keys(value,BATTLE_KEYS):return false
	for key in ["wave","district_id","seed","variant_id"]:
		if not value[key] is int:return false
	if value.wave!=wave or wave<1 or wave>6 or value.district_id<0 or value.district_id>2 or value.seed!=seed+wave*101 or not _finite(value.elapsed) or float(value.elapsed)<0 or not value.variant_title is String:return false
	if not value.points is Array or value.points.size()!=3 or not value.obstacles is Array or value.obstacles.size()>2 or not value.routes is Array or value.routes.size()!=3:return false
	var expected:Dictionary=Catalog.layout(value.district_id,wave,value.seed)
	return value.points==expected.points and value.obstacles==expected.obstacles and value.routes==expected.logistics_routes and value.variant_id==expected.variant_id and value.variant_title==expected.variant_title

static func _cargo(value:Variant,run:Dictionary,receipts:Dictionary)->bool:
	if not _keys(value,CARGO_KEYS) or run.battle.is_empty() or run.collected_mask!=run.required_mask or run.required_mask==0:return false
	for key in ["id","carrier","last_carrier","checkpoint","route_choice","pickup_revision"]:
		if not value[key] is int:return false
	if value.id!=run.attempts or value.id<1 or not value.phase is String or value.phase not in ["ground","carrying","delivered"] or not value.spawn_kind is String or value.spawn_kind not in ["completion","retry"]:return false
	if not _point(value.point,run.battle.obstacles) or not _point(value.origin,run.battle.obstacles) or value.carrier<-1 or value.carrier>=run.players or value.last_carrier<-1 or value.last_carrier>=run.players:return false
	if not value.regrab_until is Array or value.regrab_until.size()!=run.players or not value.nodes is Array or not value.source_charges is Array or value.source_charges.size()>3:return false
	var has_cooldown:=false
	for deadline in value.regrab_until:
		if not _finite(deadline) or float(deadline)<0 or float(deadline)>float(run.battle.elapsed)+1.00001:return false
		if float(deadline)>0:has_cooldown=true
	if (value.last_carrier==-1 and has_cooldown) or (value.last_carrier>=0 and not has_cooldown):return false
	var is_completion:bool=run.last_wave==receipts.ready_wave
	if value.spawn_kind!=("completion" if is_completion else "retry"):return false
	if is_completion:
		if value.source_charges.size()!=3 or run.battle.district_id!=receipts.ready_district:return false
		for charge in value.source_charges:
			if not _finite(charge) or float(charge)<0 or float(charge)>1.2:return false
		match int(run.battle.district_id):
			0:
				var completed:=0
				for charge in value.source_charges:
					if float(charge)>=1:completed+=1
				var index:int=run.battle.points.find(value.origin)
				if completed<2 or index<0 or float(value.source_charges[index])<1:return false
			1:
				if value.origin!=Vector2.ZERO or value.source_charges!=[0.0,0.0,0.0]:return false
			2:
				if value.origin!=run.battle.points[2] or float(value.source_charges[0])<1.2 or float(value.source_charges[1])<1.2:return false
	else:
		if not value.source_charges.is_empty():return false
		var origin:Vector2=run.battle.points[0] if run.battle.district_id==0 else (run.battle.routes[0].from.lerp(run.battle.routes[0].to,.5) if run.battle.district_id==1 else run.battle.points[2])
		if value.origin!=origin:return false
	if value.route_choice not in [-1,0,1] or value.pickup_revision<0 or value.pickup_revision>256:return false
	if value.route_choice==-1:
		return value.pickup_revision==0 and value.nodes.is_empty() and value.checkpoint==0 and value.phase=="ground" and value.carrier==-1 and value.last_carrier==-1 and not has_cooldown and not run.fulfilled and value.point==value.origin
	if value.pickup_revision<1 or value.nodes.size()!=2 or run.event_serial<value.pickup_revision:return false
	for node in value.nodes:
		if not _point(node,run.battle.obstacles):return false
	var options:Dictionary=Paths.options(run.battle,value.origin,value.source_charges,run.seed)
	if value.nodes!=(options.direct if value.route_choice==0 else options.outer):return false
	if value.phase=="delivered":
		return run.fulfilled and run.fulfilled_wave==run.last_wave and value.checkpoint==2 and value.carrier==-1 and value.point.distance_squared_to(value.nodes[1])<=1.44001
	if run.fulfilled or value.checkpoint<0 or value.checkpoint>1:return false
	if value.phase=="ground":return value.carrier==-1 and value.last_carrier>=0 and has_cooldown and run.event_serial>=value.pickup_revision+1
	return value.carrier>=0 and float(run.battle.elapsed)>=float(value.regrab_until[value.carrier])

static func _entitlement(value:Variant,wave:int,players:int)->bool:
	if not _keys(value,["kind","delivery_wave","actors","choices_per_actor","claimed","apply_rule"]):return false
	if not value.delivery_wave is int or value.delivery_wave!=wave or not value.choices_per_actor is int or value.choices_per_actor!=1 or not value.claimed is bool or not value.kind is String or value.kind!="extra_legal_draft_choice" or not value.apply_rule is String or value.apply_rule!=ENTITLEMENT_RULE or not value.actors is Array or value.actors.size()!=players:return false
	for index in players:
		if not value.actors[index] is int or value.actors[index]!=index:return false
	return true

static func _keys(value:Variant,keys:Array)->bool:return value is Dictionary and value.size()==keys.size() and value.has_all(keys)
static func _finite(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _point(value:Variant,walls:Array)->bool:
	if not value is Vector2 or not value.is_finite() or not Catalog.BOUNDS.has_point(value):return false
	for wall in walls:
		if wall.has_point(value):return false
	return true
