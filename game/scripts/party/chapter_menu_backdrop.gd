class_name FurChapterMenuBackdrop
extends RefCounted
## Original generated menu illustration. This is deliberately not a world renderer.
const ASSET_PATH:="res://assets/adventure/chapter-storybook-menu-v1.png"
const RENEWED_ASSET_PATH:="res://assets/art/harbor-menu-v2.png"

static func create()->TextureRect:
	var backdrop:=TextureRect.new()
	backdrop.name="StorybookMenuIllustration"
	backdrop.texture=load(RENEWED_ASSET_PATH if ResourceLoader.exists(RENEWED_ASSET_PATH) else ASSET_PATH) as Texture2D
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only the illustration receives this quiet vignette; buttons/text stay crisp.
	var shader:=Shader.new();shader.code="""
shader_type canvas_item;
void fragment(){vec4 image=texture(TEXTURE,UV);float edge=smoothstep(.28,.82,length((UV-.5)*vec2(1.0,.75)));image.rgb=mix(image.rgb,vec3(.09,.17,.20),edge*.22);COLOR=image;}
"""
	var material:=ShaderMaterial.new();material.shader=shader;backdrop.material=material
	return backdrop
