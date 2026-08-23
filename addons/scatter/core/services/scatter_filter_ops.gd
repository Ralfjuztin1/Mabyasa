@tool
class_name ScatterFilterOps
extends RefCounted


static func remove_outside(
		buffer: ScatterInstances,
		shape: ScatterShapeValue,
) -> void:
	if shape == null:
		return
	buffer.normalize()
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var point := buffer.transforms[index].origin
		if not shape.contains_local(point):
			buffer.remove_at(index)


static func remove_random(
		buffer: ScatterInstances,
		probability_percent: float,
		rng: RandomNumberGenerator,
) -> void:
	buffer.normalize()
	var threshold := clampf(probability_percent / 100.0, 0.0, 1.0)
	for index in range(buffer.transforms.size() - 1, -1, -1):
		if rng.randf() < threshold:
			buffer.remove_at(index)
