shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D color_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D arm_map:filter_linear_mipmap,repeat_enable;
uniform vec4 tint:source_color=vec4(.42,.23,.13,1);
uniform bool fabric=false;
varying vec3 p;
varying vec3 n;
varying mat3 local_to_view_normal;
void vertex(){p=VERTEX;n=NORMAL;local_to_view_normal=MODELVIEW_NORMAL_MATRIX;}
void fragment(){
	vec3 weight=pow(abs(normalize(n)),vec3(6.0));weight/=max(weight.x+weight.y+weight.z,.0001);
	float scale=fabric ? .42 : .085;
	vec3 sampled=texture(color_map,p.zy*scale).rgb*weight.x+texture(color_map,p.xz*scale).rgb*weight.y+texture(color_map,p.xy*scale).rgb*weight.z;
	vec3 orm=texture(arm_map,p.zy*scale).rgb*weight.x+texture(arm_map,p.xz*scale).rgb*weight.y+texture(arm_map,p.xy*scale).rgb*weight.z;
	vec3 x=texture(normal_map,p.zy*scale).rgb*2.0-1.0;
	vec3 y=texture(normal_map,p.xz*scale).rgb*2.0-1.0;
	vec3 z=texture(normal_map,p.xy*scale).rgb*2.0-1.0;
	float strength=fabric ? .34 : .12;x.xy*=strength;y.xy*=strength;z.xy*=strength;
	vec3 mapped=normalize(vec3(x.z*sign(n.x),x.y,x.x)*weight.x+vec3(y.x,y.z*sign(n.y),y.y)*weight.y+vec3(z.x,z.y,z.z*sign(n.z))*weight.z);
	NORMAL=normalize(local_to_view_normal*mapped);
	if(fabric){float lum=dot(sampled,vec3(.2126,.7152,.0722));ALBEDO=tint.rgb*clamp(.84+lum*.55,.8,1.14);ROUGHNESS=.92;SPECULAR=.15;RIM=.14;RIM_TINT=.8;}
	else{ALBEDO=mix(tint.rgb,sampled*1.28,.42);ROUGHNESS=.43+orm.g*.25;SPECULAR=.30;CLEARCOAT=.11;CLEARCOAT_ROUGHNESS=.42;}
	AO=.78+.22*orm.r;
}
