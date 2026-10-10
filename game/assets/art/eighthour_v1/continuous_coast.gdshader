shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D surface_color:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D surface_normal:hint_normal,filter_linear_mipmap_anisotropic;
varying vec3 world_normal;
varying vec3 world_point;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);world_point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec3 source=texture(surface_color,UV).rgb;
 float luminance=dot(source,vec3(.2126,.7152,.0722));
 // Preserve baked broad fractures while matching the limestone / moss palette.
 // Raw photographic brown was rejected in the native proof, not silently accepted.
 float green=smoothstep(.0,.070,source.g-source.r*.95);
 float ground=smoothstep(.64,.88,world_normal.y)*smoothstep(-.3,1.0,world_point.y);
 vec3 stone=mix(vec3(.36,.35,.30),vec3(.21,.30,.13),green*.38);
 vec3 bank=mix(vec3(.47,.41,.29),vec3(.25,.36,.16),green);
 float variation=.70+.62*sqrt(clamp(luminance,0.0,1.0));
 ALBEDO=mix(stone,bank,ground)*variation;
 NORMAL_MAP=texture(surface_normal,UV).rgb;NORMAL_MAP_DEPTH=.68;
 ROUGHNESS=.91;SPECULAR=.20;
}
