@tool
class_name ScatterMath
extends RefCounted


static func positive_vec3(value: Vector3) -> Vector3:
	return Vector3(
		maxf(absf(value.x), 0.001),
		maxf(absf(value.y), 0.001),
		maxf(absf(value.z), 0.001),
	)


static func box_corners(center: Vector3, size: Vector3, rotation_degrees: Vector3) -> Array[Vector3]:
	var half_size := positive_vec3(size) * 0.5
	var basis := Basis.from_euler(rotation_degrees * PI / 180.0)
	var result: Array[Vector3] = []
	for local in [
		Vector3(-half_size.x, -half_size.y, -half_size.z),
		Vector3(half_size.x, -half_size.y, -half_size.z),
		Vector3(half_size.x, -half_size.y, half_size.z),
		Vector3(-half_size.x, -half_size.y, half_size.z),
		Vector3(-half_size.x, half_size.y, -half_size.z),
		Vector3(half_size.x, half_size.y, -half_size.z),
		Vector3(half_size.x, half_size.y, half_size.z),
		Vector3(-half_size.x, half_size.y, half_size.z),
	]:
		result.append(center + basis * local)
	return result


static func aabb_intersection(a: AABB, b: AABB) -> AABB:
	var start := Vector3(
		maxf(a.position.x, b.position.x),
		maxf(a.position.y, b.position.y),
		maxf(a.position.z, b.position.z),
	)
	var finish := Vector3(
		minf(a.end.x, b.end.x),
		minf(a.end.y, b.end.y),
		minf(a.end.z, b.end.z),
	)
	if finish.x < start.x or finish.y < start.y or finish.z < start.z:
		return AABB()
	return AABB(start, finish - start)


static func transformed_aabb(bounds: AABB, transform: Transform3D) -> AABB:
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
	var result := AABB(transform * corners[0], Vector3.ZERO)
	for index in range(1, corners.size()):
		result = result.expand(transform * corners[index])
	return result


static func distance_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	if ab.length_squared() < 0.000001:
		return point.distance_to(a)
	var weight := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * weight)


static func basis_from_up(up: Vector3, forward_hint: Vector3) -> Basis:
	var y := up.normalized()
	var z := forward_hint - y * forward_hint.dot(y)
	if z.length_squared() < 0.000001:
		z = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z).orthonormalized()


static func basis_from_forward(forward: Vector3, up: Vector3) -> Basis:
	var z := -forward.normalized()
	var x := up.cross(z).normalized()
	if x.length_squared() < 0.000001:
		x = Vector3.RIGHT
	return Basis(x, z.cross(x).normalized(), z).orthonormalized()


static func snapped_vec3(value: Vector3, step: Vector3) -> Vector3:
	return Vector3(
		snappedf(value.x, step.x) if step.x != 0.0 else value.x,
		snappedf(value.y, step.y) if step.y != 0.0 else value.y,
		snappedf(value.z, step.z) if step.z != 0.0 else value.z,
	)


static func random_snapped(rng: RandomNumberGenerator, extent: float, step: float) -> float:
	var value := rng.randf_range(-extent, extent)
	return snappedf(value, step) if step > 0.0 else value


static func pow_vec3(value: Vector3, exponent: int) -> Vector3:
	return Vector3(pow(value.x, exponent), pow(value.y, exponent), pow(value.z, exponent))
