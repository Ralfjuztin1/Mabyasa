@tool
class_name ScatterLookAtView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"target", "Target")
	add_vector3_property(&"up", "Up")
