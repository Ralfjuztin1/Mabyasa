@tool
class_name ScatterValueTypeRegistry
extends RefCounted

const VALUE := &"value"
const SHAPE := &"shape"
const REGION := &"region"
const REGULAR_REGION := &"regular_region"
const PATH := &"path"
const DIRECT_SAMPLEABLE := &"direct_sampleable"
const INSTANCES := &"instances"
const DYNAMIC_GEOMETRY := &"dynamic_geometry"

static var _parents: Dictionary = {}
static var _colors: Dictionary = {}
static var _visual_ids: Dictionary = {}
static var _next_visual_id := 1
static var _initialized := false


static func ensure_builtins() -> void:
	if _initialized:
		return
	_initialized = true
	_register_raw(VALUE, [], Color("a0a0a0"))
	_register_raw(SHAPE, [VALUE], Color("55b8a6"))
	_register_raw(REGION, [SHAPE], Color("55b8a6"))
	_register_raw(DIRECT_SAMPLEABLE, [VALUE], Color("62c6bb"))
	_register_raw(REGULAR_REGION, [REGION, DIRECT_SAMPLEABLE], Color("55b8a6"))
	_register_raw(PATH, [SHAPE, DIRECT_SAMPLEABLE], Color("63a7dc"))
	_register_raw(INSTANCES, [VALUE], Color("b889e8"))
	# Session-visible wildcard used by adaptive geometry ports. It must never
	# survive as the resolved type of a connected core graph port.
	_register_raw(DYNAMIC_GEOMETRY, [VALUE], Color("6f91b5"))


static func register_type(type_id: StringName, parents: Array[StringName], color: Color) -> bool:
	ensure_builtins()
	if type_id == &"" or _parents.has(type_id):
		return false
	for parent in parents:
		if parent == type_id or not _parents.has(parent):
			return false
	return _register_raw(type_id, parents, color)


static func _register_raw(type_id: StringName, parents: Array[StringName], color: Color) -> bool:
	_parents[type_id] = parents.duplicate()
	_colors[type_id] = color
	_visual_ids[type_id] = _next_visual_id
	_next_visual_id += 1
	return true


static func unregister_type(type_id: StringName) -> bool:
	ensure_builtins()
	if not _parents.has(type_id) or _is_builtin(type_id):
		return false
	for child in _parents:
		if type_id in _parents[child]:
			return false
	_parents.erase(type_id)
	_colors.erase(type_id)
	_visual_ids.erase(type_id)
	return true


static func is_registered(type_id: StringName) -> bool:
	ensure_builtins()
	return _parents.has(type_id)


static func is_assignable(actual: StringName, expected: StringName) -> bool:
	ensure_builtins()
	if actual == expected:
		return _parents.has(actual)
	if not _parents.has(actual) or not _parents.has(expected):
		return false
	var pending: Array[StringName] = [actual]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current := pending.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for parent: StringName in _parents.get(current, []):
			if parent == expected:
				return true
			pending.push_back(parent)
	return false


static func is_geometry_value_type(type_id: StringName) -> bool:
	return type_id in [SHAPE, REGION, REGULAR_REGION, PATH]


static func is_visual_connection_valid(actual: StringName, expected: StringName) -> bool:
	if actual == DYNAMIC_GEOMETRY:
		return expected == DYNAMIC_GEOMETRY or is_geometry_value_type(expected)
	if expected == DYNAMIC_GEOMETRY:
		return is_geometry_value_type(actual)
	return is_assignable(actual, expected)


static func color(type_id: StringName) -> Color:
	ensure_builtins()
	return _colors.get(type_id, Color.WHITE)


static func visual_id(type_id: StringName) -> int:
	ensure_builtins()
	return _visual_ids.get(type_id, 0)


static func registered_types() -> Array[StringName]:
	ensure_builtins()
	var result: Array[StringName] = []
	for type_id: StringName in _parents:
		result.append(type_id)
	return result


static func _is_builtin(type_id: StringName) -> bool:
	return type_id in [VALUE, SHAPE, REGION, REGULAR_REGION, PATH, DIRECT_SAMPLEABLE, INSTANCES, DYNAMIC_GEOMETRY]
