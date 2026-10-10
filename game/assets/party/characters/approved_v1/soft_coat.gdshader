shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform sampler2D coat_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D fibre_noise : filter_linear_mipmap, repeat_enable;
uniform bool fur_layer=false;
uniform float coat_length=.009;
uniform float gait_phase=0.0;
uniform float gait_weight=0.0;
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
	float eye_distance=length(vec2((abs(base.x)-.25)/.11,(base.y-2.04)/.13));
	grooming_mask=mix(1.0,smoothstep(.85,1.35,eye_distance),smoothstep(.20,.30,abs(base.z)));
	grooming_mask*=mix(1.0,.48,smoothstep(1.62,1.83,base.y)*(1.0-smoothstep(1.94,2.02,base.y)));
	float a=sin(gait_phase)*gait_weight;
	VERTEX+=(swing(base,vec3(-.25,.38,0),a*.38)-base)*COLOR.r;
	VERTEX+=(swing(base,vec3(.25,.38,0),-a*.38)-base)*COLOR.g;
	VERTEX+=(swing(base,vec3(-.40,1.35,0),-a*.20)-base)*COLOR.b;
	VERTEX+=(swing(base,vec3(.40,1.35,0),a*.20)-base)*COLOR.a;
	layer=INSTANCE_CUSTOM.r;
	if(fur_layer){VERTEX+=NORMAL*coat_length*layer*grooming_mask;}
}
void fragment(){
	vec3 coat=texture(coat_texture,UV).rgb;
	float lum=dot(coat,vec3(.2126,.7152,.0722));
	float plush=smoothstep(.045,.16,lum);
	coat=mix(coat,mix(vec3(lum),coat,.82)*1.12,plush);
	ALBEDO=coat;
	ALPHA=1.0;
	ROUGHNESS=mix(.30,.94,smoothstep(.035,.19,lum));
	SPECULAR=mix(.48,.15,smoothstep(.035,.19,lum));
	RIM=.20*plush;RIM_TINT=.8;
	if(fur_layer){
		float pattern=texture(fibre_noise,UV*9.0).r;
		float density=smoothstep(.24+layer*.48,.32+layer*.48,pattern);
		float nose_mask=smoothstep(.035,.10,lum);
		float eye_dist=length(vec2((abs(local_point.x)-.25)/.11,(local_point.y-2.04)/.13));
		float eye_mask=mix(1.0,smoothstep(.82,1.35,eye_dist),smoothstep(.20,.30,abs(local_point.z)));
		ALPHA=density*nose_mask*eye_mask;ALPHA_SCISSOR_THRESHOLD=.42;
		ALBEDO=coat*1.03;ROUGHNESS=.98;SPECULAR=.10;
		RIM=.28;RIM_TINT=.8;
	}
}
