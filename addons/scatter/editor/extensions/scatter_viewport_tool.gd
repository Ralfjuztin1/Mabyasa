@tool
class_name ScatterViewportTool
extends RefCounted


func get_toolbar() -> Control:
	return null


func activate() -> void:
	pass


func deactivate() -> void:
	pass


func forward_3d_gui_input(_camera: Camera3D, _event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_PASS
