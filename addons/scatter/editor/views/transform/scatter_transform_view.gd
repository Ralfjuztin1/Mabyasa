@tool
class_name ScatterTransformView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"position", "Position")
	add_vector3_property(&"rotation", "Rotation")
	add_vector3_property(&"scale", "Scale")
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local", "Instance"]))
