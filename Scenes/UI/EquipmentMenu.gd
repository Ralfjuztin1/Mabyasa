extends CanvasLayer

## Read-only equipment overview. Opened from the Panday's menu.
## The blacksmith remains paused underneath this screen, so Back returns
## to the same forge session without unpausing player movement.

const BlacksmithRules = preload("res://Scripts/Core/BlacksmithRules.gd")
const PANEL_TEXTURE_PATH: String = "res://Assets/UI/PauseMenu/panel_base_9slice.png"
const BUTTON_NORMAL_PATH: String = "res://Assets/UI/PauseMenu/button_normal.png"
const BUTTON_SELECTED_PATH: String = "res://Assets/UI/PauseMenu/button_selected.png"
const PIXEL_FONT_PATH: String = "res://Assets/UI/Sprout Lands - UI Pack - Basic pack/fonts/pixelFont-7-8x14-sproutLands.ttf"

const COLOR_GOLD: Color = Color(0.94, 0.70, 0.25, 1.0)
const COLOR_TEXT: Color = Color(0.94, 0.92, 0.83, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.71, 0.63, 1.0)
const COLOR_PANEL: Color = Color(0.035, 0.055, 0.041, 0.96)
const COLOR_DETAIL: Color = Color(0.05, 0.07, 0.052, 0.98)
const COLOR_BORDER: Color = Color(0.72, 0.62, 0.36, 0.40)
const GEAR_ORDER: Array[String] = ["sword", "armor", "helmet"]

var return_to_blacksmith: Node = null
var _theme: Theme
var _gold_label: Label
var _atk_label: Label
var _def_label: Label
var _hp_label: Label
var _gear_cards: HBoxContainer
var _status_label: Label
var _owns_pause: bool = false
var _was_paused: bool = false
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _closing: bool = false


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_mouse_mode = Input.mouse_mode
	_was_paused = get_tree().paused
	_owns_pause = not is_instance_valid(return_to_blacksmith) and not _was_paused

	_build_theme()
	_build_interface()
	_refresh()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _owns_pause:
		get_tree().paused = true

	if is_instance_valid(PlayerProgression):
		if not PlayerProgression.stats_changed.is_connected(_refresh):
			PlayerProgression.stats_changed.connect(_refresh)


func _exit_tree() -> void:
	if is_instance_valid(PlayerProgression) and PlayerProgression.stats_changed.is_connected(_refresh):
		PlayerProgression.stats_changed.disconnect(_refresh)

	if _owns_pause and is_inside_tree() and get_tree().paused:
		get_tree().paused = _was_paused

	if not is_instance_valid(return_to_blacksmith) and is_inside_tree() and not get_tree().paused:
		Input.set_mouse_mode(_previous_mouse_mode)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _build_theme() -> void:
	_theme = Theme.new()
	var font: Font = load(PIXEL_FONT_PATH) as Font
	if font != null:
		_theme.default_font = font
	_theme.default_font_size = 14


func _build_interface() -> void:
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = _theme
	add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.005, 0.012, 0.008, 0.90)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(980, 560)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(frame)

	var margin := _make_margin(frame, 24, 20, 24, 18)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)

	var title := Label.new()
	title.text = "MY EQUIPMENT"
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 27)
	title_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Every temper adds a small, permanent stat bonus. Gear is never destroyed by a failed strike."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 12)
	title_stack.add_child(subtitle)

	_gold_label = Label.new()
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	_gold_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_gold_label)

	var close_button := _make_button("CLOSE  X", Vector2(96, 38))
	close_button.pressed.connect(_go_back)
	header.add_child(close_button)

	main.add_child(_make_separator())

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 10)
	main.add_child(summary_row)
	_atk_label = _make_summary_card(summary_row, "TOTAL ATTACK")
	_def_label = _make_summary_card(summary_row, "TOTAL DEFENSE")
	_hp_label = _make_summary_card(summary_row, "MAX HP")

	var section_title := Label.new()
	section_title.text = "EQUIPPED GEAR"
	section_title.add_theme_color_override("font_color", COLOR_GOLD)
	section_title.add_theme_font_size_override("font_size", 16)
	main.add_child(section_title)

	_gear_cards = HBoxContainer.new()
	_gear_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gear_cards.add_theme_constant_override("separation", 12)
	main.add_child(_gear_cards)

	main.add_child(_make_separator())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main.add_child(footer)

	_status_label = Label.new()
	_status_label.text = "Visit the Panday to improve any of these pieces."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	footer.add_child(_status_label)

	var back_button := _make_button("BACK TO PANDAY", Vector2(170, 40))
	back_button.pressed.connect(_go_back)
	footer.add_child(back_button)


func _make_summary_card(parent: HBoxContainer, heading_text: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_PANEL))
	parent.add_child(panel)

	var margin := _make_margin(panel, 12, 8, 12, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_color_override("font_color", COLOR_MUTED)
	heading.add_theme_font_size_override("font_size", 11)
	box.add_child(heading)

	var value := Label.new()
	value.add_theme_color_override("font_color", COLOR_TEXT)
	value.add_theme_font_size_override("font_size", 20)
	box.add_child(value)
	return value


func _make_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _make_frame_style() -> StyleBox:
	var texture: Texture2D = load(PANEL_TEXTURE_PATH) as Texture2D
	if texture != null:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = 26.0
		style.texture_margin_top = 24.0
		style.texture_margin_right = 26.0
		style.texture_margin_bottom = 24.0
		style.content_margin_left = 20.0
		style.content_margin_top = 18.0
		style.content_margin_right = 20.0
		style.content_margin_bottom = 16.0
		return style
	return _make_inner_panel_style(COLOR_PANEL)


func _make_button_style(selected: bool = false) -> StyleBox:
	var texture_path: String = BUTTON_SELECTED_PATH if selected else BUTTON_NORMAL_PATH
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture != null:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = 30.0
		style.texture_margin_top = 16.0
		style.texture_margin_right = 34.0
		style.texture_margin_bottom = 16.0
		style.content_margin_left = 14.0
		style.content_margin_top = 6.0
		style.content_margin_right = 16.0
		style.content_margin_bottom = 6.0
		return style
	return _make_inner_panel_style(COLOR_PANEL if not selected else Color(0.15, 0.14, 0.07, 1.0))


func _make_button(text_value: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_button_style(false))
	button.add_theme_stylebox_override("hover", _make_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_button_style(true))
	button.add_theme_stylebox_override("focus", _make_button_style(true))
	return button


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(0.72, 0.62, 0.36, 0.32)
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


func _make_inner_panel_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _format_number(value: int) -> String:
	return "%d" % value
func _refresh() -> void:
	if not is_instance_valid(PlayerProgression):
		return

	_gold_label.text = "%s G" % _format_number(int(PlayerProgression.gold))
	_atk_label.text = str(PlayerProgression.get_total_atk())
	_def_label.text = str(PlayerProgression.get_total_def())
	_hp_label.text = str(PlayerProgression.get_total_max_hp())

	for child: Node in _gear_cards.get_children():
		child.queue_free()

	for gear_type: String in GEAR_ORDER:
		var info: Dictionary = BlacksmithRules.get_upgrade_info(gear_type)
		_gear_cards.add_child(_build_gear_card(info))


func _build_gear_card(info: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_DETAIL))

	var margin := _make_margin(card, 14, 16, 14, 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var slot := Label.new()
	slot.text = str(info.get("slot", "GEAR"))
	slot.add_theme_color_override("font_color", COLOR_GOLD)
	slot.add_theme_font_size_override("font_size", 13)
	box.add_child(slot)

	var name_label := Label.new()
	name_label.text = str(info.get("name", "Gear"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 48)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.add_theme_font_size_override("font_size", 18)
	box.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "LEVEL %d / %d" % [int(info.get("current_level", 1)), BlacksmithRules.MAX_GEAR_LEVEL]
	level_label.add_theme_color_override("font_color", COLOR_GOLD)
	level_label.add_theme_font_size_override("font_size", 14)
	box.add_child(level_label)

	var level_bar := ProgressBar.new()
	level_bar.max_value = BlacksmithRules.MAX_GEAR_LEVEL
	level_bar.value = int(info.get("current_level", 1))
	level_bar.show_percentage = false
	level_bar.custom_minimum_size = Vector2(0, 12)
	level_bar.add_theme_stylebox_override("background", _make_progress_style(Color(0.10, 0.12, 0.09, 1.0)))
	level_bar.add_theme_stylebox_override("fill", _make_progress_style(COLOR_GOLD))
	box.add_child(level_bar)

	box.add_child(_make_separator())

	var stat_label := Label.new()
	stat_label.text = "CURRENT GEAR BONUS"
	stat_label.add_theme_color_override("font_color", COLOR_MUTED)
	stat_label.add_theme_font_size_override("font_size", 11)
	box.add_child(stat_label)

	var bonus_label := Label.new()
	bonus_label.text = "+%d %s" % [int(info.get("current_bonus", 0)), str(info.get("stat_short", "STAT"))]
	bonus_label.add_theme_color_override("font_color", COLOR_TEXT)
	bonus_label.add_theme_font_size_override("font_size", 21)
	box.add_child(bonus_label)

	var next_label := Label.new()
	if bool(info.get("is_max_level", false)):
		next_label.text = "Masterwork · no further upgrades"
	else:
		next_label.text = "Next level: +%d %s" % [int(info.get("next_bonus", 0)), str(info.get("stat_short", "STAT"))]
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_label.add_theme_color_override("font_color", COLOR_GOLD)
	next_label.add_theme_font_size_override("font_size", 13)
	box.add_child(next_label)

	var description := Label.new()
	description.text = str(info.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(description)

	var flavor := Label.new()
	flavor.text = "“%s”" % str(info.get("flavor", "A careful hand makes good work."))
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.add_theme_color_override("font_color", COLOR_GOLD)
	flavor.add_theme_font_size_override("font_size", 12)
	box.add_child(flavor)

	return card


func _make_progress_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style


func _go_back() -> void:
	if _closing:
		return
	_closing = true

	if is_instance_valid(return_to_blacksmith):
		return_to_blacksmith.visible = true
		queue_free()
		return

	queue_free()
