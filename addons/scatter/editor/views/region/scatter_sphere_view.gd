@tool
class_name ScatterSphereView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"region", "Regular Region")


func _build_properties() -> void:
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local"]))
	add_vector3_property(&"center", "Center")
	add_number_property(&"radius", "Radius", 0.001, 1000000.0, 0.1)
