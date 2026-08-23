@tool
class_name ScatterGraphFactory
extends RefCounted


static func create_empty() -> ScatterGraph:
	var graph := ScatterGraph.new()
	var final_output := ScatterNodeRegistry.create_node(&"final_output")
	if final_output != null:
		graph.add_node(final_output, Vector2(980, 120))
	return graph


static func create_default() -> ScatterGraph:
	var graph := ScatterGraph.new()
	var box := ScatterNodeRegistry.create_node(&"shape_box")
	var random := ScatterNodeRegistry.create_node(&"create_random")
	var random_rotation := ScatterNodeRegistry.create_node(&"random_rotation")
	var scale := ScatterNodeRegistry.create_node(&"scale")
	var final_output := ScatterNodeRegistry.create_node(&"final_output")
	for item in [
		[box, Vector2(40, 20)],
		[random, Vector2(40, 300)],
		[random_rotation, Vector2(330, 300)],
		[scale, Vector2(620, 300)],
		[final_output, Vector2(930, 160)],
	]:
		if item[0] != null:
			graph.add_node(item[0], item[1])
	if null in [box, random, random_rotation, scale, final_output]:
		return graph
	graph.connect_nodes(box.node_id, &"region", random.node_id, &"shape")
	graph.connect_nodes(random.node_id, &"instances", random_rotation.node_id, &"instances")
	graph.connect_nodes(random_rotation.node_id, &"instances", scale.node_id, &"instances")
	graph.connect_nodes(scale.node_id, &"instances", final_output.node_id, &"instances", 0)
	return graph
