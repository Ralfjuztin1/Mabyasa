@tool
class_name ScatterBoxRegion
extends ScatterRegularRegionValue

var center := Vector3.ZERO
var size := Vector3.ONE
var rotation_degrees := Vector3.ZERO


func _init(p_center := Vector3.ZERO, p_size := Vector3.ONE, p_rotation_degrees := Vector3.ZERO) -> void:
	center = p_center
	size = p_size
	rotation_degrees = p_rotation_degrees


func get_local_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(rotation_degrees * PI / 180.0), center)


func get_bounds_local() -> AABB:
	var corners := ScatterMath.box_corners(center, size, rotation_degrees)
	var result := AABB(corners[0], Vector3.ZERO)
	for corner in corners:
		result = result.expand(corner)
	return result


func contains_local(point: Vector3) -> bool:
	var half_size := ScatterMath.positive_vec3(size) * 0.5
	var rotation := Basis.from_euler(rotation_degrees * PI / 180.0)
	var local := rotation.inverse() * (point - center)
	return (
		absf(local.x) <= half_size.x
		and absf(local.y) <= half_size.y
		and absf(local.z) <= half_size.z
	)


func sample_local(value: float) -> Vector3:
	var unit := Vector3(
		ScatterSampleHash.dimension(value, 0) - 0.5,
		ScatterSampleHash.dimension(value, 1) - 0.5,
		ScatterSampleHash.dimension(value, 2) - 0.5,
	)
	return center + Basis.from_euler(rotation_degrees * PI / 180.0) * (unit * ScatterMath.positive_vec3(size))


func get_edges() -> Array[ScatterEdge]:
	var corners := ScatterMath.box_corners(center, size, rotation_degrees)
	var result: Array[ScatterEdge] = []
	for pair in [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]:
		result.append(ScatterEdge.new(corners[pair[0]], corners[pair[1]]))
	return result
