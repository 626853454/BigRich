class_name FurMarketStory
extends Node3D

var bell_pivot: Node3D
var seals: Array[MeshInstance3D]=[]
var sign: Label3D
var progress:=-1
var celebration:=0.0

func _ready() -> void:
	var timber:=material(Color("855939"),.75)
	var brass:=material(Color("ffc76b"),.32)
	brass.metallic=.4
	for x in [-6.6,-4.4]:box(Vector3(x,1.9,-10.2),Vector3(.14,3.8,.14),timber)
	box(Vector3(-5.5,3.78,-10.2),Vector3(2.6,.19,.23),timber)
	bell_pivot=Node3D.new();bell_pivot.position=Vector3(-5.5,3.3,-10.2);add_child(bell_pivot)
	var bell:=MeshInstance3D.new();var shape:=CylinderMesh.new()
	shape.top_radius=.23;shape.bottom_radius=.49;shape.height=.62;shape.radial_segments=24
	bell.mesh=shape;bell.material_override=brass;bell_pivot.add_child(bell)
	var lip:=MeshInstance3D.new();var rim:=TorusMesh.new();rim.inner_radius=.45;rim.outer_radius=.51;rim.rings=24;rim.ring_segments=6
	lip.mesh=rim;lip.material_override=brass;lip.position.y=-.31;bell_pivot.add_child(lip)
	var hanger:=MeshInstance3D.new();var hoop:=TorusMesh.new();hoop.inner_radius=.10;hoop.outer_radius=.14;hoop.rings=16;hoop.ring_segments=6
	hanger.mesh=hoop;hanger.material_override=brass;hanger.position.y=.42;hanger.rotation.x=PI/2;bell_pivot.add_child(hanger)
	var clapper:=MeshInstance3D.new();var bead:=SphereMesh.new();bead.radius=.10;bead.height=.20;bead.radial_segments=12;bead.rings=6
	clapper.mesh=bead;clapper.material_override=brass;clapper.position.y=-.43;bell_pivot.add_child(clapper)
	for side in [-1,1]:
		var seal:=MeshInstance3D.new();var stamp:=SphereMesh.new();stamp.radius=.14;stamp.height=.28;stamp.radial_segments=12;stamp.rings=6
		seal.mesh=stamp;seal.material_override=material(Color("e96782"),.60);seal.scale.z=.3
		seal.position=Vector3(side*.19,-.10,.45);bell_pivot.add_child(seal);seals.append(seal)
	var backing:=box(Vector3(-5.5,1.6,-10),Vector3(3.1,1.25,.12),material(Color("253d56"),.8))
	backing.rotation.x=-.80
	sign=Label3D.new();var font:=FurVisualStyle.font()
	sign.font=font;sign.font_size=60;sign.pixel_size=.009;sign.outline_size=3;sign.outline_modulate=Color("253d56")
	sign.text="关门铃\n封条还在";sign.position=backing.position+backing.basis*Vector3(0,0,.075);sign.rotation=backing.rotation
	sign.modulate=Color("ffefc2");add_child(sign)

func material(colour: Color, roughness: float) -> StandardMaterial3D:
	var surface:=StandardMaterial3D.new();surface.albedo_color=colour;surface.roughness=roughness
	return surface

func box(position_value: Vector3, size_value: Vector3, surface: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size_value
	node.mesh=shape;node.material_override=surface;node.position=position_value;add_child(node)
	return node

func reset() -> void:
	progress=-1;celebration=0

func update_story(model: FurCombatModel, delta: float) -> int:
	var next:=0
	# wave still names the completed third battle while round four is on the board.
	# Keep the earned half seal through this transition, without replaying its cue.
	if model.wave>3 or model.wave==3 and model.phase in ["draft","route","board"]:next=1
	if model.phase=="victory":next=2
	if model.phase in ["camp","waiting"]:next=0
	var newly_earned:=-1
	if next!=progress:
		if next>progress and progress>=0 and next>0:newly_earned=next;celebration=1.6
		progress=next
		for index in seals.size():seals[index].visible=index>=progress
		sign.text="关门铃\n"+["封条还在","半枚到手","整枚到手！"][progress]
	celebration=maxf(0,celebration-delta)
	bell_pivot.rotation.z=sin(celebration*14)*.18*(celebration/1.6)
	return newly_earned
