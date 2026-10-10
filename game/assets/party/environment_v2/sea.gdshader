shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.14,0.53,0.68,1.0);
uniform vec4 shelf_color : source_color = vec4(0.51,0.84,0.76,1.0);
uniform vec4 shelf_a = vec4(-18.0,9.0,12.4,9.3);
uniform vec4 shelf_b = vec4(0.0,-13.0,12.4,9.3);
uniform vec4 shelf_c = vec4(18.0,9.0,12.4,9.3);
uniform int shelf_count = 3;
uniform float shore_power = 2.0;
uniform float geometry_wave_scale = 1.0;
uniform float normal_wave_scale = 1.0;
uniform float ripple_normal_strength = 2.0;
uniform float stroke_visibility = 0.0;
uniform float roughness_base = .29;
uniform float specular_strength = .58;
uniform vec2 ripple_frequency = vec2(.26,.60);
uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
varying vec2 water_position;
float ripple_height(vec2 uv){
 // Two rotated, incommensurate filtered fields break the visible tiled rows
 // of the previous one-frequency texture, while staying temporally smooth.
 vec2 second=vec2(uv.x*1.37+uv.y*.41,-uv.x*.27+uv.y*1.71)+vec2(.193,.427);
 return texture(surface_noise,uv).r*.63+texture(surface_noise,second).r*.37;
}
float shelf_distance(vec2 p,vec4 region){vec2 q=abs((p-region.xy)/region.zw);return pow(pow(q.x,shore_power)+pow(q.y,shore_power),1.0/shore_power);}
void vertex(){
 water_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 float phase_a=dot(water_position,vec2(.24,.17))+TIME*.42;
 float phase_b=dot(water_position,vec2(-.31,.22))-TIME*.31;
 VERTEX.y+=(sin(phase_a)*.13+sin(phase_b)*.06)*geometry_wave_scale;
 // Exact derivative of the same displaced surface, in local mesh coordinates.
 // Godot performs the ordinary vertex-normal model/view transformation.
 // Fragment adds finer shading ripples in world space; the actual plane keeps
 // this bounded large-wave displacement and its corresponding normal.
 float slope_x=(cos(phase_a)*.13*.24-cos(phase_b)*.06*.31)*geometry_wave_scale;
 float slope_z=(cos(phase_a)*.13*.17+cos(phase_b)*.06*.22)*geometry_wave_scale;
 NORMAL=normalize(vec3(-slope_x*normal_wave_scale,1.0,-slope_z*normal_wave_scale));
}
void fragment(){
 // Coordinates are shared with the analytic vertex wave; colour and roughness
 // are continuous low-frequency detail. Fine ripples have an analytic normal
 // in world space, explicitly transformed to view space without a TBN remap.
 vec2 p=water_position;
 float phase_a=dot(p,vec2(.24,.17))+TIME*.42;
 float phase_b=dot(p,vec2(-.31,.22))-TIME*.31;
 vec2 slope=vec2(cos(phase_a)*.13*.24-cos(phase_b)*.06*.31,cos(phase_a)*.13*.17+cos(phase_b)*.06*.22)*geometry_wave_scale*normal_wave_scale;
 // A filtered, advected height field supplies irregular small ripples. Two
 // pure intersecting sine normals made regular rows of specular beads.
 // Central differences are measured in world metres, not texture pixels.
 vec2 wind=vec2(.95,.31);
 vec2 crosswind=vec2(-.31,.95);
 vec2 ripple_uv=vec2(dot(p,wind),dot(p,crosswind))*ripple_frequency+vec2(TIME*.012,-TIME*.027);
 vec2 step_u=vec2(.018,0.0);
 vec2 step_v=vec2(0.0,.018);
 vec2 gradient=vec2(ripple_height(ripple_uv+step_u)-ripple_height(ripple_uv-step_u),ripple_height(ripple_uv+step_v)-ripple_height(ripple_uv-step_v))*ripple_frequency*(.024/.036);
 slope+=(wind*gradient.x+crosswind*gradient.y)*ripple_normal_strength;
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(vec3(-slope.x,1.0,-slope.y)),0.0)).xyz);
 float coast=shelf_distance(p,shelf_a);
 if(shelf_count>1){coast=min(coast,shelf_distance(p,shelf_b));}
 if(shelf_count>2){coast=min(coast,shelf_distance(p,shelf_c));}
 float broad=texture(surface_noise,p*.06+vec2(TIME*.0018,-TIME*.0012)).r;
 float shallow=1.0-smoothstep(.99,1.34,coast+(broad-.5)*.085);
 float detail=texture(surface_noise,p*.071+vec2(TIME*.0025,TIME*.0017)).r;
 // Clamp before exponentiation: fractional GPU pow is undefined for even a
 // tiny negative base and contaminates bloom/IBL with black NaN pixels.
 float caustic_band=clamp(1.0-abs(texture(surface_noise,p*.053+vec2(TIME*.0012,0)).r-.52)*2.0,0.0,1.0);
 float caustic_square=caustic_band*caustic_band;
 float caustic=caustic_square*caustic_square*caustic_square*shallow;
 // Bright peaks, not an isocontour: this cannot draw the previous closed
 // "elevation map" loops. Anisotropic coordinates make short soft strokes
 // along one wind direction; a second broad field breaks their coverage.
 vec2 flow_uv=vec2(dot(p,vec2(.93,.36))*.115,dot(p,vec2(-.36,.93))*.72)+vec2(TIME*.008,-TIME*.055);
 float peak=texture(surface_noise,flow_uv).r;
 float sparse=smoothstep(.48,.64,texture(surface_noise,p*.047+vec2(.37,.13)).r);
 float glint=smoothstep(.64,.81,peak)*sparse*(1.0-shallow*.48)*stroke_visibility;
 float swell=texture(surface_noise,p*.026+vec2(TIME*.0013,-TIME*.002)).r;
 ALBEDO=mix(deep_color.rgb,shelf_color.rgb,shallow*.86)*(0.92+broad*.09+swell*.07)+shelf_color.rgb*caustic*.028+vec3(.085,.11,.10)*glint;
 EMISSION=vec3(.018,.027,.027)*glint;
 // Broken, softer highlights leave the coastline readable at board distance.
 // Surface geometry still supplies real moving normals, not painted white bands.
 ROUGHNESS=roughness_base+detail*.06;
 SPECULAR=specular_strength;
 METALLIC=0.0;
}
