@tool
class_name ScatterShapeTransformView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"geometry", &"geometry", model.get_input_ports()[0].label)


func _build_properties() -> void:
	add_vector3_property(&"position", "Position")
	add_vector3_property(&"rotation", "Rotation")
	add_vector3_property(&"scale", "Scale")
