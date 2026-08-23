@tool
class_name ScatterGridView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")
	add_port_row(&"shape", &"", "Shape")


func _build_properties() -> void:
	add_enum_property(
		&"space",
		"Space",
		PackedStringArray(["Global", "Local", "Instance"]),
		"Global uses world axes, Local uses MultiMesh axes, and Instance uses the Shape local transform.",
	)
	add_vector3_property(&"spacing", "Spacing")
	add_vector3_property(&"offset", "Offset", "Grid phase offset in the selected Space.")
