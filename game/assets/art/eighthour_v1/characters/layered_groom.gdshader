shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, alpha_to_coverage;
uniform sampler2D clump_coverage:filter_linear_mipmap_anisotropic;
uniform sampler2D coat_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float gait_phase=0.0;
uniform float gait_weight=0.0;
uniform float seated_pose=0.0;
uniform float table_gesture=0.0;
uniform int coat_character=-1;
uniform bool refined_muzzle=false;
varying vec3 root_point;
vec3 swing(vec3 point,vec3 pivot,float angle){vec3 p=point-pivot;float c=cos(angle),s=sin(angle);return pivot+vec3(p.x,c*p.y-s*p.z,s*p.y+c*p.z);}
void vertex(){
 vec3 base=VERTEX;root_point=base;float a=sin(gait_phase)*gait_weight;
 VERTEX+=(swing(base,vec3(.25,.38,0),a*.38)-base)*COLOR.r;
 VERTEX+=(swing(base,vec3(-.25,.38,0),-a*.38)-base)*COLOR.g;
 VERTEX+=(swing(base,vec3(.40,1.35,0),-a*.20)-base)*COLOR.b;
 VERTEX+=(swing(base,vec3(-.40,1.35,0),a*.20)-base)*COLOR.a;
 vec3 seated_base=VERTEX;vec3 seated_normal=NORMAL;
 VERTEX+=(swing(seated_base,vec3(.25,.38,0),-1.10*seated_pose)-seated_base)*COLOR.r;
 VERTEX+=(swing(seated_base,vec3(-.25,.38,0),-1.10*seated_pose)-seated_base)*COLOR.g;
 VERTEX+=(swing(seated_base,vec3(.40,1.35,0),(-.52*seated_pose-.48*table_gesture))-seated_base)*COLOR.b;
 VERTEX+=(swing(seated_base,vec3(-.40,1.35,0),(-.52*seated_pose-.48*table_gesture))-seated_base)*COLOR.a;
 NORMAL+=(swing(seated_normal,vec3(0),-1.10*seated_pose)-seated_normal)*(COLOR.r+COLOR.g);
 NORMAL+=(swing(seated_normal,vec3(0),(-.52*seated_pose-.48*table_gesture))-seated_normal)*(COLOR.b+COLOR.a);
 NORMAL=normalize(NORMAL);

}
void fragment(){
 float along=1.0-UV2.y;
 float variant=floor(fract(sin(dot(UV,vec2(31.91,78.13)))*43758.5)*4.0);
 vec2 quadrant=vec2(mod(variant,2.0),floor(variant/2.0));
 vec2 uv=(quadrant+vec2(UV2.x,1.0-along))*.5;
 float edge=1.0-abs(dot(normalize(NORMAL),normalize(VIEW)));
 ALPHA=texture(clump_coverage,uv).a*smoothstep(.12,.66,edge);
 ALPHA_SCISSOR_THRESHOLD=.28;ALPHA_ANTIALIASING_EDGE=.35;
 vec3 pigment=texture(coat_texture,UV).rgb;
 float lum=dot(pigment,vec3(.2126,.7152,.0722));
 if(refined_muzzle && coat_character==1){
  float q=pow(root_point.x/.288,2.0)+pow((root_point.y-1.895)/.23,2.0);
  float jaw=(1.0-smoothstep(.52,1.0,pow(root_point.x/.40,2.0)+pow((root_point.y-1.655)/.21,2.0)))*smoothstep(.24,.32,root_point.z);
  pigment=mix(pigment,vec3(.24,.12,.063),jaw);
  pigment=mix(pigment,vec3(.80,.72,.61),(1.0-smoothstep(.70,1.05,q))*smoothstep(.30,.38,root_point.z));
  lum=dot(pigment,vec3(.2126,.7152,.0722));
 }
 pigment=mix(vec3(lum),pigment,.82)*1.12;
 ALBEDO=pigment*mix(.98,1.045,along);
 ROUGHNESS=.94;SPECULAR=.10;RIM=.07;RIM_TINT=.9;
}
