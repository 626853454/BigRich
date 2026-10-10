class_name FurFurnitureMaterials
extends RefCounted
const ROOT:="res://assets/art/eighthour_v1/furniture/"
const SHADER=preload("res://assets/art/eighthour_v1/furniture/furniture_surface.gdshader")
static var _cache:Dictionary={}
static func surface(label:String)->ShaderMaterial:
	if _cache.has(label):return _cache[label]
	var fabric:bool=label.begins_with("FurnitureFelt")
	var result:=ShaderMaterial.new();result.shader=SHADER;result.set_shader_parameter("fabric",fabric)
	result.set_shader_parameter("color_map",load(ROOT+("book_pattern_col1_1k.jpg" if fabric else "dark_wood_diff_1k.jpg")))
	result.set_shader_parameter("normal_map",load(ROOT+("book_pattern_nor_gl_1k.jpg" if fabric else "dark_wood_nor_gl_1k.jpg")))
	result.set_shader_parameter("arm_map",load(ROOT+("book_pattern_arm_1k.jpg" if fabric else "dark_wood_arm_1k.jpg")))
	result.set_shader_parameter("tint",Color("306b62") if fabric else (Color("b99470") if "GoldenEdges" in label else Color("986e4d")))
	_cache[label]=result;return result
