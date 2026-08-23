@tool
class_name ScatterExtensionRegistry
extends RefCounted

signal changed

static var _shared: ScatterExtensionRegistry
var _view_scripts: Dictionary = {}
var _extension_scripts: Dictionary = {}


static func shared() -> ScatterExtensionRegistry:
	if _shared == null:
		_shared = ScatterExtensionRegistry.new()
	return _shared


static func register_node(node_script: Script, view_script: Script, editor_extension_script: Script) -> bool:
	if node_script == null or view_script == null or editor_extension_script == null:
		return false
	var prototype = node_script.new()
	if not prototype is ScatterNode or not view_script.can_instantiate() or not editor_extension_script.can_instantiate():
		return false
	var type_id: StringName = prototype.get_type_id()
	if not ScatterNodeRegistry.register_node(node_script):
		return false
	shared()._view_scripts[type_id] = view_script
	shared()._extension_scripts[type_id] = editor_extension_script
	shared().changed.emit()
	return true


static func unregister_node(type_id: StringName) -> void:
	ScatterNodeRegistry.unregister_node(type_id)
	shared()._view_scripts.erase(type_id)
	shared()._extension_scripts.erase(type_id)
	shared().changed.emit()


static func get_view_script(type_id: StringName) -> Script:
	return shared()._view_scripts.get(type_id)


static func create_editor_extension(type_id: StringName) -> ScatterNodeEditorExtension:
	var script: Script = shared()._extension_scripts.get(type_id)
	return script.new() as ScatterNodeEditorExtension if script != null else null
