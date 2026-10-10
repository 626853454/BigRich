shader_type spatial;
render_mode diffuse_burley, specular_disabled;
void fragment(){
 vec3 c=COLOR.rgb;
 ALBEDO=mix(c,vec3(.98,.98,.96),.60);
 ROUGHNESS=1.0;
 SSS_STRENGTH=.32;
 BACKLIGHT=vec3(.16,.19,.21);
}
