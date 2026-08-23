@tool
class_name ScatterGraph
extends Resource

const ConnectionService := preload("res://addons/scatter/core/services/scatter_connection_service.gd")

@export var seed := 0
@export var auto_rebuild := true
@export_flags_3d_physics var collision_mask := 1
@export var nodes: Array[ScatterNode] = []
@export var connections: Array[ScatterConnection] = []
@export var next_node_id := 1


func allocate_node_id() -> int:
	var result := next_node_id
	next_node_id += 1
	return result


func add_node(node: ScatterNode, position := Vector2.ZERO) -> ScatterNode:
	if node == null:
		return null
	if node.node_id <= 0:
		node.node_id = allocate_node_id()
	else:
		next_node_id = maxi(next_node_id, node.node_id + 1)
	node.graph_position = position
	if not nodes.has(node):
		nodes.append(node)
	emit_changed()
	return node


func add_existing_nodes(restored_nodes: Array, restored_connections: Array) -> void:
	for value in restored_nodes:
		if value is ScatterNode and find_node(value.node_id) == null:
			nodes.append(value)
			next_node_id = maxi(next_node_id, value.node_id + 1)
	for value in restored_connections:
		if value is ScatterConnection and not has_connection(value):
			connections.append(value)
	normalize_connection_orders()
	emit_changed()


func find_node(node_id: int) -> ScatterNode:
	for node in nodes:
		if node.node_id == node_id:
			return node
	return null


func find_first(type_id: StringName) -> ScatterNode:
	for node in nodes:
		if node.get_type_id() == type_id:
			return node
	return null


func final_output_node() -> ScatterNode:
	return find_first(&"final_output")


func nodes_of_type(type_id: StringName) -> Array[ScatterNode]:
	var result: Array[ScatterNode] = []
	for node in nodes:
		if node.get_type_id() == type_id:
			result.append(node)
	return result


func remove_node(node_id: int) -> void:
	remove_nodes([node_id])


func remove_nodes(node_ids: Array) -> void:
	for index in range(nodes.size() - 1, -1, -1):
		if node_ids.has(nodes[index].node_id):
			nodes.remove_at(index)
	for index in range(connections.size() - 1, -1, -1):
		var connection := connections[index]
		if node_ids.has(connection.from_node_id) or node_ids.has(connection.to_node_id):
			connections.remove_at(index)
	normalize_connection_orders()
	emit_changed()


func connections_for_nodes(node_ids: Array) -> Array[ScatterConnection]:
	var result: Array[ScatterConnection] = []
	for connection in connections:
		if node_ids.has(connection.from_node_id) or node_ids.has(connection.to_node_id):
			result.append(connection)
	return result


func connect_nodes(
		from_node_id: int,
		from_port_id: StringName,
		to_node_id: int,
		to_port_id: StringName,
		order := -1,
) -> ScatterConnection:
	var plan: Dictionary = ConnectionService.plan_connect(
		self,
		from_node_id,
		from_port_id,
		to_node_id,
		to_port_id,
		order,
	)
	if not bool(plan.accepted):
		return null
	ConnectionService.apply(self, plan)
	return plan.added


func add_connection(connection: ScatterConnection) -> void:
	if connection == null or has_connection(connection):
		return
	connections.append(connection)
	normalize_connection_orders()
	emit_changed()


func remove_connection(connection: ScatterConnection) -> void:
	if connection == null:
		return
	for index in range(connections.size() - 1, -1, -1):
		if connections[index] == connection or connections[index].matches(connection):
			connections.remove_at(index)
	normalize_connection_orders()
	emit_changed()


func disconnect_nodes(
		from_node_id: int,
		from_port_id: StringName,
		to_node_id: int,
		to_port_id: StringName,
		order := -1,
) -> ScatterConnection:
	for index in range(connections.size() - 1, -1, -1):
		var connection := connections[index]
		if (
			connection.from_node_id == from_node_id
			and connection.from_port_id == from_port_id
			and connection.to_node_id == to_node_id
			and connection.to_port_id == to_port_id
			and (order < 0 or connection.order == order)
		):
			var plan: Dictionary = ConnectionService.plan_disconnect(self, connection)
			ConnectionService.apply(self, plan)
			return connection
	return null


func has_connection(candidate: ScatterConnection) -> bool:
	for connection in connections:
		if connection == candidate or connection.matches(candidate):
			return true
	return false


func incoming_connections(node_id: int, port_id: StringName) -> Array[ScatterConnection]:
	var result: Array[ScatterConnection] = []
	for connection in connections:
		if connection.to_node_id == node_id and connection.to_port_id == port_id:
			result.append(connection)
	result.sort_custom(func(a: ScatterConnection, b: ScatterConnection) -> bool:
		return a.order < b.order
	)
	return result


func outgoing_connections(node_id: int, port_id: StringName = &"") -> Array[ScatterConnection]:
	var result: Array[ScatterConnection] = []
	for connection in connections:
		if connection.from_node_id == node_id and (port_id.is_empty() or connection.from_port_id == port_id):
			result.append(connection)
	return result


func would_create_cycle(from_node_id: int, to_node_id: int) -> bool:
	if from_node_id == to_node_id:
		return true
	var pending: Array[int] = [to_node_id]
	var visited: Dictionary[int, bool] = {}
	while not pending.is_empty():
		var current := pending.pop_back()
		if current == from_node_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for connection in outgoing_connections(current):
			pending.append(connection.to_node_id)
	return false


func duplicate_graph() -> ScatterGraph:
	var result := duplicate(true) as ScatterGraph
	if result != null:
		result.normalize_connection_orders()
	return result


func normalize_connection_orders() -> void:
	var groups: Dictionary = {}
	for connection in connections:
		var target := find_node(connection.to_node_id)
		var port := target.input_port(connection.to_port_id) if target != null else null
		if port != null and not port.variadic:
			connection.order = 0
			continue
		var key := "%d:%s" % [connection.to_node_id, connection.to_port_id]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(connection)
	for values in groups.values():
		var group: Array = values
		group.sort_custom(func(a: ScatterConnection, b: ScatterConnection) -> bool:
			return a.order < b.order
		)
		for index in group.size():
			group[index].order = index
