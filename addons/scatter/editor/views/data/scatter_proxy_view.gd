@tool
class_name ScatterProxyView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")


func _build_properties() -> void:
	add_node_path_property(&"scatter_node", "Target Node")
	add_bool_property(&"auto_rebuild", "Auto Rebuild")
