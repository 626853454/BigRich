class_name FurEnemyBehaviorView
extends Node3D

# Fixed presentation pool. Critical warnings and hostile bullets survive lowFX.
const WARNING_LIMIT := 24
const PROJECTILE_LIMIT := 36
const CHARGER_COLOR := Color("ff704d")
const RANGER_COLOR := Color("ffb547")
const PROJECTILE_COLOR := Color("f6535c")
const Behaviors = preload("res://scripts/furball/enemy_behaviors.gd")
var warnings: Array[Dictionary] = []
var hostile_mesh: MultiMeshInstance3D
var active_warnings := 0
var active_projectiles := 0
var rejected_values := 0
var strip_mesh: BoxMesh
var ray_mesh: ArrayMesh
var arrow_mesh: CylinderMesh
var target_mesh: TorusMesh
var charger_material: StandardMaterial3D
var ranger_material: StandardMaterial3D

func _ready() -> void:
	strip_mesh = BoxMesh.new(); strip_mesh.size = Vector3(1, .028, 1)
	ray_mesh = _create_ray_mesh()
	arrow_mesh = CylinderMesh.new(); arrow_mesh.top_radius = 0; arrow_mesh.bottom_radius = .25
	arrow_mesh.height = .6; arrow_mesh.radial_segments = 3
	target_mesh = TorusMesh.new(); target_mesh.inner_radius = .22; target_mesh.outer_radius = .29
	target_mesh.rings = 16; target_mesh.ring_segments = 4
	charger_material = _material(CHARGER_COLOR)
	ranger_material = _material(RANGER_COLOR)
	ranger_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in WARNING_LIMIT:
		var group := Node3D.new(); group.name = "EnemyWarning%02d" % index; group.visible = false; add_child(group)
		var body := MeshInstance3D.new(); body.mesh = strip_mesh
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; group.add_child(body)
		var tip := MeshInstance3D.new(); tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; group.add_child(tip)
		warnings.append({"root": group, "body": body, "tip": tip})
	var sphere := SphereMesh.new(); sphere.radius = .13; sphere.height = .26; sphere.radial_segments = 8; sphere.rings = 4
	var batch := MultiMesh.new(); batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = sphere; batch.instance_count = PROJECTILE_LIMIT; batch.visible_instance_count = 0
	hostile_mesh = MultiMeshInstance3D.new(); hostile_mesh.name = "HostileProjectiles"
	hostile_mesh.multimesh = batch; hostile_mesh.material_override = _material(PROJECTILE_COLOR)
	hostile_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(hostile_mesh)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true; material.emission = color; material.emission_energy_multiplier = .7
	return material

func clear() -> void:
	for marker in warnings: marker.root.visible = false
	if hostile_mesh != null: hostile_mesh.multimesh.visible_instance_count = 0
	active_warnings = 0; active_projectiles = 0

func apply_presentation(frame: Dictionary, _low_fx: bool = false) -> Dictionary:
	if hostile_mesh == null: return {"warnings": 0, "projectiles": 0, "rejected": 0}
	clear(); rejected_values = 0
	if not frame.is_empty() and (frame.size() != 2 or not frame.has_all(["warnings", "projectiles"])):
		rejected_values = 1; return {"warnings": 0, "projectiles": 0, "rejected": 1}
	var incoming_warnings: Variant = frame.get("warnings", [])
	var incoming_projectiles: Variant = frame.get("projectiles", [])
	if incoming_warnings is not Array or incoming_projectiles is not Array or incoming_warnings.size() > WARNING_LIMIT or incoming_projectiles.size() > PROJECTILE_LIMIT:
		rejected_values = 1; return {"warnings": 0, "projectiles": 0, "rejected": 1}
	var seen: Dictionary = {}
	for item in incoming_warnings:
		if not _valid_warning(item) or seen.has(item.get("id", -1)):
			rejected_values += 1; continue
		seen[item.id] = true
		var marker: Dictionary = warnings[active_warnings]
		var direction: Vector2 = item.direction.normalized()
		var length: float = item.length
		var kind: int = item.kind
		var root_node: Node3D = marker.root
		root_node.position = Vector3(item.pos.x, .07, item.pos.y)
		root_node.rotation.y = atan2(direction.x, direction.y)
		var body: MeshInstance3D = marker.body
		body.mesh = strip_mesh if kind == 3 else ray_mesh
		body.position = Vector3(0, 0, length * .5) if kind == 3 else Vector3.ZERO
		body.scale = Vector3(.48, 1, length) if kind == 3 else Vector3(length, 1, length)
		body.material_override = charger_material if kind == 3 else ranger_material
		var tip: MeshInstance3D = marker.tip
		tip.position = Vector3(0, .18 if kind == 3 else .025, length)
		tip.mesh = arrow_mesh if kind == 3 else target_mesh
		tip.rotation = Vector3(PI * .5, 0, 0) if kind == 3 else Vector3.ZERO
		tip.material_override = charger_material if kind == 3 else ranger_material
		root_node.visible = true; active_warnings += 1
	seen.clear()
	for item in incoming_projectiles:
		if not _valid_projectile(item) or seen.has(item.get("id", -1)):
			rejected_values += 1; continue
		seen[item.id] = true
		hostile_mesh.multimesh.set_instance_transform(active_projectiles, Transform3D(Basis.IDENTITY, Vector3(item.pos.x, .32, item.pos.y)))
		active_projectiles += 1
	hostile_mesh.multimesh.visible_instance_count = active_projectiles
	return {"warnings": active_warnings, "projectiles": active_projectiles, "rejected": rejected_values}

func _create_ray_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	for index in 3:
		var angle := (index - 1) * Behaviors.FAN_ANGLE
		var direction := Vector3(sin(angle), 0, cos(angle))
		var side := Vector3(cos(angle), 0, -sin(angle)) * .0042
		for vertex in [-side, direction - side, side, side, direction - side, direction + side]:
			vertices.append(vertex); normals.append(Vector3.UP)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _position(value: Variant) -> bool:
	return value is Vector2 and value.is_finite() and absf(value.x) <= 64 and absf(value.y) <= 64

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _valid_warning(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 6 or not value.has_all(["id", "kind", "pos", "direction", "length", "ttl"]): return false
	if value.id is not int or value.id <= 0 or value.kind not in [3, 4] or value.kind is not int: return false
	return _position(value.pos) and value.direction is Vector2 and value.direction.is_finite() and value.direction.length_squared() > .00001 and value.direction.length_squared() <= 1.01 and _number(value.length, .1, 12) and _number(value.ttl, .00001, 5)

func _valid_projectile(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 4 or not value.has_all(["id", "pos", "velocity", "ttl"]): return false
	return value.id is int and value.id > 0 and _position(value.pos) and value.velocity is Vector2 and value.velocity.is_finite() and value.velocity.length_squared() <= 32 * 32 and _number(value.ttl, .00001, 5)
