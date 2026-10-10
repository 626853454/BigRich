shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0,.83,.55,1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
void fragment(){
 float across=pow(max(0.0,1.0-abs(UV.y*2.0-1.0)),1.7);
 float head=1.0-smoothstep(0.0,.10,abs(UV.x-progress));
 float trail=(1.0-smoothstep(progress-.02,progress+.01,UV.x))*.24;
 ALBEDO=tint.rgb;EMISSION=tint.rgb*.8;
 ALPHA=max(head,trail)*across*fade;
}
