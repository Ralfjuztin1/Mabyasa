@tool
class_name ScatterGraphClipboard
extends RefCounted

var nodes: Array[ScatterNode] = []
var connections: Array[ScatterConnection] = []
var center := Vector2.ZERO


func is_empty() -> bool:
	return nodes.is_empty()


func clear() -> void:
	nodes.clear()
	connections.clear()
	center = Vector2.ZERO


func capture(graph: ScatterGraph, node_ids: Array[int]) -> void:
	clear()
	if graph == null or node_ids.is_empty():
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for node_id in node_ids:
		var node := graph.find_node(node_id)
		if node == null or not node.is_deletable():
			continue
		var copy := node.duplicate(true) as ScatterNode
		nodes.append(copy)
		minimum = minimum.min(node.graph_position)
		maximum = maximum.max(node.graph_position)
	for connection in graph.connections:
		if node_ids.has(connection.from_node_id) and node_ids.has(connection.to_node_id):
			connections.append(connection.duplicate(true) as ScatterConnection)
	if not nodes.is_empty():
		center = (minimum + maximum) * 0.5


func instantiate(
		graph: ScatterGraph,
		target_position: Vector2,
) -> Dictionary:
	var created_nodes: Array[ScatterNode] = []
	var created_connections: Array[ScatterConnection] = []
	var remap: Dictionary[int, int] = {}
	var offset := target_position - center
	for source in nodes:
		var copy := source.duplicate(true) as ScatterNode
		var old_id := copy.node_id
		copy.node_id = graph.allocate_node_id()
		copy.graph_position += offset
		remap[old_id] = copy.node_id
		created_nodes.append(copy)
	for source in connections:
		if not remap.has(source.from_node_id) or not remap.has(source.to_node_id):
			continue
		created_connections.append(ScatterConnection.create(
			remap[source.from_node_id],
			source.from_port_id,
			remap[source.to_node_id],
			source.to_port_id,
			source.order,
		))
	_refresh_dynamic_port_types(created_nodes, created_connections)
	return {
		"nodes": created_nodes,
		"connections": created_connections,
	}


func _refresh_dynamic_port_types(
		created_nodes: Array[ScatterNode],
		created_connections: Array[ScatterConnection],
) -> void:
	# Adaptive port state is derived from the copied subgraph, not from the
	# source node. Connections crossing the clipboard boundary are deliberately
	# absent, so a node copied on its own becomes unbound again.
	var copied_graph := ScatterGraph.new()
	copied_graph.nodes = created_nodes
	copied_graph.connections = created_connections
	for node in created_nodes:
		var dynamic_port: ScatterPort
		for port in node.get_input_ports():
			if node.is_dynamic_port_type(port.id, false):
				dynamic_port = port
				break
		if dynamic_port == null:
			for port in node.get_output_ports():
				if node.is_dynamic_port_type(port.id, true):
					dynamic_port = port
					break
		if dynamic_port == null:
			continue
		var inferred := node.infer_dynamic_port_type(copied_graph, created_connections)
		node.set_dynamic_port_type(inferred)
