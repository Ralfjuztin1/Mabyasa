@tool
class_name ScatterToolbar
extends VBoxContainer

signal add_requested
signal focus_requested
signal output_requested
signal save_requested
signal load_requested
signal build_requested
signal seed_changed(value: int)
signal reroll_requested
signal auto_build_changed(value: bool)

var _seed: SpinBox
var _auto_build: CheckBox
var _save: Button
var _syncing := false


func _ready() -> void:
	_build_actions()


func set_editor_enabled(value: bool) -> void:
	for row in get_children():
		for control in row.get_children():
			if control is BaseButton:
				control.disabled = not value
			elif control is SpinBox:
				control.editable = value


func sync_graph(seed: int, auto_build: bool) -> void:
	_syncing = true
	_seed.value = seed
	_auto_build.button_pressed = auto_build
	_syncing = false


func set_recipe_dirty(value: bool) -> void:
	if _save != null:
		_save.text = tr("Save") + (tr("(*) ") if value else "")
		_save.tooltip_text = (
			tr("Save unsaved recipe changes to the linked .tres file")
			if value
			else tr("Save the linked Scatter recipe")
		)


func _build_actions() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_label("Seed"))
	_seed = _spin(-2147483648.0, 2147483647.0, 1.0)
	_seed.custom_minimum_size.x = 100
	_seed.value_changed.connect(func(value: float):
		if not _syncing: seed_changed.emit(int(value))
	)
	row.add_child(_seed)
	_add_button(row, "Reroll", reroll_requested.emit)
	_auto_build = CheckBox.new()
	_auto_build.text = tr("Auto Build")
	_auto_build.toggled.connect(func(value: bool):
		if not _syncing: auto_build_changed.emit(value)
	)
	row.add_child(_auto_build)
	_add_button(row, "Build", build_requested.emit, "Evaluate the graph and write the MultiMesh instance buffer")

	var spacer := Control.new()
	row.add_spacer(false)

	#_add_button(row, "Add Node", add_requested.emit, "Add a node to the Scatter graph")
	#_add_button(row, "Focus", focus_requested.emit)
	#_add_button(row, "Output", output_requested.emit)
	_save = _add_button(row, "Save", save_requested.emit, "Save the linked Scatter recipe (Ctrl+S)")
	#_add_button(row, "Load", load_requested.emit)


func _add_button(parent: Container, caption: String, callback: Callable, tooltip := "") -> Button:
	var button := Button.new()
	button.text = tr(caption)
	button.tooltip_text = tr(tooltip) if tooltip != "" else ""
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(caption: String) -> Label:
	var label := Label.new()
	label.text = tr(caption)
	return label


func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	return spin
