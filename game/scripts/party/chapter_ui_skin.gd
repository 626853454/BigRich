class_name FurChapterUISkin
extends RefCounted
## Shallow ceramic/enamel bevels authored in Blender. Shared nine-patch surfaces.
static var _cache:Dictionary={}
static func box(kind:String="ivory")->StyleBox:
	if _cache.has(kind):return _cache[kind]
	if kind in ["menu","orange","blue"]:
		var panel:=StyleBoxFlat.new();panel.bg_color={"menu":Color("f8f1e5"),"orange":Color("faeedc"),"blue":Color("e7eff0")}[kind]
		panel.border_color=Color("cfb98f");panel.set_border_width_all(1);panel.set_corner_radius_all(22);panel.corner_detail=12
		panel.border_width_bottom=3;panel.shadow_color=Color(.06,.10,.10,.22);panel.shadow_size=10;panel.shadow_offset=Vector2(0,5)
		panel.content_margin_left=22;panel.content_margin_right=22;panel.content_margin_top=16;panel.content_margin_bottom=16
		_cache[kind]=panel;return panel
	var aliases:Dictionary={"hover":"ivory_hover","pressed":"ivory_pressed","gold":"ivory","gold_hover":"ivory_hover","gold_pressed":"ivory_pressed","toolbar_hover":"primary_hover","toolbar_pressed":"primary_pressed"}
	var asset:String=aliases.get(kind,kind)
	if asset not in ["primary","primary_hover","primary_pressed","ivory","ivory_hover","ivory_pressed","disabled","selected","toolbar","danger"]:asset="ivory"
	var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/eighthour_v1/runtime/button_"+asset+".png")
	skin.texture_margin_left=44;skin.texture_margin_right=44;skin.texture_margin_top=16;skin.texture_margin_bottom=16
	skin.content_margin_left=24;skin.content_margin_right=24;skin.content_margin_top=12;skin.content_margin_bottom=14
	skin.expand_margin_left=6;skin.expand_margin_right=6;skin.expand_margin_top=5;skin.expand_margin_bottom=5
	_cache[kind]=skin;return skin
