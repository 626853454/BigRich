shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx,cull_disabled;
uniform sampler2D scan_color:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D scan_normal:hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D scan_orm:hint_default_white,filter_linear_mipmap;
uniform vec4 stone_tint:source_color=vec4(.67,.66,.60,1);
uniform vec4 moss_tint:source_color=vec4(.34,.46,.27,1);
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 sample=texture(scan_color,UV).rgb;float lum=dot(sample,vec3(.2126,.7152,.0722));
 float form=.66+sqrt(max(lum,0.0))*.71;
 float moss=smoothstep(.012,.068,sample.g-sample.r*.87)*.52;
 moss=max(moss,smoothstep(.28,.78,world_normal.y)*smoothstep(-.15,1.0,world_point.y)*(.22+.28*smoothstep(.16,.48,lum)));
 float wet=1.0-smoothstep(-3.03,-2.48,world_point.y);
 ALBEDO=mix(stone_tint.rgb,moss_tint.rgb,moss)*form*mix(1.0,.62,wet);
 NORMAL_MAP=texture(scan_normal,UV).rgb;NORMAL_MAP_DEPTH=.42;
 ROUGHNESS=mix(.87,.42,wet);SPECULAR=.23;AO=mix(1.0,texture(scan_orm,UV).r,.50);AO_LIGHT_AFFECT=.30;
}
