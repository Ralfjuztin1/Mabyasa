@tool
class_name ScatterStatusBar
extends HBoxContainer

var _label: Label
var _title: Label


func _ready() -> void:
	_title = Label.new()
	_title.text = tr("Scatter")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)


func set_title(value: String) -> void:
	_title.text = value


func show_message(message: String) -> void:
	_label.text = message


func show_instance_count(count: int) -> void:
	_label.text = tr("%d instances - editor-generated MultiMesh buffer is ready for runtime.") % count
