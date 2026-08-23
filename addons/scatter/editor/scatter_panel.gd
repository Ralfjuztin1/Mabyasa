@tool
class_name ScatterPanel
extends VBoxContainer

signal build_requested
signal recipe_changed
signal target_requested(target: MultiMeshInstance3D)
signal viewport_tool_changed(tool_id: StringName, node_id: int)
signal paint_settings_changed(collision_mask: int, erase: bool, radius: float, can_clear: bool)

var target: MultiMeshInstance3D
var graph: ScatterGraph
var paint_active := false
var paint_erase := false
var brush_radius := 2.0
var active_paint_node_id := 0
var active_path_node_id := 0
var active_viewport_tool: StringName = &""

var _undo_redo: EditorUndoRedoManager
var _graph_editor: ScatterGraphEditor
var _work_area: HSplitContainer
var _sidebar: ScatterRecipeSidebar
var _toolbar: ScatterToolbar
var _status: ScatterStatusBar
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _updating := false
var _edit_sessions: Dictionary[String, ScatterRecipeEditSession] = {}
var _edit_session: ScatterRecipeEditSession
var _active_session_key := ""


func _ready() -> void:
	name = "ScatterEditor"
	set_shortcut_context(self)
	custom_minimum_size = Vector2(0, 350)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_work_area = HSplitContainer.new()
	_work_area.name = "WorkArea"
	_work_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_work_area.set_split_offsets([380])
	add_child(_work_area)
	
	_sidebar = ScatterRecipeSidebar.new()
	_work_area.add_child(_sidebar)
	_sidebar.recipe_selected.connect(_sidebar_recipe_selected)

	var view := VBoxContainer.new()
	_work_area.add_child(view)
	
	_toolbar = ScatterToolbar.new()
	view.add_child(_toolbar)
	_connect_toolbar()
	_graph_editor = ScatterGraphEditor.new()
	_graph_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_child(_graph_editor)
	_graph_editor.recipe_changed.connect(_on_recipe_changed)
	_graph_editor.build_requested.connect(func(): build_requested.emit())
	_graph_editor.viewport_tool_changed.connect(_viewport_selection_changed)
	_graph_editor.status_changed.connect(update_status)
	_status = ScatterStatusBar.new()
	view.add_child(_status)
	_status.show_message(tr("Select a MultiMeshInstance3D to edit its Scatter graph."))
	_build_file_dialogs()
	if is_instance_valid(target):
		_bind_target()


func _shortcut_input(event: InputEvent) -> void:
	if not _is_recipe_save_shortcut(event) or not _has_editor_keyboard_focus():
		return
	if graph == null or _edit_session == null:
		return
	_save_recipe()
	get_viewport().set_input_as_handled()


func _is_recipe_save_shortcut(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_S
		and event.is_command_or_control_pressed()
		and not event.shift_pressed
		and not event.alt_pressed
	)


func _has_editor_keyboard_focus() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	return focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner))


func set_undo_redo(value: EditorUndoRedoManager) -> void:
	_undo_redo = value


func set_target(value: MultiMeshInstance3D) -> void:
	if target == value and graph != null:
		return
	stop_painting()
	if is_node_ready() and _graph_editor != null:
		_graph_editor.clear_target()
	target = value
	graph = null
	_edit_session = null
	if not is_node_ready():
		return
	_bind_target()


func _bind_target() -> void:
	_updating = true
	if not is_instance_valid(target):
		graph = null
		_edit_session = null
		_graph_editor.clear_target()
		_status.set_title(tr("Scatter"))
		_toolbar.set_editor_enabled(false)
		_toolbar.set_recipe_dirty(false)
		_active_session_key = ""
		_refresh_sidebar()
		update_status(tr("Select a MultiMeshInstance3D to edit its Scatter graph."))
		_updating = false
		return
	_status.set_title(tr("%s") % target.name)
	var attached_graph := ScatterGraphAttachment.get_graph(target)
	if attached_graph == null:
		graph = null
		_edit_session = null
		_graph_editor.clear_target()
		_toolbar.set_editor_enabled(false)
		_toolbar.set_recipe_dirty(false)
		_active_session_key = ""
		_refresh_sidebar()
		update_status(tr("Configure or load a Scatter recipe from the Inspector."))
		_updating = false
		return
	var recipe_path := attached_graph.resource_path
	_prune_edit_sessions()
	var session_key := _edit_session_key(target, recipe_path)
	_edit_session = _edit_sessions.get(session_key)
	if _edit_session == null:
		_edit_session = ScatterRecipeEditSession.create(attached_graph, target, _edit_context_for(target))
		if _edit_session == null:
			_graph_editor.clear_target()
			_toolbar.set_editor_enabled(false)
			update_status(tr("Could not create a recipe editing session."))
			_updating = false
			return
		_edit_sessions[session_key] = _edit_session
	else:
		_edit_session.bind_owner(target, _edit_context_for(target))
	_active_session_key = session_key
	graph = _edit_session.working_graph
	_graph_editor.configure(target, graph, _undo_redo)
	_toolbar.set_editor_enabled(true)
	_toolbar.set_recipe_dirty(_edit_session.dirty)
	_refresh_sidebar()
	_sync_toolbar()
	update_status()
	_updating = false


func _connect_toolbar() -> void:
	_toolbar.add_requested.connect(func(): _graph_editor.popup_add_menu())
	_toolbar.focus_requested.connect(func(): _graph_editor.focus_recipe())
	_toolbar.output_requested.connect(func(): _graph_editor.focus_output())
	_toolbar.save_requested.connect(_save_recipe)
	_toolbar.load_requested.connect(_load_recipe)
	_toolbar.build_requested.connect(func(): build_requested.emit())
	_toolbar.seed_changed.connect(_seed_changed)
	_toolbar.reroll_requested.connect(_reroll)
	_toolbar.auto_build_changed.connect(_auto_rebuild_changed)


func _build_file_dialogs() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.filters = PackedStringArray(["*.tres ; Scatter Recipe"])
	_save_dialog.file_selected.connect(_recipe_file_selected)
	add_child(_save_dialog)
	_load_dialog = FileDialog.new()
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = FileDialog.ACCESS_RESOURCES
	_load_dialog.filters = PackedStringArray(["*.tres ; Scatter Recipe"])
	_load_dialog.file_selected.connect(_load_recipe_file)
	add_child(_load_dialog)


func _sync_toolbar() -> void:
	if graph == null:
		return
	_toolbar.sync_graph(graph.seed, graph.auto_rebuild)
	_update_paint_ui()


func _commit_graph_property(property: StringName, value: Variant, caption: String, merge := UndoRedo.MERGE_DISABLE) -> void:
	if graph == null or graph.get(property) == value:
		return
	var undo := ScatterUndoService.new(_undo_redo, target, _graph_property_changed)
	undo.commit_property(graph, property, value, caption, "", merge)


func _seed_changed(value: float) -> void:
	if not _updating:
		_commit_graph_property(&"seed", int(value), tr("Scatter Seed"), UndoRedo.MERGE_ENDS)


func _reroll() -> void:
	if graph != null:
		_commit_graph_property(&"seed", randi_range(-2147483648, 2147483647), tr("Reroll Scatter Seed"))


func _auto_rebuild_changed(value: bool) -> void:
	if not _updating:
		_commit_graph_property(&"auto_rebuild", value, tr("Auto Build"))


func _collision_mask_changed(value: float) -> void:
	if not _updating:
		_commit_graph_property(&"collision_mask", int(value), tr("Collision Mask"), UndoRedo.MERGE_ENDS)


func _graph_property_changed() -> void:
	_sync_toolbar()
	_on_recipe_changed()
	if graph != null and graph.auto_rebuild:
		build_requested.emit()


func _viewport_selection_changed(node_id: int, tool_id: StringName) -> void:
	active_viewport_tool = tool_id
	active_paint_node_id = node_id if tool_id == &"paint" else 0
	active_path_node_id = node_id if tool_id == &"path" else 0
	paint_active = tool_id == &"paint"
	_update_paint_ui()
	viewport_tool_changed.emit(tool_id, node_id)


func get_active_paint_node() -> ScatterPaintRegionNode:
	if graph == null:
		return null
	return graph.find_node(active_paint_node_id) as ScatterPaintRegionNode


func get_active_path_node() -> ScatterPathNode:
	if graph == null:
		return null
	return graph.find_node(active_path_node_id) as ScatterPathNode


func set_paint_erase(active: bool) -> void:
	paint_erase = active
	_update_paint_ui()


func set_brush_radius(value: float) -> void:
	brush_radius = clampf(value, 0.05, 1000.0)
	_update_paint_ui()


func set_collision_mask(value: int) -> void:
	_collision_mask_changed(value)


func clear_active_paint() -> void:
	_clear_active_paint()


func stop_painting() -> void:
	if not paint_active:
		return
	paint_active = false
	_update_paint_ui()


func stop_viewport_editing() -> void:
	if _graph_editor != null:
		_graph_editor.clear_viewport_tool_selection()


func _clear_active_paint() -> void:
	var paint_node := get_active_paint_node()
	if paint_node == null or paint_node.strokes.is_empty():
		return
	var empty: Array[ScatterPaintStroke] = []
	var undo := ScatterUndoService.new(_undo_redo, target, _paint_data_changed)
	undo.commit_property(paint_node, &"strokes", empty, tr("Clear Paint Layer"))


func _paint_data_changed() -> void:
	if graph != null:
		graph.emit_changed()
	_graph_editor.sync_views()
	_on_recipe_changed()
	if graph != null and graph.auto_rebuild:
		build_requested.emit()
	if is_instance_valid(target):
		target.update_gizmos()


func _path_data_changed() -> void:
	if graph != null:
		graph.emit_changed()
	_graph_editor.sync_views()
	_on_recipe_changed()
	if graph != null and graph.auto_rebuild:
		build_requested.emit()
	if is_instance_valid(target):
		target.update_gizmos()


func _update_paint_ui() -> void:
	paint_settings_changed.emit(
		graph.collision_mask if graph != null else 1,
		paint_erase,
		brush_radius,
		get_active_paint_node() != null,
	)


func _save_recipe() -> void:
	if graph == null or _edit_session == null:
		return
	var error := _edit_session.save()
	if error == OK and is_instance_valid(target):
		ScatterGraphAttachment.attach(target, _edit_session.source_graph)
		_toolbar.set_recipe_dirty(false)
	_refresh_sidebar()
	update_status(
		tr("Recipe saved to %s") % _edit_session.recipe_path
		if error == OK
		else tr("Could not save recipe: %s") % error_string(error)
	)


func _recipe_file_selected(path: String) -> void:
	var created := ScatterRecipeIO.create_recipe_from_target(target, path)
	if created == null:
		update_status(tr("Could not create recipe: %s") % path)
		return
	_link_recipe_with_undo(created, tr("Configure Scatter"))


func configure_recipe() -> void:
	if not is_instance_valid(target):
		return
	_save_dialog.current_file = "%s_scatter.tres" % target.name.to_snake_case()
	_save_dialog.popup_centered_ratio(0.65)


func load_recipe() -> void:
	if is_instance_valid(target):
		_load_dialog.popup_centered_ratio(0.65)


func _load_recipe() -> void:
	load_recipe()


func _load_recipe_file(path: String) -> void:
	var loaded := ScatterRecipeIO.load_graph(path)
	if loaded == null:
		update_status(tr("The selected resource is not a ScatterGraph."))
		return
	_link_recipe_with_undo(loaded, tr("Load Scatter Recipe"))


func _link_recipe_with_undo(value: ScatterGraph, caption: String) -> void:
	if value == null or not is_instance_valid(target):
		return
	var previous := ScatterGraphAttachment.get_graph(target)
	if _undo_redo == null:
		_set_graph_on_target(target, value)
		return
	_undo_redo.create_action(caption, UndoRedo.MERGE_DISABLE, target)
	_undo_redo.add_do_method(self, "_set_graph_on_target", target, value)
	_undo_redo.add_undo_method(self, "_set_graph_on_target", target, previous)
	_undo_redo.commit_action()


func _set_graph_on_target(owner: MultiMeshInstance3D, value: ScatterGraph) -> void:
	if not is_instance_valid(owner):
		return
	if value == null:
		ScatterGraphAttachment.detach(owner)
		if target == owner:
			_bind_target()
		return
	if not ScatterGraphAttachment.attach(owner, value):
		update_status(tr("Could not link the selected Scatter recipe."))
		return
	if target == owner:
		graph = null
		_edit_session = null
		_bind_target()
		recipe_changed.emit()


func _on_recipe_changed() -> void:
	if _edit_session != null:
		_edit_session.mark_dirty()
		_toolbar.set_recipe_dirty(true)
	_refresh_sidebar()
	recipe_changed.emit()
	if is_instance_valid(target):
		target.update_gizmos()


func update_output_counts(output_counts: Dictionary) -> void:
	if _graph_editor != null:
		_graph_editor.update_output_counts(output_counts)
	update_status()


func get_graph_for_build(owner: MultiMeshInstance3D) -> ScatterGraph:
	if owner == target and graph != null:
		return graph
	var attached := ScatterGraphAttachment.get_graph(owner)
	if attached == null:
		return null
	_prune_edit_sessions()
	var session_key := _edit_session_key(owner, attached.resource_path)
	var session: ScatterRecipeEditSession = _edit_sessions.get(session_key)
	return session.working_graph if session != null else attached


func _edit_session_key(owner: MultiMeshInstance3D, recipe_path: String) -> String:
	var context := _edit_context_for(owner)
	var context_id := context.get_instance_id() if is_instance_valid(context) else 0
	return "%d::%s" % [context_id, recipe_path]


func _edit_context_for(owner: MultiMeshInstance3D) -> Node:
	if not is_instance_valid(owner):
		return null
	var context: Node = owner
	while is_instance_valid(context.owner):
		context = context.owner
	return context


func _prune_edit_sessions() -> void:
	for key in _edit_sessions.keys():
		var session := _edit_sessions.get(key) as ScatterRecipeEditSession
		if session == null or not session.has_valid_context():
			_edit_sessions.erase(key)
			if key == _active_session_key:
				_active_session_key = ""


func close_scene_sessions(scene_path: String) -> bool:
	var active_closed := false
	for key in _edit_sessions.keys():
		var session := _edit_sessions.get(key) as ScatterRecipeEditSession
		if session != null and session.belongs_to_scene(scene_path):
			active_closed = active_closed or key == _active_session_key
			_edit_sessions.erase(key)
	if active_closed:
		stop_viewport_editing()
		target = null
		graph = null
		_edit_session = null
		_active_session_key = ""
		_graph_editor.clear_target()
		_toolbar.set_editor_enabled(false)
		_toolbar.set_recipe_dirty(false)
		_status.set_title(tr("Scatter"))
		update_status(tr("Select a MultiMeshInstance3D to edit its Scatter graph."))
	_refresh_sidebar()
	return active_closed


func _refresh_sidebar() -> void:
	if _sidebar != null:
		_sidebar.sync_sessions(_edit_sessions, _active_session_key)


func _sidebar_recipe_selected(session_key: String) -> void:
	var session := _edit_sessions.get(session_key) as ScatterRecipeEditSession
	if session == null:
		return
	var owner := session.get_target()
	if not is_instance_valid(owner):
		_edit_sessions.erase(session_key)
		_refresh_sidebar()
		return
	target_requested.emit(owner)


func update_status(message := "") -> void:
	if _status == null:
		return
	if message != "":
		_status.show_message(message)
		return
	var count := 0
	if is_instance_valid(target) and target.multimesh != null:
		count = target.multimesh.instance_count
	_status.show_instance_count(count)
