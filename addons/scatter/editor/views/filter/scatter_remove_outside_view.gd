@tool
class_name ScatterRemoveOutsideView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")
	add_port_row(&"shape", &"", "Shape")


func _build_properties() -> void:
	pass
