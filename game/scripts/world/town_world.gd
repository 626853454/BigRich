class_name TownWorld
extends Node3D

const STALL = preload("res://assets/models/tea_stall_blockout.glb")
const LANTERN = preload("res://assets/models/lantern_blockout.glb")
var materials := {}
var buildings: Array[Dictionary] = []
var camera: FixedOverheadCamera

func _ready() -> void:
	_build_materials()
	_build_ground()
	_build_structures()
	_build_lanterns()
	_build_street_details()
	camera = get_parent().get_node("Camera") as FixedOverheadCamera

func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera.subject):
		return
	var player_point := camera.subject.global_position + Vector3(0, 0.65, 0)
	for building in buildings:
		# Cut away only scenery intersecting the camera-to-player sightline.
		var obstructs: bool = building.bounds.intersects_segment(camera.global_position, player_point) != null
		if building.has("label"):
			building.label.visible = not obstructs
		for material in building.materials:
			var alpha: float = move_toward(material.albedo_color.a, 0.08 if obstructs else 1.0, delta * 3.5)
			var color: Color = material.albedo_color
			color.a = alpha
			material.albedo_color = color
		for mesh in building.meshes:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if obstructs else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _build_materials() -> void:
	materials[&"ground"] = _material(Color("101c21"))
	materials[&"wall"] = _material(Color("2b383b"))
	materials[&"roof"] = _material(Color("253034"))
	materials[&"wood"] = _material(Color("493b30"))
	materials[&"iron"] = _material(Color("1e2629"))
	materials[&"gold"] = _material(Color("dba061"), 1.4)
	materials[&"window"] = _material(Color("ba7841"), 0.7)

func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _build_ground() -> void:
	_add_box("Ground", Vector3(34, 0.25, 34), Vector3(0, -0.2, 0), materials[&"ground"])
	for x in range(1, TownContent.SIZE - 1):
		for y in range(1, TownContent.SIZE - 1):
			if TownContent.is_walkable(Vector2i(x, y)):
				var shade := 0.13 + 0.035 * sin(float(x * 17 + y * 31))
				var stone := _material(Color(shade * 0.78, shade, shade * 1.07))
				for half in 2:
					var offset := Vector3(-0.48 + half * 0.97, 0.0, 0)
					_add_box("Stone_%d_%d_%d" % [x, y, half], Vector3(0.94, 0.07, 1.94), TileWorldMapper.to_world(Vector2i(x, y)) + offset, stone)

func _build_structures() -> void:
	for location_id in TownContent.LOCATIONS:
		var location: Dictionary = TownContent.LOCATIONS[location_id]
		var rect: Rect2i = location.building
		var center := TileWorldMapper.to_world(rect.position) + Vector3((rect.size.x - 1) * 1.0, 0, (rect.size.y - 1) * 1.0)
		var height := 5.2 if location_id == &"guild" else 4.5
		var size := Vector3(rect.size.x * 2.0 - 0.15, height, rect.size.y * 2.0 - 0.15)
		if location_id == &"shop":
			# Reserve the front of the footprint for the Blender stall.
			center.z += 1.45
			size.z = 3.0
		var wall := materials[&"wall"].duplicate() as StandardMaterial3D
		wall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var door_material := wall.duplicate() as StandardMaterial3D
		door_material.albedo_color = Color("192226")
		var roof_material := wall.duplicate() as StandardMaterial3D
		roof_material.albedo_color = Color("1c282c")
		var window_material := materials[&"window"].duplicate() as StandardMaterial3D
		window_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var meshes: Array[MeshInstance3D] = []
		meshes.append(_add_box(String(location_id), size, center + Vector3(0, height / 2, 0), wall, true))
		meshes.append(_add_box(String(location_id) + "_roof", Vector3(size.x + 0.4, 0.35, size.z + 0.4), center + Vector3(0, height + 0.05, 0), roof_material))
		# Doors face their actual approach tile; front-facing streets stay readable.
		var door_world := TileWorldMapper.to_world(location.door)
		var north_door := door_world.z < center.z
		var facade_z := center.z + (-size.z / 2 - 0.05 if north_door else size.z / 2 + 0.05)
		meshes.append(_add_box("Door", Vector3(1.05, 2.5, 0.14), Vector3(door_world.x, 1.25, facade_z), door_material))
		for side in [-1, 1]:
			meshes.append(_add_box("WindowFrame", Vector3(0.95, 1.3, 0.16), Vector3(door_world.x + side * 1.7, 2.1, facade_z), wall))
			meshes.append(_add_box("WindowGlow", Vector3(0.72, 1.05, 0.08), Vector3(door_world.x + side * 1.7, 2.1, facade_z + (-0.1 if north_door else 0.1)), window_material))
		var bounds := AABB(center - Vector3(size.x / 2, 0, size.z / 2), size + Vector3(0, 0.5, 0)).grow(0.15)
		var cutaway := {"bounds": bounds, "materials": [wall, door_material, roof_material, window_material], "meshes": meshes}
		var sign := Label3D.new()
		sign.name = String(location_id) + "_label"
		sign.text = location.name
		sign.position = door_world + Vector3(0, 3.5, 0)
		sign.font_size = 54
		sign.pixel_size = 0.009
		sign.modulate = Color("e1bf88")
		sign.outline_modulate = Color("10171b")
		sign.outline_size = 10
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sign)
		cutaway["label"] = sign
		buildings.append(cutaway)
		var marker := MeshInstance3D.new()
		marker.name = String(location_id) + "_threshold"
		var ring := TorusMesh.new()
		ring.inner_radius = 0.47
		ring.outer_radius = 0.53
		marker.mesh = ring
		marker.material_override = materials[&"gold"]
		marker.position = door_world + Vector3(0, 0.09, 0)
		add_child(marker)
	var stall := STALL.instantiate() as Node3D
	stall.name = "TeaStall"
	stall.position = TileWorldMapper.to_world(Vector2i(3, 9))
	# The existing Blender asset is placed on the blocked building side of the door.
	stall.position.z -= 0.05
	add_child(stall)
	_add_box("TeaStallPorch", Vector3(4.1, 0.12, 1.4), TileWorldMapper.to_world(Vector2i(3, 8)) + Vector3(0, -0.01, 0.45), materials[&"wood"])

func _build_lanterns() -> void:
	for tile in [Vector2i(5, 7), Vector2i(9, 7), Vector2i(5, 10), Vector2i(9, 10), Vector2i(5, 4), Vector2i(9, 4)]:
		var lantern := LANTERN.instantiate() as Node3D
		lantern.name = "StreetLantern_%d_%d" % [tile.x, tile.y]
		lantern.position = TileWorldMapper.to_world(tile) + Vector3(0.65, 0, 0.65)
		add_child(lantern)
		var light := OmniLight3D.new()
		light.light_color = Color("ffb56b")
		light.light_energy = 1.35
		light.omni_range = 5.5
		light.omni_attenuation = 1.5
		light.position = Vector3(0, 2.45, 0)
		lantern.add_child(light)
	var tea_light := OmniLight3D.new()
	tea_light.name = "TeaStallLight"
	tea_light.position = TileWorldMapper.to_world(Vector2i(3, 8)) + Vector3(0, 2.4, -0.2)
	tea_light.light_color = Color("ffbb77")
	tea_light.light_energy = 1.8
	tea_light.omni_range = 6.5
	add_child(tea_light)

func _build_street_details() -> void:
	for i in 6:
		var x := -9.5 + i * 3.8
		_add_box("BackFence", Vector3(0.15, 3.4, 0.15), Vector3(x, 1.7, -13.0), materials[&"iron"])
	for y in [0.9, 2.6]:
		_add_box("FenceRail", Vector3(21, 0.1, 0.12), Vector3(0, y, -13), materials[&"iron"])
	for point in [Vector3(-11.0, 0.45, 6.5), Vector3(-11.0, 0.4, 5.4), Vector3(10.7, 0.55, -6.5)]:
		var crate := _add_box("StreetCrate", Vector3(0.9, point.y * 2, 0.9), point, materials[&"wood"])
		crate.rotation.y = 0.13
	# Oversized pipes outline the distant wall without occupying walkable tiles.
	for x in [-14.3, 14.3]:
		_add_box("DrainPipe", Vector3(0.5, 5.8, 0.5), Vector3(x, 2.9, -8), materials[&"iron"])
		_add_boundary_wall("SideWall", Vector3(0.7, 7, 28), Vector3(x, 3.5, 0))
	_add_boundary_wall("DistantWall", Vector3(29, 7, 0.7), Vector3(0, 3.5, 14.2))
	_add_boundary_wall("ForegroundWall", Vector3(29, 1.6, 0.7), Vector3(0, 0.8, -14.2))

func _add_boundary_wall(node_name: String, size: Vector3, position: Vector3) -> void:
	var material := materials[&"wall"].duplicate() as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := _add_box(node_name, size, position, material)
	buildings.append({"bounds": AABB(position - size / 2, size), "materials": [material], "meshes": [mesh]})

func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		visual.add_child(body)
	return visual
