@tool
class_name ScatterSingleView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"offset", "Offset")
	add_vector3_property(&"rotation", "Rotation")
	add_vector3_property(&"scale", "Scale")
