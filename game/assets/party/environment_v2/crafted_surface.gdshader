shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D wood_grain : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_grain : source_color, filter_linear_mipmap, repeat_enable;
uniform bool vertex_colors_are_srgb = true;
uniform int surface_family = 0;
uniform float wet_level = -100.0;
uniform float grain_strength_scale = 1.0;
uniform float relief_strength = 0.0;
varying vec3 world_point;
varying vec3 world_normal;
varying float authored_family;
vec3 linear_colour(vec3 c){return mix(c/12.92,pow((c+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),c));}
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 authored_family=UV2.x;
}
void fragment(){
 vec3 weights=pow(abs(normalize(world_normal)),vec3(4.0));weights/=max(dot(weights,vec3(1.0)),.0001);
 int family=surface_family<0?int(floor(authored_family+.5)):surface_family;
 float grain=1.0;float roughness=.84;float specular=.28;float metallic=0.0;float relief=0.0;
 if(family==0){
  vec3 p=world_point*.24;
  vec3 sample_colour=texture(stone_grain,p.yz).rgb*weights.x+texture(stone_grain,p.xz).rgb*weights.y+texture(stone_grain,p.xy).rgb*weights.z;
  float luma=dot(sample_colour,vec3(.2126,.7152,.0722));
  grain=mix(1.0,clamp(luma/.71015,.65,1.35),.065*grain_strength_scale);roughness=.88+(1.0-grain)*.6;relief=luma*.35;
 }else if(family==1){
  vec3 p=world_point*vec3(.22,.15,.22);
  vec3 sample_colour=texture(wood_grain,p.yz).rgb*weights.x+texture(wood_grain,p.xz).rgb*weights.y+texture(wood_grain,p.xy).rgb*weights.z;
  float luma=dot(sample_colour,vec3(.2126,.7152,.0722));
  grain=mix(1.0,clamp(luma/.30254,.65,1.35),.12*grain_strength_scale);roughness=.69+(1.0-grain)*.4;specular=.34;relief=luma;
 }else if(family==2){roughness=.93;specular=.18;
 }else if(family==3){roughness=.36;specular=.48;metallic=.48;
 }else if(family==5){roughness=.70;specular=.27;
 }else if(family==6){roughness=.64;specular=.25;
 }else if(family==7){roughness=.91;specular=.20;
 }else if(family==8){roughness=.24;specular=.45;
 }else{roughness=.25;specular=.58;}
 vec3 base=vertex_colors_are_srgb?linear_colour(COLOR.rgb):COLOR.rgb;
 float damp=(1.0-smoothstep(wet_level,wet_level+.72,world_point.y))*float(family==0);
 // Screen-space surface gradient: micro relief follows the actual mesh normal,
 // not a guessed tangent frame. The old material defaults to zero relief.
 vec3 dpdx=dFdx(VERTEX);vec3 dpdy=dFdy(VERTEX);
 vec3 r1=cross(dpdy,NORMAL);vec3 r2=cross(NORMAL,dpdx);float determinant=dot(dpdx,r1);
 vec3 surface_gradient=sign(determinant)*(dFdx(relief)*r1+dFdy(relief)*r2);
 NORMAL=normalize(max(abs(determinant),.0000001)*NORMAL-relief_strength*surface_gradient);
 ALBEDO=base*grain*mix(1.0,.82,damp);EMISSION=family==8?base*.16:vec3(0.0);ROUGHNESS=clamp(roughness-damp*.18,.22,.97);SPECULAR=specular;METALLIC=metallic;
}
