@tool
class_name ScatterRemoveRandomView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_number_property(&"probability", "Probability", 0.0, 100.0, 1.0)
