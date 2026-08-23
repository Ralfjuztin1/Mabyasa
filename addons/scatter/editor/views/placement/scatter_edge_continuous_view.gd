@tool
class_name ScatterEdgeContinuousView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")
	add_port_row(&"path", &"", "Path")


func _build_properties() -> void:
	add_number_property(&"item_length", "Item Length", 0.001, 1000000.0, 0.1)
	add_bool_property(&"ignore_slopes", "Ignore Slopes")
