@tool
class_name ScatterGraphAttachment
extends RefCounted

const META_KEY := &"_scatter_graph"


static func get_graph(target: MultiMeshInstance3D) -> ScatterGraph:
	if not is_instance_valid(target) or not target.has_meta(META_KEY):
		return null
	var graph := target.get_meta(META_KEY) as ScatterGraph
	# A recipe must remain an external resource. Inline graph metadata belonged to
	# the pre-recipe workflow and is deliberately not adopted by this version.
	if graph == null or graph.resource_path.is_empty():
		return null
	return graph


static func get_recipe_path(target: MultiMeshInstance3D) -> String:
	var graph := get_graph(target)
	return graph.resource_path if graph != null else ""


static func attach(target: MultiMeshInstance3D, graph: ScatterGraph) -> bool:
	if not is_instance_valid(target) or graph == null or graph.resource_path.is_empty():
		return false
	# Keep the graph as an ExtResource in scene metadata. This intentionally
	# avoids a scene-local duplicate, so edits are made to the linked recipe.
	graph.resource_local_to_scene = false
	target.set_meta(META_KEY, graph)
	target.notify_property_list_changed()
	return true


static func attach_path(target: MultiMeshInstance3D, path: String) -> ScatterGraph:
	if path.is_empty() or not ResourceLoader.exists(path, "ScatterGraph"):
		return null
	var graph := ResourceLoader.load(path, "ScatterGraph") as ScatterGraph
	return graph if attach(target, graph) else null


static func detach(target: MultiMeshInstance3D) -> void:
	if is_instance_valid(target) and target.has_meta(META_KEY):
		target.remove_meta(META_KEY)
		target.notify_property_list_changed()
