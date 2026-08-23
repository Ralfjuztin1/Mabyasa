@tool
class_name ScatterRandomCustomDataView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_color_property(&"from_color", "From")
	add_color_property(&"to_color", "To")
