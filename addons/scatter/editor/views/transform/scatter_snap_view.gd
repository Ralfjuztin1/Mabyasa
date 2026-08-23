@tool
class_name ScatterSnapView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"position_step", "Position Step")
	add_vector3_property(&"rotation_step", "Rotation Step")
	add_vector3_property(&"scale_step", "Scale Step")
