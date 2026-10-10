class_name FurPartyPropFinish
extends RefCounted
## Exact original accessory material families. Read-only source resources;
## callers supply an independent duplicate. No colour/mesh/weapon rule writes.
const METAL:=["BrushedPan","Cookpot","GunSteel"]
const BRASS:=["WarmBrass","BrassTrim","PotBadge","HatBadge","PastryBadge"]
const WOOD:=["OiledHandle"]
const LEATHER:=["GunGrip","PotLeather","LeatherTrim","BeretLeather"]
const FOOD:=["BakedDough","Cocoa","Icing"]
static var _brush:NoiseTexture2D
static var _grain:NoiseTexture2D
static func _normal_texture(seed_value:int,frequency:float)->NoiseTexture2D:
	var noise:=FastNoiseLite.new();noise.seed=seed_value
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=frequency;noise.fractal_octaves=1
	var result:=NoiseTexture2D.new();result.width=128;result.height=128
	result.noise=noise;result.seamless=true;result.as_normal_map=true;result.bump_strength=.10
	return result
static func recognized(name:String)->bool:
	return name in METAL or name in BRASS or name in WOOD or name in LEATHER or name in FOOD or name=="AirgunEnamel"
static func apply(material:StandardMaterial3D,name:String)->void:
	if name in METAL:
		if _brush==null:_brush=_normal_texture(202610065,.055)
		material.roughness=.46;material.metallic=.72;material.metallic_specular=.42
		material.normal_enabled=true;material.normal_texture=_brush;material.normal_scale=.045
		material.uv1_triplanar=true;material.uv1_scale=Vector3(24,2,24)
	elif name in BRASS:
		material.roughness=.49;material.metallic=.65;material.metallic_specular=.4
	elif name=="AirgunEnamel":
		material.roughness=.48;material.metallic=.13;material.metallic_specular=.32
		material.clearcoat_enabled=true;material.clearcoat=.18;material.clearcoat_roughness=.35
	elif name in WOOD or name in LEATHER:
		if _grain==null:_grain=_normal_texture(202610066,.075)
		material.roughness=.91;material.metallic=0.0;material.metallic_specular=.15
		material.normal_enabled=true;material.normal_texture=_grain;material.normal_scale=.04
		material.uv1_triplanar=true;material.uv1_scale=Vector3(6,28,6) if name in WOOD else Vector3.ONE*14.0
	elif name in FOOD:
		material.roughness=.98;material.metallic=0.0;material.metallic_specular=.06
