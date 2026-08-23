@tool
class_name ScatterEditorContext
extends RefCounted

var target: MultiMeshInstance3D
var graph: ScatterGraph
var undo: ScatterUndoService
var sync_views: Callable
var graph_changed: Callable
var build_requested: Callable
var output_counts: Dictionary = {}


func commit_property(
		node: ScatterNode,
		property: StringName,
		value: Variant,
		caption: String,
		component := "",
		merge_mode := UndoRedo.MERGE_DISABLE,
) -> void:
	undo.commit_property(node, property, value, caption, component, merge_mode)


func notify_model_changed() -> void:
	if graph != null:
		graph.emit_changed()
	if sync_views.is_valid():
		sync_views.call()
	if graph_changed.is_valid():
		graph_changed.call()
	if graph != null and graph.auto_rebuild and build_requested.is_valid():
		build_requested.call()
