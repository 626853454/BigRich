class_name FurUIMahjongTilePreview
extends Control
## A larger read-only view of an already visible hand/public discard tile.
const Tiles=preload("res://scripts/party/mahjong_tile_geometry.gd")
const Surfaces=preload("res://scripts/party/mahjong_surface_materials.gd")
var _view:SubViewport
var _face:MeshInstance3D
var _stage:Node3D
var _type:int=-1
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(115,150)
func _ready()->void:
	_view=SubViewport.new();_view.size=Vector2i(230,300);_view.transparent_bg=true;_view.own_world_3d=true;_view.msaa_3d=Viewport.MSAA_4X;_view.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(_view)
	var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.texture=_view.get_texture();picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(picture)
	_stage=Node3D.new();_view.add_child(_stage);_stage.rotation_degrees=Vector3(-5,-18,4)
	var body:=MeshInstance3D.new();body.mesh=Tiles.body();body.scale=Vector3(.42,.60,.18);body.material_override=Surfaces.surface("ceramic",Color("faf4e4"));_stage.add_child(body)
	var back:=MeshInstance3D.new();back.mesh=Tiles.body();back.scale=Vector3(.40,.57,.09);back.position.z=-.13;back.material_override=Surfaces.surface("ceramic",Color("25645a"));_stage.add_child(back)
	_face=MeshInstance3D.new();_face.material_override=Tiles.material();_stage.add_child(_face)
	var world:=WorldEnvironment.new();world.environment=Environment.new();FurArtLighting.apply(world.environment,1);world.environment.ssao_enabled=false;world.environment.glow_enabled=false;_view.add_child(world)
	var key:=DirectionalLight3D.new();FurArtLighting.key(key);key.light_energy=1.65;key.shadow_enabled=false;_view.add_child(key)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,160,0);fill.light_energy=.28;_view.add_child(fill)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.8;camera.position=Vector3(0,.10,4);_view.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
	show_tile(_type)
func show_tile(type_index:int)->void:
	_type=type_index;visible=type_index>=0 and type_index<34
	if is_instance_valid(_face) and visible:_face.mesh=Tiles.face(type_index);_view.render_target_update_mode=SubViewport.UPDATE_ONCE
