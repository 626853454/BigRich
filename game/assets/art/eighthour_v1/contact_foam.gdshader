shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled,diffuse_burley;
uniform sampler2D surface_noise:filter_linear_mipmap,repeat_enable;
uniform float strength=.84;
varying vec2 p;
void vertex(){
 p=(MODEL_MATRIX*vec4(VERTEX,1)).xz;
 VERTEX.y+=sin(dot(p,vec2(.29,.17))+TIME*.53)*.075+sin(dot(p,vec2(-.47,.23))-TIME*.41)*.035+sin(dot(p,vec2(.13,-.66))+TIME*.31)*.021;
}
void fragment(){
 float broad=texture(surface_noise,p*.24+vec2(TIME*.008,TIME*.011)).r;
 float fine=texture(surface_noise,p*1.34-vec2(TIME*.018,TIME*.024)).r;
 float wash=.5+.5*sin(TIME*.7+UV.x*.23);
 float edge=smoothstep(.00,.12,UV.y)*(1.0-smoothstep(.3+wash*.22,.97,UV.y));
 float bubbles=smoothstep(.41,.62,broad)*smoothstep(.30,.62,fine);
 ALBEDO=vec3(.78,.90,.85);ROUGHNESS=.60;SPECULAR=.18;ALPHA=edge*bubbles*strength;
}
