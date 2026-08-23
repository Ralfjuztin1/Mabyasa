@tool
class_name ScatterRandomView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")
	add_port_row(&"shape", &"", "Shape")


func _build_properties() -> void:
	add_number_property(&"amount", "Amount", 0, 1000000, 1, true)
