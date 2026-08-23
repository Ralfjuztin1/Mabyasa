@tool
class_name ScatterConnectionService
extends RefCounted


static func plan_connect(
		graph,
		from_node_id: int,
		from_port_id: StringName,
		to_node_id: int,
		to_port_id: StringName,
		order := -1,
) -> Dictionary:
	var plan: Dictionary = _empty_plan()
	var source: Variant = graph.find_node(from_node_id) if graph != null else null
	var target: Variant = graph.find_node(to_node_id) if graph != null else null
	if source == null or target == null or graph.would_create_cycle(from_node_id, to_node_id):
		return plan
	var output: Variant = source.output_port(from_port_id)
	var input: Variant = target.input_port(to_port_id)
	if output == null or input == null or not output.connectable or not input.connectable:
		return plan

	var overrides: Dictionary[int, StringName] = {}
	var dynamic_ports: Dictionary[int, Dictionary] = {}
	var source_dynamic: bool = source.is_dynamic_port_type(from_port_id, true)
	var target_dynamic: bool = target.is_dynamic_port_type(to_port_id, false)
	if source_dynamic:
		dynamic_ports[source.node_id] = {"node": source, "port": from_port_id, "is_output": true}
	if target_dynamic:
		dynamic_ports[target.node_id] = {"node": target, "port": to_port_id, "is_output": false}

	var output_type: StringName = output.type_id
	var input_type: StringName = input.type_id
	# The source owns the actual value type. When both ends are adaptive, keep a
	# concrete source type and let the target input adopt it. An unbound source
	# can instead adopt a concrete target constraint.
	if source_dynamic and (not target_dynamic or output_type == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY):
		var proposed_source: StringName = source.propose_dynamic_port_type(from_port_id, true, input_type)
		if not proposed_source.is_empty():
			overrides[source.node_id] = proposed_source
			output_type = proposed_source
	if target_dynamic:
		var proposed_target: StringName = target.propose_dynamic_port_type(to_port_id, false, output_type)
		if not proposed_target.is_empty():
			overrides[target.node_id] = proposed_target
			input_type = proposed_target
	if source_dynamic and output_type == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY and input_type != ScatterValueTypeRegistry.DYNAMIC_GEOMETRY:
		var rebound_source: StringName = source.propose_dynamic_port_type(from_port_id, true, input_type)
		if not rebound_source.is_empty():
			overrides[source.node_id] = rebound_source
			output_type = rebound_source
	if (
		output_type == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY
		or input_type == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY
		or not ScatterValueTypeRegistry.is_assignable(output_type, input_type)
	):
		return plan

	var removed: Array[ScatterConnection] = []
	if input.variadic:
		if order < 0:
			order = graph.incoming_connections(to_node_id, to_port_id).size()
	else:
		order = 0
		for previous in graph.incoming_connections(to_node_id, to_port_id):
			_append_unique(removed, previous)
	var added: ScatterConnection = ScatterConnection.create(from_node_id, from_port_id, to_node_id, to_port_id, maxi(order, 0))
	for current in graph.connections:
		if removed.has(current):
			continue
		if not overrides.has(current.from_node_id) and not overrides.has(current.to_node_id):
			continue
		if not _connection_is_valid(graph, current, overrides):
			_append_unique(removed, current)

	var future: Array[ScatterConnection] = _future_connections(graph, removed, added)
	_infer_dynamic_neighbors(graph, removed, future, overrides, dynamic_ports)
	plan.accepted = true
	plan.added = added
	plan.removed = removed
	plan.type_changes = _type_changes(overrides, dynamic_ports)
	return plan


static func plan_disconnect(graph, connection: ScatterConnection) -> Dictionary:
	var plan: Dictionary = _empty_plan()
	if graph == null or connection == null or not graph.has_connection(connection):
		return plan
	var removed: Array[ScatterConnection] = [connection]
	var future: Array[ScatterConnection] = _future_connections(graph, removed, null)
	var overrides: Dictionary[int, StringName] = {}
	var dynamic_ports: Dictionary[int, Dictionary] = {}
	for endpoint in [
		{"node_id": connection.from_node_id, "port": connection.from_port_id, "is_output": true},
		{"node_id": connection.to_node_id, "port": connection.to_port_id, "is_output": false},
	]:
		var node: Variant = graph.find_node(endpoint.node_id)
		if node == null or not node.is_dynamic_port_type(endpoint.port, endpoint.is_output):
			continue
		dynamic_ports[node.node_id] = {"node": node, "port": endpoint.port, "is_output": endpoint.is_output}
		overrides[node.node_id] = node.infer_dynamic_port_type(graph, future)
	plan.accepted = true
	plan.removed = removed
	plan.type_changes = _type_changes(overrides, dynamic_ports)
	return plan


static func apply(graph, plan: Dictionary) -> void:
	if graph == null or not bool(plan.get("accepted", false)):
		return
	for connection in plan.get("removed", []):
		graph.remove_connection(connection)
	for change in plan.get("type_changes", []):
		change.node.set_dynamic_port_type(change.after)
	var added: ScatterConnection = plan.get("added")
	if added != null:
		graph.add_connection(added)


static func _connection_is_valid(
		graph,
		connection: ScatterConnection,
		overrides: Dictionary[int, StringName],
) -> bool:
	var source: Variant = graph.find_node(connection.from_node_id)
	var target: Variant = graph.find_node(connection.to_node_id)
	if source == null or target == null:
		return false
	var output: Variant = source.output_port(connection.from_port_id)
	var input: Variant = target.input_port(connection.to_port_id)
	if output == null or input == null:
		return false
	var actual: StringName = overrides.get(source.node_id, output.type_id)
	var expected: StringName = overrides.get(target.node_id, input.type_id)
	return ScatterValueTypeRegistry.is_assignable(actual, expected)


static func _infer_dynamic_neighbors(
		graph,
		removed: Array[ScatterConnection],
		future: Array[ScatterConnection],
		overrides: Dictionary[int, StringName],
		dynamic_ports: Dictionary[int, Dictionary],
) -> void:
	for connection in removed:
		for endpoint in [
			{"node_id": connection.from_node_id, "port": connection.from_port_id, "is_output": true},
			{"node_id": connection.to_node_id, "port": connection.to_port_id, "is_output": false},
		]:
			if overrides.has(endpoint.node_id):
				continue
			var node: Variant = graph.find_node(endpoint.node_id)
			if node == null or not node.is_dynamic_port_type(endpoint.port, endpoint.is_output):
				continue
			dynamic_ports[node.node_id] = {"node": node, "port": endpoint.port, "is_output": endpoint.is_output}
			overrides[node.node_id] = node.infer_dynamic_port_type(graph, future)


static func _type_changes(
		overrides: Dictionary[int, StringName],
		dynamic_ports: Dictionary[int, Dictionary],
) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for node_id in overrides:
		if not dynamic_ports.has(node_id):
			continue
		var info: Dictionary = dynamic_ports[node_id]
		var node: Variant = info.node
		var before: StringName = node.get_dynamic_port_type(info.port, info.is_output)
		var after: StringName = overrides[node_id]
		if before != after:
			changes.append({"node": node, "before": before, "after": after})
	return changes


static func _future_connections(
		graph,
		removed: Array[ScatterConnection],
		added: ScatterConnection,
) -> Array[ScatterConnection]:
	var result: Array[ScatterConnection] = []
	for connection in graph.connections:
		if not removed.has(connection):
			result.append(connection)
	if added != null:
		result.append(added)
	return result


static func _append_unique(values: Array[ScatterConnection], connection: ScatterConnection) -> void:
	if connection != null and not values.has(connection):
		values.append(connection)


static func _empty_plan() -> Dictionary:
	return {
		"accepted": false,
		"added": null,
		"removed": [] as Array[ScatterConnection],
		"type_changes": [] as Array[Dictionary],
	}
