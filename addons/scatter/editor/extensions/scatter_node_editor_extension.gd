@tool
class_name ScatterNodeEditorExtension
extends RefCounted


func draw_gizmo(_context: ScatterNodeEditorContext, _sink: ScatterGizmoSink) -> void:
	pass


func create_viewport_tool(_context: ScatterNodeEditorContext) -> ScatterViewportTool:
	return null


func on_selected(_context: ScatterNodeEditorContext) -> void:
	pass


func on_deselected(_context: ScatterNodeEditorContext) -> void:
	pass


func get_handle_name(_context: ScatterNodeEditorContext, _handle_id: int) -> String:
	return ""


func get_handle_value(_context: ScatterNodeEditorContext, _handle_id: int) -> Variant:
	return null


func set_handle(_context: ScatterNodeEditorContext, _handle_id: int, _camera: Camera3D, _screen_position: Vector2) -> void:
	pass


func commit_handle(_context: ScatterNodeEditorContext, _restore: Variant, _cancel: bool) -> void:
	pass
