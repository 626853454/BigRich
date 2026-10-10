class_name FurDistrictView
extends Node3D

const Catalog=preload("res://scripts/furball/district_catalog.gd")
const Style=preload("res://scripts/furball/visual_style.gd")
var walls:Array[MeshInstance3D]=[]
var points:Array[Dictionary]=[]
var lanes:Array[Dictionary]=[]
var packages:Array[Dictionary]=[]
var last_state:Dictionary={}
var active_district:=-1
var caption_top:=292.0
const VIEW_NODE_LIMIT:=80

func _ready() -> void:
	# Fixed pools, even when districts change. Nothing is created per tick.
	for index in 2:
		var wall:=_box(Vector3.ONE,Color("be805e"),.4)
		wall.visible=false;walls.append(wall)
	for index in 3:
		var ring:=MeshInstance3D.new();var shape:=TorusMesh.new()
		shape.inner_radius=1.42;shape.outer_radius=1.58;shape.rings=32;shape.ring_segments=6
		ring.mesh=shape;ring.position.y=.09;ring.material_override=_material(Color("ffc374"),.3)
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ring)
		var post:=_box(Vector3(.72,.5,.55),Color("ffe0a0"),.35)
		var milk_mesh:=CylinderMesh.new();milk_mesh.top_radius=.28;milk_mesh.bottom_radius=.23
		milk_mesh.height=.60;milk_mesh.radial_segments=16
		var label:=Label3D.new();label.font=Style.font();label.font_size=48;label.pixel_size=.013
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=7
		label.outline_modulate=Color("202c48");label.no_depth_test=true;add_child(label)
		points.append({"ring":ring,"post":post,"label":label,"account_mesh":post.mesh,"milk_mesh":milk_mesh})
	for index in 3:
		var stripe:=_box(Vector3(27.5,.022,.14),Color("78d6e6"),.05)
		stripe.position=Vector3(0,.05,float(Catalog.LOGISTICS_LANES[index]));stripe.visible=false
		var warning:=_box(Vector3(27.5,.025,.5),Color("ffad75"),.20)
		warning.position=Vector3(0,.075,float(Catalog.LOGISTICS_LANES[index]));warning.visible=false
		var arrow:=Node3D.new();add_child(arrow)
		var shaft:=_box(Vector3(1.3,.05,.14),Color("ffac64"),.3)
		remove_child(shaft);arrow.add_child(shaft);shaft.position.x=-.1
		for side in [-1,1]:
			var tip:=_box(Vector3(.62,.05,.14),Color("ffac64"),.3)
			remove_child(tip);arrow.add_child(tip)
			tip.position=Vector3(.48,0,side*.19);tip.rotation.y=side*.7
		arrow.visible=false
		lanes.append({"stripe":stripe,"warning":warning,"arrow":arrow})
	for index in Catalog.PACKAGE_LIMIT:
		var parcel:=_box(Vector3(.62,.45,.62),Color("7ef5cf"),.45);parcel.visible=false
		for orientation in 2:
			var seal:=_box(Vector3(.66,.018,.09),Color("efffed"),.15)
			remove_child(seal);parcel.add_child(seal);seal.position.y=.233
			seal.rotation.y=orientation*PI/2
		var cart:=_box(Vector3(1.5,.45,.75),Color("dc706e"),.25);cart.visible=false
		var wheel_mesh:=CylinderMesh.new();wheel_mesh.top_radius=.15;wheel_mesh.bottom_radius=.15
		wheel_mesh.height=.10;wheel_mesh.radial_segments=10
		var wheel_material:=_material(Color("303449"))
		for x in [-.47,.47]:
			for z in [-.43,.43]:
				var wheel:=MeshInstance3D.new();wheel.mesh=wheel_mesh;wheel.material_override=wheel_material
				wheel.rotation.x=PI/2;wheel.position=Vector3(x,-.14,z)
				wheel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cart.add_child(wheel)
		var danger:=Label3D.new();danger.font=Style.font();danger.font_size=44;danger.pixel_size=.013
		danger.billboard=BaseMaterial3D.BILLBOARD_ENABLED;danger.outline_size=7;danger.no_depth_test=true
		danger.outline_modulate=Color("202c48");danger.modulate=Color("ffdf9e");danger.text="避让"
		danger.visible=false;add_child(danger)
		var sign:=Label3D.new();sign.font=Style.font();sign.font_size=44;sign.pixel_size=.013
		sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.outline_size=6;sign.no_depth_test=true
		sign.outline_modulate=Color("202c48");sign.visible=false;add_child(sign)
		packages.append({"parcel":parcel,"cart":cart,"sign":sign,"danger":danger})
	clear()
	if not last_state.is_empty():render(last_state)

func _box(size:Vector3,colour:Color,glow:float=0) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size
	node.mesh=shape;node.material_override=_material(colour,glow)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	return node

func _material(colour:Color,glow:float=0) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_color=colour;result.roughness=.9
	result.emission_enabled=glow>0;result.emission=colour;result.emission_energy_multiplier=glow
	return result

func clear() -> void:
	active_district=-1
	for wall in walls:wall.visible=false
	for point in points:
		point.ring.visible=false;point.post.visible=false;point.label.visible=false
	for lane in lanes:
		lane.stripe.visible=false;lane.warning.visible=false;lane.arrow.visible=false
	for package in packages:
		package.parcel.visible=false;package.cart.visible=false;package.sign.visible=false;package.danger.visible=false

func render(next_state:Dictionary) -> void:
	last_state=next_state
	if not is_node_ready():return
	clear()
	if next_state.is_empty():return
	active_district=int(next_state.get("district_id",-1))
	if active_district<0 or active_district>2:return
	var content:Dictionary=Catalog.entry(active_district)
	var colour:=Color(content.colour)
	if active_district==0:
		var rectangles:Array=next_state.get("obstacles",[])
		for index in mini(rectangles.size(),walls.size()):
			var rect:Rect2=rectangles[index];var center:=rect.get_center()
			walls[index].position=Vector3(center.x,.28,center.y)
			walls[index].scale=Vector3(rect.size.x,.56,rect.size.y);walls[index].visible=true
		for index in 3:_render_point(index,next_state.points[index],float(next_state.charges[index]),1.0,"账台 %d" % (index+1),colour)
	elif active_district==1:
		var routes:Array=next_state.logistics_routes
		for index in 3:
			var lane:Dictionary=lanes[index];var route:Dictionary=routes[index]
			var center:Vector2=(route.from+route.to)*.5
			var heading:Vector2=route.to-route.from
			var angle:float=-heading.angle()
			for stripe in [lane.stripe,lane.warning]:
				stripe.position=Vector3(center.x,stripe.position.y,center.y)
				stripe.scale.x=heading.length()/27.5;stripe.rotation.y=angle
			lane.stripe.visible=true
		var packets:Array=next_state.get("packets",[])
		for index in mini(packets.size(),packages.size()):
			var packet:Dictionary=packets[index];var slot:Dictionary=packages[index]
			var lane:Dictionary=lanes[clampi(int(packet.lane),0,2)]
			var route:Dictionary=routes[int(packet.lane)]
			var heading:Vector2=(route.to-route.from)*int(packet.direction)
			var center:Vector2=(route.from+route.to)*.5
			if packet.phase=="warning":
				lane.warning.visible=true;lane.arrow.visible=true
				var arrow_point:Vector2=packet.point+heading.normalized()*2.3
				lane.arrow.position=Vector3(arrow_point.x,.14,arrow_point.y)
				lane.arrow.rotation.y=-heading.angle()
				slot.sign.visible=true;slot.sign.text="车流预告 · 看箭头"
				# Keep the long sign off the initial central player pair and crossing hub.
				var caption_point:Vector2=packet.point+heading*.28+heading.normalized().orthogonal()*1.2
				slot.sign.position=Vector3(caption_point.x,1.1,caption_point.y)
			else:
				slot.parcel.visible=true;slot.parcel.position=Vector3(packet.point.x,.34,packet.point.y)
				slot.cart.visible=maxf(0,float(packet.age)-.8)*6.5<=heading.length()
				slot.cart.position=Vector3(packet.cart_point.x,.25,packet.cart_point.y)
				slot.cart.rotation.y=-heading.angle()
				slot.danger.visible=slot.cart.visible
				slot.danger.position=slot.cart.position+Vector3(0,.9,0)
				slot.sign.visible=true;slot.sign.text="接货"
				slot.sign.position=slot.parcel.position+Vector3(0,.55,0)
	elif active_district==2:
		for index in 2:_render_point(index,next_state.points[index],float(next_state.charges[index]),1.2,"奶站 %d" % (index+1),colour)
		_render_point(2,next_state.points[2],float(next_state.get("feast_progress",0)),.8,"合流开席" if bool(next_state.get("feast_ready",false)) else "先充满两站",Color("ffd784"))
		points[2].ring.visible=bool(next_state.get("feast_ready",false))
		points[2].ring.scale=Vector3(2.0/1.5,1,2.0/1.5)
		points[2].post.visible=false
		if not bool(next_state.get("feast_ready",false)):points[2].label.text="先充满两站"

func _render_point(index:int,point:Vector2,charge:float,target:float,title:String,colour:Color) -> void:
	var slot:Dictionary=points[index];var ready:=charge>=target
	slot.ring.visible=true;slot.ring.position=Vector3(point.x,.09,point.y)
	slot.ring.scale=Vector3.ONE
	slot.ring.material_override.albedo_color=Color("f8ffbd") if ready else colour
	slot.post.visible=true;slot.post.position=Vector3(point.x,.25,point.y)
	slot.post.mesh=slot.milk_mesh if active_district==2 else slot.account_mesh
	slot.post.scale=Vector3(1,.4+clampf(charge/target,0,1)*.6,1)
	slot.post.material_override.albedo_color=Color("f8ffbd") if ready else colour
	slot.label.visible=true;slot.label.position=Vector3(point.x,2.1,point.y)
	slot.label.text=("%s ✓" % title) if ready else ("%s %d%%" % [title,int(clampf(charge/target,0,1)*100)])
	# Keep task captions below the actual rule/order/challenge header. Only
	# their presentation moves; task points, rings and interaction stay put.
	var camera:Camera3D=get_viewport().get_camera_3d()
	if camera!=null:
		var screen:Vector2=camera.unproject_position(slot.label.global_position)
		if screen.y<caption_top:
			var depth:float=-camera.to_local(slot.label.global_position).z
			screen.y=caption_top
			if depth>0:slot.label.global_position=camera.project_position(screen,depth)
