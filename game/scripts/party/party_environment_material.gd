class_name FurPartyEnvironmentMaterial
extends RefCounted
## True world-space texture sampling also covers authored meshes with no UVs.
## Family -1 consumes explicit per-vertex UV2.x tags; never guesses from color.
const SHADER=preload("res://assets/party/environment_v2/crafted_surface.gdshader")
const WOOD=preload("res://assets/art/textures/honey_wood_albedo_v1.png")
const STONE=preload("res://assets/art/textures/limestone_albedo_v1.png")
static var _cache:Dictionary={}

static func material(family:int=0,wet_level:float=-100.0,vertex_srgb:bool=true)->ShaderMaterial:
	var key:String="%d/%.3f/%s"%[family,wet_level,str(vertex_srgb)]
	if _cache.has(key):return _cache[key]
	var result:=ShaderMaterial.new();result.shader=SHADER
	result.set_shader_parameter("wood_grain",WOOD);result.set_shader_parameter("stone_grain",STONE)
	result.set_shader_parameter("surface_family",family);result.set_shader_parameter("wet_level",wet_level)
	result.set_shader_parameter("vertex_colors_are_srgb",vertex_srgb)
	result.set_meta("authored_material_family",family);result.set_meta("world_space_textures",true)
	_cache[key]=result;return result
