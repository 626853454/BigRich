class_name FurVisualStyle
extends RefCounted

const UI_FONT=preload("res://assets/furball/fonts/NotoSansCJK-Regular.woff2")
const DISPLAY_FONT=preload("res://assets/party/fonts/ZCOOLKuaiLe-Regular.ttf")

static func display_font() -> FontFile:
	return DISPLAY_FONT

static func font() -> FontFile:
	# Keep exported and freshly imported projects independent of installed fonts.
	var resource:FontFile=UI_FONT
	resource.allow_system_fallback=false
	return resource
