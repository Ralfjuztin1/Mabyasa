@tool
class_name ScatterRecipeIO
extends RefCounted


static func save_graph(graph: ScatterGraph, path := "") -> Error:
	if graph == null:
		return ERR_INVALID_PARAMETER
	var recipe_path := path if not path.is_empty() else graph.resource_path
	if recipe_path.is_empty():
		return ERR_INVALID_PARAMETER
	graph.resource_local_to_scene = false
	var error := ResourceSaver.save(graph, recipe_path)
	if error == OK and graph.resource_path != recipe_path:
		graph.take_over_path(recipe_path)
	return error


static func load_graph(path: String) -> ScatterGraph:
	if path.is_empty() or not ResourceLoader.exists(path, "ScatterGraph"):
		return null
	var loaded := ResourceLoader.load(path, "ScatterGraph")
	if not loaded is ScatterGraph:
		return null
	return loaded as ScatterGraph


static func create_recipe_from_target(target: MultiMeshInstance3D, path: String) -> ScatterGraph:
	if not is_instance_valid(target) or path.is_empty():
		return null
	var graph := ScatterGraphFactory.create_default()
	if save_graph(graph, path) != OK:
		return null
	return load_graph(path)
