@tool
@abstract
class_name ScatterValue
extends RefCounted


@abstract func get_value_type_id() -> StringName


func duplicate_value() -> ScatterValue:
	return self
