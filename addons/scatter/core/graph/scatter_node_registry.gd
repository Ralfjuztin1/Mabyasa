@tool
class_name ScatterNodeRegistry
extends RefCounted

static var _node_scripts: Dictionary[StringName, Script] = {}


static func register_node(node_script: Script) -> bool:
	if node_script == null or not node_script.can_instantiate():
		return false
	var node = node_script.new()
	if not node is ScatterNode:
		return false
	var type_id: StringName = node.get_type_id()
	if type_id.is_empty() or _node_scripts.has(type_id):
		return false
	_node_scripts[type_id] = node_script
	return true


static func unregister_node(type_id: StringName) -> void:
	_node_scripts.erase(type_id)


static func clear() -> void:
	_node_scripts.clear()


static func create_node(type_id: StringName) -> ScatterNode:
	var script: Script = _node_scripts.get(type_id)
	return script.new() as ScatterNode if script != null else null


static func type_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_node_scripts.keys())
	return result


static func prototypes() -> Array[ScatterNode]:
	var result: Array[ScatterNode] = []
	for type_id in type_ids():
		var node := create_node(type_id)
		if node != null:
			result.append(node)
	result.sort_custom(func(a: ScatterNode, b: ScatterNode) -> bool:
		var category_compare := String(a.get_category()).naturalnocasecmp_to(String(b.get_category()))
		return a.get_caption().naturalnocasecmp_to(b.get_caption()) < 0 if category_compare == 0 else category_compare < 0
	)
	return result
