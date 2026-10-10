class_name FurPartyGroomedFur
extends RefCounted
## Actual short fibre ribbon geometry comes from the editable Blender mesh.
## Soft UV edges use a transparent no-depth/no-shadow pass, not AO-stipple shells.
static var _material:ShaderMaterial
static func material()->ShaderMaterial:
	if _material!=null:return _material
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
void fragment(){
 ALBEDO=COLOR.rgb;
 ROUGHNESS=.94;SPECULAR=.10;RIM=.09;RIM_TINT=.42;
 // Four rounded sub-millimetre fibres per physical bundle, not broad sheets.
 float strand=fract(UV.x*4.0);float side=strand*2.0-1.0;
 float fibre=1.0-smoothstep(.44,.82,abs(side));
 float edge=smoothstep(0.0,.07,UV.x)*smoothstep(0.0,.07,1.0-UV.x);
 NORMAL_MAP=vec3(.5+side*.30,.5,1.0);NORMAL_MAP_DEPTH=.28;
 ALPHA=fibre*edge*(.95-.15*UV.y);
}
"""
	_material=ShaderMaterial.new();_material.shader=shader
	return _material
