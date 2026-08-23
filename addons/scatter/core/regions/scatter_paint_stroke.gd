@tool
class_name ScatterPaintStroke
extends Resource

@export var position := Vector3.ZERO
@export var normal := Vector3.UP
@export var radius := 1.0


static func create(p_position: Vector3, p_normal: Vector3, p_radius: float) -> ScatterPaintStroke:
	var stroke := ScatterPaintStroke.new()
	stroke.position = p_position
	stroke.normal = p_normal.normalized()
	stroke.radius = maxf(p_radius, 0.001)
	return stroke
