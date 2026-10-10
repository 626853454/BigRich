class_name FurSpatialGrid
extends RefCounted

const CELL := 2.5
var cells: Dictionary = {}

func rebuild(pool: FurEntityPool) -> void:
	cells.clear()
	for slot in pool.active:
		var cell := Vector2i(floori(pool.pos[slot].x / CELL), floori(pool.pos[slot].y / CELL))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(slot)

func nearby(point: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var lo := Vector2i(floori((point.x-radius)/CELL), floori((point.y-radius)/CELL))
	var hi := Vector2i(floori((point.x+radius)/CELL), floori((point.y+radius)/CELL))
	for x in range(lo.x, hi.x+1):
		for y in range(lo.y, hi.y+1):
			var key := Vector2i(x,y)
			if cells.has(key): result.append_array(cells[key])
	return result
