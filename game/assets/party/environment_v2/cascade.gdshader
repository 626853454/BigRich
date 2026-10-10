shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 water_color : source_color = vec4(.33,.73,.78,1.0);
uniform vec4 aerated_color : source_color = vec4(.77,.93,.91,1.0);
uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
void vertex(){
 // A small moving surface relief catches light without moving the river's
 // fixed top and bottom endpoints or introducing more CPU scene objects.
 float ends=sin(clamp(UV.y,0.0,1.0)*3.14159265);
 VERTEX+=NORMAL*(sin(UV.x*29.0+UV.y*11.0-TIME*3.1)*.021+sin(UV.x*51.0-UV.y*8.0+TIME*2.2)*.009)*ends;
}
void fragment(){
 float flow=texture(surface_noise,vec2(UV.x*1.13,UV.y*.41-TIME*.26)).r;
 float thread=texture(surface_noise,vec2(UV.x*2.37+.18,UV.y*.11-TIME*.32)).r;
 float aeration=smoothstep(.46,.66,flow)*.32+smoothstep(.58,.73,thread)*.20+smoothstep(.58,1.0,UV.y)*.40;
 ALBEDO=mix(water_color.rgb,aerated_color.rgb,aeration);
 ROUGHNESS=.22+flow*.10;SPECULAR=.42;
 float edge=smoothstep(0.0,.07,UV.x)*(1.0-smoothstep(.93,1.0,UV.x));
 ALPHA=edge*(.72+aeration*.28);
}
