shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying float height;
void vertex(){height=VERTEX.y;}
void fragment(){
 float up=smoothstep(.04,1.22,height);
 ALBEDO=mix(vec3(.060,.105,.170),vec3(.245,.355,.470),up);
 ROUGHNESS=1.0;SSS_STRENGTH=.32;BACKLIGHT=vec3(.035,.060,.10);
 AO_LIGHT_AFFECT=.16;
}
