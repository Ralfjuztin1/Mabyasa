@tool
class_name ScatterNodeInputs
extends RefCounted

var _values: Dictionary = {}


func add_value(port_id: StringName, value: ScatterValue) -> void:
	if value == null:
		return
	if not _values.has(port_id):
		_values[port_id] = []
	_values[port_id].append(value)


func has(port_id: StringName) -> bool:
	return _values.has(port_id) and not Array(_values[port_id]).is_empty()


func first(port_id: StringName) -> ScatterValue:
	if not has(port_id):
		return null
	return _values[port_id][0] as ScatterValue


func all(port_id: StringName) -> Array[ScatterValue]:
	var result: Array[ScatterValue] = []
	for value in Array(_values.get(port_id, [])):
		if value is ScatterValue:
			result.append(value)
	return result


func region(port_id: StringName = &"region") -> ScatterRegionValue:
	return first(port_id) as ScatterRegionValue


func shape(port_id: StringName = &"shape") -> ScatterShapeValue:
	return first(port_id) as ScatterShapeValue


func path(port_id: StringName = &"path") -> ScatterPathValue:
	return first(port_id) as ScatterPathValue


func instances(port_id: StringName = &"instances") -> ScatterInstances:
	return first(port_id) as ScatterInstances
