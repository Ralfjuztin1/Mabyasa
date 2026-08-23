@tool
class_name ScatterPathTubeRegion
extends ScatterRegionValue

var path: ScatterPathValue
var radius := 1.0


func _init(p_path: ScatterPathValue = null, p_radius := 1.0) -> void:
	path = p_path if p_path != null else ScatterPathValue.new()
	radius = maxf(p_radius, 0.001)


func get_bounds_local() -> AABB:
	var points := path.get_points_local()
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(point)
	return result.grow(radius)


func contains_local(point: Vector3) -> bool:
	var points := path.get_points_local()
	var segment_count := points.size() if path.is_closed() and points.size() > 1 else maxi(0, points.size() - 1)
	for index in segment_count:
		if ScatterMath.distance_to_segment(point, points[index], points[(index + 1) % points.size()]) <= radius:
			return true
	return false


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	var points := path.get_points_local()
	var segment_count := points.size() if path.is_closed() and points.size() > 1 else maxi(0, points.size() - 1)
	for index in segment_count:
		result.append(ScatterEdge.new(points[index], points[(index + 1) % points.size()]))
	return result
