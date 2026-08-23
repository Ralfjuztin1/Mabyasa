@tool
class_name ScatterSubtractView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"shape", "Shape")
	add_port_row(&"a", &"", "A")
	add_port_row(&"b", &"", "B")


func _build_properties() -> void:
	add_enum_property(
		&"pivot",
		"Pivot",
		PackedStringArray(["From A", "From B", "Bounds Center"]),
		"Defines the result's local reference frame without changing its geometry.",
	)
