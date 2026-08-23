@tool
class_name ScatterGraphController
extends RefCounted

const ConnectionService := preload("res://addons/scatter/core/services/scatter_connection_service.gd")

var graph: ScatterGraph
var target: MultiMeshInstance3D
var undo_redo: EditorUndoRedoManager
var refresh_graph: Callable
var sync_views: Callable
var graph_changed: Callable
var build_requested: Callable


func configure(
		p_graph: ScatterGraph,
		p_target: MultiMeshInstance3D,
		p_undo_redo: EditorUndoRedoManager,
		p_refresh_graph: Callable,
		p_sync_views: Callable,
		p_graph_changed: Callable,
		p_build_requested: Callable,
) -> void:
	graph = p_graph
	target = p_target
	undo_redo = p_undo_redo
	refresh_graph = p_refresh_graph
	sync_views = p_sync_views
	graph_changed = p_graph_changed
	build_requested = p_build_requested


func add_node(type_id: StringName, position: Vector2) -> ScatterNode:
	var node := ScatterNodeRegistry.create_node(type_id)
	if node == null:
		return null
	node.node_id = graph.allocate_node_id()
	node.graph_position = position
	_commit_restore_action(tr("Add Scatter Node"), [node], [])
	return node


func delete_nodes(node_ids: Array[int]) -> void:
	var deletable: Array[int] = []
	var removed_nodes: Array[ScatterNode] = []
	for node_id in node_ids:
		var node := graph.find_node(node_id)
		if node != null and node.is_deletable() and not deletable.has(node_id):
			deletable.append(node_id)
			removed_nodes.append(node)
	if deletable.is_empty():
		return
	var removed_connections := graph.connections_for_nodes(deletable)
	if undo_redo == null:
		graph.remove_nodes(deletable)
		_notify_structure_changed()
		return
	undo_redo.create_action(tr("Delete Scatter Nodes"), UndoRedo.MERGE_DISABLE, target)
	undo_redo.add_do_method(graph, "remove_nodes", deletable)
	undo_redo.add_undo_method(graph, "add_existing_nodes", removed_nodes, removed_connections)
	_add_structure_callbacks()
	undo_redo.commit_action()


func connect_ports(
		from_node_id: int,
		from_port_id: StringName,
		to_node_id: int,
		to_port_id: StringName,
		order := -1,
) -> bool:
	var plan: Dictionary = ConnectionService.plan_connect(
		graph,
		from_node_id,
		from_port_id,
		to_node_id,
		to_port_id,
		order,
	)
	if not bool(plan.accepted):
		return false
	if undo_redo == null:
		ConnectionService.apply(graph, plan)
		_notify_structure_changed()
		return true
	undo_redo.create_action(tr("Connect Scatter Nodes"), UndoRedo.MERGE_DISABLE, target)
	for previous in plan.removed:
		undo_redo.add_do_method(graph, "remove_connection", previous)
		undo_redo.add_undo_method(graph, "add_connection", previous)
	for change in plan.type_changes:
		undo_redo.add_do_method(change.node, "set_dynamic_port_type", change.after)
		undo_redo.add_undo_method(change.node, "set_dynamic_port_type", change.before)
	undo_redo.add_do_method(graph, "add_connection", plan.added)
	undo_redo.add_undo_method(graph, "remove_connection", plan.added)
	_add_structure_callbacks()
	undo_redo.commit_action()
	return true


func disconnect_connection(connection: ScatterConnection) -> void:
	var plan: Dictionary = ConnectionService.plan_disconnect(graph, connection)
	if not bool(plan.accepted):
		return
	if undo_redo == null:
		ConnectionService.apply(graph, plan)
		_notify_structure_changed()
		return
	undo_redo.create_action(tr("Disconnect Scatter Nodes"), UndoRedo.MERGE_DISABLE, target)
	undo_redo.add_do_method(graph, "remove_connection", connection)
	undo_redo.add_undo_method(graph, "add_connection", connection)
	for change in plan.type_changes:
		undo_redo.add_do_method(change.node, "set_dynamic_port_type", change.after)
		undo_redo.add_undo_method(change.node, "set_dynamic_port_type", change.before)
	_add_structure_callbacks()
	undo_redo.commit_action()


func move_nodes(changes: Dictionary) -> void:
	if changes.is_empty():
		return
	if undo_redo == null:
		for node_id in changes:
			var node := graph.find_node(int(node_id))
			if node != null:
				node.graph_position = changes[node_id].to
		_notify_layout_changed()
		return
	undo_redo.create_action(tr("Move Scatter Nodes"), UndoRedo.MERGE_ENDS, target)
	for node_id in changes:
		var node := graph.find_node(int(node_id))
		if node == null:
			continue
		undo_redo.add_do_property(node, &"graph_position", changes[node_id].to)
		undo_redo.add_undo_property(node, &"graph_position", changes[node_id].from)
	undo_redo.add_do_method(self, "_notify_layout_changed")
	undo_redo.add_undo_method(self, "_notify_layout_changed")
	# GraphNode already moved visually, but the model has not. Execute the do
	# properties now so model and view stay in the same UndoRedo transaction.
	undo_redo.commit_action()


func toggle_nodes(node_ids: Array[int]) -> void:
	var nodes: Array[ScatterNode] = []
	var enable := false
	for node_id in node_ids:
		var node := graph.find_node(node_id)
		if node != null and node.can_disable():
			nodes.append(node)
			if not node.enabled:
				enable = true
	if nodes.is_empty():
		return
	if undo_redo == null:
		for node in nodes:
			node.enabled = enable
		_notify_model_changed()
		return
	undo_redo.create_action(
		tr("Enable Scatter Nodes") if enable else tr("Disable Scatter Nodes"),
		UndoRedo.MERGE_DISABLE,
		target,
	)
	for node in nodes:
		undo_redo.add_do_property(node, &"enabled", enable)
		undo_redo.add_undo_property(node, &"enabled", node.enabled)
	undo_redo.add_do_method(self, "_notify_model_changed")
	undo_redo.add_undo_method(self, "_notify_model_changed")
	undo_redo.commit_action()


func paste(clipboard: ScatterGraphClipboard, position: Vector2) -> Array[int]:
	if clipboard == null or clipboard.is_empty():
		return []
	var payload := clipboard.instantiate(graph, position)
	var created_nodes: Array = payload.nodes
	var created_connections: Array = payload.connections
	_commit_restore_action(tr("Paste Scatter Nodes"), created_nodes, created_connections)
	var result: Array[int] = []
	for node in created_nodes:
		result.append(node.node_id)
	return result


func _commit_restore_action(
		action_name: String,
		nodes: Array,
		connections: Array,
) -> void:
	var ids: Array[int] = []
	for node in nodes:
		ids.append(node.node_id)
	if undo_redo == null:
		graph.add_existing_nodes(nodes, connections)
		_notify_structure_changed()
		return
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, target)
	undo_redo.add_do_method(graph, "add_existing_nodes", nodes, connections)
	undo_redo.add_undo_method(graph, "remove_nodes", ids)
	_add_structure_callbacks()
	undo_redo.commit_action()


func _add_structure_callbacks() -> void:
	undo_redo.add_do_method(self, "_notify_structure_changed")
	undo_redo.add_undo_method(self, "_notify_structure_changed")


func _notify_structure_changed() -> void:
	if refresh_graph.is_valid():
		refresh_graph.call()
	_notify_common()


func _notify_model_changed() -> void:
	graph.emit_changed()
	if sync_views.is_valid():
		sync_views.call()
	_notify_common()


func _notify_layout_changed() -> void:
	graph.emit_changed()
	if sync_views.is_valid():
		sync_views.call()
	if graph_changed.is_valid():
		graph_changed.call()


func _notify_common() -> void:
	if graph_changed.is_valid():
		graph_changed.call()
	if graph.auto_rebuild and build_requested.is_valid():
		build_requested.call()
