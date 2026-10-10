shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley;
uniform vec4 foam_color : source_color = vec4(.86,.95,.90,1.0);
uniform float strength = .72;
uniform float wave_follow = 1.0;
uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
void vertex(){vec2 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;VERTEX.y+=(sin(dot(p,vec2(.24,.17))+TIME*.42)*.13+sin(dot(p,vec2(-.31,.22))-TIME*.31)*.06)*wave_follow;}
void fragment(){
 float broad=texture(surface_noise,vec2(UV.x*.037-TIME*.003,UV.y*.17+TIME*.002)).r;
 float fine=texture(surface_noise,vec2(UV.x*.19+TIME*.012,UV.y*.63-TIME*.009)).r;
 float wash=.5+.5*sin(TIME*.42+UV.x*.071);
 float shifted=UV.y+(broad-.5)*.35-wash*.13;
 float edge=smoothstep(.015,.20,shifted)*(1.0-smoothstep(.42,.98,shifted));
 float broken=smoothstep(.40,.62,broad)*mix(.28,1.0,smoothstep(.30,.63,fine));
 ALBEDO=foam_color.rgb;ROUGHNESS=.56;SPECULAR=.22;
 ALPHA=edge*broken*strength;
}
