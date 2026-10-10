class_name FurUIMeterSkin
extends RefCounted
## Nine-slice gauges rendered from the authored recessed ceramic / enamel model.
static var _boxes:Dictionary={}
static var _images:Dictionary={}
static func image(name:String)->Texture2D:
	if not _images.has(name):_images[name]=load("res://assets/ui/atelier_v1/"+name+".png")
	return _images[name]
static func box(kind:String="track")->StyleBoxTexture:
	if not _boxes.has(kind):
		var skin:=StyleBoxTexture.new();skin.texture=image("meter_"+kind)
		skin.texture_margin_left=14;skin.texture_margin_right=14;skin.texture_margin_top=4;skin.texture_margin_bottom=4
		skin.content_margin_left=2;skin.content_margin_right=2;skin.content_margin_top=2;skin.content_margin_bottom=2
		_boxes[kind]=skin
	return _boxes[kind]
