class_name FurHarborCraftedAssets
extends RefCounted
const HOUSE="res://assets/party/harbor_crafted_v1/harbor_tea_house.glb"
static var _house:PackedScene
static var _plants:Dictionary={}
static var _props:Dictionary={}
static var _finished:Dictionary={}
static var _wood_normal:NoiseTexture2D
static func terrace(chapter:int,region:int)->Node3D:
	return FurTravelArtAssets.instance("chapter_terrace_%d_%d_atelier"%[clampi(chapter,1,2),clampi(region,0,2)])
static func prop(name:String)->Node3D:
	if name=="ruin_arch_crafted":return FurTravelArtAssets.instance("ruin_arch_atelier")
	if name=="mahjong_table_crafted":return FurTravelArtAssets.instance("mahjong_table_sculpted_v2",true)
	if name=="mahjong_room_crafted":return FurTravelArtAssets.instance("mahjong_room_atelier")
	if name=="tea_pavilion_crafted":return FurTravelArtAssets.instance("tea_pavilion_atelier")
	if name=="clock_pavilion_crafted":return FurTravelArtAssets.instance("clock_pavilion_atelier")
	if name=="lighthouse_crafted":return FurTravelArtAssets.instance("lighthouse_atelier")
	if name=="windmill_crafted":return FurTravelArtAssets.instance("windmill_atelier")
	if name=="windmill_sails_crafted":return FurTravelArtAssets.instance("windmill_sails_atelier")
	if name=="bamboo_crafted":return FurTravelArtAssets.instance("bamboo_atelier")
	if name=="harbor_sailboat_crafted":return FurTravelArtAssets.instance("harbor_sailboat_atelier")
	assert(name in ["mahjong_table_crafted","mahjong_room_crafted","clock_pavilion_crafted","tea_pavilion_crafted","lighthouse_crafted","windmill_crafted","windmill_sails_crafted","bamboo_crafted","ruin_arch_crafted","harbor_sailboat_crafted"])
	if not _props.has(name):_props[name]=load("res://assets/party/harbor_crafted_v1/%s.glb"%name)
	var result:Node3D=(_props[name] as PackedScene).instantiate();_finish_materials(result);return result
static func plant(tree:bool=false)->Node3D:
	return FurTravelArtAssets.instance("garden_tree_atelier" if tree else "garden_bush_atelier")
static func coast(region:int)->Node3D:
	var source:PackedScene=load("res://assets/art/sevenhour_v1/coast_atelier_%d.glb"%region)
	var instance:Node3D=source.instantiate();_coast_paint(instance);return instance
static func _coast_paint(node:Node)->void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			node.set_surface_override_material(i,FurPartyEnvironmentMaterial.material(0,-2.96,false))
	for child in node.get_children():_coast_paint(child)
static func house(size:Vector3,roof:Color=Color.WHITE)->Node3D:
	var instance:Node3D=FurTravelArtAssets.instance("harbor_tea_house_atelier")
	instance.name="CraftedCoastalTeaHouse"
	instance.scale=Vector3(size.x/3.5,(size.y+size.x*.33+.4)/3.75,size.z/2.7)
	_finish_materials(instance)
	if roof!=Color.WHITE:_tint_roof(instance,roof)
	return instance
static func _tint_roof(node:Node,colour:Color)->void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source:StandardMaterial3D=node.mesh.surface_get_material(i) as StandardMaterial3D
			if source!=null and (source.resource_name.begins_with("Teal") or source.resource_name=="Painted_TeaHouse_Glaze"):
				var material:StandardMaterial3D=source.duplicate();material.albedo_color=colour
				if source.resource_name.begins_with("Painted_"):material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=false
				node.set_surface_override_material(i,material)
	for child in node.get_children():_tint_roof(child,colour)

static func _finish_materials(node:Node)->void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original:StandardMaterial3D=node.mesh.surface_get_material(surface) as StandardMaterial3D
			if original==null:continue
			var title:String=original.resource_name.to_lower()
			if not ("wood" in title or "timber" in title or "oak" in title or "joinery" in title):continue
			var key:int=original.get_instance_id()
			if not _finished.has(key):
				if _wood_normal==null:
					var noise:=FastNoiseLite.new();noise.seed=719;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=.055;noise.fractal_octaves=2
					_wood_normal=NoiseTexture2D.new();_wood_normal.width=128;_wood_normal.height=128;_wood_normal.seamless=true;_wood_normal.noise=noise;_wood_normal.as_normal_map=true;_wood_normal.bump_strength=.15
				var finish:StandardMaterial3D=original.duplicate();finish.normal_enabled=true;finish.normal_texture=_wood_normal;finish.normal_scale=.065;finish.uv1_triplanar=true;finish.uv1_scale=Vector3(3.0,27.0,3.0);_finished[key]=finish
			node.set_surface_override_material(surface,_finished[key])
	for child in node.get_children():_finish_materials(child)
