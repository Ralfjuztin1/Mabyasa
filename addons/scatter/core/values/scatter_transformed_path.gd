@tool
class_name ScatterTransformedPath
extends ScatterPathValue

var source: ScatterPathValue
var local_from_source := Transform3D.IDENTITY
var source_from_local := Transform3D.IDENTITY
var _resolved: ScatterPathValue


func _init(
		p_source: ScatterPathValue = null,
		p_local_from_source := Transform3D.IDENTITY,
) -> void:
	source = p_source if p_source != null else ScatterPathValue.new()
	local_from_source = p_local_from_source
	source_from_local = local_from_source.affine_inverse()
	var transformed_points := PackedVector3Array()
	for point in source.get_points_local():
		transformed_points.append(local_from_source * point)
	_resolved = ScatterPathValue.new(transformed_points, source.is_closed())


func get_local_transform() -> Transform3D:
	return local_from_source * source.get_local_transform()


func get_points_local() -> PackedVector3Array:
	return _resolved.get_points_local()


func get_bounds_local() -> AABB:
	return _resolved.get_bounds_local()


func contains_local(point: Vector3) -> bool:
	return _resolved.contains_local(point)


func is_closed() -> bool:
	return source.is_closed()


func get_length_local() -> float:
	return _resolved.get_length_local()


func sample_local(value: float) -> Vector3:
	return _resolved.sample_local(value)


func tangent_local(value: float) -> Vector3:
	return _resolved.tangent_local(value)
