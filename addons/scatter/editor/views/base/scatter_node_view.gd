@tool
@abstract
class_name ScatterNodeView
extends GraphNode

const CONTENT_PADDING := 5.0

var model: ScatterNode
var context: ScatterEditorContext
var input_port_order: Array[StringName] = []
var output_port_order: Array[StringName] = []
var _bindings: Array[Dictionary] = []
var _syncing := false


func _enter_tree() -> void:
	set("theme_override_constants/separation", 8)


func bind_model(p_model: ScatterNode, p_context: ScatterEditorContext) -> void:
	model = p_model
	context = p_context
	name = str(model.node_id)
	title = tr(model.get_caption())
	tooltip_text = tr(model.get_description())
	position_offset = model.graph_position
	custom_minimum_size.x = minimum_width()
	if model.can_disable():
		var enabled := CheckBox.new()
		enabled.tooltip_text = tr("Enable or disable this node")
		enabled.button_pressed = model.enabled
		enabled.toggled.connect(_enabled_changed)
		get_titlebar_hbox().add_child(enabled)
		_bindings.append({"property": &"enabled", "kind": "bool", "control": enabled})
	_add_content_padding(&"ContentPaddingTop")
	_build_ports()
	if model.supports_seed():
		_add_seed_controls()
	_build_properties()
	_add_content_padding(&"ContentPaddingBottom")
	_tint_native_titlebar(model.get_color())


@abstract func _build_ports() -> void


@abstract func _build_properties() -> void


func minimum_width() -> float:
	return 270.0


func sync_from_model() -> void:
	if model == null:
		return
	_syncing = true
	position_offset = model.graph_position
	for binding in _bindings:
		var property: StringName = binding.property
		var value = model.get(property)
		match binding.kind:
			"bool":
				(binding.control as BaseButton).button_pressed = bool(value)
			"number":
				(binding.control as SpinBox).value = float(value)
			"vector2", "vector3":
				var controls: Array = binding.controls
				for axis in controls.size():
					(controls[axis] as SpinBox).value = value[axis]
			"enum":
				(binding.control as OptionButton).select(int(value))
			"color":
				(binding.control as ColorPickerButton).color = value
			"path":
				(binding.control as LineEdit).text = _path_to_text(value)
			"text", "node_path":
				(binding.control as LineEdit).text = String(value)
	_syncing = false
	update_runtime_stats()


func update_runtime_stats() -> void:
	pass


func get_viewport_tool_id() -> StringName:
	return &""


func viewport_tool_activated() -> void:
	pass


func viewport_tool_deactivated() -> void:
	pass


func input_port_id(index: int) -> StringName:
	return input_port_order[index] if index >= 0 and index < input_port_order.size() else &""


func output_port_id(index: int) -> StringName:
	return output_port_order[index] if index >= 0 and index < output_port_order.size() else &""


func input_port_index(port_id: StringName, order := 0) -> int:
	var seen := 0
	for index in input_port_order.size():
		if input_port_order[index] != port_id:
			continue
		if seen == order:
			return index
		seen += 1
	return -1


func output_port_index(port_id: StringName) -> int:
	return output_port_order.find(port_id)


func add_port_row(
		input_id: StringName,
		output_id: StringName,
		label_text: String,
	) -> Label:
	var label := Label.new()
	label.text = tr(label_text)
	if not output_id.is_empty():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
	var input_port := model.input_port(input_id) if not input_id.is_empty() else null
	var output_port := model.output_port(output_id) if not output_id.is_empty() else null
	set_slot(
		get_child_count() - 1,
		input_port != null,
		input_port.visual_type() if input_port != null else 0,
		input_port.color() if input_port != null else Color.WHITE,
		output_port != null,
		output_port.visual_type() if output_port != null else 0,
		output_port.color() if output_port != null else Color.WHITE,
	)
	if input_port != null:
		input_port_order.append(input_id)
	if output_port != null:
		output_port_order.append(output_id)
	return label


func _add_content_padding(control_name: StringName) -> void:
	var spacer := Control.new()
	spacer.name = control_name
	spacer.custom_minimum_size.y = CONTENT_PADDING * maxf(get_theme_default_base_scale(), 1.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)


func add_bool_property(property: StringName, label_text: String, tooltip := "") -> CheckBox:
	var control := CheckBox.new()
	control.button_pressed = bool(model.get(property))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.toggled.connect(_bool_changed.bind(property, label_text))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({"property": property, "kind": "bool", "control": control})
	return control


func add_number_property(
		property: StringName,
		label_text: String,
		minimum: float,
		maximum: float,
		step: float,
		integer := false,
		tooltip := "",
	) -> SpinBox:
	var control := SpinBox.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = float(model.get(property))
	control.value_changed.connect(_number_changed.bind(property, label_text, integer))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({"property": property, "kind": "number", "control": control})
	return control


func add_vector2_property(property: StringName, label_text: String, tooltip := "") -> HBoxContainer:
	return _add_vector_property(property, label_text, 2, tooltip)


func add_vector3_property(property: StringName, label_text: String, tooltip := "") -> HBoxContainer:
	return _add_vector_property(property, label_text, 3, tooltip)


func add_enum_property(
		property: StringName,
		label_text: String,
		items: PackedStringArray,
		tooltip := "",
	) -> OptionButton:
	var control := OptionButton.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		control.add_item(tr(item))
	control.select(int(model.get(property)))
	control.item_selected.connect(_enum_changed.bind(property, label_text))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({"property": property, "kind": "enum", "control": control})
	return control


func add_color_property(property: StringName, label_text: String, tooltip := "") -> ColorPickerButton:
	var control := ColorPickerButton.new()
	control.color = model.get(property)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.color_changed.connect(_color_changed.bind(property, label_text))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({"property": property, "kind": "color", "control": control})
	return control


func add_path_property(property: StringName, label_text: String, tooltip := "") -> LineEdit:
	var control := _add_line_edit(property, label_text, tooltip)
	control.text = _path_to_text(model.get(property))
	_bindings.append({"property": property, "kind": "path", "control": control})
	return control


func add_file_property(property: StringName, label_text: String, tooltip := "") -> LineEdit:
	var control := _add_line_edit(property, label_text, tooltip)
	control.text = String(model.get(property))
	_bindings.append({"property": property, "kind": "text", "control": control})
	return control


func add_node_path_property(property: StringName, label_text: String, tooltip := "") -> LineEdit:
	var control := _add_line_edit(property, label_text, tooltip)
	control.text = String(model.get(property))
	_bindings.append({"property": property, "kind": "node_path", "control": control})
	return control


func _add_seed_controls() -> void:
	var row := HBoxContainer.new()
	var override_control := CheckBox.new()
	var seed_control := SpinBox.new()
	override_control.text = tr("Independent Seed")
	override_control.tooltip_text = tr("Use a fixed seed for this node")
	override_control.button_pressed = model.override_seed
	override_control.toggled.connect(_seed_override_changed.bind(seed_control))
	row.add_child(override_control)
	seed_control.min_value = -2147483648
	seed_control.max_value = 2147483647
	seed_control.step = 1
	seed_control.value = model.custom_seed
	seed_control.visible = model.override_seed
	seed_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_control.value_changed.connect(_number_changed.bind(&"custom_seed", "Independent Seed", true))
	row.add_child(seed_control)
	add_child(row)
	_bindings.append({"property": &"override_seed", "kind": "bool", "control": override_control})
	_bindings.append({"property": &"custom_seed", "kind": "number", "control": seed_control})


func _add_vector_property(
		property: StringName,
		label_text: String,
		count: int,
		tooltip: String,
	) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls: Array[SpinBox] = []
	var value = model.get(property)
	for axis in count:
		var control := SpinBox.new()
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.x = 150
		control.min_value = -1000000.0
		control.max_value = 1000000.0
		control.step = 0.05
		control.value = value[axis]
		control.prefix = ["X ", "Y ", "Z "][axis]
		control.value_changed.connect(_vector_changed.bind(property, label_text, axis, count))
		box.add_child(control)
		controls.append(control)
	_add_property_row(label_text, tooltip, box)
	_bindings.append({
		"property": property,
		"kind": "vector2" if count == 2 else "vector3",
		"controls": controls,
	})
	return box


func _add_line_edit(property: StringName, label_text: String, tooltip: String) -> LineEdit:
	var control := LineEdit.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.text_submitted.connect(_text_submitted.bind(property, label_text))
	control.focus_exited.connect(_text_focus_exited.bind(control, property, label_text))
	_add_property_row(label_text, tooltip, control)
	return control


func _add_property_row(label_text: String, tooltip: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(label_text)
	label.custom_minimum_size.x = 84
	label.tooltip_text = tr(tooltip) if tooltip != "" else ""
	control.tooltip_text = label.tooltip_text
	row.add_child(label)
	row.add_child(control)
	add_child(row)


func _enabled_changed(value: bool) -> void:
	if _syncing:
		return
	context.commit_property(model, &"enabled", value, tr("Node Enabled"))


func _bool_changed(value: bool, property: StringName, caption: String) -> void:
	if _syncing:
		return
	context.commit_property(model, property, value, tr(caption))


func _number_changed(value: float, property: StringName, caption: String, integer: bool) -> void:
	if _syncing:
		return
	context.commit_property(
		model,
		property,
		int(value) if integer else value,
		tr(caption),
		"",
		UndoRedo.MERGE_ENDS,
	)


func _vector_changed(
		value: float,
		property: StringName,
		caption: String,
		axis: int,
		count: int,
) -> void:
	if _syncing:
		return
	var vector = model.get(property)
	vector[axis] = value
	context.commit_property(
		model,
		property,
		vector,
		tr(caption),
		["X", "Y", "Z"][axis],
		UndoRedo.MERGE_ENDS,
	)


func _enum_changed(value: int, property: StringName, caption: String) -> void:
	if _syncing:
		return
	context.commit_property(model, property, value, tr(caption))


func _color_changed(value: Color, property: StringName, caption: String) -> void:
	if _syncing:
		return
	context.commit_property(model, property, value, tr(caption), "", UndoRedo.MERGE_ENDS)


func _seed_override_changed(value: bool, seed_control: SpinBox) -> void:
	seed_control.visible = value
	_bool_changed(value, &"override_seed", "Independent Seed")


func _text_submitted(text: String, property: StringName, caption: String) -> void:
	_commit_text(text, property, caption)


func _text_focus_exited(control: LineEdit, property: StringName, caption: String) -> void:
	_commit_text(control.text, property, caption)


func _commit_text(text: String, property: StringName, caption: String) -> void:
	if _syncing:
		return
	var current = model.get(property)
	var value: Variant = text
	if current is PackedVector3Array:
		value = _text_to_path(text)
	elif current is NodePath:
		value = NodePath(text)
	context.commit_property(model, property, value, tr(caption))


func _tint_native_titlebar(color: Color) -> void:
	var normal := get_theme_stylebox("titlebar")
	if normal is StyleBoxFlat:
		var tinted := normal.duplicate() as StyleBoxFlat
		tinted.bg_color = color.darkened(0.38)
		add_theme_stylebox_override("titlebar", tinted)
	var selected_style := get_theme_stylebox("titlebar_selected")
	if selected_style is StyleBoxFlat:
		var tinted_selected := selected_style.duplicate() as StyleBoxFlat
		tinted_selected.bg_color = color.darkened(0.27)
		add_theme_stylebox_override("titlebar_selected", tinted_selected)


static func _path_to_text(points: PackedVector3Array) -> String:
	var parts: PackedStringArray = []
	for point in points:
		parts.append("%s,%s,%s" % [point.x, point.y, point.z])
	return "; ".join(parts)


static func _text_to_path(text: String) -> PackedVector3Array:
	var result := PackedVector3Array()
	for raw_point in text.split(";", false):
		var values := raw_point.strip_edges().split(",", false)
		if values.size() == 3:
			result.append(Vector3(values[0].to_float(), values[1].to_float(), values[2].to_float()))
	return result
