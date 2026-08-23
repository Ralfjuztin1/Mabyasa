@tool
class_name ScatterPort
extends RefCounted

var id: StringName
var label: String
var type_id: StringName
var variadic := false
var connectable := true
var visible := true
var visual_type_id: StringName


func _init(
		p_id: StringName = &"value",
		p_label := "Value",
		p_type_id: StringName = ScatterValueTypeRegistry.INSTANCES,
		p_variadic := false,
		p_connectable := true,
		p_visible := true,
		p_visual_type_id: StringName = &"",
	) -> void:
	id = p_id
	label = p_label
	type_id = p_type_id
	variadic = p_variadic
	connectable = p_connectable
	visible = p_visible
	visual_type_id = p_visual_type_id


func color() -> Color:
	return ScatterValueTypeRegistry.color(type_id)


func visual_type() -> int:
	return ScatterValueTypeRegistry.visual_id(visual_type_id if not visual_type_id.is_empty() else type_id)
