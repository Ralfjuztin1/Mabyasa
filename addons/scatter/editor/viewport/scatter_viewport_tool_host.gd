@tool
class_name ScatterViewportToolHost
extends RefCounted

var _plugin: EditorPlugin
var _panel: ScatterPanel
var _gizmo: ScatterGizmoPlugin
var _paint: ScatterPaintTool
var _path: ScatterPathTool
var _paint_toolbar: Control
var _path_toolbar: Control
var _target: MultiMeshInstance3D
var _active_id: StringName
var _activators: Dictionary = {}
var _deactivators: Dictionary = {}
var _forwarders: Dictionary = {}


func configure(
		plugin: EditorPlugin,
		panel: ScatterPanel,
		gizmo: ScatterGizmoPlugin,
		undo_redo: EditorUndoRedoManager,
		build_requested: Callable,
		scene_changed: Callable,
) -> void:
	_plugin = plugin
	_panel = panel
	_gizmo = gizmo
	_paint = ScatterPaintTool.new()
	_paint.configure(panel, gizmo, undo_redo, build_requested, scene_changed)
	_paint_toolbar = _paint.get_toolbar()
	plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _paint_toolbar)
	_path = ScatterPathTool.new()
	_path.configure(gizmo, undo_redo, panel._path_data_changed)
	_path_toolbar = _path.get_toolbar()
	plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _path_toolbar)
	_activators = {&"paint": _activate_paint, &"path": _activate_path}
	_deactivators = {&"paint": _paint.stop, &"path": _path.deactivate}
	_forwarders = {&"paint": _paint.forward_3d_gui_input, &"path": _path.forward_3d_gui_input}


func shutdown() -> void:
	deactivate()
	if _paint_toolbar != null:
		_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _paint_toolbar)
		_paint_toolbar.queue_free()
	if _path_toolbar != null:
		_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _path_toolbar)
		_path_toolbar.queue_free()
	_paint = null
	_path = null
	_paint_toolbar = null
	_path_toolbar = null


func set_target(target: MultiMeshInstance3D) -> void:
	_target = target
	if _paint != null:
		_paint.set_target(target)


func select(tool_id: StringName, node_id: int) -> void:
	deactivate()
	_active_id = tool_id
	var activator: Callable = _activators.get(tool_id, Callable())
	if activator.is_valid():
		activator.call(node_id)


func deactivate() -> void:
	var deactivator: Callable = _deactivators.get(_active_id, Callable())
	if deactivator.is_valid():
		deactivator.call()
	_active_id = &""


func forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var forwarder: Callable = _forwarders.get(_active_id, Callable())
	return int(forwarder.call(camera, event)) if forwarder.is_valid() else EditorPlugin.AFTER_GUI_INPUT_PASS


func _activate_paint(_node_id: int) -> void:
	_paint.activate()
	_plugin.make_bottom_panel_item_visible(_panel)


func _activate_path(_node_id: int) -> void:
	_path.activate(_target, _panel.get_active_path_node())
	_plugin.make_bottom_panel_item_visible(_panel)
