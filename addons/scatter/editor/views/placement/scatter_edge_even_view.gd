@tool
class_name ScatterEdgeEvenView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"path", &"", "Path")
	add_port_row(&"", &"instances", "Instances")


func _build_properties() -> void:
	add_number_property(&"spacing", "Spacing", 0.001, 1000000.0, 0.1)
	add_number_property(&"offset", "Offset", -1000000.0, 1000000.0, 0.1)
	add_bool_property(&"align_to_path", "Align to Path")
