@tool
class_name ScatterPaintRegion
extends ScatterRegionValue

var strokes: Array[ScatterPaintStroke] = []
var depth := 0.35
var surface_offset := 0.0


func _init(
		p_strokes: Array[ScatterPaintStroke] = [],
		p_depth := 0.35,
		p_surface_offset := 0.0,
) -> void:
	strokes = p_strokes
	depth = maxf(p_depth, 0.01)
	surface_offset = p_surface_offset


func get_bounds_local() -> AABB:
	if strokes.is_empty():
		return AABB()
	var first := strokes[0]
	var first_radius := maxf(first.radius, 0.001)
	var result := AABB(first.position - Vector3.ONE * first_radius, Vector3.ONE * first_radius * 2.0)
	for stroke in strokes:
		var radius := maxf(stroke.radius, 0.001)
		result = result.merge(AABB(stroke.position - Vector3.ONE * radius, Vector3.ONE * radius * 2.0))
	return result.grow(depth * 0.5)


func contains_local(point: Vector3) -> bool:
	for stroke in strokes:
		var normal := stroke.normal.normalized()
		var center := stroke.position + normal * surface_offset
		var delta := point - center
		if absf(delta.dot(normal)) <= depth * 0.5:
			var tangent_delta := delta - normal * delta.dot(normal)
			if tangent_delta.length_squared() <= stroke.radius * stroke.radius:
				return true
	return false


func is_empty() -> bool:
	return strokes.is_empty()
