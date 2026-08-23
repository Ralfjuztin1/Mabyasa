@tool
class_name ScatterPathExtrudeRegion
extends ScatterRegionValue

enum Pivot {
	PROJECTED_CENTROID,
	PROJECTED_PATH_ORIGIN,
}

const EPSILON := 0.00001

var path: ScatterPathValue
var normal := Vector3.UP
var forward := 1.0
var backward := 0.0
var pivot_mode: int = Pivot.PROJECTED_CENTROID

var _basis := Basis.IDENTITY
var _plane_origin := Vector3.ZERO
var _pivot_origin := Vector3.ZERO
var _polygon := PackedVector2Array()
var _projected_points := PackedVector3Array()
var _signed_area := 0.0


func _init(
		p_path: ScatterPathValue = null,
		p_normal := Vector3.UP,
		p_forward := 1.0,
		p_backward := 0.0,
		p_pivot_mode: int = Pivot.PROJECTED_CENTROID,
	) -> void:
	path = p_path if p_path != null else ScatterPathValue.new()
	normal = p_normal.normalized() if not p_normal.is_zero_approx() else Vector3.UP
	forward = maxf(p_forward, 0.0)
	backward = maxf(p_backward, 0.0)
	pivot_mode = p_pivot_mode
	_rebuild()


func get_local_transform() -> Transform3D:
	return Transform3D(_basis, _pivot_origin)


func get_bounds_local() -> AABB:
	if is_empty():
		return AABB()
	var first := _projected_points[0] - normal * backward
	var result := AABB(first, Vector3.ZERO)
	for point in _projected_points:
		result = result.expand(point - normal * backward)
		result = result.expand(point + normal * forward)
	return result


func contains_local(point: Vector3) -> bool:
	if is_empty():
		return false
	var relative := point - _plane_origin
	var height := relative.dot(normal)
	if height < -backward - EPSILON or height > forward + EPSILON:
		return false
	return _contains_polygon(Vector2(relative.dot(_basis.x), relative.dot(_basis.z)))


func is_empty() -> bool:
	return _polygon.size() < 3 or absf(_signed_area) <= EPSILON or forward + backward <= EPSILON


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	if is_empty():
		return result
	for index in _projected_points.size():
		var next := (index + 1) % _projected_points.size()
		var bottom_a := _projected_points[index] - normal * backward
		var bottom_b := _projected_points[next] - normal * backward
		var top_a := _projected_points[index] + normal * forward
		var top_b := _projected_points[next] + normal * forward
		result.append(ScatterEdge.new(bottom_a, bottom_b))
		result.append(ScatterEdge.new(top_a, top_b))
		result.append(ScatterEdge.new(bottom_a, top_a))
	return result


func _rebuild() -> void:
	_polygon = PackedVector2Array()
	_projected_points = PackedVector3Array()
	_signed_area = 0.0
	var points := path.get_points_local()
	if points.size() < 3:
		return
	_plane_origin = Vector3.ZERO
	for point in points:
		_plane_origin += point
	_plane_origin /= float(points.size())
	_basis = ScatterMath.basis_from_up(normal, path.get_local_transform().basis.z)
	for point in points:
		var projected := point - normal * normal.dot(point - _plane_origin)
		var relative := projected - _plane_origin
		var point_2d := Vector2(relative.dot(_basis.x), relative.dot(_basis.z))
		if not _polygon.is_empty() and _polygon[-1].distance_squared_to(point_2d) <= EPSILON * EPSILON:
			continue
		_polygon.append(point_2d)
		_projected_points.append(projected)
	if _polygon.size() > 1 and _polygon[0].distance_squared_to(_polygon[-1]) <= EPSILON * EPSILON:
		_polygon.resize(_polygon.size() - 1)
		_projected_points.resize(_projected_points.size() - 1)
	if _polygon.size() < 3:
		return
	var centroid_numerator := Vector2.ZERO
	for index in _polygon.size():
		var a := _polygon[index]
		var b := _polygon[(index + 1) % _polygon.size()]
		var cross := a.cross(b)
		_signed_area += cross
		centroid_numerator += (a + b) * cross
	_signed_area *= 0.5
	var centroid_2d := Vector2.ZERO
	if absf(_signed_area) > EPSILON:
		centroid_2d = centroid_numerator / (6.0 * _signed_area)
	else:
		for point in _polygon:
			centroid_2d += point
		centroid_2d /= float(_polygon.size())
	var projected_centroid := _plane_origin + _basis.x * centroid_2d.x + _basis.z * centroid_2d.y
	if pivot_mode == Pivot.PROJECTED_PATH_ORIGIN:
		var path_origin := path.get_local_transform().origin
		_pivot_origin = path_origin - normal * normal.dot(path_origin - _plane_origin)
	else:
		_pivot_origin = projected_centroid


func _contains_polygon(point: Vector2) -> bool:
	var inside := false
	for index in _polygon.size():
		var a := _polygon[index]
		var b := _polygon[(index + 1) % _polygon.size()]
		if _distance_squared_to_segment_2d(point, a, b) <= EPSILON * EPSILON:
			return true
		if (a.y > point.y) != (b.y > point.y):
			var crossing_x := (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
			if point.x < crossing_x:
				inside = not inside
	return inside


static func _distance_squared_to_segment_2d(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	if segment.length_squared() <= EPSILON * EPSILON:
		return point.distance_squared_to(a)
	var weight := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_squared_to(a + segment * weight)
