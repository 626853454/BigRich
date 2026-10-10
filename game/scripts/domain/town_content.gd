class_name TownContent
extends RefCounted

const SIZE := 15
const SPAWN := Vector2i(7, 7)
const OBJECTIVES := [&"shop", &"event", &"risk"]

const LOCATIONS := {
	&"guild": {"name": "商会", "door": Vector2i(7, 10), "radius": 1.25, "building": Rect2i(6, 11, 3, 3), "kind": &"guild"},
	&"shop": {"name": "茶货商铺", "door": Vector2i(3, 8), "radius": 1.25, "building": Rect2i(2, 9, 3, 3), "kind": &"trade"},
	&"event": {"name": "传闻告示", "door": Vector2i(11, 8), "radius": 1.25, "building": Rect2i(10, 9, 3, 3), "kind": &"event"},
	&"risk": {"name": "巡夜关口", "door": Vector2i(3, 6), "radius": 1.25, "building": Rect2i(2, 3, 3, 3), "kind": &"risk"},
	&"station": {"name": "驿站", "door": Vector2i(11, 6), "radius": 1.25, "building": Rect2i(10, 3, 3, 3), "kind": &"station"},
}

static func is_walkable(position: Vector2i) -> bool:
	if position.x <= 0 or position.y <= 0 or position.x >= SIZE - 1 or position.y >= SIZE - 1:
		return false
	for location in LOCATIONS.values():
		if location.building.has_point(position):
			return false
	return true

static func is_in_reach(position: Vector2i, location_id: StringName) -> bool:
	if not LOCATIONS.has(location_id):
		return false
	var location: Dictionary = LOCATIONS[location_id]
	return position.distance_squared_to(location.door) <= location.radius * location.radius

static func nearby(position: Vector2i, completed: Array[StringName]) -> StringName:
	for location_id in LOCATIONS:
		if not completed.has(location_id) and is_in_reach(position, location_id):
			return location_id
	return &""
