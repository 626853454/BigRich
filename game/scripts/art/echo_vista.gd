class_name FurEchoVista
extends RefCounted
static func build(parent:Node3D)->void:
	var base:=FurHarborCraftedAssets.terrace(2,1);base.position=Vector3(0,-.86,-.6);base.scale=Vector3(.53,.65,.50);parent.add_child(base)
	var bridge:=FurTravelArtAssets.instance("echo_arched_walkway_v2",true);bridge.position=Vector3(0,-.80,-5.10);parent.add_child(bridge)
	for i in 5:
		var cloud:=FurTravelArtAssets.instance("cloud_bank_atelier");cloud.position=Vector3(-13+i*6,-4.3-float(i%2),-6.5-float(i%3)*3);cloud.scale=Vector3(2.4,2.8,2.4);parent.add_child(cloud)
	for i in 2:
		var far_isle:=FurHarborCraftedAssets.terrace(2,i);far_isle.position=Vector3(-10 if i==0 else 11,-3.0,-17-i*5);far_isle.scale=Vector3(.32,.5,.35);parent.add_child(far_isle)
		var tower:=FurTravelArtAssets.instance("echo_clock_sculpted_v2",true);tower.position=far_isle.position+Vector3(0,-.05,0);tower.scale=Vector3.ONE*.92;parent.add_child(tower)
