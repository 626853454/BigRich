shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D surface_noise:filter_linear_mipmap,repeat_enable;
varying vec3 point;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 float large=texture(surface_noise,point.xz*.13).r;
 float grain=texture(surface_noise,point.xz*2.8).r;
 float vegetation=smoothstep(-.045,.052,COLOR.g-COLOR.r);
 vec3 moss_tint=vec3(.79,.87,.66);
 ALBEDO=COLOR.rgb*mix(.92,1.035,large)*mix(vec3(1),moss_tint,vegetation*.29);
 float bump=grain*.0016;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX);vec3 a=cross(sy,NORMAL),b=cross(NORMAL,sx);float det=dot(sx,a);
 NORMAL=normalize(max(abs(det),.0000001)*NORMAL-sign(det)*(dFdx(bump)*a+dFdy(bump)*b));
 ROUGHNESS=.92;SPECULAR=.18;
}
