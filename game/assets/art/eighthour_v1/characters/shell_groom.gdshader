// Shell coverage method informed by sofluffy (Max Muermann, MIT); notice alongside.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back, alpha_to_coverage;
uniform sampler2D coat_texture:source_color,filter_linear_mipmap_anisotropic;
uniform float gait_phase=0.0;
uniform float gait_weight=0.0;
uniform float seated_pose=0.0;
uniform float table_gesture=0.0;
uniform float coat_depth=.037;
uniform int coat_character=0;
uniform bool legacy_mouth_cut=false;
uniform bool flowing_clumps=false;
uniform bool tailored_fur_mask=false;
uniform float clump_relief=0.0;
uniform bool refined_muzzle=false;
uniform float fibre_density=520.0;
uniform bool tabletop_detail=false;
uniform vec2 eye_center=vec2(.19825,2.0389);
uniform vec2 eye_radius=vec2(.090,.11);
varying vec3 root_normal;
varying vec3 root_point;
varying vec3 local_normal;
varying float shell_height;
varying float clothing_mask;
vec3 swing(vec3 point,vec3 pivot,float angle){vec3 p=point-pivot;float c=cos(angle),s=sin(angle);return pivot+vec3(p.x,c*p.y-s*p.z,s*p.y+c*p.z);}
float noise2(vec2 p){vec3 p3=fract(vec3(p.xyx)*.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
void vertex(){
 vec3 base=VERTEX;root_point=base;local_normal=NORMAL;shell_height=UV2.x;clothing_mask=UV2.y;
 root_normal=normalize((MODELVIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 down=vec3(0.0,-1.0,0.0);
 if(flowing_clumps)down.x=sign(base.x)*.35*smoothstep(1.5,1.9,base.y);
 vec3 tangent=down-NORMAL*dot(down,NORMAL);
 float eye=length((vec2(abs(base.x),base.y)-eye_center)/eye_radius);
 float mask=mix(1.0,smoothstep(.85,1.3,eye),smoothstep(.12,.25,base.z));
 float h=shell_height;float depth=coat_depth;
 if(flowing_clumps)depth*=1.3+sin(base.x*34.0+base.y*7.0+sin(base.z*21.0))*sin(base.y*23.0+base.z*8.0)*.25;
 if(flowing_clumps && coat_character==0 && abs(base.x)<.28 && base.y>1.65 && base.y<1.97 && base.z>.47)depth*=.30;
 if(flowing_clumps && coat_character==0 && base.y>2.20)depth*=.64;
 if(refined_muzzle && coat_character==1 && abs(base.x)<.27 && base.y>1.72 && base.y<2.04 && base.z>.32)depth*=.25;
 VERTEX+=mask*depth*(NORMAL*(h*.80+.03)+tangent*(h*h*(flowing_clumps ? .90 : .36)));
 float a=sin(gait_phase)*gait_weight;vec3 posed=VERTEX;
 VERTEX+=(swing(posed,vec3(.25,.38,0),a*.38)-posed)*COLOR.r;
 VERTEX+=(swing(posed,vec3(-.25,.38,0),-a*.38)-posed)*COLOR.g;
 VERTEX+=(swing(posed,vec3(.40,1.35,0),-a*.20)-posed)*COLOR.b;
 VERTEX+=(swing(posed,vec3(-.40,1.35,0),a*.20)-posed)*COLOR.a;
 vec3 seated_base=VERTEX;vec3 seated_normal=NORMAL;
 VERTEX+=(swing(seated_base,vec3(.25,.38,0),-1.10*seated_pose)-seated_base)*COLOR.r;
 VERTEX+=(swing(seated_base,vec3(-.25,.38,0),-1.10*seated_pose)-seated_base)*COLOR.g;
 VERTEX+=(swing(seated_base,vec3(.40,1.35,0),(-.52*seated_pose-.48*table_gesture))-seated_base)*COLOR.b;
 VERTEX+=(swing(seated_base,vec3(-.40,1.35,0),(-.52*seated_pose-.48*table_gesture))-seated_base)*COLOR.a;
 NORMAL+=(swing(seated_normal,vec3(0),-1.10*seated_pose)-seated_normal)*(COLOR.r+COLOR.g);
 NORMAL+=(swing(seated_normal,vec3(0),(-.52*seated_pose-.48*table_gesture))-seated_normal)*(COLOR.b+COLOR.a);
 NORMAL=normalize(NORMAL);
 root_normal=normalize((MODELVIEW_MATRIX*vec4(NORMAL,0)).xyz);

}
void fragment(){
 // glTF uses a top-left V origin, so Blender UV.y is inverted on export.
 if(tailored_fur_mask && clothing_mask>.5)discard;
 vec3 coat=texture(coat_texture,UV).rgb;float lum=dot(coat,vec3(.2126,.7152,.0722));
 if(coat_character==0){
  float inner_ear=(1.0-smoothstep(.60,1.0,pow((abs(root_point.x)-.45)/.145,2.0)+pow((root_point.y-2.52)/.29,2.0)))*smoothstep(.12,.48,local_normal.z);
  if(inner_ear>.20)discard;
  coat=mix(coat,vec3(.68,.31,.28),inner_ear*.94);lum=dot(coat,vec3(.2126,.7152,.0722));
 }
 if(refined_muzzle && coat_character==1){
  float region=pow(root_point.x/.288,2.0)+pow((root_point.y-1.895)/.23,2.0);
  float old_lower=(1.0-smoothstep(.52,1.0,pow(root_point.x/.40,2.0)+pow((root_point.y-1.655)/.21,2.0)))*smoothstep(.24,.32,root_point.z);
  coat=mix(coat,vec3(.24,.12,.063),old_lower);
  bool nose=abs(root_point.x)<.18 && root_point.y>1.94 && root_point.z>.43 && lum<.12;
  if(!nose)coat=mix(coat,vec3(.80,.72,.61),(1.0-smoothstep(.70,1.05,region))*smoothstep(.30,.38,root_point.z));
  lum=dot(coat,vec3(.2126,.7152,.0722));
 }
 // A luminance threshold erased the bear's shaded brown fur. Mask by anatomy.
 bool on_nose=coat_character==0 ? (abs(root_point.x)<.19 && root_point.y>1.77 && root_point.y<2.005 && root_point.z>.63) : (abs(root_point.x)<.18 && root_point.y>1.91 && root_point.y<2.085 && root_point.z>.43);
 if(on_nose && lum<.10)discard;
 if(lum<.04 && abs(root_point.x)<.27 && root_point.y>1.48 && root_point.y<2.22 && root_point.z>.29)discard;
 if(legacy_mouth_cut && coat_character==0 && root_point.z>.50 && length(vec2(root_point.x/.216,(root_point.y-1.595)/.116))<1.02)discard;
 if(legacy_mouth_cut && coat_character==1 && root_point.z>.32 && length(vec2(root_point.x/.16,(root_point.y-1.665)/.080))<1.02)discard;
 if(lum<.003)discard;
 float eye=length((vec2(abs(root_point.x),root_point.y)-eye_center)/eye_radius);
 if(root_point.z>.15 && eye<.93)discard;
 vec2 p=UV*fibre_density;
 if(flowing_clumps){
  vec3 axis=abs(local_normal);
  p=(axis.z>axis.x && axis.z>axis.y ? root_point.xy : (axis.x>axis.y ? root_point.zy : root_point.xz))*fibre_density;
  p.x+=sin(p.y*.03+sin(p.x*.025))*1.1;
 }
 vec2 cell=floor(p);float rnd=noise2(cell);
 float h=shell_height;float len=.58+.42*rnd;
 vec2 offset=fract(p)-vec2(.5);offset.x+=sin(h*2.0+rnd*6.283)*h*.09;
 float radius=max(.04,(len-h)*.82+.06);float dist=length(offset*vec2(1.0,.62));
 float aa=clamp(length(fwidth(p))*.22,.018,.12);
 float opacity=(1.0-smoothstep(radius-aa,radius+aa,dist))*(1.0-smoothstep(len-.055,len+.025,h));
 if(tabletop_detail){float edge=1.0-abs(dot(normalize(root_normal),normalize(VIEW)));opacity*=smoothstep(.14,.72,edge);}
 ALPHA=opacity;ALPHA_SCISSOR_THRESHOLD=.35;ALPHA_ANTIALIASING_EDGE=.42;
 vec3 nw=pow(abs(local_normal),vec3(6.0));nw/=max(nw.x+nw.y+nw.z,.0001);
 vec3 q=root_point;
 vec3 flows=vec3(sin(q.z*360.0+2.6*sin(q.y*100.0+q.z*33.0)),sin(q.x*360.0+2.6*sin(q.z*100.0+q.x*33.0)),sin(q.x*360.0+2.6*sin(q.y*100.0+q.x*33.0)));
 float relief=dot(nw,pow(.5+.5*flows,vec3(3.0)))*(.56+.44*sin(q.y*160.0+q.z*118.0+q.x*19.0));
 vec3 px=dFdx(VERTEX),py=dFdy(VERTEX);vec3 r1=cross(py,root_normal),r2=cross(root_normal,px);float det=dot(px,r1);
 vec3 grad=sign(det)*(dFdx(relief)*r1+dFdy(relief)*r2);
 NORMAL=normalize(max(abs(det),.0000001)*root_normal-clump_relief*grad);
 coat=mix(vec3(lum),coat,.82)*1.12;
 ALBEDO=coat*mix(.98,1.01,h);
 ROUGHNESS=.92;SPECULAR=.14;RIM=.12;RIM_TINT=.9;
}
