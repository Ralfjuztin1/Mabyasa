@tool
class_name ScatterPaintTool
extends RefCounted

var panel: ScatterPanel
var gizmo: ScatterGizmoPlugin
var undo_redo: EditorUndoRedoManager
var target: MultiMeshInstance3D
var build_requested: Callable
var scene_changed: Callable
var toolbar: HBoxContainer
var _last_paint_position := Vector3.INF
var _paint_button: Button
var _erase_button: Button
var _radius: SpinBox
var _collision_mask: SpinBox
var _clear_layer: Button
var _syncing := false


func _init() -> void:
	_build_toolbar()


func configure(
		p_panel: ScatterPanel,
		p_gizmo: ScatterGizmoPlugin,
		p_undo_redo: EditorUndoRedoManager,
		p_build_requested: Callable,
		p_scene_changed: Callable,
) -> void:
	panel = p_panel
	gizmo = p_gizmo
	undo_redo = p_undo_redo
	build_requested = p_build_requested
	scene_changed = p_scene_changed
	panel.paint_settings_changed.connect(_sync_toolbar)
	_sync_from_panel()


func get_toolbar() -> Control:
	return toolbar


func activate() -> void:
	reset_stroke()
	_sync_from_panel()
	toolbar.visible = is_instance_valid(target) and panel != null and panel.get_active_paint_node() != null


func set_target(value: MultiMeshInstance3D) -> void:
	if is_instance_valid(target) and target != value and gizmo != null:
		gizmo.clear_brush_preview(target)
	target = value
	reset_stroke()


func reset_stroke() -> void:
	_last_paint_position = Vector3.INF


func stop() -> void:
	reset_stroke()
	toolbar.visible = false
	if is_instance_valid(target) and gizmo != null:
		gizmo.clear_brush_preview(target)


func forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(target) or panel == null or not panel.paint_active or not toolbar.visible:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		_update_brush_preview(camera, event.position)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_paint_at_screen(camera, event.position, true)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			reset_stroke()
			_paint_at_screen(camera, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		reset_stroke()
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _brush_hit(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	if not target.is_inside_tree() or target.get_world_3d() == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var mask: int = panel.graph.collision_mask if panel.graph != null else 1
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100000.0, mask)
	return target.get_world_3d().direct_space_state.intersect_ray(query)


func _update_brush_preview(camera: Camera3D, screen_position: Vector2) -> void:
	var hit := _brush_hit(camera, screen_position)
	if hit.is_empty():
		gizmo.clear_brush_preview(target)
		return
	var local_position := target.to_local(hit.position)
	var local_normal := (target.global_transform.basis.inverse() * Vector3(hit.normal)).normalized()
	gizmo.set_brush_preview(target, local_position, local_normal, panel.brush_radius, panel.paint_erase)


func _paint_at_screen(camera: Camera3D, screen_position: Vector2, dragging := false) -> void:
	var paint_node: ScatterPaintRegionNode = panel.get_active_paint_node()
	if paint_node == null:
		return
	var hit := _brush_hit(camera, screen_position)
	if hit.is_empty():
		return
	var local_position := target.to_local(hit.position)
	var authored_position: Vector3 = hit.position if paint_node.space == ScatterSpace.Type.GLOBAL else local_position
	if (
		dragging
		and _last_paint_position != Vector3.INF
		and _last_paint_position.distance_to(authored_position) < panel.brush_radius * 0.35
	):
		return
	_last_paint_position = authored_position
	var local_normal := (target.global_transform.basis.inverse() * Vector3(hit.normal)).normalized()
	var authored_normal: Vector3 = Vector3(hit.normal).normalized() if paint_node.space == ScatterSpace.Type.GLOBAL else local_normal
	var next_strokes: Array[ScatterPaintStroke] = paint_node.strokes.duplicate()
	if panel.paint_erase:
		for index in range(next_strokes.size() - 1, -1, -1):
			var stroke := next_strokes[index]
			var erase_radius := panel.brush_radius + stroke.radius * 0.35
			if stroke.position.distance_to(authored_position) <= erase_radius:
				next_strokes.remove_at(index)
	else:
		next_strokes.append(ScatterPaintStroke.create(authored_position, authored_normal, panel.brush_radius))
	var undo := ScatterUndoService.new(undo_redo, target, _paint_data_changed)
	undo.commit_property(
		paint_node,
		&"strokes",
		next_strokes,
		tr("Erase Scatter Paint") if panel.paint_erase else tr("Paint Scatter Region"),
		"stroke",
		UndoRedo.MERGE_ENDS if dragging else UndoRedo.MERGE_DISABLE,
	)
	gizmo.set_brush_preview(target, local_position, local_normal, panel.brush_radius, panel.paint_erase)


func _paint_data_changed() -> void:
	if panel != null:
		panel._paint_data_changed()
	if scene_changed.is_valid():
		scene_changed.call(false)


func _build_toolbar() -> void:
	toolbar = HBoxContainer.new()
	toolbar.name = "ScatterPaintToolbar"
	toolbar.visible = false
	var label := Label.new()
	label.text = tr("Scatter Paint")
	toolbar.add_child(label)
	var mode_group := ButtonGroup.new()
	_paint_button = _mode_button("Paint", mode_group, false)
	_erase_button = _mode_button("Erase", mode_group, true)
	toolbar.add_child(_paint_button)
	toolbar.add_child(_erase_button)
	toolbar.add_child(_label("Radius"))
	_radius = _spin(0.05, 1000.0, 0.05)
	_radius.custom_minimum_size.x = 90.0
	_radius.value_changed.connect(_radius_changed)
	toolbar.add_child(_radius)
	_clear_layer = Button.new()
	_clear_layer.text = tr("Clear Layer")
	_clear_layer.pressed.connect(_clear_pressed)
	toolbar.add_child(_clear_layer)
	toolbar.add_child(VSeparator.new())
	toolbar.add_child(_label("Collision Mask"))
	_collision_mask = _spin(1.0, 4294967295.0, 1.0)
	_collision_mask.custom_minimum_size.x = 90.0
	_collision_mask.value_changed.connect(_collision_mask_changed)
	toolbar.add_child(_collision_mask)


func _mode_button(caption: String, group: ButtonGroup, erase: bool) -> Button:
	var button := Button.new()
	button.text = tr(caption)
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(_paint_mode_pressed.bind(erase))
	return button


func _label(caption: String) -> Label:
	var label := Label.new()
	label.text = tr(caption)
	return label


func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	return spin


func _paint_mode_pressed(erase: bool) -> void:
	if not _syncing and panel != null:
		panel.set_paint_erase(erase)


func _radius_changed(value: float) -> void:
	if not _syncing and panel != null:
		panel.set_brush_radius(value)


func _collision_mask_changed(value: float) -> void:
	if not _syncing and panel != null:
		panel.set_collision_mask(int(value))


func _clear_pressed() -> void:
	if panel != null:
		panel.clear_active_paint()


func _sync_from_panel() -> void:
	if panel == null:
		return
	_sync_toolbar(
		panel.graph.collision_mask if panel.graph != null else 1,
		panel.paint_erase,
		panel.brush_radius,
		panel.get_active_paint_node() != null,
	)


func _sync_toolbar(collision_mask: int, erase: bool, radius: float, can_clear: bool) -> void:
	_syncing = true
	_paint_button.button_pressed = not erase
	_erase_button.button_pressed = erase
	_radius.value = radius
	_collision_mask.value = collision_mask
	_clear_layer.disabled = not can_clear
	_syncing = false
