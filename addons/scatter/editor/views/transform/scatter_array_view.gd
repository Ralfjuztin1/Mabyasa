@tool
class_name ScatterArrayView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_number_property(&"amount", "Amount", 1, 10000, 1, true)
	add_number_property(&"min_amount", "Minimum Amount", -1, 10000, 1, true)
	add_bool_property(&"local_offset", "Local Offset")
	add_vector3_property(&"offset", "Offset")
	add_bool_property(&"local_rotation", "Local Rotation")
	add_vector3_property(&"rotation", "Rotation")
	add_bool_property(&"individual_rotation_pivots", "Individual Pivots")
	add_vector3_property(&"rotation_pivot", "Rotation Pivot")
	add_bool_property(&"local_scale", "Local Scale")
	add_vector3_property(&"scale", "Scale")
	add_bool_property(&"randomize_indices", "Randomize Indices")
