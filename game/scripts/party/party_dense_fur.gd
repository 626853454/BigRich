class_name FurPartyDenseFur
extends RefCounted
## One-triangle short fibre bundles, backed by actual editable geometry.
## No patterned skin normal, shell stack, random alpha stipple, or extra nodes.
static var _material:ShaderMaterial
static func material()->ShaderMaterial:
	if _material!=null:return _material
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled;
varying vec3 outward_normal;
void vertex(){
 // A tapered ribbon is double-sided but the coat follows its exported skin
 // normal on either face. Automatic backface reversal darkened orange roots.
 outward_normal=normalize(MODELVIEW_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 NORMAL=normalize(outward_normal);
 ALBEDO=COLOR.rgb;
 ROUGHNESS=1.0;SPECULAR=0.0;RIM=.08;RIM_TINT=.35;
 // Three fine fibre lobes follow physical triangular taper and groom flow.
 // Smooth derivative-filtered edges avoid peppered/discarded alpha pixels.
 float fibre_u=fract(UV.x*3.0);
 float side=fibre_u*2.0-1.0;
 float filter_width=max(fwidth(fibre_u)*.6,.035);
 float fibre=1.0-smoothstep(.56-filter_width,.90+filter_width,abs(side));
 float outside=smoothstep(0.0,.06,UV.x)*smoothstep(0.0,.06,1.0-UV.x);
 // Retain smooth exported skin/groom normals. The old alternating cylindrical
 // normal lobes made orange fur appear as dark short scratches in real close-up.
 // Fibre silhouette/taper remains actual geometry and alpha, not normal ridges.
 ALPHA=fibre*outside*(.92-.12*UV.y);
}
void light(){
 // Modest wrap approximates light spreading through a soft dense short coat.
 // Shadow attenuation, actual root colour and real light energy stay operative.
 float lambert=max(dot(NORMAL,LIGHT),0.0);
 float wrap=clamp((dot(NORMAL,LIGHT)+.14)/1.14,0.0,1.0);
 DIFFUSE_LIGHT+=mix(lambert,wrap,.55)*ATTENUATION*LIGHT_COLOR/3.14159265;
}
"""
	_material=ShaderMaterial.new();_material.shader=shader
	return _material
