@tool
class_name ScatterUndoService
extends RefCounted

var manager: EditorUndoRedoManager
var history_context: Object
var model_changed: Callable


func _init(
		p_manager: EditorUndoRedoManager = null,
		p_history_context: Object = null,
		p_model_changed: Callable = Callable(),
) -> void:
	manager = p_manager
	history_context = p_history_context
	model_changed = p_model_changed


func commit_property(
		object: Object,
		property: StringName,
		value: Variant,
		caption: String,
		component := "",
		merge_mode := UndoRedo.MERGE_DISABLE,
) -> void:
	if object == null:
		return
	var previous = object.get(property)
	if previous == value:
		return
	if manager == null:
		object.set(property, value)
		_notify_model_changed()
		return
	var identity := object.get_instance_id()
	var action_name := "Edit %s%s [%d:%s]" % [
		caption,
		" %s" % component if component != "" else "",
		identity,
		property,
	]
	manager.create_action(action_name, merge_mode, history_context if is_instance_valid(history_context) else object)
	manager.add_do_property(object, property, value)
	manager.add_undo_property(object, property, previous)
	if object.has_method("emit_changed"):
		manager.add_do_method(object, "emit_changed")
		manager.add_undo_method(object, "emit_changed")
	manager.add_do_method(self, "_notify_model_changed")
	manager.add_undo_method(self, "_notify_model_changed")
	manager.commit_action()


func _notify_model_changed() -> void:
	if model_changed.is_valid():
		model_changed.call()
