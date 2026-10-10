shader_type canvas_item;
uniform float corner_fraction=.055;
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	vec2 p=abs(UV-.5)-vec2(.5-corner_fraction);
	float d=length(max(p,vec2(0)))+min(max(p.x,p.y),0.0)-corner_fraction;
	COLOR=vec4(source.rgb,source.a*(1.0-smoothstep(-.003,.001,d)));
}
