class_name FurUIIcons
extends RefCounted
## Original Blender-rendered UI emblems; shared cache avoids repeated loading.
static var _textures:Dictionary={}
static func get_icon(key:String)->Texture2D:
	if not _textures.has(key):
		var path:String="res://assets/ui/eighthour_v1/icon_"+key+".png"
		if not ResourceLoader.exists(path):return null
		_textures[key]=load(path)
	return _textures[key]
static func view(key:String,extent:Vector2=Vector2(48,48))->TextureRect:
	var rect:=TextureRect.new();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rect.texture=get_icon(key);rect.custom_minimum_size=extent;rect.size=extent
	rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return rect
