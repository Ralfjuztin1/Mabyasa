@tool
class_name ScatterPathTubeView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"path", &"", "Path")
	add_port_row(&"", &"region", "Region")


func _build_properties() -> void:
	add_number_property(&"radius", "Radius", 0.001, 1000000.0, 0.1)
