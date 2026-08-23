@tool
class_name ScatterGraphCompiler
extends RefCounted


static func compile(graph: ScatterGraph) -> ScatterExecutionPlan:
	var plan := ScatterExecutionPlan.new()
	plan.graph = graph
	if graph == null:
		_add_error(plan, &"graph_missing", -1, "Scatter graph is missing.")
		return plan
	var outputs := graph.nodes_of_type(&"final_output")
	if outputs.size() != 1:
		_add_error(plan, &"final_output_count", -1, "Scatter graph must contain exactly one Final Output node.", {"count": outputs.size()})
		return plan
	plan.final_node_id = outputs[0].node_id
	var node_ids: Dictionary = {}
	for node in graph.nodes:
		if node_ids.has(node.node_id):
			_add_error(plan, &"duplicate_node_id", node.node_id, "Scatter graph contains a duplicate node ID.")
		node_ids[node.node_id] = true
	for connection in graph.connections:
		_validate_connection(graph, connection, plan)
	for node in graph.nodes:
		for port in node.get_input_ports():
			if not port.variadic:
				continue
			var incoming := graph.incoming_connections(node.node_id, port.id)
			for index in incoming.size():
				if incoming[index].order != index:
					_add_error(plan, &"invalid_variadic_order", node.node_id, "Variadic connection order must be contiguous and unique.", {"port": port.id})
					break
	if plan.has_errors():
		return plan
	var cycle_visiting: Dictionary = {}
	var cycle_visited: Dictionary = {}
	for node in graph.nodes:
		if _detect_cycle(graph, node.node_id, cycle_visiting, cycle_visited):
			_add_error(plan, &"cycle", node.node_id, "Scatter graph contains a cycle.")
			return plan
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	_visit(graph, plan.final_node_id, visiting, visited, plan)
	return plan


static func _detect_cycle(graph: ScatterGraph, node_id: int, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(node_id):
		return true
	if visited.has(node_id):
		return false
	visiting[node_id] = true
	for connection in graph.outgoing_connections(node_id):
		if _detect_cycle(graph, connection.to_node_id, visiting, visited):
			return true
	visiting.erase(node_id)
	visited[node_id] = true
	return false


static func _validate_connection(graph: ScatterGraph, connection: ScatterConnection, plan: ScatterExecutionPlan) -> void:
	var source := graph.find_node(connection.from_node_id)
	var target := graph.find_node(connection.to_node_id)
	if source == null or target == null:
		_add_error(plan, &"dangling_node", connection.to_node_id, "Connection references a missing node.")
		return
	var output := source.output_port(connection.from_port_id)
	var input := target.input_port(connection.to_port_id)
	if output == null or input == null:
		_add_error(plan, &"dangling_port", target.node_id, "Connection references a missing port.", {"from_port": connection.from_port_id, "to_port": connection.to_port_id})
		return
	if not output.connectable or not input.connectable:
		_add_error(plan, &"hidden_port_connection", target.node_id, "Connection references a non-connectable port.")
	elif not ScatterValueTypeRegistry.is_assignable(output.type_id, input.type_id):
		_add_error(plan, &"incompatible_types", target.node_id, "Connection value types are incompatible.", {"actual": output.type_id, "expected": input.type_id})
	if not input.variadic and graph.incoming_connections(target.node_id, input.id).size() > 1:
		_add_error(plan, &"multiple_non_variadic_inputs", target.node_id, "A non-variadic input has multiple connections.")


static func _visit(
		graph: ScatterGraph,
		node_id: int,
		visiting: Dictionary,
		visited: Dictionary,
		plan: ScatterExecutionPlan,
) -> void:
	if visited.has(node_id) or plan.has_errors():
		return
	if visiting.has(node_id):
		_add_error(plan, &"cycle", node_id, "Scatter graph contains a cycle.")
		return
	visiting[node_id] = true
	var node := graph.find_node(node_id)
	if node == null:
		_add_error(plan, &"missing_node", node_id, "Scatter graph references a missing node.")
		return
	for port in node.get_input_ports():
		for connection in graph.incoming_connections(node_id, port.id):
			_visit(graph, connection.from_node_id, visiting, visited, plan)
	visiting.erase(node_id)
	visited[node_id] = true
	plan.ordered_node_ids.append(node_id)


static func _add_error(plan: ScatterExecutionPlan, code: StringName, node_id: int, message: String, details := {}) -> void:
	plan.diagnostics.append(ScatterDiagnostic.new(ScatterDiagnostic.Severity.ERROR, code, node_id, message, details))
