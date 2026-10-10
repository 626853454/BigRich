class_name FurMahjongTableContactRig
extends Node
## Table-only skeletal pose. The fixed sorting rail delivers a tile to the paw;
## its carried interval uses the actual Contact bone, then releases to the table.
var skeleton:Skeleton3D
var _indices:Dictionary={}
var _rest:Dictionary={}
var last_reach_error:float=0
var contact_active:bool=false
var _character:Node3D

func install(character:Node3D,actor:int)->bool:
	_character=character
	var body_rig:Node3D=character.get_node_or_null("SoftBodyRig")
	if body_rig==null or body_rig.get_child_count()==0:return false
	var old_model:Node3D=body_rig.get_child(0)
	var materials:Dictionary={}
	var render_settings:Dictionary={}
	for mesh:MeshInstance3D in old_model.find_children("*","MeshInstance3D",true,false):
		var list:Array=[]
		for surface in mesh.mesh.get_surface_count():list.append(mesh.get_surface_override_material(surface))
		materials[str(mesh.name)]=list
		render_settings[str(mesh.name)]={"lod_bias":mesh.lod_bias,"visibility_range_end":mesh.visibility_range_end,"visibility_range_end_margin":mesh.visibility_range_end_margin,"cast_shadow":mesh.cast_shadow}
	var packed:PackedScene=load("res://assets/mahjong_night/rigs/%s_table_contact.glb"%("nemo" if actor==0 else "bear"))
	if packed==null:return false
	var model:Node3D=packed.instantiate();body_rig.add_child(model);body_rig.move_child(model,0)
	var found:Array=model.find_children("*","Skeleton3D",true,false)
	if found.is_empty():model.queue_free();return false
	skeleton=found[0]
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var name_key:String=str(mesh.name)
		if name_key.begins_with("Collar"):mesh.hide()
		if materials.has(name_key):
			for surface in mini(mesh.mesh.get_surface_count(),materials[name_key].size()):mesh.set_surface_override_material(surface,materials[name_key][surface])
			for property:String in render_settings[name_key]:mesh.set(property,render_settings[name_key][property])
		if name_key in ["BoundedShellGroom","LayeredCurvedGroom"]:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_rig.remove_child(old_model);old_model.queue_free()
	for name_key:String in ["Root","Head","Leg.R","Leg.L","Upper.R","Lower.R","Paw.R","Contact.R","Upper.L","Lower.L","Paw.L","Contact.L"]:
		var index:int=skeleton.find_bone(name_key)
		if index<0:index=skeleton.find_bone(name_key.replace(".","_"))
		if index<0:return false
		_indices[name_key]=index;_rest[name_key]=skeleton.get_bone_global_rest(index)
	for material:ShaderMaterial in character.get_meta("approved_coat_materials",[]):
		material.set_shader_parameter("gait_weight",0.0);material.set_shader_parameter("seated_pose",0.0);material.set_shader_parameter("table_gesture",0.0)
	character.set_meta("night_skeletal_rig",true)
	seat();return true

func _pose(name_key:String,pose:Transform3D)->void:skeleton.set_bone_global_pose(_indices[name_key],pose)
func seat()->void:
	if not is_instance_valid(skeleton) or _rest.size()!=12:return
	contact_active=false
	_pose("Root",_rest.Root);_pose("Head",_rest.Head)
	for side:String in ["R","L"]:
		var leg:Transform3D=_rest["Leg."+side];_pose("Leg."+side,Transform3D(Basis(Vector3.RIGHT,-1.10)*leg.basis,leg.origin))
		var pivot:Vector3=_rest["Upper."+side].origin;var turn:=Basis(Vector3.RIGHT,-.52)
		for bone:String in ["Upper.","Lower.","Paw.","Contact."]:
			var rest:Transform3D=_rest[bone+side];_pose(bone+side,Transform3D(turn*rest.basis,pivot+turn*(rest.origin-pivot)))

func contact_world(side:String="L")->Vector3:
	if not is_instance_valid(skeleton) or not _indices.has("Contact."+side):return Vector3.ZERO
	return skeleton.global_transform*skeleton.get_bone_global_pose(_indices["Contact."+side]).origin

func reach(world_target:Vector3,weight:float,side:String="L")->Vector3:
	if not is_instance_valid(skeleton):return world_target
	var initial:Vector3=contact_world(side);var desired:Vector3=initial.lerp(world_target,clampf(weight,0,1))
	var goal:Vector3=skeleton.global_transform.affine_inverse()*desired
	var upper:Transform3D=_rest["Upper."+side];var lower:Transform3D=_rest["Lower."+side];var paw:Transform3D=_rest["Paw."+side];var contact:Transform3D=_rest["Contact."+side]
	var hand_rotation:=Basis(Vector3.RIGHT,-.52)
	var wrist_goal:Vector3=goal-hand_rotation*(contact.origin-paw.origin)
	var a:float=upper.origin.distance_to(lower.origin);var b:float=lower.origin.distance_to(paw.origin)
	var ray:Vector3=wrist_goal-upper.origin;var distance:float=clampf(ray.length(),absf(a-b)+.001,a+b-.001);var direction:Vector3=ray.normalized()
	var pole:Vector3=Vector3(1.0 if side=="R" else -1.0,.78,-.42)-upper.origin
	var perpendicular:Vector3=(pole-direction*pole.dot(direction)).normalized()
	if perpendicular.length()<.5:perpendicular=direction.cross(Vector3.UP).normalized()
	var along:float=(a*a-b*b+distance*distance)/(2*distance);var height:float=sqrt(maxf(0,a*a-along*along))
	var elbow:Vector3=upper.origin+direction*along+perpendicular*height
	var wrist:Vector3=upper.origin+direction*distance
	var upper_rotation:=Basis(Quaternion((lower.origin-upper.origin).normalized(),(elbow-upper.origin).normalized()))
	var lower_rotation:=Basis(Quaternion((paw.origin-lower.origin).normalized(),(wrist-elbow).normalized()))
	_pose("Upper."+side,Transform3D(upper_rotation*upper.basis,upper.origin))
	_pose("Lower."+side,Transform3D(lower_rotation*lower.basis,elbow))
	_pose("Paw."+side,Transform3D(hand_rotation*paw.basis,wrist))
	var actual_contact:Vector3=wrist+hand_rotation*(contact.origin-paw.origin)
	_pose("Contact."+side,Transform3D(hand_rotation*contact.basis,actual_contact))
	var actual_world:Vector3=skeleton.global_transform*actual_contact
	last_reach_error=actual_world.distance_to(desired);contact_active=weight>.1
	return actual_world

func celebrate(amount:float)->void:
	seat()
	var head:Transform3D=_rest.Head
	_pose("Head",Transform3D(Basis(Vector3.RIGHT,-amount*.17)*Basis(Vector3.FORWARD,amount*.07)*head.basis,head.origin))
	for side:String in ["R","L"]:
		var pivot:Vector3=_rest["Upper."+side].origin;var turn:=Basis(Vector3.RIGHT,-.52-amount*(.84 if side=="R" else .63))*Basis(Vector3.FORWARD,amount*(.09 if side=="R" else -.07))
		for bone:String in ["Upper.","Lower.","Paw.","Contact."]:
			var rest:Transform3D=_rest[bone+side];_pose(bone+side,Transform3D(turn*rest.basis,pivot+turn*(rest.origin-pivot)))

func attend(phase:float,active:bool)->void:
	seat()
	var head:Transform3D=_rest.Head
	var pitch:float=(.10 if active else .035)+sin(phase*.65)*.018
	_pose("Head",Transform3D(Basis(Vector3.RIGHT,pitch)*Basis(Vector3.UP,sin(phase*.38)*.022)*head.basis,head.origin+Vector3(0,sin(phase)*.008,0)))

func weave(phase:float)->void:
	# Small authored skeletal invitation gesture; floating tile exchange remains
	# visible as a game convention, not a claim of physical paw contact.
	seat()
	var envelope:float=sin(clampf(phase,0,1)*PI)
	var head:Transform3D=_rest.Head
	_pose("Head",Transform3D(Basis(Vector3.RIGHT,envelope*.13)*Basis(Vector3.UP,sin(phase*TAU)*.08)*head.basis,head.origin))
	for side:String in ["L","R"]:
		var sign_value:float=-1.0 if side=="L" else 1.0
		var pivot:Vector3=_rest["Upper."+side].origin
		var turn:=Basis(Vector3.RIGHT,-.52-envelope*.40)*Basis(Vector3.FORWARD,sign_value*envelope*.18)*Basis(Vector3.UP,sign_value*sin(phase*TAU)*.12)
		for bone:String in ["Upper.","Lower.","Paw.","Contact."]:
			var rest:Transform3D=_rest[bone+side];_pose(bone+side,Transform3D(turn*rest.basis,pivot+turn*(rest.origin-pivot)))

func diagnostics()->Dictionary:
	return {"installed":is_instance_valid(skeleton),"bones":_rest.size(),"actual_contact":contact_world(),"reach_error":last_reach_error,"contact_active":contact_active}
