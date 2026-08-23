@tool
class_name ScatterTransformedRegularRegion
extends ScatterRegularRegionValue

var source: ScatterRegularRegionValue
var local_from_authored := Transform3D.IDENTITY
var authored_from_local := Transform3D.IDENTITY


func _init(p_source: ScatterRegularRegionValue = null, p_local_from_authored := Transform3D.IDENTITY) -> void:
	source = p_source if p_source != null else ScatterBoxRegion.new(Vector3.ZERO, Vector3.ZERO)
	local_from_authored = p_local_from_authored
	authored_from_local = local_from_authored.affine_inverse()


func get_local_transform() -> Transform3D:
	return local_from_authored * source.get_local_transform()


func get_bounds_local() -> AABB:
	var bounds := source.get_bounds_local()
	var corners := [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0, 0),
		bounds.position + Vector3(0, bounds.size.y, 0),
		bounds.position + Vector3(0, 0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, bounds.size.y, 0),
		bounds.position + Vector3(bounds.size.x, 0, bounds.size.z),
		bounds.position + Vector3(0, bounds.size.y, bounds.size.z),
		bounds.end,
	]
	var result := AABB(local_from_authored * corners[0], Vector3.ZERO)
	for corner in corners:
		result = result.expand(local_from_authored * corner)
	return result


func contains_local(point: Vector3) -> bool:
	return source.contains_local(authored_from_local * point)


func sample_local(value: float) -> Vector3:
	return local_from_authored * source.sample_local(value)


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	for edge in source.get_edges():
		result.append(ScatterEdge.new(local_from_authored * edge.a, local_from_authored * edge.b))
	return result
