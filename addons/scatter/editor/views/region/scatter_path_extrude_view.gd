@tool
class_name ScatterPathExtrudeView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"path", &"", "Path")
	add_port_row(&"", &"region", "Region")


func _build_properties() -> void:
	add_vector3_property(&"normal", "Normal")
	add_number_property(&"forward", "Forward", 0.0, 1000000.0, 0.1)
	add_number_property(&"backward", "Backward", 0.0, 1000000.0, 0.1)
	add_enum_property(&"pivot", "Pivot", PackedStringArray(["Projected Centroid", "Projected Path Origin"]))
