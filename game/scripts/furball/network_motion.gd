class_name FurNetworkMotion
extends RefCounted

# Presentation only. Authority positions, collisions and warning geometry remain
# untouched. Stable allocation identities prevent smoothing across slot reuse.
var tracks: Dictionary = {}
var duration := .083

func clear() -> void:
	tracks.clear()

func sample(entity_id: int, fallback: Vector2, now: float) -> Vector2:
	if not tracks.has(entity_id): return fallback
	var track: Dictionary = tracks[entity_id]
	var progress := clampf((now-track.started)/duration, 0.0, 1.0)
	return track.from.lerp(track.to, progress)

func receive(pool: FurEntityPool, now: float, interval: float) -> void:
	var next: Dictionary = {}
	for slot in pool.active:
		var entity_id: int = pool.identity[slot]
		var destination: Vector2 = pool.pos[slot]
		var origin := sample(entity_id, destination, now)
		# Teleports / scene transitions snap. A new identity also snaps by design.
		if origin.distance_squared_to(destination)>36.0: origin=destination
		next[entity_id] = {"from":origin,"to":destination,"started":now}
	duration=clampf(interval,.04,.15)
	tracks=next
