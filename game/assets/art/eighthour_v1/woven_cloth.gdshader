shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx,cull_back;
uniform vec4 fabric_color:source_color=vec4(.26,.47,.61,1);
uniform float thread_scale=190.0;
uniform float relief=.00048;
varying vec3 local_point;
varying vec3 local_normal;
void vertex(){local_point=VERTEX;local_normal=NORMAL;}
float woven(vec2 point){
 vec2 p=point*thread_scale;vec2 cell=floor(p);vec2 f=fract(p);
 float cross_over=mod(cell.x+cell.y,2.0);
 float warp=pow(max(0.0,sin(f.x*3.14159265)),.65);
 float weft=pow(max(0.0,sin(f.y*3.14159265)),.65);
 return mix(warp*.78+weft*.22,weft*.78+warp*.22,cross_over);
}
void fragment(){
 vec3 weight=pow(abs(normalize(local_normal)),vec3(8.0));weight/=max(dot(weight,vec3(1)),.001);
 float height=dot(weight,vec3(woven(local_point.zy),woven(local_point.xz),woven(local_point.xy)));
 vec3 px=dFdx(VERTEX),py=dFdy(VERTEX);vec3 r1=cross(py,NORMAL),r2=cross(NORMAL,px);float det=dot(px,r1);
 vec3 grad=sign(det)*(dFdx(height)*r1+dFdy(height)*r2);
 float coverage=1.0-smoothstep(.4,1.3,length(fwidth(local_point))*thread_scale);
 NORMAL=normalize(max(abs(det),.0000001)*NORMAL-relief*grad*coverage);
 ALBEDO=fabric_color.rgb*mix(1.0,.97+height*.055,coverage);
 ROUGHNESS=.81;SPECULAR=.21;RIM=.12;RIM_TINT=.7;
}
