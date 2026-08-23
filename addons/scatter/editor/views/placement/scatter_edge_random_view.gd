@tool
class_name ScatterEdgeRandomView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")
	add_port_row(&"path", &"", "Path")


func _build_properties() -> void:
	add_number_property(&"instance_count", "Instance Count", 0, 1000000, 1, true)
	add_bool_property(&"align_to_path", "Align to Path")
