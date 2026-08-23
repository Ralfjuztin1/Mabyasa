@tool
class_name ScatterProjectView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"ray_direction", "Ray Direction")
	add_number_property(&"ray_length", "Ray Length", 0.0, 1000000.0, 0.1)
	add_number_property(&"ray_offset", "Ray Offset", -1000000.0, 1000000.0, 0.1)
	add_bool_property(&"remove_points_on_miss", "Remove on Miss")
	add_bool_property(&"align_with_collision_normal", "Align to Normal")
	add_number_property(&"max_slope", "Maximum Slope", 0.0, 90.0, 1.0)
	add_number_property(&"collision_mask", "Collision Mask", 0, 4294967295.0, 1, true)
	add_number_property(&"exclude_mask", "Exclude Mask", 0, 4294967295.0, 1, true)
