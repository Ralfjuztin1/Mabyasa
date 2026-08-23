@tool
@abstract
class_name ScatterShapeValue
extends ScatterValue


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.SHAPE


## Maps the shape's own coordinate system into MultiMesh Local space.
## Composite shapes that no longer have a single source coordinate system use
## identity and continue to implement their queries directly in Local space.
func get_local_transform() -> Transform3D:
	return Transform3D.IDENTITY


func shape_to_local(point: Vector3) -> Vector3:
	return get_local_transform() * point


func local_to_shape(point: Vector3) -> Vector3:
	return get_local_transform().affine_inverse() * point


@abstract func get_bounds_local() -> AABB


@abstract func contains_local(point: Vector3) -> bool


func is_empty() -> bool:
	return get_bounds_local().size.is_zero_approx()
