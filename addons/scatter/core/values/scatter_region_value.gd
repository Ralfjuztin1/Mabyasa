@tool
@abstract
class_name ScatterRegionValue
extends ScatterShapeValue

enum BooleanPivot {
	FROM_A,
	FROM_B,
	BOUNDS_CENTER,
}


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.REGION


func get_edges() -> Array[ScatterEdge]:
	return []


static func resolve_boolean_pivot(
		mode: int,
		a: ScatterShapeValue,
		b: ScatterShapeValue,
		bounds: AABB,
) -> Transform3D:
	match mode:
		BooleanPivot.FROM_A:
			return a.get_local_transform() if a != null else Transform3D.IDENTITY
		BooleanPivot.FROM_B:
			return b.get_local_transform() if b != null else Transform3D.IDENTITY
		_:
			return Transform3D(Basis.IDENTITY, bounds.get_center())
