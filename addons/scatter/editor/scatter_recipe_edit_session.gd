@tool
class_name ScatterRecipeEditSession
extends RefCounted

var recipe_path := ""
var source_graph: ScatterGraph
var working_graph: ScatterGraph
var dirty := false
var target_ref: WeakRef
var scene_context_ref: WeakRef
var scene_path := ""


static func create(
		source: ScatterGraph,
		owner: MultiMeshInstance3D = null,
		context: Node = null,
) -> ScatterRecipeEditSession:
	if source == null or source.resource_path.is_empty():
		return null
	var session := ScatterRecipeEditSession.new()
	session.recipe_path = source.resource_path
	session.source_graph = source
	session.working_graph = source.duplicate_graph()
	session.working_graph.resource_local_to_scene = true
	session.bind_owner(owner, context)
	return session


func bind_owner(owner: MultiMeshInstance3D, context: Node) -> void:
	target_ref = weakref(owner) if is_instance_valid(owner) else null
	scene_context_ref = weakref(context) if is_instance_valid(context) else null
	scene_path = context.scene_file_path if is_instance_valid(context) else ""


func get_target() -> MultiMeshInstance3D:
	return target_ref.get_ref() as MultiMeshInstance3D if target_ref != null else null


func has_valid_context() -> bool:
	return scene_context_ref != null and scene_context_ref.get_ref() != null


func belongs_to_scene(path: String) -> bool:
	return not path.is_empty() and scene_path == path


func display_name() -> String:
	return recipe_path.get_file() if not recipe_path.is_empty() else "Untitled Recipe"


func mark_dirty() -> void:
	dirty = true


func save() -> Error:
	if working_graph == null or recipe_path.is_empty():
		return ERR_INVALID_PARAMETER
	var snapshot := working_graph.duplicate_graph()
	snapshot.resource_local_to_scene = false
	var error := ResourceSaver.save(snapshot, recipe_path)
	if error != OK:
		return error
	var saved_graph := ResourceLoader.load(
		recipe_path,
		"ScatterGraph",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as ScatterGraph
	if saved_graph == null:
		return ERR_CANT_OPEN
	_sync_source_graph(saved_graph)
	dirty = false
	return OK


func _sync_source_graph(saved_graph: ScatterGraph) -> void:
	if source_graph == null:
		source_graph = saved_graph
		return
	var existing_nodes: Dictionary[int, ScatterNode] = {}
	for node in source_graph.nodes:
		existing_nodes[node.node_id] = node
	var synchronized_nodes: Array[ScatterNode] = []
	for saved_node in saved_graph.nodes:
		var existing := existing_nodes.get(saved_node.node_id) as ScatterNode
		if existing != null and existing.get_script() == saved_node.get_script():
			existing.copy_from_resource(saved_node)
			existing.emit_changed()
			synchronized_nodes.append(existing)
		else:
			synchronized_nodes.append(saved_node)
	saved_graph.nodes = synchronized_nodes
	source_graph.copy_from_resource(saved_graph)
	source_graph.normalize_connection_orders()
	source_graph.emit_changed()
