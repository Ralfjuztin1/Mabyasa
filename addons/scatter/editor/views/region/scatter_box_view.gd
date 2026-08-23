@tool
class_name ScatterBoxView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"region", "Regular Region")


func _build_properties() -> void:
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local"]))
	add_vector3_property(&"center", "Center")
	add_vector3_property(&"size", "Size")
	add_vector3_property(&"rotation", "Rotation")
