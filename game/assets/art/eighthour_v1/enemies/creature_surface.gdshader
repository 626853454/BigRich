shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic,repeat_disable;
void fragment(){
	float response=clamp(UV2.x,.14,.96);
	float metal=clamp(1.0-UV2.y,0.0,.75);
	ALBEDO=texture(albedo_map,UV).rgb;ROUGHNESS=response;METALLIC=metal;
	SPECULAR=.38;CLEARCOAT=1.0-smoothstep(.20,.46,response);CLEARCOAT_ROUGHNESS=.18;
	SSS_STRENGTH=(1.0-smoothstep(.20,.31,response))*.30;
	BACKLIGHT=COLOR.rgb*.10*(1.0-smoothstep(.20,.35,response));
}
