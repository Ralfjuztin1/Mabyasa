@tool
class_name ScatterBrushGeometry
extends RefCounted


static func circle(
		center: Vector3,
		normal: Vector3,
		radius: float,
		with_cross := false,
) -> PackedVector3Array:
	var lines := PackedVector3Array()
	normal = normal.normalized()
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.001:
		tangent = normal.cross(Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent).normalized()
	for index in 48:
		var angle_a := TAU * float(index) / 48.0
		var angle_b := TAU * float(index + 1) / 48.0
		lines.append(center + (tangent * cos(angle_a) + bitangent * sin(angle_a)) * radius)
		lines.append(center + (tangent * cos(angle_b) + bitangent * sin(angle_b)) * radius)
	if with_cross:
		lines.append(center - tangent * radius)
		lines.append(center + tangent * radius)
		lines.append(center - bitangent * radius)
		lines.append(center + bitangent * radius)
		lines.append(center)
		lines.append(center + normal * minf(radius * 0.5, 1.0))
	return lines
