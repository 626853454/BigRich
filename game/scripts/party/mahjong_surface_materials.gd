class_name FurMahjongSurfaceMaterials
extends RefCounted
## Shared bounded material library; no state/identity/input or texture downloads.
static var _cache:Dictionary={}

static func surface(kind:String,colour:Color,vertex_colours:bool=false)->ShaderMaterial:
	var key:=kind+colour.to_html()+str(vertex_colours)
	if _cache.has(key):return _cache[key]
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint:source_color=vec4(1.0);
uniform int kind=0;
uniform bool use_vertex=false;
varying vec3 local_position;
varying vec3 world_position;
varying vec3 local_normal;
varying vec4 vertex_tint;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise21(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);}
void vertex(){local_position=VERTEX;world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_normal=NORMAL;vertex_tint=COLOR;}
void fragment(){
 vec3 base=tint.rgb*(use_vertex?vertex_tint.rgb:vec3(1.0));
 float variation=1.0;float rough=.5;float metal=0.0;
 if(kind==0){ // porcelain: broad reflection with extremely quiet glaze pores
  float pores=noise21(local_position.xy*72.0);variation=.985+.015*pores;rough=.19+.035*pores;
 }else if(kind==1){ // woven cloth: constant density on the actual tabletop
  vec2 uv=world_position.xz*70.0;float warp=sin(uv.x)*sin(uv.y);
  variation=.982+.005*warp+.010*noise21(world_position.xz*9.0);rough=.92;
 }else if(kind==2){ // timber grain, aligned along each furniture piece
  // World-space longitudinal fibres: never apply a woven XY lattice to timber.
  vec2 p=world_position.xz;
  float wandering=noise21(vec2(p.x*.12,p.y*.65));
  float wave=sin(p.y*11.0+wandering*4.0);
  float darkline=smoothstep(.75,.99,wave);
  variation=.97-.065*darkline+.035*noise21(vec2(p.x*.16,p.y*2.0));rough=.44;
 }else if(kind==3){variation=.98+.02*noise21(local_position.xy*14.0);rough=.32;metal=.68;
 }else{variation=.97+.03*noise21(local_position.xz*3.0);rough=.82;}
 ALBEDO=base*variation;ROUGHNESS=rough;METALLIC=metal;SPECULAR=.42;
 CLEARCOAT=(kind==0)?0.28:((kind==2)?0.12:0.0);
 CLEARCOAT_ROUGHNESS=0.45;
}
"""
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.set_shader_parameter("tint",colour);mat.set_shader_parameter("kind",{"ceramic":0,"cloth":1,"wood":2,"brass":3,"stone":4}.get(kind,4));mat.set_shader_parameter("use_vertex",vertex_colours)
	_cache[key]=mat;return mat

static func cache_size()->int:return _cache.size()
