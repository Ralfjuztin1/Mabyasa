@tool
class_name ScatterNodeOutputs
extends RefCounted

var _values: Dictionary = {}


func set_value(port_id: StringName, value: ScatterValue) -> void:
	_values[port_id] = value


func get_value(port_id: StringName) -> ScatterValue:
	return _values.get(port_id)


func has_value(port_id: StringName) -> bool:
	return _values.has(port_id)


func port_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for port_id: StringName in _values:
		result.append(port_id)
	return result


static func single(port_id: StringName, value: ScatterValue) -> ScatterNodeOutputs:
	var outputs := ScatterNodeOutputs.new()
	outputs.set_value(port_id, value)
	return outputs
