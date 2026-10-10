shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform sampler2D coat_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D fibre_noise : filter_linear_mipmap, repeat_enable;
uniform bool fur_layer=false;
uniform float coat_length=.009;
uniform int coat_character=-1;
uniform bool refined_muzzle=false;
uniform float surface_relief=0.0;
uniform float sheen_strength=.20;
varying vec3 surface_normal;
uniform float gait_phase=0.0;
uniform float gait_weight=0.0;
uniform float seated_pose=0.0;
uniform float table_gesture=0.0;
varying float layer;
varying float grooming_mask;
varying vec3 local_point;
vec3 swing(vec3 point,vec3 pivot,float angle){
	vec3 p=point-pivot;float c=cos(angle),s=sin(angle);
	return pivot+vec3(p.x,c*p.y-s*p.z,s*p.y+c*p.z);
}
void vertex(){
	vec3 base=VERTEX;
	local_point=base;
	surface_normal=NORMAL;
	float eye_distance=length(vec2((abs(base.x)-.25)/.11,(base.y-2.04)/.13));
	grooming_mask=mix(1.0,smoothstep(.85,1.35,eye_distance),smoothstep(.20,.30,abs(base.z)));
	grooming_mask*=mix(1.0,.48,smoothstep(1.62,1.83,base.y)*(1.0-smoothstep(1.94,2.02,base.y)));
	float a=sin(gait_phase)*gait_weight;
	float side=coat_character>=0 ? -1.0 : 1.0;
	VERTEX+=(swing(base,vec3(-.25*side,.38,0),a*.38)-base)*COLOR.r;
	VERTEX+=(swing(base,vec3(.25*side,.38,0),-a*.38)-base)*COLOR.g;
	VERTEX+=(swing(base,vec3(-.40*side,1.35,0),-a*.20)-base)*COLOR.b;
	VERTEX+=(swing(base,vec3(.40*side,1.35,0),a*.20)-base)*COLOR.a;
	layer=INSTANCE_CUSTOM.r;
	
 vec3 seated_base=VERTEX;vec3 seated_normal=NORMAL;
 VERTEX+=(swing(seated_base,vec3(.25,.38,0),-1.10*seated_pose)-seated_base)*COLOR.r;
 VERTEX+=(swing(seated_base,vec3(-.25,.38,0),-1.10*seated_pose)-seated_base)*COLOR.g;
 VERTEX+=(swing(seated_base,vec3(.40,1.35,0),(-.52*seated_pose-.48*table_gesture))-seated_base)*COLOR.b;
 VERTEX+=(swing(seated_base,vec3(-.40,1.35,0),(-.52*seated_pose-.48*table_gesture))-seated_base)*COLOR.a;
 NORMAL+=(swing(seated_normal,vec3(0),-1.10*seated_pose)-seated_normal)*(COLOR.r+COLOR.g);
 NORMAL+=(swing(seated_normal,vec3(0),(-.52*seated_pose-.48*table_gesture))-seated_normal)*(COLOR.b+COLOR.a);
 NORMAL=normalize(NORMAL);

}
float combed_height(vec2 p){
 // Filtered anisotropic fibre fields; height is only used for relief, not dirt.
 float bend=texture(fibre_noise,p*vec2(.55,.32)).r;
 vec2 comb=p*vec2(29.0,7.0)+vec2(bend*.027,0.0);
 float cluster=texture(fibre_noise,comb*.27).r;
 float fine=texture(fibre_noise,comb).r;
 return fine*.34+cluster*.66;
}
void fragment(){
	vec3 coat=texture(coat_texture,UV).rgb;
	float lum=dot(coat,vec3(.2126,.7152,.0722));
	float inner_ear=0.0;
	if(coat_character==0){
	 inner_ear=(1.0-smoothstep(.60,1.0,pow((abs(local_point.x)-.45)/.145,2.0)+pow((local_point.y-2.52)/.29,2.0)))*smoothstep(.12,.48,surface_normal.z);
	 coat=mix(coat,vec3(.68,.31,.28),inner_ear*.94);lum=dot(coat,vec3(.2126,.7152,.0722));
	}
	if(refined_muzzle && coat_character==1){
	 float q=pow(local_point.x/.288,2.0)+pow((local_point.y-1.895)/.23,2.0);
	 float old_lower=(1.0-smoothstep(.52,1.0,pow(local_point.x/.40,2.0)+pow((local_point.y-1.655)/.21,2.0)))*smoothstep(.24,.32,local_point.z);
	 coat=mix(coat,vec3(.24,.12,.063),old_lower);
	 bool nose=abs(local_point.x)<.18 && local_point.y>1.94 && local_point.z>.43 && lum<.12;
	 if(!nose)coat=mix(coat,vec3(.80,.72,.61),(1.0-smoothstep(.70,1.05,q))*smoothstep(.30,.38,local_point.z));
	 lum=dot(coat,vec3(.2126,.7152,.0722));
	}
	float plush=smoothstep(.045,.16,lum);
 if(coat_character>=0){
  bool on_nose=coat_character==0 ? (abs(local_point.x)<.19 && local_point.y>1.77 && local_point.y<2.005 && local_point.z>.63) : (abs(local_point.x)<.18 && local_point.y>1.91 && local_point.y<2.085 && local_point.z>.43);
  plush=on_nose ? smoothstep(.035,.11,lum) : 1.0;
 }
	coat=mix(coat,mix(vec3(lum),coat,.82)*1.12,plush);

 vec3 w=pow(abs(normalize(surface_normal)),vec3(5.0));w/=max(dot(w,vec3(1.0)),.0001);
 float height=dot(w,vec3(combed_height(local_point.zy),combed_height(local_point.xz),combed_height(local_point.xy)));
 vec3 px=dFdx(VERTEX),py=dFdy(VERTEX);vec3 r1=cross(py,NORMAL),r2=cross(NORMAL,px);float det=dot(px,r1);
 vec3 grad=sign(det)*(dFdx(height)*r1+dFdy(height)*r2);
 NORMAL=normalize(max(abs(det),.0000001)*NORMAL-surface_relief*plush*grad);
 ALBEDO=coat;
	ROUGHNESS=mix(mix(.30,.94,plush),.78,inner_ear);
	SPECULAR=mix(.48,.15,plush);
	RIM=sheen_strength*plush;RIM_TINT=.8;
}
