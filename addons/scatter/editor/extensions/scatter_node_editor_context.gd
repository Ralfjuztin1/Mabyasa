@tool
class_name ScatterNodeEditorContext
extends RefCounted

var target: MultiMeshInstance3D
var graph: ScatterGraph
var node: ScatterNode
var undo_redo: EditorUndoRedoManager
var changed: Callable


static func create(p_target: MultiMeshInstance3D, p_graph: ScatterGraph, p_node: ScatterNode, p_undo_redo: EditorUndoRedoManager = null) -> ScatterNodeEditorContext:
	var context := ScatterNodeEditorContext.new()
	context.target = p_target
	context.graph = p_graph
	context.node = p_node
	context.undo_redo = p_undo_redo
	return context
