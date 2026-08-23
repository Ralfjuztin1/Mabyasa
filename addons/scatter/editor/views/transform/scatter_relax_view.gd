@tool
class_name ScatterRelaxView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_number_property(&"iterations", "Iterations", 1, 100, 1, true)
	add_number_property(&"offset_step", "Offset Step", 0.0, 1000000.0, 0.01)
	add_number_property(&"consecutive_step_multiplier", "Step Multiplier", 0.0, 1000000.0, 0.05)
