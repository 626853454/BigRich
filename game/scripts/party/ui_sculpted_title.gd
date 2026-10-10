class_name FurUISculptedTitle
extends Control
## Real extruded Blender typography. Frozen viewport, not a concept screenshot.
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var view:=SubViewport.new();view.size=Vector2i(1000,220);view.own_world_3d=true;view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(view)
	var picture:=TextureRect.new();picture.texture=view.get_texture();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(picture)
	var stage:=Node3D.new();view.add_child(stage)
	var title:=FurTravelArtAssets.instance("adventure_title",true);title.rotation=Vector3(PI*.5+.04,-.035,-.010);stage.add_child(title)
	var env:=WorldEnvironment.new();env.environment=Environment.new();FurArtLighting.apply(env.environment);FurAtelierLighting.studio(env.environment);env.environment.sky.sky_material.energy_multiplier=.5;env.environment.ssao_enabled=false;env.environment.glow_enabled=false;stage.add_child(env)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-28,0);key.light_energy=1.7;key.light_color=Color("fff1d5");stage.add_child(key)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,145,0);fill.light_energy=.55;fill.light_color=Color("c7e7f0");stage.add_child(fill)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=5.6;camera.position=Vector3(0,.48,8);stage.add_child(camera);camera.look_at(Vector3(0,.48,0));camera.current=true
