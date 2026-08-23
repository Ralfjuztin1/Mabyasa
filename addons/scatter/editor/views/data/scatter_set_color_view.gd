@tool
class_name ScatterSetColorView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_color_property(&"color", "Color")
