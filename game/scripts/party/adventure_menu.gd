class_name FurAdventureMenu
extends Control
## Real invitation stage and live 3D destination cards share gameplay assets.
signal chapter_chosen(index:int)
signal full_journey
signal resume_journey
signal mode_chosen(index:int)
signal settings_requested
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
const Preview=preload("res://scripts/party/chapter_preview_3d.gd")
const Icons=preload("res://scripts/party/ui_icons.gd")
var mode:int=0
var chapter_buttons:Array[Button]=[]
var mode_buttons:Array[Button]=[]
var _view:SubViewport
var _clock:float=0.0
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	theme=Palette.create();FurUIPreferences.ensure_loaded();_build_stage();_build_controls()
	if not FurUIPreferences.reduced_motion:
		modulate.a=0.0;create_tween().tween_property(self,"modulate:a",1.0,.22).set_trans(Tween.TRANS_SINE)
func _label(value:String,at:Vector2,extent:Vector2,font_size:int,colour:Color=Palette.INK,parent:Node=null)->Label:
	var label:=Label.new();label.text=value;label.position=at;label.size=extent;label.add_theme_font_override("font",FurVisualStyle.font());label.add_theme_font_size_override("font_size",font_size);label.add_theme_font_override("font",FurChapterUITheme.font(font_size>=22));label.add_theme_color_override("font_color",colour);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(parent if parent!=null else self).add_child(label);return label
func _button(value:String,at:Vector2,extent:Vector2,kind:String,callback:Callable,icon:String="")->Button:
	var button:=Button.new();button.text=value;button.position=at;button.size=extent;button.add_theme_font_size_override("font_size",22);Palette.apply_button(button,kind,icon);button.pressed.connect(callback);add_child(button);return button
func _build_controls()->void:
	# One invitation, three destinations, one primary call to action.
	var panel:=Panel.new();panel.position=Vector2(768,87);panel.size=Vector2(782,772)
	var invitation:=StyleBoxTexture.new();invitation.texture=load("res://assets/ui/eighthour_v1/runtime/invitation_arch.png");panel.add_theme_stylebox_override("panel",invitation);add_child(panel)
	var title:=FurUISculptedTitle.new();title.position=Vector2(54,40);title.size=Vector2(664,142);add_child(title)
	_label("海 风   ·   玩 具   ·   远 行",Vector2(138,184),Vector2(460,30),20,Color("265964"))
	_label("和重要的伙伴，一起去看更大的世界",Vector2(91,221),Vector2(610,34),18,Color("204e57"))
	var crest:=Icons.view("compass",Vector2(87,87));crest.position=Vector2(1115,88);add_child(crest)
	var heading:=_label("下一站，一起冒险",Vector2(818,188),Vector2(683,56),38)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=_label("不同的地方 · 同样的伙伴",Vector2(820,246),Vector2(677,28),18,Palette.MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var titles:=["海岛远征","云顶雀馆","时光空港"]
	var subtitles:=["经营 × 合作割草","实体麻将 × 流派","记录 × 双人接力"]
	var emblems:=["compass","mahjong","clock"]
	for i in 3:
		var card:=Button.new();card.position=Vector2(815+i*234,294);card.size=Vector2(220,278);card.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;card.focus_mode=Control.FOCUS_ALL
		var normal:StyleBoxTexture=FurUICeramicFrame.style()
		var hover:=normal.duplicate() as StyleBoxTexture;hover.modulate_color=Color(1.035,1.025,1.0)
		var pressed:=normal.duplicate() as StyleBoxTexture;pressed.modulate_color=Color(.95,.96,.94)
		card.add_theme_stylebox_override("normal",normal);card.add_theme_stylebox_override("hover",hover);card.add_theme_stylebox_override("pressed",pressed);card.add_theme_stylebox_override("focus",Palette.focus_style());card.pressed.connect(func():chapter_chosen.emit(i));add_child(card);FurUIContactShadow.attach(card,true);chapter_buttons.append(card)
		var preview:=Preview.new();preview.configure(i);preview.position=Vector2(9,10);preview.size=Vector2(202,182);card.add_child(preview)
		card.mouse_entered.connect(preview.set_emphasis.bind(true));card.mouse_exited.connect(preview.set_emphasis.bind(false));card.focus_entered.connect(preview.set_emphasis.bind(true));card.focus_exited.connect(preview.set_emphasis.bind(false))
		var number:=_label("0%d"%(i+1),Vector2(18,18),Vector2(36,26),15,Color("fff9e8"),card);number.add_theme_color_override("font_shadow_color",Palette.INK);number.add_theme_constant_override("shadow_offset_y",1)
		var icon:=Icons.view(emblems[i],Vector2(29,29));icon.position=Vector2(12,204);card.add_child(icon)
		_label(titles[i],Vector2(47,204),Vector2(165,34),24,Palette.INK,card)
		var desc:=_label(subtitles[i],Vector2(14,244),Vector2(194,24),15,Palette.MUTED,card);desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.tooltip_text="试玩第%d章：%s。不改变完整旅程的规则。"%[i+1,titles[i]]
	var start:=_button("开始完整旅程  →",Vector2(820,604),Vector2(445,78),"primary",func():full_journey.emit(),"compass");start.add_theme_font_size_override("font_size",27);start.add_theme_constant_override("icon_max_width",50)
	_button("继续旅程 →",Vector2(1289,615),Vector2(212,59),"ivory",func():resume_journey.emit()).add_theme_font_size_override("font_size",21)
	_label("选择游玩方式",Vector2(825,706),Vector2(435,28),18,Palette.MUTED)
	for i in 2:
		var option:=_button("1人 + 泡泡AI" if i==0 else "2名本地玩家",Vector2(823+i*248,748),Vector2(232,54),"selected" if mode==i else "ivory",_choose_mode.bind(i));option.add_theme_font_size_override("font_size",19);mode_buttons.append(option);option.icon=Icons.get_icon("check") if mode==i else null;option.expand_icon=true;option.add_theme_constant_override("icon_max_width",25)
		option.tooltip_text="泡泡会自己掷骰、选路和选择手牌" if i==0 else "两人使用同一台电脑，分别控制小柯和泡泡"
	_button("设置",Vector2(1360,754),Vector2(135,44),"quiet",func():settings_requested.emit(),"settings").add_theme_font_size_override("font_size",17)
	_label("普通格自由探索 · 挑战站开启玩法",Vector2(107,818),Vector2(595,28),18,Color("214c54"))
func _choose_mode(index:int)->void:
	mode=index
	for i in mode_buttons.size():
		Palette.apply_button(mode_buttons[i],"selected" if i==mode else "ivory");mode_buttons[i].icon=Icons.get_icon("check") if i==mode else null;mode_buttons[i].add_theme_constant_override("icon_max_width",25)
	mode_chosen.emit(index)
func _part(stage:Node3D,mesh:Mesh,at:Vector3,colour:Color,rough:float=.75)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;var m:=StandardMaterial3D.new();m.albedo_color=colour;m.roughness=rough;node.material_override=m;stage.add_child(node);return node
func _build_stage()->void:
	_view=SubViewport.new();_view.name="ActualCharacterInvitationStage";_view.size=Vector2i(1600,900);_view.own_world_3d=true;_view.msaa_3d=Viewport.MSAA_4X;_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(_view)
	var texture:=TextureRect.new();texture.texture=_view.get_texture();texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(texture)
	var stage:=Node3D.new();_view.add_child(stage)
	var world:=WorldEnvironment.new();world.environment=Environment.new();FurArtLighting.apply(world.environment);FurAtelierLighting.studio(world.environment);world.environment.sky.sky_material.energy_multiplier=.30;world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("a8d5e3");world.environment.ssao_radius=.35;world.environment.ssao_intensity=.85;stage.add_child(world)
	var key:=DirectionalLight3D.new();FurArtLighting.key(key);key.light_energy=1.40;key.rotation_degrees=Vector3(-38,-35,0);key.directional_shadow_max_distance=30;stage.add_child(key)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,145,0);fill.light_color=Color("c8e4f4");fill.light_energy=.12;stage.add_child(fill)
	var terrace:=FurTravelArtAssets.instance("harbor_invitation_terrace");terrace.position=Vector3(-4.4,-.07,.15);stage.add_child(terrace)
	var water:=FurPartyWaterSurface.sea(stage,Vector2(70,42),-1.35,[{"center":Vector3(-4.4,0,.15),"radius":Vector2(4.5,3.2)}]);water.material_override.set_shader_parameter("deep_color",Color("397f95"));water.material_override.set_shader_parameter("shelf_color",Color("89c5b4"));water.material_override.set_shader_parameter("ripple_normal_strength",1.15)
	var house:=FurHarborCraftedAssets.house(Vector3(2.55,1.45,1.8));house.position=Vector3(-8.1,0,-1.80);house.rotation.y=.18;stage.add_child(house)
	var lighthouse:=FurHarborCraftedAssets.prop("lighthouse_crafted");lighthouse.position=Vector3(-7.7,-.95,-16.0);lighthouse.scale=Vector3.ONE*.90;stage.add_child(lighthouse)
	var far_isle:=FurTravelArtAssets.instance("harbor_invitation_terrace");far_isle.position=Vector3(-4.3,-1.0,-16.6);far_isle.scale=Vector3(1.10,.66,.90);stage.add_child(far_isle)
	var far_house:=FurHarborCraftedAssets.house(Vector3(2.2,1.45,1.4));far_house.position=Vector3(-4.4,-.9,-17.0);stage.add_child(far_house)
	var lamp:=FurTravelArtAssets.instance("maritime_lantern");lamp.position=Vector3(-1.55,.015,1.95);lamp.scale=Vector3.ONE*1.05;stage.add_child(lamp)
	var dock:=FurTravelArtAssets.instance("harbor_dock_module");dock.position=Vector3(-8.2,-.65,2.7);dock.rotation.y=-.44;stage.add_child(dock)
	var boat:=FurHarborCraftedAssets.prop("harbor_sailboat_crafted");boat.position=Vector3(-9.8,-1.19,1.0);boat.scale=Vector3.ONE*.75;boat.rotation.y=.3;stage.add_child(boat)
	for i in 2:
		var pawn:=FurPartyPawn.new();pawn.build(i);pawn.scale=Vector3.ONE*1.53;pawn.position=Vector3(-5.20+i*2.65,0,1.05+i*.05);pawn.rotation.y=.17 if i==0 else -.14;stage.add_child(pawn);pawn.rotation.z=.025 if i==0 else -.018
	for at in [Vector3(-11,3.5,-24),Vector3(3.4,5.5,-30),Vector3(-3.5,4.2,-34)]:
		var cloud:=FurTravelArtAssets.instance("cloud_bank_atelier");cloud.position=at;cloud.scale=Vector3(2.5,2.7,2.4);stage.add_child(cloud)
	for i in 3:
		var house_far:=FurHarborCraftedAssets.house(Vector3(1.65,1.35,1.35));house_far.position=Vector3(-8.6+i*3.2,-.90,-18.9-float(i%2));house_far.rotation.y=.10-.13*i;stage.add_child(house_far)
	for data in [[Vector3(-8.3,-.08,1.0),1.3],[Vector3(-1.4,-.08,2.5),.8],[Vector3(-6.8,-.04,-2.0),.85]]:
		var shrub:=FurCoastalSculptAssets.instance("coastal_leaf_shrub");shrub.position=data[0];shrub.scale=Vector3.ONE*data[1];stage.add_child(shrub)
	var tree:=FurCoastalSculptAssets.instance("island_tree_recessed_canopy");tree.position=Vector3(-9.65,-.12,-.5);tree.scale=Vector3.ONE*1.10;stage.add_child(tree)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.fov=49.0;camera.position=Vector3(0,6.8,17);stage.add_child(camera);camera.look_at(Vector3(0,1.8,0));camera.current=true
	var lens:=CameraAttributesPractical.new();lens.dof_blur_far_enabled=true;lens.dof_blur_far_distance=23.0;lens.dof_blur_far_transition=15.0;lens.dof_blur_amount=.038;camera.attributes=lens
func _process(delta:float)->void:
	_clock+=delta
	if is_instance_valid(_view) and _clock>=1.0/30.0:
		_view.render_target_update_mode=SubViewport.UPDATE_ONCE;_clock=fmod(_clock,1.0/30.0)
