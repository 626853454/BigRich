class_name FurUIEchoWorld
extends SubViewportContainer
## Snapshot-only toy board. No movement, score or route authority lives here.
var view:SubViewport
var _root:Node3D
var _tiles:Array[MeshInstance3D]=[]
var _players:Array[Node3D]=[]
var _ghosts:Array[Node3D]=[]
var _landmarks:Node3D
var _hover:MeshInstance3D
var _state:Dictionary={}
var _ghost_positions:Array=[]
var _lit:Array=[]
var _motion:Tween
var _materials:Dictionary={}
var _built:=false
var _landmark_variant:int=-1
var _plate_marks:Array[MeshInstance3D]=[]
var _delivery_marks:Array[MeshInstance3D]=[]
const SPACING:=1.4
func _ready()->void:
	stretch=true;mouse_filter=Control.MOUSE_FILTER_IGNORE
	view=SubViewport.new();view.size=Vector2i(930,530);view.transparent_bg=false;view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE;view.msaa_3d=Viewport.MSAA_4X;add_child(view)
	_root=Node3D.new();view.add_child(_root)
	var world:=WorldEnvironment.new();world.environment=Environment.new();FurArtLighting.apply(world.environment,2);FurAtelierLighting.studio(world.environment);world.environment.sky.sky_material.energy_multiplier=.33;world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("b8cbdc");world.environment.ssao_radius=.28;world.environment.ssao_intensity=.75;_root.add_child(world)
	var key:=DirectionalLight3D.new();FurArtLighting.key(key);key.light_energy=1.50;key.directional_shadow_max_distance=24;_root.add_child(key)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-35,150,0);fill.light_energy=.15;fill.light_color=Color("d5e6f6");_root.add_child(fill)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=36;camera.position=Vector3(1.5,6.8,10.5);_root.add_child(camera);camera.look_at(Vector3(0,.55,-1.0));camera.current=true
	var case_model:=FurUIModelAssets.instance("echo_case");_root.add_child(case_model)
	var clock_tower:=FurTravelArtAssets.instance("echo_clock_sculpted_v2",true);clock_tower.position=Vector3(-3.45,-.78,-5.10);clock_tower.scale=Vector3.ONE*1.18;_root.add_child(clock_tower)
	var time_gate:=FurTravelArtAssets.instance("echo_time_gate_atelier");time_gate.position=Vector3(3.30,-.78,-4.60);time_gate.scale=Vector3.ONE*1.04;_root.add_child(time_gate)
	FurEchoVista.build(_root)
	for y in 5:
		for x in 5:
			var tile:=MeshInstance3D.new();tile.name="GlazedTile_%d_%d"%[x,y];tile.mesh=FurUIModelAssets.tile_mesh();tile.position=_position(Vector2i(x,y));tile.material_override=_material(Color("f5eddf"));_root.add_child(tile);_tiles.append(tile)
	_landmarks=Node3D.new();_root.add_child(_landmarks)
	for i in 2:
		var pawn:=FurPartyPawn.new();pawn.build(i);pawn.scale=Vector3.ONE*.63;_root.add_child(pawn);pawn.set_process(false);_players.append(pawn)
		var ghost:=Node3D.new();ghost.scale=Vector3.ONE*.62;_root.add_child(ghost);_ghosts.append(ghost)
		var material:=StandardMaterial3D.new();material.albedo_color=Color(.47,.56,.79,.28);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
		_materials["ghost_%d"%i]=material
		# Share only immutable silhouette meshes; ghosts need no skin/fur shaders,
		# animation resources or a second character controller.
		for source in pawn.find_children("*","MeshInstance3D",true,false):
			if str(source.name).contains("Coat") or str(source.name).contains("Fibre"):continue
			var mesh:=MeshInstance3D.new();mesh.mesh=source.mesh;mesh.transform=pawn.global_transform.affine_inverse()*source.global_transform;mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ghost.add_child(mesh)
	_hover=_block("Move destination preview",Vector3.ZERO,Vector3(1.24,.025,1.24),Color("f6d789"),_root);_hover.hide()
	_built=true
	if not _state.is_empty():_sync(false)
func configure(snapshot:Dictionary,ghosts:Array,lit:Array)->void:
	_state=snapshot.duplicate(true);_ghost_positions=ghosts.duplicate();_lit=lit.duplicate()
	if _built:_sync(true)
func _position(point:Vector2i)->Vector3:return Vector3((point.x-2)*SPACING,.14,(point.y-2)*SPACING)
func _material(color:Color)->StandardMaterial3D:
	var key:String=color.to_html()
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new();mat.albedo_color=color.srgb_to_linear();mat.roughness=.32;mat.metallic=0;mat.clearcoat_enabled=true;mat.clearcoat=.18;mat.clearcoat_roughness=.27;_materials[key]=mat
	return _materials[key]
func _block(title:String,at:Vector3,extent:Vector3,color:Color,parent:Node)->MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.name=title;mesh.mesh=FurChapterPreview3D._bevel_box();mesh.scale=extent*.5;mesh.position=at;mesh.material_override=_material(color);parent.add_child(mesh);return mesh
func _mark(value:String,at:Vector3,color:Color)->MeshInstance3D:
	var label:=MeshInstance3D.new();var glyph:=TextMesh.new();glyph.font=preload("res://assets/art/sevenhour_v1/NotoSansSC-Bold-Outline.ttf");glyph.font_size=24;glyph.pixel_size=.024;glyph.depth=.004;glyph.curve_step=.7;glyph.text=value;glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;glyph.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.mesh=glyph;label.material_override=_material(color);label.position=at;label.rotation_degrees.x=-90;label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_landmarks.add_child(label)
	return label
func _build_landmarks()->void:
	for child in _landmarks.get_children():_landmarks.remove_child(child);child.queue_free()
	_plate_marks.clear();_delivery_marks.clear();_landmark_variant=int(_state.variant)
	for wall in _state.walls:
		var obstacle:=FurUIModelAssets.instance("echo_obstacle");obstacle.position=_position(wall)+Vector3(0,.13,0);_landmarks.add_child(obstacle)
	for i in 2:
		var pressure_ring:=FurUIModelAssets.instance("echo_pressure_ring");pressure_ring.position=_position(_state.plates[i])+Vector3(0,.13,0);_landmarks.add_child(pressure_ring)
		_plate_marks.append(_mark("AB"[i],_position(_state.plates[i])+Vector3(0,.14,0),Color("574e5a")))
		var at:Vector3=_position(_state.delivery_points[i])+Vector3((-.34 if i==0 else .34) if _state.delivery_points[0]==_state.delivery_points[1] else 0,0,0)
		var mailbox:=FurTravelArtAssets.instance("echo_mailbox_atelier");mailbox.position=at+Vector3(0,.13,0);mailbox.scale=Vector3.ONE*.88;_landmarks.add_child(mailbox)
		_delivery_marks.append(_mark(["柯","泡"][i],at+Vector3(0,.92,0),Color("325a61")))
func _sync(animate:bool)->void:
	if is_instance_valid(_motion):_motion.kill()
	_motion=null
	if _landmark_variant!=int(_state.variant):_build_landmarks()
	for y in 5:
		for x in 5:
			var cell:=Vector2i(x,y);var color:=Color("f5eddf");var plate:int=_state.plates.find(cell);var at:Vector3=_position(cell)
			if cell in _state.walls:color=Color("a9a0b5")
			if plate>=0:
				color=[Color("e3b190"),Color("91b9bf")][plate] if not _lit[plate] else Color("a4d2b6")
				_plate_marks[plate].material_override=_material(Color("286052") if _lit[plate] else Color("574e5a"))
			_tiles[y*5+x].material_override=_material(color)
	for i in 2:
		var delivery_text:String="✓" if _state.delivered[i] else ["柯","泡"][i]
		var glyph:TextMesh=_delivery_marks[i].mesh as TextMesh
		if glyph.text!=delivery_text:glyph.text=delivery_text
		var destination:Vector3=_position(_state.positions[i])+Vector3(0,.13,0)
		if _state.positions[0]==_state.positions[1]:destination.x+=-.25 if i==0 else .25
		if animate and not FurUIPreferences.reduced_motion:
			if not is_instance_valid(_motion):_motion=create_tween();_motion.set_parallel(true);_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_motion.tween_property(_players[i],"position",destination,.20)
		else:_players[i].position=destination
		_ghosts[i].visible=i<_ghost_positions.size()
		if _ghosts[i].visible:_ghosts[i].position=_position(_ghost_positions[i])+Vector3(.15,.14,.16)
	_hover.hide()
	if is_instance_valid(_motion):
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;_motion.finished.connect(func():view.render_target_update_mode=SubViewport.UPDATE_ONCE)
	else:view.render_target_update_mode=SubViewport.UPDATE_ONCE
func preview_move(point:Vector2i,enabled:bool)->void:
	if not _built:return
	_hover.visible=enabled
	if enabled:_hover.position=_position(point)+Vector3(0,.142,0)
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
