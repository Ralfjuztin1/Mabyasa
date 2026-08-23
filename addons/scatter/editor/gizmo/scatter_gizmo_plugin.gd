@tool
class_name ScatterGizmoPlugin
extends EditorNode3DGizmoPlugin

var _undo_redo: EditorUndoRedoManager
var _changed: Callable
var _graph_provider: Callable
var _active_target_id := 0
var _active_node_id := 0
var _extension: ScatterNodeEditorExtension
var _context: ScatterNodeEditorContext
var _brush_previews: Dictionary = {}


func _init() -> void:
	create_material("region", Color(0.28, 0.82, 0.72, 0.95))
	create_material("path", Color(0.28, 0.82, 0.72, 0.95))
	create_material("paint", Color(0.22, 0.72, 1.0, 0.9))
	create_material("instances", Color(0.73, 0.54, 0.93, 0.75))
	create_material("cursor", Color(0.35, 1.0, 0.45, 1.0))
	create_material("erase", Color(1.0, 0.28, 0.32, 1.0))
	create_handle_material("handles")


func configure(p_undo_redo: EditorUndoRedoManager, p_changed: Callable, p_graph_provider: Callable = Callable()) -> void:
	_undo_redo = p_undo_redo
	_changed = p_changed
	_graph_provider = p_graph_provider


func set_active_node(target: MultiMeshInstance3D, node_id: int) -> void:
	var previous := instance_from_id(_active_target_id) as MultiMeshInstance3D
	if _extension != null and _context != null:
		_extension.on_deselected(_context)
	_active_target_id = target.get_instance_id() if is_instance_valid(target) else 0
	_active_node_id = node_id
	_context = _make_context(target, node_id)
	_extension = ScatterExtensionRegistry.create_editor_extension(_context.node.get_type_id()) if _context != null else null
	if _extension != null:
		_extension.on_selected(_context)
	if is_instance_valid(previous):
		previous.update_gizmos()
	if is_instance_valid(target):
		target.update_gizmos()


func set_active_path(target: MultiMeshInstance3D, node_id: int) -> void:
	set_active_node(target, node_id)


func set_brush_preview(target: MultiMeshInstance3D, position: Vector3, normal: Vector3, radius: float, erase: bool) -> void:
	if is_instance_valid(target):
		_brush_previews[target.get_instance_id()] = {"position": position, "normal": normal, "radius": radius, "erase": erase}
		target.update_gizmos()


func clear_brush_preview(target: MultiMeshInstance3D) -> void:
	if is_instance_valid(target):
		_brush_previews.erase(target.get_instance_id())
		target.update_gizmos()


func _get_gizmo_name() -> String:
	return "Scatter Selection"


func _has_gizmo(node_3d: Node3D) -> bool:
	return node_3d is MultiMeshInstance3D and _graph_for_target(node_3d) != null


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	if not is_instance_valid(target):
		return
	if target.get_instance_id() == _active_target_id and _extension != null and _context != null:
		_extension.draw_gizmo(_context, ScatterGizmoSink.new(gizmo, self))
	var preview: Dictionary = _brush_previews.get(target.get_instance_id(), {})
	if not preview.is_empty():
		var lines := ScatterBrushGeometry.circle(preview.position, preview.normal, preview.radius, true)
		gizmo.add_lines(lines, get_material("erase" if preview.erase else "cursor", gizmo), false)


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return _extension.get_handle_name(_context, handle_id) if _extension != null else ""


func _get_handle_value(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	return _extension.get_handle_value(_context, handle_id) if _extension != null else null


func _set_handle(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_position: Vector2) -> void:
	if _extension != null:
		_extension.set_handle(_context, handle_id, camera, screen_position)


func _commit_handle(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	if _extension != null:
		_extension.commit_handle(_context, restore, cancel)


func _make_context(target: MultiMeshInstance3D, node_id: int) -> ScatterNodeEditorContext:
	var graph := _graph_for_target(target)
	var node := graph.find_node(node_id) if graph != null else null
	if node == null:
		return null
	var context := ScatterNodeEditorContext.create(target, graph, node, _undo_redo)
	context.changed = _changed
	return context


func _graph_for_target(target: MultiMeshInstance3D) -> ScatterGraph:
	if not is_instance_valid(target):
		return null
	if _graph_provider.is_valid():
		var provided = _graph_provider.call(target)
		if provided is ScatterGraph:
			return provided
	return ScatterGraphAttachment.get_graph(target)
