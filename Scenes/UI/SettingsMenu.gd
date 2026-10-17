extends CanvasLayer

signal closed

const SETTINGS_FILE: String = "user://mabiyasa_settings.cfg"
const DEFAULT_FOV: float = 75.0
const DEFAULT_SENSITIVITY_PERCENT: float = 100.0
const DEFAULT_VOLUME_PERCENT: float = 100.0

var _config := ConfigFile.new()
var _opened_from_pause_menu: bool = false
var _loading_controls: bool = false

var _fov_slider: HSlider
var _fov_value: Label
var _sensitivity_slider: HSlider
var _sensitivity_value: Label
var _volume_slider: HSlider
var _volume_value: Label
var _window_mode: OptionButton
var _vsync_check: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_interface()
	_load_config()
	_load_values_into_controls()
	_apply_all_settings()
	hide()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(from_pause_menu: bool = false) -> void:
	_opened_from_pause_menu = from_pause_menu
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_config()
	_load_values_into_controls()
	_apply_all_settings()


func close() -> void:
	visible = false
	_save_config()
	closed.emit()


func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.025, 0.02, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.065, 0.05, 0.98)
	panel_style.border_color = Color(0.75, 0.59, 0.30, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 26.0
	panel_style.content_margin_right = 26.0
	panel_style.content_margin_top = 22.0
	panel_style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 15)
	panel.add_child(root)

	var title := Label.new()
	title.text = "GAME SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.91, 0.75, 0.43))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Adjust your adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.77, 0.69))
	root.add_child(subtitle)

	_fov_slider = _add_slider_row(root, "Field of View", 55.0, 100.0, 1.0)
	_fov_value = _last_value_label
	_sensitivity_slider = _add_slider_row(root, "Mouse Sensitivity", 25.0, 300.0, 5.0)
	_sensitivity_value = _last_value_label
	_volume_slider = _add_slider_row(root, "Master Volume", 0.0, 100.0, 1.0)
	_volume_value = _last_value_label

	_add_separator(root)
	_window_mode = OptionButton.new()
	_window_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window_mode.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	_window_mode.add_item("Maximized", DisplayServer.WINDOW_MODE_MAXIMIZED)
	_window_mode.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	root.add_child(_add_labeled_control(root, "Display Mode", _window_mode))

	_vsync_check = CheckBox.new()
	_vsync_check.text = "Enable VSync"
	_vsync_check.add_theme_color_override("font_color", Color(0.91, 0.89, 0.78))
	root.add_child(_vsync_check)

	_add_separator(root)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)

	var reset_button := _make_button("Reset Defaults")
	reset_button.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_button)

	var back_button := _make_button("Back")
	back_button.pressed.connect(close)
	buttons.add_child(back_button)

	_fov_slider.value_changed.connect(_on_fov_changed)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_window_mode.item_selected.connect(_on_window_mode_selected)
	_vsync_check.toggled.connect(_on_vsync_toggled)


var _last_value_label: Label


func _add_slider_row(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var heading := HBoxContainer.new()
	row.add_child(heading)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.91, 0.89, 0.78))
	heading.add_child(label)

	_last_value_label = Label.new()
	_last_value_label.custom_minimum_size.x = 65
	_last_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_last_value_label.add_theme_color_override("font_color", Color(0.91, 0.75, 0.43))
	heading.add_child(_last_value_label)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 22
	row.add_child(slider)
	return slider


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.91, 0.89, 0.78))
	row.add_child(label)
	control.custom_minimum_size.x = 180
	row.add_child(control)
	return row


func _add_separator(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	parent.add_child(separator)


func _make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(145, 42)
	button.focus_mode = Control.FOCUS_ALL

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.15, 0.10)
	normal.border_color = Color(0.70, 0.55, 0.29, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.20, 0.12)
	hover.border_color = Color(0.96, 0.78, 0.40)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color(0.96, 0.91, 0.77))
	return button


func _load_config() -> void:
	_config = ConfigFile.new()
	var error: Error = _config.load(SETTINGS_FILE)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("[SETTINGS] Could not load settings file; defaults will be used.")


func _load_values_into_controls() -> void:
	_loading_controls = true
	_fov_slider.value = float(_config.get_value("settings", "fov", DEFAULT_FOV))
	_sensitivity_slider.value = float(_config.get_value("settings", "sensitivity_percent", DEFAULT_SENSITIVITY_PERCENT))
	_volume_slider.value = float(_config.get_value("settings", "volume_percent", DEFAULT_VOLUME_PERCENT))

	var configured_mode: int = int(_config.get_value("settings", "window_mode", DisplayServer.window_get_mode()))
	var mode_index: int = _window_mode.get_item_index(configured_mode)
	if mode_index < 0:
		mode_index = _window_mode.get_item_index(DisplayServer.window_get_mode())
	_window_mode.select(maxi(mode_index, 0))

	_vsync_check.button_pressed = bool(_config.get_value("settings", "vsync", true))
	_update_value_labels()
	_loading_controls = false


func _apply_all_settings() -> void:
	_apply_fov(_fov_slider.value)
	_apply_sensitivity(_sensitivity_slider.value)
	_apply_volume(_volume_slider.value)
	_apply_window_mode(int(_window_mode.get_item_id(_window_mode.selected)))
	_apply_vsync(_vsync_check.button_pressed)


func _apply_fov(value: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var camera := player.get_node_or_null("Head/SpringArm3D/Camera3D") as Camera3D
	if is_instance_valid(camera):
		camera.fov = clampf(value, 55.0, 100.0)


func _apply_sensitivity(value: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	if not player.has_method("get"):
		return
	if not player.has_meta("mabiyasa_base_mouse_sensitivity"):
		var current_value: Variant = player.get("mouse_sensitivity")
		if current_value != null:
			player.set_meta("mabiyasa_base_mouse_sensitivity", float(current_value))
	if player.has_meta("mabiyasa_base_mouse_sensitivity"):
		var base_sensitivity: float = float(player.get_meta("mabiyasa_base_mouse_sensitivity"))
		player.set("mouse_sensitivity", base_sensitivity * clampf(value, 25.0, 300.0) / 100.0)


func _apply_volume(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_linear(bus_index, clampf(value, 0.0, 100.0) / 100.0)


func _apply_window_mode(mode: int) -> void:
	if mode in [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]:
		DisplayServer.window_set_mode(mode)


func _apply_vsync(enabled: bool) -> void:
	var mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func _save_config() -> void:
	_config.set_value("settings", "fov", _fov_slider.value)
	_config.set_value("settings", "sensitivity_percent", _sensitivity_slider.value)
	_config.set_value("settings", "volume_percent", _volume_slider.value)
	_config.set_value("settings", "window_mode", int(_window_mode.get_item_id(_window_mode.selected)))
	_config.set_value("settings", "vsync", _vsync_check.button_pressed)
	var error: Error = _config.save(SETTINGS_FILE)
	if error != OK:
		push_warning("[SETTINGS] Could not save settings. Error code: %s" % error)


func _update_value_labels() -> void:
	_fov_value.text = "%d°" % int(roundf(_fov_slider.value))
	_sensitivity_value.text = "%d%%" % int(roundf(_sensitivity_slider.value))
	_volume_value.text = "%d%%" % int(roundf(_volume_slider.value))


func _on_fov_changed(value: float) -> void:
	_update_value_labels()
	_apply_fov(value)
	if not _loading_controls:
		_save_config()


func _on_sensitivity_changed(value: float) -> void:
	_update_value_labels()
	_apply_sensitivity(value)
	if not _loading_controls:
		_save_config()


func _on_volume_changed(value: float) -> void:
	_update_value_labels()
	_apply_volume(value)
	if not _loading_controls:
		_save_config()


func _on_window_mode_selected(index: int) -> void:
	if _loading_controls:
		return
	_apply_window_mode(int(_window_mode.get_item_id(index)))
	_save_config()


func _on_vsync_toggled(enabled: bool) -> void:
	if _loading_controls:
		return
	_apply_vsync(enabled)
	_save_config()


func _on_reset_pressed() -> void:
	_loading_controls = true
	_fov_slider.value = DEFAULT_FOV
	_sensitivity_slider.value = DEFAULT_SENSITIVITY_PERCENT
	_volume_slider.value = DEFAULT_VOLUME_PERCENT
	_window_mode.select(_window_mode.get_item_index(DisplayServer.WINDOW_MODE_MAXIMIZED))
	_vsync_check.button_pressed = true
	_update_value_labels()
	_loading_controls = false
	_apply_all_settings()
	_save_config()
