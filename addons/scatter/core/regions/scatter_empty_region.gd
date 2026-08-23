@tool
class_name ScatterEmptyRegion
extends ScatterRegionValue


func get_bounds_local() -> AABB:
	return AABB()


func contains_local(_point: Vector3) -> bool:
	return false


func is_empty() -> bool:
	return true
