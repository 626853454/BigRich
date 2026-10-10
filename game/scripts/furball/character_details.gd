class_name FurCharacterDetails
extends RefCounted

static func promise_hat() -> Node3D:
	var hat:=Node3D.new();hat.name="PromiseCookieBeret";hat.rotation.z=-.12
	var pastry:=StandardMaterial3D.new();pastry.albedo_color=Color("e5af69");pastry.roughness=.82
	var biscuit:=MeshInstance3D.new();var cookie:=CylinderMesh.new()
	cookie.top_radius=.37;cookie.bottom_radius=.43;cookie.height=.16;cookie.radial_segments=24
	biscuit.mesh=cookie;biscuit.material_override=pastry;biscuit.position.y=.06;hat.add_child(biscuit)
	var chocolate:=StandardMaterial3D.new();chocolate.albedo_color=Color("795141");chocolate.roughness=.78
	var chips:=MultiMeshInstance3D.new();var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
	var shape:=SphereMesh.new();shape.radius=.052;shape.height=.055;shape.radial_segments=8;shape.rings=3
	batch.mesh=shape;batch.instance_count=5
	var positions:=[Vector3(-.21,.15,.14),Vector3(.16,.15,.24),Vector3(-.13,.15,-.23),Vector3(.24,.15,-.11),Vector3(0,.15,.02)]
	for index in 5:batch.set_instance_transform(index,Transform3D(Basis(),positions[index]))
	chips.multimesh=batch;chips.material_override=chocolate;hat.add_child(chips)
	var ribbon_material:=StandardMaterial3D.new();ribbon_material.albedo_color=Color("f29eb4");ribbon_material.roughness=.75
	for side in [-1,1]:
		var ribbon:=MeshInstance3D.new();var fold:=BoxMesh.new();fold.size=Vector3(.14,.09,.21)
		ribbon.mesh=fold;ribbon.material_override=ribbon_material;ribbon.position=Vector3(side*.085,.15,-.28);ribbon.rotation.z=side*.25;hat.add_child(ribbon)
	return hat
