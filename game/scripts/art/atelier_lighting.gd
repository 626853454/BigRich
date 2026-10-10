class_name FurAtelierLighting
extends RefCounted
## Physical illumination inputs, kept distinct from the visible backdrop.
const STUDIO=preload("res://assets/art/eighthour_v1/studio_small_09_1k.hdr")
const DAYLIGHT=preload("res://assets/art/eighthour_v1/kloppenheim_06_puresky_2k.hdr")
static func studio(environment:Environment)->void:
	var material:=PanoramaSkyMaterial.new();material.panorama=STUDIO;material.energy_multiplier=.65
	var sky:=Sky.new();sky.sky_material=material;sky.radiance_size=Sky.RADIANCE_SIZE_256;sky.process_mode=Sky.PROCESS_MODE_QUALITY
	environment.sky=sky;environment.sky_rotation=Vector3(0,1.05,0)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;environment.ambient_light_sky_contribution=1.0
	environment.ambient_light_energy=1.0;environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode=Environment.TONE_MAPPER_AGX;environment.tonemap_exposure=1.0
	environment.adjustment_enabled=false
	environment.ssao_enabled=true;environment.ssao_radius=.22;environment.ssao_intensity=.72;environment.ssao_power=1.0
	environment.glow_enabled=false
static func daylight(environment:Environment)->void:
	studio(environment)
	var material:=PanoramaSkyMaterial.new();material.panorama=DAYLIGHT;material.energy_multiplier=.60
	environment.sky.sky_material=material;environment.sky_rotation=Vector3(0,.42,0)
	environment.ssao_radius=.55;environment.ssao_intensity=.85
static func island(environment:Environment,board_root:Node3D)->void:
	daylight(environment);environment.sky.sky_material.energy_multiplier=.26
	for child in board_root.get_children():
		if child is DirectionalLight3D:
			if child.shadow_enabled:child.light_energy=1.65;child.light_color=Color("fff0d9");child.rotation_degrees=Vector3(-46,-48,0)
			else:child.light_energy=.07
