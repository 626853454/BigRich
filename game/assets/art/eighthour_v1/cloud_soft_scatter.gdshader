shader_type spatial;
render_mode diffuse_burley,specular_disabled;
varying float height;
void vertex(){height=VERTEX.y;}
void fragment(){
	float up=smoothstep(.04,1.22,height);
	ALBEDO=mix(vec3(.66,.74,.80),vec3(.96,.95,.91),up);
	ROUGHNESS=1.0;SSS_STRENGTH=.52;BACKLIGHT=vec3(.14,.17,.20);
	AO_LIGHT_AFFECT=.18;
}
