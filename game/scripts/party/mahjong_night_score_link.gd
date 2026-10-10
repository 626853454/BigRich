class_name FurMahjongNightScoreLink
extends MeshInstance3D

# One short-lived ribbon follows an actual scored group into its actual relic.
# At most 32 quads / one transparent surface, no particle allocation or rule access.
var _shader:ShaderMaterial
var _motion:Tween
var activations:int=0
var last_from:Vector3
var last_to:Vector3

func _ready()->void:
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shader=ShaderMaterial.new();_shader.shader=load("res://assets/mahjong_night/show/score_link.gdshader");material_override=_shader;hide()

func activate(start:Vector3,finish:Vector3,camera:Camera3D,route:String,speed:float)->void:
	if not is_instance_valid(camera) or start.distance_to(finish)<.1:return
	if is_instance_valid(_motion):_motion.kill()
	last_from=start;last_to=finish;activations+=1
	var positions:=PackedVector3Array();var texcoords:=PackedVector2Array();var indices:=PackedInt32Array()
	for i in 33:
		var t:float=float(i)/32.0;var point:Vector3=start.lerp(finish,t)+Vector3.UP*sin(t*PI)*.66
		var tangent:Vector3=(finish-start)+Vector3.UP*cos(t*PI)*PI*.66
		var side:Vector3=tangent.cross(camera.global_position-point).normalized()*.095
		positions.append(point-side);positions.append(point+side);texcoords.append(Vector2(t,0));texcoords.append(Vector2(t,1))
		if i<32:indices.append_array(PackedInt32Array([i*2,i*2+1,i*2+2,i*2+1,i*2+3,i*2+2]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=texcoords;arrays[Mesh.ARRAY_INDEX]=indices
	var ribbon:=ArrayMesh.new();ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh=ribbon
	_shader.set_shader_parameter("tint",{"连顺":Color("aaf4e9"),"爆杠":Color("ffcb79"),"接力":Color("ffd2ca")}.get(route,Color("ffe1a0")))
	_shader.set_shader_parameter("progress",0.0);_shader.set_shader_parameter("fade",1.0);show()
	_motion=create_tween();_motion.set_speed_scale(speed)
	_motion.tween_method(func(t:float):_shader.set_shader_parameter("progress",t),0.0,1.0,.12)
	_motion.tween_method(func(t:float):_shader.set_shader_parameter("fade",1.0-t),0.0,1.0,.05)
	_motion.tween_callback(hide)

func clear()->void:
	if is_instance_valid(_motion):_motion.kill()
	hide()
