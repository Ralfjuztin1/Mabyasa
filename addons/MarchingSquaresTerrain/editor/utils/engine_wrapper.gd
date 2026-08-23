extends Object
class_name EngineWrapper


static var instance : EngineWrapper:
	get:
		if not instance:
			instance = EngineWrapper.new()
		return instance


func is_editor() -> bool:
	return Engine.is_editor_hint()


func get_edited_scene_root():
	var editor_interface = Engine.get_singleton('EditorInterface')
	return editor_interface.get_edited_scene_root()


func get_root_for_node(node: Node) -> Node:
	if is_editor():
		return get_edited_scene_root()
	return node.get_tree().root


func set_owner_recursive(node: Node, _owner: Node = null) -> void:
	if not _owner:
		_owner = get_root_for_node(node)
	node.owner = _owner
	for c in node.get_children():
		set_owner_recursive(c, _owner)
