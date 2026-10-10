// World reconstruction follows Godot's reverse-Z depth-buffer documentation.
shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx,cull_back;
uniform sampler2D scene_depth:hint_depth_texture,filter_nearest,repeat_disable;
uniform sampler2D scene_color:hint_screen_texture,filter_linear_mipmap,repeat_disable;
uniform sampler2D surface_noise:filter_linear_mipmap,repeat_enable;
uniform vec4 water_tint:source_color=vec4(.045,.31,.43,1);
uniform vec4 shallow_tint:source_color=vec4(.09,.51,.53,1);
uniform float clarity=.37;
uniform float refraction_strength=.004;
uniform float wave_strength=1.0;
uniform int diagnostic=0;
varying vec3 water_world;
vec3 wave(vec2 p,float time){
 float a=dot(p,vec2(.29,.17))+time*.53;
 float b=dot(p,vec2(-.47,.23))-time*.41;
 float c=dot(p,vec2(.13,-.66))+time*.31;
 return vec3(sin(a)*.075+sin(b)*.035+sin(c)*.021,
 cos(a)*.075*.29-cos(b)*.035*.47+cos(c)*.021*.13,
 cos(a)*.075*.17+cos(b)*.035*.23-cos(c)*.021*.66)*wave_strength;
}
vec3 position_at(vec2 uv,float depth,mat4 inverse_view,mat4 inverse_projection){
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(uv,depth)*2.0-1.0;
 #else
 vec3 ndc=vec3(uv*2.0-1.0,depth);
 #endif
 vec4 world=inverse_view*inverse_projection*vec4(ndc,1.0);
 return world.xyz/world.w;
}
float field(vec2 uv){return texture(surface_noise,uv).r*.64+texture(surface_noise,vec2(uv.x*1.31+uv.y*.47,-uv.x*.36+uv.y*1.67)+vec2(.19,.43)).r*.36;}
void vertex(){
 water_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;vec3 swell=wave(water_world.xz,TIME);VERTEX.y+=swell.x;water_world.y+=swell.x;
 NORMAL=normalize(vec3(-swell.y,1,-swell.z));
}
void fragment(){
 vec2 p=water_world.xz;vec3 swell=wave(p,TIME);
 vec2 uv=vec2(dot(p,vec2(.95,.31)),dot(p,vec2(-.31,.95)))*vec2(.24,.61)+vec2(TIME*.014,-TIME*.031);
 float dx=(field(uv+vec2(.015,0))-field(uv-vec2(.015,0)))*.24*.65;
 float dz=(field(uv+vec2(0,.015))-field(uv-vec2(0,.015)))*.61*.65;
 vec2 fine=vec2(.95,.31)*dx+vec2(-.31,.95)*dz;
 vec3 world_normal=normalize(vec3(-swell.y-fine.x*1.8,1,-swell.z-fine.y*1.8));
 NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0)).xyz);
 float depth=texture(scene_depth,SCREEN_UV).r;vec3 bottom=position_at(SCREEN_UV,depth,INV_VIEW_MATRIX,INV_PROJECTION_MATRIX);
 float thickness=clamp(water_world.y-bottom.y,0.0,35.0);
 if(depth<.0000001)thickness=35.0;
 vec2 refr_uv=clamp(SCREEN_UV+NORMAL.xy*refraction_strength*min(thickness,1.5),vec2(.001),vec2(.999));
 vec3 refr_bottom=position_at(refr_uv,texture(scene_depth,refr_uv).r,INV_VIEW_MATRIX,INV_PROJECTION_MATRIX);
 if(refr_bottom.y>water_world.y+.03)refr_uv=SCREEN_UV;
 vec3 behind=textureLod(scene_color,refr_uv,0.0).rgb;
 float transmitted=exp(-thickness*clarity)*.87;
 float fresnel=.025+.22*pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),4.0);
 transmitted*=1.0-fresnel;
 float breakup=smoothstep(.36,.67,field(p*.20+vec2(TIME*.006,TIME*.019)));
 float edge=(1.0-smoothstep(.03,.28,thickness))*breakup*.62;
 float n1=texture(surface_noise,bottom.xz*.082+vec2(TIME*.006,0)).r;
 float n2=texture(surface_noise,vec2(bottom.z*.12,-bottom.x*.073)+vec2(0,TIME*.009)).r;
 float caustic=pow(clamp(1.0-abs(n1-n2)*8.5,0.0,1.0),10.0)*exp(-thickness*.8)*.13;
 vec3 tint=mix(shallow_tint.rgb,water_tint.rgb,smoothstep(.4,8.0,thickness));
 ALBEDO=mix(tint*(1.0-transmitted),vec3(.76,.88,.83),edge*.73);
 vec3 spectral_filter=exp(-thickness*vec3(.24,.07,.015));
 EMISSION=behind*transmitted*spectral_filter*(1.0-edge*.73)*(1.0+caustic);
 SPECULAR=.42;ROUGHNESS=.13+field(uv*.61)*.035;METALLIC=0.0;ALPHA=.995;
 if(diagnostic==1){ALBEDO=vec3(0);EMISSION=vec3(thickness/15.0,thickness/15.0,thickness/15.0);ROUGHNESS=1.0;SPECULAR=0.0;}
 if(diagnostic==2){ALBEDO=tint;EMISSION=vec3(0);}
}
