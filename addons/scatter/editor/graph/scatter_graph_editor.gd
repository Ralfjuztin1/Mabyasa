@tool
class_name ScatterGraphEditor
extends GraphEdit

signal recipe_changed
signal build_requested
signal viewport_tool_changed(node_id: int, tool_id: StringName)
signal status_changed(message: String)

enum NodeMenuAction {
	ADD,
	CUT,
	COPY,
	PASTE,
	DELETE,
	DUPLICATE,
	CLEAR_COPY_BUFFER,
	TOGGLE_ENABLED,
}

enum ConnectionMenuAction {
	DISCONNECT,
}

var target: MultiMeshInstance3D
var graph: ScatterGraph
var editor_context: ScatterEditorContext
var controller := ScatterGraphController.new()
var clipboard := ScatterGraphClipboard.new()

var _undo_redo: EditorUndoRedoManager
var _add_popup: PopupMenu
var _node_popup: PopupMenu
var _connection_popup: PopupMenu
var _popup_types: Dictionary[int, StringName] = {}
var _clicked_connection: Dictionary = {}
var _menu_graph_position := Vector2.ZERO
var _menu_screen_position := Vector2.ZERO
var _pending_add_position := Vector2.INF
var _pending_moves: Dictionary = {}
var _move_commit_pending := false
var _active_viewport_node_id := 0
var _rebuilding_graph := false
var _graph_rebuild_pending := false


func _ready() -> void:
	name = "RecipeGraph"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_grid = true
	minimap_enabled = true
	minimap_size = Vector2(190, 120)
	right_disconnects = true
	_refresh_valid_connection_types()
	connection_request.connect(_connection_requested)
	disconnection_request.connect(_disconnection_requested)
	delete_nodes_request.connect(_delete_nodes_requested)
	copy_nodes_request.connect(_copy_selected_nodes.bind(false))
	cut_nodes_request.connect(_copy_selected_nodes.bind(true))
	paste_nodes_request.connect(_paste_nodes_requested)
	duplicate_nodes_request.connect(_duplicate_selected_nodes)
	popup_request.connect(_show_context_menu)
	node_selected.connect(_node_selected)
	node_deselected.connect(_node_deselected)
	_build_context_menus()
	_build_add_popup()
	ScatterExtensionRegistry.shared().changed.connect(_registry_changed)


func _refresh_valid_connection_types() -> void:
	if has_method("clear_valid_connection_types"):
		call("clear_valid_connection_types")
	for actual in ScatterValueTypeRegistry.registered_types():
		for expected in ScatterValueTypeRegistry.registered_types():
			if ScatterValueTypeRegistry.is_visual_connection_valid(actual, expected):
				add_valid_connection_type(
					ScatterValueTypeRegistry.visual_id(actual),
					ScatterValueTypeRegistry.visual_id(expected),
				)


func _registry_changed() -> void:
	_refresh_valid_connection_types()
	_build_add_popup()
	if graph != null:
		rebuild_graph()


func configure(
		p_target: MultiMeshInstance3D,
		p_graph: ScatterGraph,
		p_undo_redo: EditorUndoRedoManager,
) -> void:
	target = p_target
	graph = p_graph
	_undo_redo = p_undo_redo
	editor_context = ScatterEditorContext.new()
	editor_context.target = target
	editor_context.graph = graph
	editor_context.sync_views = sync_views
	editor_context.graph_changed = _emit_recipe_changed
	editor_context.build_requested = _emit_build_requested
	editor_context.undo = ScatterUndoService.new(
		_undo_redo,
		target if is_instance_valid(target) else graph,
		editor_context.notify_model_changed,
	)
	controller.configure(
		graph,
		target,
		_undo_redo,
		_queue_graph_rebuild,
		sync_views,
		_emit_recipe_changed,
		_emit_build_requested,
	)
	rebuild_graph(true)


func clear_target() -> void:
	_graph_rebuild_pending = false
	_set_active_viewport_view(null)
	target = null
	graph = null
	editor_context = null
	clear_connections()
	_clear_node_views()


func rebuild_graph(focus_view := false) -> void:
	# A synchronous rebuild from GraphEdit's connection signals destroys and
	# recreates the port controls while Godot is still dispatching the same
	# mouse event. Its subsequent port hot-zone check then sees an incomplete
	# layout and starts a box selection. Structural edits therefore queue their
	# visual rebuild until the input dispatch has finished.
	_graph_rebuild_pending = false
	if graph == null or editor_context == null:
		clear_target()
		return
	var previous_scroll := scroll_offset
	var previous_zoom := zoom
	var selection := selected_node_ids(false)
	# Tool scripts may be hot-reloaded on an existing GraphEdit instance; cast
	# the newly-added field because Godot initializes it as Nil in that case.
	var previous_active := int(_active_viewport_node_id)
	var previous_active_view := get_view(previous_active)
	if previous_active_view != null:
		previous_active_view.viewport_tool_deactivated()
	_active_viewport_node_id = 0
	_rebuilding_graph = true
	clear_connections()
	_clear_node_views()
	for node in graph.nodes:
		var view_script := ScatterExtensionRegistry.get_view_script(node.get_type_id())
		if view_script == null:
			continue
		var view = view_script.new()
		if not view is ScatterNodeView:
			continue
		add_child(view)
		view.bind_model(node, editor_context)
		view.dragged.connect(_node_dragged.bind(node.node_id))
	for connection in graph.connections:
		var from_view := get_view(connection.from_node_id)
		var to_view := get_view(connection.to_node_id)
		if from_view == null or to_view == null:
			continue
		var from_index := from_view.output_port_index(connection.from_port_id)
		var input_port := to_view.model.input_port(connection.to_port_id)
		var port_order := connection.order if input_port != null and input_port.variadic else 0
		var to_index := to_view.input_port_index(connection.to_port_id, port_order)
		if from_index >= 0 and to_index >= 0:
			connect_node(from_view.name, from_index, to_view.name, to_index)
	zoom = previous_zoom
	scroll_offset = previous_scroll
	for node_id in selection:
		var view := get_view(node_id)
		if view != null:
			view.selected = true
	_rebuilding_graph = false
	var restored_active := get_view(previous_active)
	if restored_active != null and restored_active.selected:
		_set_active_viewport_view(restored_active)
	elif previous_active != 0:
		viewport_tool_changed.emit(0, &"")
	if focus_view:
		focus_recipe()


func _queue_graph_rebuild() -> void:
	if _graph_rebuild_pending:
		return
	_graph_rebuild_pending = true
	_flush_graph_rebuild.call_deferred()


func _flush_graph_rebuild() -> void:
	if not _graph_rebuild_pending:
		return
	_graph_rebuild_pending = false
	rebuild_graph()


func sync_views() -> void:
	for child in get_children():
		if child is ScatterNodeView:
			child.sync_from_model()


func update_output_counts(output_counts: Dictionary) -> void:
	if editor_context == null:
		return
	editor_context.output_counts = output_counts.duplicate()
	sync_views()


func get_view(node_id: int) -> ScatterNodeView:
	return get_node_or_null(NodePath(str(node_id))) as ScatterNodeView


func selected_node_ids(deletable_only := true) -> Array[int]:
	var result: Array[int] = []
	for child in get_children():
		if not child is ScatterNodeView or not child.selected:
			continue
		if deletable_only and not child.model.is_deletable():
			continue
		result.append(child.model.node_id)
	return result


func focus_recipe() -> void:
	if graph == null or graph.nodes.is_empty():
		return
	zoom = 0.9
	var bounds := Rect2(graph.nodes[0].graph_position, Vector2.ZERO)
	for node in graph.nodes:
		bounds = bounds.expand(node.graph_position)
	scroll_offset = bounds.get_center() - size * 0.5


func focus_output() -> void:
	if graph == null:
		return
	var output := graph.final_output_node()
	if output == null:
		return
	zoom = 0.9
	scroll_offset = output.graph_position - size * 0.55


func clear_viewport_tool_selection() -> void:
	var active := get_view(int(_active_viewport_node_id))
	if active != null:
		active.selected = false
	_set_active_viewport_view(null)


func popup_add_menu(screen_position := Vector2i.ZERO) -> void:
	if graph == null:
		return
	_pending_add_position = (scroll_offset + size * 0.5) / maxf(zoom, 0.001)
	_add_popup.position = screen_position if screen_position != Vector2i.ZERO else Vector2i(get_screen_position() + size * 0.5)
	_add_popup.reset_size()
	_add_popup.popup()


func _build_add_popup() -> void:
	if _add_popup != null:
		remove_child(_add_popup)
		_add_popup.queue_free()
	_add_popup = PopupMenu.new()
	_add_popup.search_bar_enabled = true
	_add_popup.name = "AddNodeMenu"
	add_child(_add_popup)
	_popup_types.clear()
	var item_id := 1
	var categories: Array[StringName] = []
	for prototype in ScatterNodeRegistry.prototypes():
		if prototype.get_type_id() != &"final_output" and not categories.has(prototype.get_category()):
			categories.append(prototype.get_category())
	categories.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	for category in categories:
		_add_popup.add_separator(tr(String(category)))
		for prototype in ScatterNodeRegistry.prototypes():
			if prototype.get_category() != category or prototype.get_type_id() == &"final_output":
				continue
			_add_popup.add_item(tr(prototype.get_caption()), item_id)
			_add_popup.set_item_tooltip(_add_popup.item_count - 1, tr(prototype.get_description()))
			_popup_types[item_id] = prototype.get_type_id()
			item_id += 1
	_add_popup.id_pressed.connect(_add_type_selected)


func _build_context_menus() -> void:
	_node_popup = PopupMenu.new()
	_node_popup.name = "NodeOperationsMenu"
	_node_popup.add_item(tr("Add Node"), NodeMenuAction.ADD)
	_node_popup.add_separator()
	_add_shortcut_item(_node_popup, tr("Cut"), NodeMenuAction.CUT, &"ui_cut")
	_add_shortcut_item(_node_popup, tr("Copy"), NodeMenuAction.COPY, &"ui_copy")
	_add_shortcut_item(_node_popup, tr("Paste"), NodeMenuAction.PASTE, &"ui_paste")
	_add_shortcut_item(_node_popup, tr("Delete"), NodeMenuAction.DELETE, &"ui_graph_delete")
	_add_shortcut_item(_node_popup, tr("Duplicate"), NodeMenuAction.DUPLICATE, &"ui_graph_duplicate")
	_node_popup.add_item(tr("Clear Copy Buffer"), NodeMenuAction.CLEAR_COPY_BUFFER)
	_node_popup.add_separator()
	_node_popup.add_item(tr("Disable Nodes"), NodeMenuAction.TOGGLE_ENABLED)
	_node_popup.id_pressed.connect(_node_menu_action)
	add_child(_node_popup)
	_connection_popup = PopupMenu.new()
	_connection_popup.name = "ConnectionOperationsMenu"
	_connection_popup.add_item(tr("Disconnect"), ConnectionMenuAction.DISCONNECT)
	_connection_popup.id_pressed.connect(_connection_menu_action)
	add_child(_connection_popup)


func _add_shortcut_item(
		menu: PopupMenu,
		label: String,
		id: int,
		action: StringName,
) -> void:
	var shortcut := Shortcut.new()
	shortcut.resource_name = label
	shortcut.events = InputMap.action_get_events(action)
	menu.add_shortcut(shortcut, id)


func _connection_requested(
		from_name: StringName,
		from_port_index: int,
		to_name: StringName,
		to_port_index: int,
) -> void:
	var from_view := get_node_or_null(NodePath(from_name)) as ScatterNodeView
	var to_view := get_node_or_null(NodePath(to_name)) as ScatterNodeView
	if from_view == null or to_view == null:
		return
	var from_port_id := from_view.output_port_id(from_port_index)
	var to_port_id := to_view.input_port_id(to_port_index)
	var input_port := to_view.model.input_port(to_port_id)
	var order := to_port_index if input_port != null and input_port.variadic else 0
	if not controller.connect_ports(
		from_view.model.node_id,
		from_port_id,
		to_view.model.node_id,
		to_port_id,
		order,
	):
		status_changed.emit(tr("The connection is incompatible or would create a cycle."))


func _disconnection_requested(
		from_name: StringName,
		from_port_index: int,
		to_name: StringName,
		to_port_index: int,
) -> void:
	var connection := _find_connection(from_name, from_port_index, to_name, to_port_index)
	controller.disconnect_connection(connection)


func _find_connection(
		from_name: StringName,
		from_port_index: int,
		to_name: StringName,
		to_port_index: int,
) -> ScatterConnection:
	var from_view := get_node_or_null(NodePath(from_name)) as ScatterNodeView
	var to_view := get_node_or_null(NodePath(to_name)) as ScatterNodeView
	if from_view == null or to_view == null:
		return null
	var from_port_id := from_view.output_port_id(from_port_index)
	var to_port_id := to_view.input_port_id(to_port_index)
	var input_port := to_view.model.input_port(to_port_id)
	for connection in graph.connections:
		if (
			connection.from_node_id == from_view.model.node_id
			and connection.from_port_id == from_port_id
			and connection.to_node_id == to_view.model.node_id
			and connection.to_port_id == to_port_id
			and (input_port == null or not input_port.variadic or connection.order == to_port_index)
		):
			return connection
	return null


func _delete_nodes_requested(node_names: Array) -> void:
	var ids: Array[int] = []
	for node_name in node_names:
		ids.append(String(node_name).to_int())
	if ids.is_empty():
		ids = selected_node_ids(true)
	controller.delete_nodes(ids)


func _copy_selected_nodes(cut := false) -> void:
	var ids := selected_node_ids(true)
	clipboard.capture(graph, ids)
	if cut and not clipboard.is_empty():
		controller.delete_nodes(ids)
	elif not clipboard.is_empty():
		status_changed.emit(tr("Copied %d Scatter nodes.") % clipboard.nodes.size())


func _paste_nodes_requested() -> void:
	var local_position := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		local_position = size * 0.5
	controller.paste(clipboard, _graph_position_from_local(local_position))


func _duplicate_selected_nodes() -> void:
	var duplicate_buffer := ScatterGraphClipboard.new()
	duplicate_buffer.capture(graph, selected_node_ids(true))
	if not duplicate_buffer.is_empty():
		controller.paste(duplicate_buffer, duplicate_buffer.center + Vector2(24, 24))


func _node_dragged(from: Vector2, to: Vector2, node_id: int) -> void:
	if from.is_equal_approx(to):
		return
	_pending_moves[node_id] = {"from": from, "to": to}
	if not _move_commit_pending:
		_move_commit_pending = true
		_commit_node_moves.call_deferred()


func _commit_node_moves() -> void:
	_move_commit_pending = false
	var changes := _pending_moves.duplicate(true)
	_pending_moves.clear()
	controller.move_nodes(changes)


func _show_context_menu(local_position: Vector2) -> void:
	if graph == null:
		return
	_menu_graph_position = _graph_position_from_local(local_position)
	_menu_screen_position = get_screen_position() + local_position
	_clicked_connection = get_closest_connection_at_point(local_position, 8.0)
	if not _clicked_connection.is_empty():
		_connection_popup.position = Vector2i(_menu_screen_position)
		_connection_popup.reset_size()
		_connection_popup.popup()
		return
	var clicked_node := _graph_node_at(local_position)
	if clicked_node != null and not clicked_node.selected:
		for child in get_children():
			if child is ScatterNodeView:
				child.selected = false
		clicked_node.selected = true
	_configure_node_menu()
	_node_popup.position = Vector2i(_menu_screen_position)
	_node_popup.reset_size()
	_node_popup.popup()


func _graph_node_at(local_position: Vector2) -> ScatterNodeView:
	for index in range(get_child_count() - 1, -1, -1):
		var child := get_child(index)
		if child is ScatterNodeView and child.visible and child.get_rect().has_point(local_position):
			return child
	return null


func _configure_node_menu() -> void:
	var selection := selected_node_ids(true)
	var has_selection := not selection.is_empty()
	for id in [NodeMenuAction.CUT, NodeMenuAction.COPY, NodeMenuAction.DELETE, NodeMenuAction.DUPLICATE, NodeMenuAction.TOGGLE_ENABLED]:
		_set_menu_disabled(_node_popup, id, not has_selection)
	_set_menu_disabled(_node_popup, NodeMenuAction.PASTE, clipboard.is_empty())
	_set_menu_disabled(_node_popup, NodeMenuAction.CLEAR_COPY_BUFFER, clipboard.is_empty())
	var all_enabled := true
	for node_id in selection:
		var node := graph.find_node(node_id)
		if node != null and not node.enabled:
			all_enabled = false
			break
	var index := _node_popup.get_item_index(NodeMenuAction.TOGGLE_ENABLED)
	_node_popup.set_item_text(index, tr("Disable Nodes") if all_enabled else tr("Enable Nodes"))


func _set_menu_disabled(menu: PopupMenu, id: int, disabled: bool) -> void:
	var index := menu.get_item_index(id)
	if index >= 0:
		menu.set_item_disabled(index, disabled)


func _node_menu_action(id: int) -> void:
	match id:
		NodeMenuAction.ADD:
			_pending_add_position = _menu_graph_position
			_add_popup.position = Vector2i(_menu_screen_position)
			_add_popup.popup()
		NodeMenuAction.CUT:
			_copy_selected_nodes(true)
		NodeMenuAction.COPY:
			_copy_selected_nodes(false)
		NodeMenuAction.PASTE:
			controller.paste(clipboard, _menu_graph_position)
		NodeMenuAction.DELETE:
			controller.delete_nodes(selected_node_ids(true))
		NodeMenuAction.DUPLICATE:
			_duplicate_selected_nodes()
		NodeMenuAction.CLEAR_COPY_BUFFER:
			clipboard.clear()
		NodeMenuAction.TOGGLE_ENABLED:
			controller.toggle_nodes(selected_node_ids(true))


func _connection_menu_action(id: int) -> void:
	if id != ConnectionMenuAction.DISCONNECT or _clicked_connection.is_empty():
		return
	_disconnection_requested(
		_clicked_connection.get("from_node", StringName()),
		int(_clicked_connection.get("from_port", 0)),
		_clicked_connection.get("to_node", StringName()),
		int(_clicked_connection.get("to_port", 0)),
	)
	_clicked_connection.clear()


func _add_type_selected(id: int) -> void:
	if not _popup_types.has(id):
		return
	var position := _pending_add_position
	if not position.is_finite():
		position = (scroll_offset + size * 0.5) / maxf(zoom, 0.001)
	_pending_add_position = Vector2.INF
	controller.add_node(_popup_types[id], position)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		controller.delete_nodes(selected_node_ids(true))
		accept_event()


func _graph_position_from_local(local_position: Vector2) -> Vector2:
	return (scroll_offset + local_position) / maxf(zoom, 0.001)


func _clear_node_views() -> void:
	for child in get_children():
		if child is ScatterNodeView:
			remove_child(child)
			child.queue_free()


func _emit_recipe_changed() -> void:
	recipe_changed.emit()


func _emit_build_requested() -> void:
	build_requested.emit()


func _node_selected(node: Node) -> void:
	if not _rebuilding_graph and node is ScatterNodeView:
		_set_active_viewport_view(node)


func _node_deselected(node: Node) -> void:
	if not _rebuilding_graph and node is ScatterNodeView and node.model.node_id == int(_active_viewport_node_id):
		_set_active_viewport_view(null)


func _set_active_viewport_view(view: ScatterNodeView) -> void:
	var next_id := view.model.node_id if view != null else 0
	var current_id := int(_active_viewport_node_id)
	if next_id == current_id:
		return
	var previous := get_view(current_id)
	if previous != null:
		previous.viewport_tool_deactivated()
	_active_viewport_node_id = next_id
	if view != null and next_id != 0:
		view.viewport_tool_activated()
		viewport_tool_changed.emit(next_id, view.get_viewport_tool_id())
	else:
		viewport_tool_changed.emit(0, &"")
