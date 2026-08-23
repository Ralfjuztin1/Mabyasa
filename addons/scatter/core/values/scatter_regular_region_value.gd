@tool
@abstract
class_name ScatterRegularRegionValue
extends ScatterRegionValue


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.REGULAR_REGION


@abstract func sample_local(value: float) -> Vector3
