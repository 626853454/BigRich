class_name FurPartyLandmarkFactory
extends RefCounted
## Reuses the board's detailed assets without spawning terrain, gameplay or UI.
## The returned Node3D stands at local y=0. Caller owns its placement and lifetime.
const World=preload("res://scripts/party/world_builder.gd")
const Assets=preload("res://scripts/party/party_world_archipelago.gd")

static func build(district:int,height_limit:float=3.5)->Node3D:
	var world:=World.new();world.name="DistrictLandmark_%d"%clampi(district,0,2)
	var painter:=Assets.new();painter.w=world;world._archipelago=painter
	var actual_height:float=3.52
	match clampi(district,0,2):
		0:painter._detailed_house(Vector3.ZERO,Vector3(3.2,1.55,2.45),Color("c8a27b"),Color("557b87"),0.0,true)
		1:painter._windmill(Vector3.ZERO);actual_height=5.10
		2:painter._ruin(Vector3.ZERO);actual_height=3.23
	world._flush_batches();world._combine_static_geometry()
	world.scale=Vector3.ONE*minf(1.0,clampf(height_limit,.5,8.0)/actual_height)
	world.set_meta("height_limit",height_limit)
	world.set_meta("ground_origin",Vector3.ZERO)
	return world
