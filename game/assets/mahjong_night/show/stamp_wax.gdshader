shader_type spatial;
render_mode cull_back;
uniform vec4 wax_color : source_color = vec4(0.68,0.13,0.09,1.0);
varying float pulse_amount;
void vertex() { pulse_amount = INSTANCE_CUSTOM.x; }
void fragment() {
	ALBEDO = mix(wax_color.rgb, vec3(1.0,0.63,0.27),pulse_amount*0.48);
	METALLIC = 0.18;
	ROUGHNESS = 0.32;
	CLEARCOAT = 0.40;
	CLEARCOAT_ROUGHNESS = 0.28;
	EMISSION = wax_color.rgb * pulse_amount * 1.35;
}
