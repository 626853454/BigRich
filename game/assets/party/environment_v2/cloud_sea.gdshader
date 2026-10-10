shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec4 low_tint : source_color = vec4(.63,.72,.77,1.0);
uniform vec4 high_tint : source_color = vec4(.82,.87,.87,1.0);
uniform sampler2D surface_noise : filter_linear_mipmap, repeat_enable;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xz;}
void fragment(){
 vec2 p=world*.0065+vec2(TIME*.0003,-TIME*.0001);
 float layers=texture(surface_noise,p).r*.64+texture(surface_noise,p*2.03+vec2(.132,.073)).r*.26+texture(surface_noise,p*4.07).r*.10;
 float banks=smoothstep(.27,.75,layers);
 // Distant cloud haze is emissive atmosphere, not a floor receiving hard
 // miniature-island shadows. Nearby closed cloud meshes carry real volume.
 ALBEDO=mix(low_tint.rgb,high_tint.rgb,banks);ROUGHNESS=1.0;
}
