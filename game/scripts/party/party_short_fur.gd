class_name FurPartyShortFur
extends RefCounted
## Three fixed, millimetre-length soft-alpha shells on sculpt fur surfaces only.
## Geometry is shared; draw/overdraw cost is real and requires native measurement.
const LAYERS:=3
const TRIANGLE_LIMIT:=150000
static var _meshes:Dictionary={}
static var _materials:Array[ShaderMaterial]=[]
static var _shader:Shader

static func attach(instance:MeshInstance3D,remaining:int)->int:
	if instance.has_meta("short_fur_shell"):return 0
	var source:Mesh=instance.mesh
	var key:int=source.get_instance_id()
	if not _meshes.has(key):
		var extracted:=ArrayMesh.new()
		for surface:int in source.get_surface_count():
			var material:Material=source.surface_get_material(surface)
			if material!=null and material.resource_name=="SoftFurSculpt":
				extracted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(surface))
		_meshes[key]=extracted
	var mesh:ArrayMesh=_meshes[key]
	if mesh.get_surface_count()==0:return 0
	var triangles:int=0
	for surface:int in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		triangles+=indices.size()/3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
	if triangles*LAYERS>remaining:return 0
	_prepare()
	for layer:int in LAYERS:
		var shell:=MeshInstance3D.new()
		shell.name="ShortFurShell%d"%(layer+1)
		shell.set_meta("short_fur_shell",true)
		shell.mesh=mesh;shell.material_override=_materials[layer]
		shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_child(shell)
	return triangles*LAYERS

static func _prepare()->void:
	if _shader!=null:return
	_shader=Shader.new()
	_shader.code="""
shader_type spatial;
// Soft transparent fibres do not enter the opaque depth/SSAO micro-surface.
// No shadow; no arbitrary darkening; the same root color/BRDF as underlying fur.
render_mode blend_mix, cull_back, depth_draw_never;
uniform float shell_length;
uniform float coverage;
varying vec3 rest_position;
varying vec3 rest_normal;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float fibres(vec2 uv){
 vec2 cells=uv*520.0;vec2 id=floor(cells);
 vec2 center=vec2(hash21(id+1.7),hash21(id+8.2))*.36+.32;
 vec2 d=(fract(cells)-center)*vec2(1.0,.82);
 return 1.0-smoothstep(.035,.095,dot(d,d));
}
void vertex(){rest_position=VERTEX;rest_normal=NORMAL;VERTEX+=NORMAL*shell_length;}
void fragment(){
 vec3 w=pow(abs(normalize(rest_normal)),vec3(4.0));w/=max(w.x+w.y+w.z,.0001);
 float strand=dot(w,vec3(fibres(rest_position.zy),fibres(rest_position.xz),fibres(rest_position.xy)));
 ALBEDO=COLOR.rgb;
 ROUGHNESS=.94;SPECULAR=.10;RIM=.07;RIM_TINT=.42;
 ALPHA=strand*coverage;
}
"""
	for layer:int in LAYERS:
		var material:=ShaderMaterial.new();material.shader=_shader
		material.set_shader_parameter("shell_length",.002*float(layer+1))
		material.set_shader_parameter("coverage",.48-.10*float(layer))
		_materials.append(material)
