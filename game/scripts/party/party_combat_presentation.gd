class_name FurPartyCombatPresentation
extends RefCounted
## Party-only view settings: shared camera language and legible bounded shots.
## No model positions, hit shapes, projectile limits or timing are changed.
static func configure(view:FurCombatView)->void:
	for hero in view.heroes:
		hero.locomotion.gait_stride=2.4;hero.locomotion.gait_speed_limit=7.5
	view.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	view.camera.keep_aspect=Camera3D.KEEP_WIDTH
	view.camera.size=39.0;view.camera.far=150.0
	var focus:=Vector3(0,.8,0)
	view.camera.position=focus+Vector3(0,32,38)
	view.camera.look_at(focus)
	var shape:=SphereMesh.new();shape.radius=.105;shape.height=.21;shape.radial_segments=12;shape.rings=6
	view.shot_mesh.multimesh.mesh=shape
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded;
uniform vec4 edge : source_color = vec4(.141,.333,.420,1.0);
void fragment(){
	float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
	vec3 core=mix(COLOR.rgb,vec3(1.0),.22);
	ALBEDO=mix(edge.rgb,core,smoothstep(.18,.65,facing));
}
"""
	var material:=ShaderMaterial.new();material.shader=shader
	view.shot_mesh.material_override=material
