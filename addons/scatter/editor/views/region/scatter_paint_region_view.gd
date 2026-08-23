@tool
class_name ScatterPaintRegionView
extends ScatterNodeView

var _stroke_count: Label


func _build_ports() -> void:
	var actions := HBoxContainer.new()
	_stroke_count = Label.new()
	_stroke_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stroke_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actions.add_child(_stroke_count)
	add_child(actions)
	add_port_row(&"", &"region", "Region")
	update_runtime_stats()


func _build_properties() -> void:
	add_enum_property(&"space", "Space", PackedStringArray(["Global", "Local"]))
	add_number_property(&"depth", "Depth", 0.01, 1000.0, 0.05)
	add_number_property(&"surface_offset", "Surface Offset", -1000.0, 1000.0, 0.01)


func update_runtime_stats() -> void:
	if _stroke_count != null and model is ScatterPaintRegionNode:
		_stroke_count.text = tr("%d strokes") % (model as ScatterPaintRegionNode).strokes.size()


func get_viewport_tool_id() -> StringName:
	return &"paint"
