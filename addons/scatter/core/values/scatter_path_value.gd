@tool
class_name ScatterPathValue
extends ScatterShapeValue

const CONTAIN_EPSILON := 0.0001

var _points: PackedVector3Array
var _closed := false
var _local_transform := Transform3D.IDENTITY
var _cumulative_lengths := PackedFloat32Array()
var _length := 0.0


func _init(
		points := PackedVector3Array(),
		closed := false,
		local_transform := Transform3D.IDENTITY,
	) -> void:
	_points = points.duplicate()
	_closed = closed
	_local_transform = local_transform
	_rebuild_lengths()


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.PATH


func get_local_transform() -> Transform3D:
	return _local_transform


func get_points_local() -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in _points:
		result.append(shape_to_local(point))
	return result


func transformed_local(transform: Transform3D) -> ScatterPathValue:
	# Load by path to avoid a compile-time cycle: ScatterTransformedPath derives
	# from this class while this virtual constructor creates that wrapper.
	var transformed_script := load("res://addons/scatter/core/values/scatter_transformed_path.gd") as Script
	return transformed_script.new(self, transform) as ScatterPathValue


func get_bounds_local() -> AABB:
	if _points.is_empty():
		return AABB()
	var bounds := AABB(shape_to_local(_points[0]), Vector3.ZERO)
	for index in range(1, _points.size()):
		bounds = bounds.expand(shape_to_local(_points[index]))
	return bounds


func contains_local(point: Vector3) -> bool:
	if _points.is_empty():
		return false
	if _points.size() == 1:
		return point.distance_squared_to(shape_to_local(_points[0])) <= CONTAIN_EPSILON * CONTAIN_EPSILON
	var segment_count := _points.size() if _closed else _points.size() - 1
	for segment in segment_count:
		var start := shape_to_local(_points[segment])
		var end := _local_segment_end(segment)
		var closest := Geometry3D.get_closest_point_to_segment(point, start, end)
		if point.distance_squared_to(closest) <= CONTAIN_EPSILON * CONTAIN_EPSILON:
			return true
	return false


func is_closed() -> bool:
	return _closed


func get_length_local() -> float:
	return _length


func sample_local(value: float) -> Vector3:
	if _points.is_empty():
		return Vector3.INF
	if _points.size() == 1 or _length <= 0.000001:
		return shape_to_local(_points[0])
	var distance := clampf(value, 0.0, 1.0) * _length
	var segment := _segment_for_distance(distance)
	var start_distance := _cumulative_lengths[segment]
	var end_distance := _cumulative_lengths[segment + 1]
	var t := inverse_lerp(start_distance, end_distance, distance)
	return shape_to_local(_segment_point(segment, t))


func tangent_local(value: float) -> Vector3:
	if _points.size() < 2:
		return Vector3.FORWARD
	var segment := _segment_for_distance(clampf(value, 0.0, 1.0) * _length)
	var tangent := _local_segment_end(segment) - shape_to_local(_points[segment])
	return tangent.normalized() if not tangent.is_zero_approx() else Vector3.FORWARD


func _rebuild_lengths() -> void:
	_cumulative_lengths = PackedFloat32Array([0.0])
	_length = 0.0
	var segment_count := _points.size() if _closed and _points.size() > 1 else maxi(0, _points.size() - 1)
	for index in segment_count:
		_length += shape_to_local(_points[index]).distance_to(_local_segment_end(index))
		_cumulative_lengths.append(_length)


func _segment_for_distance(distance: float) -> int:
	var segment_count := _cumulative_lengths.size() - 1
	for index in segment_count:
		if distance <= _cumulative_lengths[index + 1]:
			return index
	return maxi(0, segment_count - 1)


func _segment_end(segment: int) -> Vector3:
	return _points[(segment + 1) % _points.size()]


func _local_segment_end(segment: int) -> Vector3:
	return shape_to_local(_segment_end(segment))


func _segment_point(segment: int, t: float) -> Vector3:
	return _points[segment].lerp(_segment_end(segment), t)
