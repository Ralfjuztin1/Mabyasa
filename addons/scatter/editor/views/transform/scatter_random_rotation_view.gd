@tool
class_name ScatterRandomRotationView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"rotation", "Rotation")
	add_vector3_property(&"snap_angle", "Snap Angle")
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local", "Instance"]))
