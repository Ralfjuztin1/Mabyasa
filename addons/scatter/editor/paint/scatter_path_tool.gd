@tool
class_name ScatterPathTool
extends RefCounted

enum Mode {
	EDIT,
	CREATE,
	DELETE,
}

var target: MultiMeshInstance3D
var path_node: ScatterPathNode
var gizmo: ScatterGizmoPlugin
var undo_redo: EditorUndoRedoManager
var path_changed: Callable
var toolbar: HBoxContainer
var _mode := Mode.EDIT
var _mode_buttons: Array[Button] = []
var _closed: CheckBox
var _syncing := false


func _init() -> void:
	_build_toolbar()


func configure(
		p_gizmo: ScatterGizmoPlugin,
		p_undo_redo: EditorUndoRedoManager,
		p_path_changed: Callable,
) -> void:
	gizmo = p_gizmo
	undo_redo = p_undo_redo
	path_changed = p_path_changed


func get_toolbar() -> Control:
	return toolbar


func activate(p_target: MultiMeshInstance3D, p_path_node: ScatterPathNode) -> void:
	target = p_target
	path_node = p_path_node
	_mode = Mode.EDIT
	_sync_toolbar()
	toolbar.visible = is_instance_valid(target) and path_node != null
	if gizmo != null:
		gizmo.set_active_path(target, path_node.node_id if path_node != null else 0)


func deactivate() -> void:
	if gizmo != null:
		gizmo.set_active_path(null, 0)
	target = null
	path_node = null
	toolbar.visible = false


func forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(target) or path_node == null or not toolbar.visible:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_mode(Mode.EDIT)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_INSERT:
			_set_mode(Mode.CREATE)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if _mode == Mode.CREATE:
		var point := _surface_point(camera, event.position)
		if point.is_finite():
			var points := path_node.points.duplicate()
			points.append(point)
			_commit_points(points, tr("Add Scatter Path Point"))
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if _mode == Mode.DELETE:
		var index := _closest_point(camera, event.position)
		if index >= 0:
			var points := path_node.points.duplicate()
			points.remove_at(index)
			_commit_points(points, tr("Delete Scatter Path Point"))
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _build_toolbar() -> void:
	toolbar = HBoxContainer.new()
	toolbar.name = "ScatterPathToolbar"
	toolbar.visible = false
	var label := Label.new()
	label.text = tr("Scatter Path")
	toolbar.add_child(label)
	var group := ButtonGroup.new()
	for entry in [
		[Mode.EDIT, "Edit Points", "Move path points with viewport handles"],
		[Mode.CREATE, "Add Points", "Click a collider or the view plane to append a point"],
		[Mode.DELETE, "Delete Points", "Click a path point to delete it"],
	]:
		var button := Button.new()
		button.text = tr(entry[1])
		button.tooltip_text = tr(entry[2])
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_set_mode.bind(entry[0]))
		toolbar.add_child(button)
		_mode_buttons.append(button)
	_closed = CheckBox.new()
	_closed.text = tr("Closed")
	_closed.tooltip_text = tr("Connect the last path point to the first")
	_closed.toggled.connect(_closed_changed)
	toolbar.add_child(_closed)


func _set_mode(value: int) -> void:
	_mode = value as Mode
	_sync_toolbar()
	if is_instance_valid(target):
		target.update_gizmos()


func _sync_toolbar() -> void:
	_syncing = true
	for index in _mode_buttons.size():
		_mode_buttons[index].button_pressed = index == _mode
	_closed.button_pressed = path_node.closed if path_node != null else false
	_syncing = false


func _closed_changed(value: bool) -> void:
	if _syncing or path_node == null:
		return
	var undo := ScatterUndoService.new(undo_redo, target, _notify_path_changed)
	undo.commit_property(path_node, &"closed", value, tr("Close Scatter Path"))


func _surface_point(camera: Camera3D, screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if target.is_inside_tree() and target.get_world_3d() != null:
		var graph := ScatterGraphAttachment.get_graph(target)
		var mask: int = graph.collision_mask if graph != null else 1
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100000.0, mask)
		var hit := target.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return target.to_local(hit.position)
	var anchor := target.global_position
	if not path_node.points.is_empty():
		anchor = target.to_global(path_node.points[-1])
	var plane_normal := camera.global_transform.basis.z.normalized()
	var view_plane := Plane(plane_normal, plane_normal.dot(anchor))
	var result = view_plane.intersects_ray(origin, direction)
	return target.to_local(result) if result != null else Vector3.INF


func _closest_point(camera: Camera3D, screen_position: Vector2) -> int:
	var closest := -1
	var best_distance := 14.0
	for index in path_node.points.size():
		var world_position := target.to_global(path_node.points[index])
		if camera.is_position_behind(world_position):
			continue
		var distance := camera.unproject_position(world_position).distance_to(screen_position)
		if distance < best_distance:
			best_distance = distance
			closest = index
	return closest


func _commit_points(points: PackedVector3Array, caption: String) -> void:
	var undo := ScatterUndoService.new(undo_redo, target, _notify_path_changed)
	undo.commit_property(path_node, &"points", points, caption)


func _notify_path_changed() -> void:
	if is_instance_valid(target):
		target.update_gizmos()
	if path_changed.is_valid():
		path_changed.call()
