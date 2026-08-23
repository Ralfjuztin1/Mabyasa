@tool
class_name ScatterClusterizeView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_file_property(&"mask", "Mask")
	add_number_property(&"mask_rotation", "Mask Rotation", -1000000.0, 1000000.0, 1.0)
	add_vector2_property(&"mask_offset", "Mask Offset")
	add_vector2_property(&"mask_scale", "Mask Scale")
	add_number_property(&"pixel_to_unit_ratio", "Pixel to Unit Ratio", 0.001, 1000000.0, 1.0)
	add_number_property(&"remove_below", "Remove Below", 0.0, 1.0, 0.01)
	add_number_property(&"remove_above", "Remove Above", 0.0, 1.0, 0.01)
	add_bool_property(&"scale_transforms", "Scale Transforms")
