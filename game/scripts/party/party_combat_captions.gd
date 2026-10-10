class_name FurPartyCombatCaptions
extends RefCounted
## Presentation only: fixed-pool merge policy and bounded screen placement.
## No model/RNG/timer writes; caller owns the existing six priority Label3Ds.
const ACTIONS := {"ready":0,"link":1,"pot_wave":3,"barrage_ready":3,"chain_ready":3}
const SHORT_TEXT := {"ready":"蓄能就绪","link":"锅印兑现","pot_wave":"锅浪开路","barrage_ready":"追加齐射"}
const MAX_OCCUPIED := 24
const HEAD_HALF_SIZE := Vector2(48,52)
const OFFSETS := [Vector2(90,-30),Vector2(140,-60),Vector2(210,-30),Vector2(140,60),Vector2(210,60),Vector2(90,-110),Vector2(-140,-60),Vector2(-210,-30),Vector2(-210,60),Vector2(140,-140),Vector2(-140,-140),Vector2(0,140)]

static func classify(event:Dictionary,text:String)->Dictionary:
	var kind:String=str(event.get("kind",""))
	var actor:Variant=event.get("owner",-1)
	var owner:int=actor if typeof(actor)==TYPE_INT and actor>=-1 and actor<=1 else -1
	if ACTIONS.has(kind):
		return {"key":"party_action-%d"%owner,"rank":ACTIONS[kind],"text":("P%d·"%[owner+1] if owner>=0 else "")+SHORT_TEXT.get(kind,"连兑引爆")}
	# Damage/critical/authority feedback never share an action merge key.
	var critical:bool=kind=="hurt" or kind in ["payoff_interrupt","cart_impact","district_complete","order_goods","order_fulfilled"] or (kind=="hit" and event.get("extra",false)==true)
	return {"key":"%s-%d"%[kind,owner],"rank":4 if critical else 2,"text":text}

static func should_replace(current:Dictionary,incoming:Dictionary)->bool:
	return current.get("key","")!=incoming.get("key","") or int(incoming.get("rank",-1))>=int(current.get("rank",-1))

static func _finite2(value:Vector2)->bool:
	return is_finite(value.x) and is_finite(value.y)

static func _finite3(value:Vector3)->bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func _text_size(text:String)->Vector2:
	# Conservative CJK bounds for the existing font42/pixel_size.012 pool.
	# Exact glyph/perspective size is deliberately not claimed.
	var lines:PackedStringArray=text.split("\n")
	var longest:int=0
	for i in mini(lines.size(),3):longest=maxi(longest,mini(lines[i].length(),24))
	return Vector2(clampf(longest*22.0+24.0,96.0,360.0),minf(lines.size(),3)*32.0+16.0)

static func screen_rect(camera:Camera3D,world:Vector3,text:String)->Rect2:
	if not is_instance_valid(camera) or not _finite3(world) or camera.is_position_behind(world):return Rect2()
	var center:Vector2=camera.unproject_position(world)
	if not _finite2(center):return Rect2()
	var size:Vector2=_text_size(text)
	return Rect2(center-size*.5,size)

static func _occupied_rect(value:Variant,camera:Camera3D)->Rect2:
	if value is Rect2:
		return value if _finite2(value.position) and _finite2(value.size) and value.size.x>=0 and value.size.y>=0 else Rect2()
	var node:Variant=value
	if value is Dictionary:
		if float(value.get("life",0))<=0:return Rect2()
		node=value.get("node",null)
	if node is Label3D and is_instance_valid(node) and node.visible:
		return screen_rect(camera,node.global_position,node.text)
	return Rect2()

static func _overlap(rect:Rect2,blocked:Array[Rect2])->float:
	var area:float=0.0
	for other in blocked:
		if rect.intersects(other):area+=rect.intersection(other).get_area()
	return area

static func place(view:Node3D,camera:Camera3D,heroes:Array,point:Vector3,owner:int,occupied:Array,labeltext:String)->Vector3:
	if not is_instance_valid(view) or not is_instance_valid(camera) or not view.is_inside_tree() or not camera.is_inside_tree() or not _finite3(point):return point if _finite3(point) else Vector3.ZERO
	var world:Vector3=view.to_global(point)
	if camera.is_position_behind(world):return point
	var anchor:Vector2=camera.unproject_position(world)
	var depth:float=-camera.to_local(world).z
	var viewport_size:Vector2=camera.get_viewport().get_visible_rect().size
	if not _finite2(anchor) or not _finite2(viewport_size) or depth<=.01 or viewport_size.x<4 or viewport_size.y<4:return point
	var requested_top:float=292.0
	# The production View exposes this real expanded-HUD boundary.
	for property in view.get_property_list():
		if property.name=="payoff_caption_top":requested_top=maxf(292.0,float(view.get("payoff_caption_top")));break
	var top:float=minf(requested_top,viewport_size.y*.38)
	var bottom:float=maxf(top+24.0,viewport_size.y-220.0)
	bottom=minf(bottom,viewport_size.y-8.0)
	var size:Vector2=_text_size(labeltext)
	size.x=minf(size.x,viewport_size.x-16.0)
	size.y=minf(size.y,maxf(8.0,bottom-top))
	var min_x:float=size.x*.5+8.0;var max_x:float=viewport_size.x-size.x*.5-8.0
	var min_y:float=top+size.y*.5;var max_y:float=bottom-size.y*.5
	var blocked:Array[Rect2]=[]
	for i in mini(heroes.size(),2):
		var hero:Variant=heroes[i]
		var root:Variant=hero.get("root",null) if hero is Dictionary else hero
		if not root is Node3D or not is_instance_valid(root):continue
		var head:Vector3=root.global_position+Vector3(0,2.5,0)
		if camera.is_position_behind(head):continue
		var screen:Vector2=camera.unproject_position(head)
		if _finite2(screen):blocked.append(Rect2(screen-HEAD_HALF_SIZE,HEAD_HALF_SIZE*2.0))
	for i in mini(occupied.size(),MAX_OCCUPIED):
		var rect:Rect2=_occupied_rect(occupied[i],camera)
		if rect.has_area():blocked.append(rect.grow(8.0))
	var side:float=-1.0 if owner==0 else 1.0
	var best:Vector2=Vector2(clampf(anchor.x+side*140.0,min_x,max_x),clampf(anchor.y-60.0,min_y,max_y))
	var best_score:float=INF
	for offset in OFFSETS:
		var candidate:Vector2=Vector2(clampf(anchor.x+offset.x*side,min_x,max_x),clampf(anchor.y+offset.y,min_y,max_y))
		var rect:=Rect2(candidate-size*.5,size)
		var collision:float=_overlap(rect,blocked)
		# First unobstructed owner-side candidate wins. If space is exhausted,
		# keep the minimum overlap rather than allocating another label/node.
		if collision<=.001:best=candidate;break
		var score:float=collision+candidate.distance_squared_to(anchor)*.0001
		if score<best_score:best=candidate;best_score=score
	var result:Vector3=view.to_local(camera.project_position(best,depth))
	return result if _finite3(result) else point
