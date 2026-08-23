@tool
class_name ScatterPathView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"path", "Path")


func _build_properties() -> void:
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local"]))
	add_bool_property(&"closed", "Closed")


func get_viewport_tool_id() -> StringName:
	return &"path"
