@tool
class_name ScatterPositionView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_enum_property(&"operation", "Operation", PackedStringArray(["Offset", "Multiply", "Override"]))
	add_vector3_property(&"position", "Position")
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local", "Instance"]))
