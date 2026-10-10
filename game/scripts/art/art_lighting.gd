class_name FurArtLighting
extends RefCounted

# A shared real sky/IBL profile. Geometry and user-interface images are separate.
static func apply(environment:Environment,chapter:int=0)->void:
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("659dc5")
	sky_material.sky_horizon_color=Color("a8cdd8")
	sky_material.ground_bottom_color=Color("414357")
	sky_material.ground_horizon_color=Color("d4d7c4")
	sky_material.sky_curve=.22;sky_material.ground_curve=.35
	sky_material.sun_angle_max=8.0;sky_material.sun_curve=.12
	var sky:=Sky.new();sky.sky_material=sky_material;sky.radiance_size=Sky.RADIANCE_SIZE_256
	environment.sky=sky
	environment.background_mode=Environment.BG_SKY
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_energy=.23
	environment.ambient_light_sky_contribution=.78
	environment.tonemap_mode=Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure=1.0
	environment.tonemap_white=3.0
	environment.adjustment_enabled=true;environment.adjustment_contrast=1.12
	environment.adjustment_saturation=1.12;environment.adjustment_brightness=.96
	# Forward+ has genuine contact occlusion. Compatibility keeps sky/materials.
	var forward:bool=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.ssao_enabled=forward
	environment.ssao_radius=.7;environment.ssao_intensity=1.1
	environment.ssao_power=1.2;environment.ssao_detail=.45
	environment.glow_enabled=forward
	environment.glow_intensity=.16;environment.glow_strength=.35
	if chapter==1:
		environment.ambient_light_energy=.38
		environment.tonemap_exposure=.98
	elif chapter==2:
		environment.ambient_light_energy=.34

static func key(light:DirectionalLight3D)->void:
	light.rotation_degrees=Vector3(-51,-38,0)
	light.light_color=Color("ffe9cc");light.light_energy=1.35
	# Actual same-camera comparison found the wide low-sample filter made a
	# visible screen-door pattern on otherwise untextured stone and fur.
	# Keep shadows and use a bounded radius; project high-quality PCF smooths
	# the penumbra. See shadow-filter-native-v1; performance still needs a gate.
	light.shadow_enabled=true;light.shadow_blur=1.0
	# Near-camera turntable A/B removed self-shadow striping at .10/1.0 while
	# preserving cast contact shadows; old .025/.7 was insufficient.
	light.shadow_bias=.10;light.shadow_normal_bias=1.0
	light.directional_shadow_max_distance=90.0
	# Two cascades keep the local board/arena readable without redrawing the
	# same detailed characters and island geometry through four shadow splits.
	light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_blend_splits=true
