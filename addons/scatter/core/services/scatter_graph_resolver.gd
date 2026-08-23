@tool
class_name ScatterGraphResolver
extends RefCounted

var _provider: Callable


func _init(provider := Callable()) -> void:
	_provider = provider


func resolve(target: MultiMeshInstance3D) -> ScatterGraph:
	if not is_instance_valid(target):
		return null
	if _provider.is_valid():
		var provided = _provider.call(target)
		if provided is ScatterGraph:
			return provided
	return ScatterGraphAttachment.get_graph(target)
