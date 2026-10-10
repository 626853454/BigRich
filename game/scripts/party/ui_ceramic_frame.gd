class_name FurUICeramicFrame
extends RefCounted
## Nine-patch images rendered from original beveled Blender models.
static var _cache:Dictionary={}
static func style(kind:String="ivory")->StyleBoxTexture:
	if _cache.has(kind):return _cache[kind]
	var box:=StyleBoxTexture.new();box.texture=load("res://assets/ui/eighthour_v1/runtime/panel_"+kind+".png")
	box.texture_margin_left=32;box.texture_margin_right=32;box.texture_margin_top=32;box.texture_margin_bottom=32
	box.expand_margin_left=5;box.expand_margin_right=5;box.expand_margin_top=5;box.expand_margin_bottom=5
	box.content_margin_left=27;box.content_margin_right=27;box.content_margin_top=24;box.content_margin_bottom=26
	_cache[kind]=box;return box
static func from_flat(source:StyleBoxFlat,compact:bool=false,quiet:bool=false)->StyleBoxTexture:
	var dark:bool=source.bg_color.v<.50
	var result:StyleBoxTexture
	if compact:
		result=FurChapterUISkin.box("primary" if dark else "ivory").duplicate() as StyleBoxTexture
	else:result=style("teal" if dark else ("muted" if quiet else "ivory")).duplicate() as StyleBoxTexture
	result.content_margin_left=source.content_margin_left;result.content_margin_right=source.content_margin_right
	result.content_margin_top=source.content_margin_top;result.content_margin_bottom=source.content_margin_bottom
	result.modulate_color=source.bg_color.lightened(.92) if not dark else Color.WHITE
	return result
