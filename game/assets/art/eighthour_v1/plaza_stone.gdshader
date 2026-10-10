shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D stone_detail:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D stone_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec3 tex=texture(stone_color,p.xz*.075).rgb;
 float lum=dot(tex,vec3(.2126,.7152,.0722));
 vec3 pigment=mix(COLOR.rgb,vec3(.56,.51,.40),.10);
 ALBEDO=pigment*mix(.92,1.055,smoothstep(.025,.48,lum));
 vec3 n=texture(stone_detail,p.xz*.12).rgb*2.0-1.0;
 vec3 world_slope=vec3(-n.x*.0015,0,-n.y*.0015);
 float h=(texture(stone_color,p.xz*.12).r)*.011;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);vec3 a=cross(dy,NORMAL),b=cross(NORMAL,dx);float det=dot(dx,a);
 NORMAL=normalize(max(abs(det),1e-7)*NORMAL-sign(det)*(dFdx(h)*a+dFdy(h)*b));
 ROUGHNESS=.79;SPECULAR=.21;
}
