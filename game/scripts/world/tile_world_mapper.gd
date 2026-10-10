class_name TileWorldMapper
extends RefCounted

const TILE_SIZE := 2.0

static func to_world(tile: Vector2i) -> Vector3:
	return Vector3((tile.x - 7) * TILE_SIZE, 0.0, (tile.y - 7) * TILE_SIZE)

static func from_world(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x / TILE_SIZE) + 7, roundi(position.z / TILE_SIZE) + 7)
