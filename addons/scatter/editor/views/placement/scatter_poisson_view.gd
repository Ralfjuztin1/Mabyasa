@tool
class_name ScatterPoissonView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")
	add_port_row(&"shape", &"", "Shape")


func _build_properties() -> void:
	add_number_property(&"radius", "Radius", 0.001, 1000000.0, 0.05)
	add_number_property(&"samples_before_rejection", "Rejection Samples", 1, 100, 1, true)
	add_number_property(&"max_points", "Maximum Points", 1, 1000000, 1, true)
