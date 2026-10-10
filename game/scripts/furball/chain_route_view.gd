class_name FurChainRouteView
extends Node3D

# Pure presentation of immutable authority-side chain edges. Every live tagged
# bait owns its incoming edge; removing that bait removes its edge immediately.
const LIMIT := 12
const ORDER_TEXT := ["1", "2", "3", "4", "5", "6"]
const OWNER_COLORS := [Color("cc8aff"), Color("69e9ed")]
const FIELDS := ["pos", "ttl", "owner", "chain_tag", "chain_order", "chain_from"]
var links: MultiMeshInstance3D
var endpoints: MultiMeshInstance3D
var labels: Array[Label3D] = []
var label_orders: Array[int] = []
var active_segments := 0
var active_steps := 0
var rejected_values := 0
var edge_mesh: ArrayMesh
var endpoint_mesh: SphereMesh
# Fixed CPU projection also supports deterministic debugging when Godot's
# headless dummy RenderingServer cannot read back MultiMesh transforms/colors.
var segment_transforms: Array[Transform3D] = []
var step_colors: Array[Color] = []

func _ready() -> void:
	edge_mesh = _make_edge_mesh()
	endpoint_mesh = SphereMesh.new()
	endpoint_mesh.radius = .10; endpoint_mesh.height = .20
	endpoint_mesh.radial_segments = 8; endpoint_mesh.rings = 4
	links = _batch("ChainEdges", edge_mesh)
	endpoints = _batch("ChainEndpoints", endpoint_mesh)
	for index in LIMIT:
		segment_transforms.append(Transform3D.IDENTITY); step_colors.append(Color.WHITE)
		var label := Label3D.new(); label.name = "ChainOrder%02d" % index
		label.font = FurVisualStyle.font(); label.font_size = 40; label.pixel_size = .015
		label.outline_size = 7; label.outline_modulate = Color("162139")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Only the small ordinal labels overlay actors; connecting arrows retain
		# depth testing so they cannot paint over enemy danger presentation.
		label.no_depth_test = true; label.shaded = false; label.visible = false
		add_child(label); labels.append(label); label_orders.append(0)

func _batch(node_name: String, mesh: Mesh) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true; multimesh.mesh = mesh
	multimesh.instance_count = LIMIT; multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new(); node.name = node_name; node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material; add_child(node)
	return node

func _make_edge_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	# A thin strip and fixed-width arrowhead, pointing along local +Z. X remains
	# unscaled so longer paths do not become wider or overwhelm combat effects.
	for point in [Vector3(-.055,0,0), Vector3(.055,0,0), Vector3(.055,0,.78), Vector3(-.055,0,0), Vector3(.055,0,.78), Vector3(-.055,0,.78), Vector3(-.16,0,.72), Vector3(.16,0,.72), Vector3(0,0,1)]: vertices.append(point)
	var normals := PackedVector3Array(); normals.resize(vertices.size()); normals.fill(Vector3.UP)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func clear() -> void:
	active_segments = 0; active_steps = 0; rejected_values = 0
	if links != null: links.multimesh.visible_instance_count = 0
	if endpoints != null: endpoints.multimesh.visible_instance_count = 0
	for label in labels: label.visible = false
	# Ordinal cache is retained: fixed predeclared strings are only applied when
	# an ordinal actually changes, never formatted in the per-frame update.

func render_baits(incoming: Variant, _low_fx: bool = false) -> Dictionary:
	clear()
	if links == null: return _result()
	if incoming is not Array or incoming.size() > LIMIT:
		rejected_values = 1; return _result()
	var selected: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value in incoming:
		if not _valid_base(value): rejected_values += 1; continue
		var tag: int = value.get("chain_tag", 0)
		if tag == 0 or float(value.ttl) <= 0: continue
		if not value.has_all(["chain_order", "chain_from"]) or value.chain_order is not int or value.chain_order < 1 or value.chain_order > 6 or not _position(value.chain_from):
			rejected_values += 1; continue
		var key := Vector3i(value.owner, tag, value.chain_order)
		if seen.has(key): rejected_values += 1; continue
		seen[key] = true; selected.append(value)
	selected.sort_custom(_ordered)
	for value in selected:
		var slot := active_steps
		var color: Color = OWNER_COLORS[value.owner]
		# Approaching ignition is brighter. LowFX uses identical critical relations.
		var intensity := .7 + .3 * (1.0 - clampf(float(value.ttl) / .72, 0, 1))
		color = Color(color.r * intensity, color.g * intensity, color.b * intensity)
		endpoints.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, Vector3(value.pos.x, .65, value.pos.y)))
		endpoints.multimesh.set_instance_color(slot, color)
		step_colors[slot] = color
		var label: Label3D = labels[slot]
		if label_orders[slot] != value.chain_order:
			label.text = ORDER_TEXT[value.chain_order - 1]; label_orders[slot] = value.chain_order
		label.position = Vector3(value.pos.x, 1.3, value.pos.y)
		label.modulate = color; label.visible = true
		active_steps += 1
		var vector: Vector2 = value.pos - value.chain_from
		var length := vector.length()
		if length <= .02: continue # No normalize/rotate of a coincident segment.
		var basis := Basis(Vector3.UP, atan2(vector.x, vector.y)).scaled(Vector3(1, 1, length))
		segment_transforms[active_segments] = Transform3D(basis, Vector3(value.chain_from.x, .62, value.chain_from.y))
		links.multimesh.set_instance_transform(active_segments, segment_transforms[active_segments])
		links.multimesh.set_instance_color(active_segments, color)
		active_segments += 1
	links.multimesh.visible_instance_count = active_segments
	endpoints.multimesh.visible_instance_count = active_steps
	return _result()

func _ordered(a: Dictionary, b: Dictionary) -> bool:
	if a.owner != b.owner: return a.owner < b.owner
	if a.chain_tag != b.chain_tag: return a.chain_tag < b.chain_tag
	return a.chain_order < b.chain_order

func _position(value: Variant) -> bool:
	return value is Vector2 and value.is_finite() and absf(value.x) <= 32 and absf(value.y) <= 32

func _valid_base(value: Variant) -> bool:
	if value is not Dictionary or not value.has_all(["pos", "ttl", "owner"]) or value.size() > FIELDS.size(): return false
	for key in value:
		if key not in FIELDS: return false
	if not _position(value.pos) or value.owner is not int or value.owner < 0 or value.owner > 1: return false
	if value.ttl is not int and value.ttl is not float: return false
	if not is_finite(float(value.ttl)) or float(value.ttl) < 0 or float(value.ttl) > 5: return false
	if value.get("chain_tag", 0) is not int or value.get("chain_tag", 0) < 0 or value.get("chain_tag", 0) > 1000000000: return false
	# Optional fields cannot hide arbitrary objects even on an untagged bait.
	if value.has("chain_order") and (value.chain_order is not int or value.chain_order < 1 or value.chain_order > 6): return false
	if value.has("chain_from") and not _position(value.chain_from): return false
	return true

func _result() -> Dictionary:
	return {"segments": active_segments, "steps": active_steps, "rejected": rejected_values}
