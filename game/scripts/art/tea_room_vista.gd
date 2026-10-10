class_name FurTeaRoomVista
extends RefCounted
## Real distant geometry beyond the playable table. It never takes input focus.
static func build(parent:Node3D)->void:
	for side in [-1,1]:
		var district:=Node3D.new();district.rotation.y=PI if side==1 else 0.0;parent.add_child(district);_side(district)
static func _side(parent:Node3D)->void:
	# Distant 3D scenery sits against a light sky wash, separate from studio IBL.
	var horizon:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(260,130);horizon.mesh=plane;horizon.rotation_degrees.x=90;horizon.position=Vector3(0,25,-95);horizon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sky_material:=StandardMaterial3D.new();sky_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;sky_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color("a1cde3"),Color("edf0df")]);var wash:=GradientTexture2D.new();wash.gradient=gradient;wash.width=8;wash.height=128;wash.fill_from=Vector2(.5,0);wash.fill_to=Vector2(.5,1);sky_material.albedo_texture=wash;horizon.material_override=sky_material;parent.add_child(horizon)
	for index in 3:
		var base:=FurHarborCraftedAssets.terrace(1,index);base.position=Vector3(-21+index*21,-7-index*1.4,-28-index*6);base.scale=Vector3(1.45,1.0,1.25);parent.add_child(base)
		var pavilion:=FurTravelArtAssets.instance("tea_pavilion_atelier");pavilion.position=base.position+Vector3(0,2.8,0);pavilion.scale=Vector3.ONE*(2.30 if index==1 else 1.65);parent.add_child(pavilion);_distant_shadow(pavilion)
		var mountains:=FurCoastalSculptAssets.instance("coast_land_rocks_02");mountains.position=base.position+Vector3(0,-3.2,-6);mountains.scale=Vector3(3.5,6.0+float(index%2)*2.0,3.5);parent.add_child(mountains);_distant_shadow(mountains)
	for index in 6:
		var cloud:=FurTravelArtAssets.instance("cloud_bank_atelier");cloud.position=Vector3(-32+index*13,-7.5-float(index%3),-23-float(index%2)*12);cloud.scale=Vector3(4.1,3.8+float(index%2)*.65,3.4);parent.add_child(cloud)

static func _distant_shadow(node:Node)->void:
	if node is GeometryInstance3D:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.lod_bias=.08
	for child in node.get_children():_distant_shadow(child)
