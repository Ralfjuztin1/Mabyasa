extends CanvasLayer

## Opens when the player interacts with the Panday in Yatu Village.
## The UI is built in code so it does not require a separate editor layout.

const BlacksmithRules = preload("res://Scripts/Core/BlacksmithRules.gd")
const EquipmentMenuScene: PackedScene = preload("res://Scenes/UI/EquipmentMenu.tscn")
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

var _theme: Theme
var _gear_list: VBoxContainer
var _gold_label: Label
var _gear_title: Label
var _gear_slot_label: Label
var _gear_description: Label
var _current_bonus_label: Label
var _next_bonus_label: Label
var _chance_label: Label
var _chance_bar: ProgressBar
var _cost_label: Label
var _status_label: Label
var _forge_button: Button
var _challenge_panel: PanelContainer
var _challenge_word_label: Label
var _challenge_hint_label: Label
var _challenge_choices: VBoxContainer
var _gear_buttons: Dictionary = {}
var _current_stat_value: Label
var _next_stat_value: Label

var _selected_gear: String = "sword"
var _challenge_open: bool = false
var _challenge_answered: bool = false
var _challenge_bonus: float = 0.0
var _challenge_entry: Resource = null
var _challenge_option_buttons: Array[Button] = []
var _return_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _tree_was_paused: bool = false
var _owns_pause: bool = false
var _closing: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_return_mouse_mode = Input.mouse_mode
	_tree_was_paused = get_tree().paused
	_owns_pause = not _tree_was_paused

	_build_theme()
	_build_interface()
	_refresh()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _owns_pause:
		get_tree().paused = true


func _exit_tree() -> void:
	if _owns_pause and is_inside_tree() and get_tree().paused:
		get_tree().paused = _tree_was_paused
	if is_inside_tree() and not get_tree().paused:
		Input.set_mouse_mode(_return_mouse_mode)


func _input(event: InputEvent) -> void:
	# Ignore input while this menu is hidden beneath EquipmentMenu.
	var root: Control = get_node_or_null("Root") as Control

	if root == null or not root.is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _build_theme() -> void:
	_theme = Theme.new()
	var font: Font = load(PIXEL_FONT_PATH) as Font
	if font != null:
		_theme.default_font = font
	_theme.default_font_size = 14


func _build_interface() -> void:
	var root := Control.new()
	root.name = "Root"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = _theme
	add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.005, 0.012, 0.008, 0.86)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1030, 610)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	frame.add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	margin.add_child(main)

	# Header
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_constant_override("separation", 12)
	main.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	header.add_child(title_stack)

	var title := Label.new()
	title.text = "PANDAY NG YATU"
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 27)
	title_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Temper your gear. A careful strike is worth more than a rushed one."
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 12)
	title_stack.add_child(subtitle)

	_gold_label = Label.new()
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	_gold_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_gold_label)

	var close_button := _make_button("CLOSE  X", Vector2(96, 38))
	close_button.pressed.connect(_close_menu)
	header.add_child(close_button)

	main.add_child(_make_separator())

	# Main columns
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	main.add_child(body)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_PANEL))
	body.add_child(left_panel)

	var left_margin := _make_margin(left_panel, 12, 12, 12, 12)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_box)

	var list_heading := Label.new()
	list_heading.text = "GEAR TO TEMPER"
	list_heading.add_theme_color_override("font_color", COLOR_GOLD)
	list_heading.add_theme_font_size_override("font_size", 16)
	left_box.add_child(list_heading)

	var list_note := Label.new()
	list_note.text = "Choose one piece to inspect its next upgrade."
	list_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_note.add_theme_color_override("font_color", COLOR_MUTED)
	list_note.add_theme_font_size_override("font_size", 12)
	left_box.add_child(list_note)

	_gear_list = VBoxContainer.new()
	_gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_list.add_theme_constant_override("separation", 8)
	left_box.add_child(_gear_list)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_DETAIL))
	body.add_child(right_panel)

	var right_margin := _make_margin(right_panel, 18, 14, 18, 12)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_box)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	right_box.add_child(slot_row)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 2)
	slot_row.add_child(title_column)

	_gear_title = Label.new()
	_gear_title.add_theme_color_override("font_color", COLOR_TEXT)
	_gear_title.add_theme_font_size_override("font_size", 22)
	title_column.add_child(_gear_title)

	_gear_slot_label = Label.new()
	_gear_slot_label.add_theme_color_override("font_color", COLOR_GOLD)
	_gear_slot_label.add_theme_font_size_override("font_size", 12)
	title_column.add_child(_gear_slot_label)

	var level_box := PanelContainer.new()
	level_box.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	slot_row.add_child(level_box)
	var level_margin := _make_margin(level_box, 10, 7, 10, 7)
	_current_bonus_label = Label.new()
	_current_bonus_label.add_theme_color_override("font_color", COLOR_TEXT)
	_current_bonus_label.add_theme_font_size_override("font_size", 14)
	level_margin.add_child(_current_bonus_label)

	_gear_description = Label.new()
	_gear_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gear_description.custom_minimum_size = Vector2(0, 40)
	_gear_description.add_theme_color_override("font_color", COLOR_MUTED)
	right_box.add_child(_gear_description)

	right_box.add_child(_make_separator())

	var stats_heading := Label.new()
	stats_heading.text = "TEMPERING PREVIEW"
	stats_heading.add_theme_color_override("font_color", COLOR_GOLD)
	stats_heading.add_theme_font_size_override("font_size", 15)
	right_box.add_child(stats_heading)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	right_box.add_child(stats_row)

	var current_box := _make_stat_card("CURRENT BONUS")
	current_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(current_box)
	_current_stat_value = current_box.find_child("Value", true, false) as Label

	var next_box := _make_stat_card("AFTER SUCCESS")
	next_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(next_box)
	_next_stat_value = next_box.find_child("Value", true, false) as Label

	var chance_header := HBoxContainer.new()
	chance_header.add_theme_constant_override("separation", 8)
	right_box.add_child(chance_header)
	var chance_title := Label.new()
	chance_title.text = "SUCCESS CHANCE"
	chance_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chance_title.add_theme_color_override("font_color", COLOR_MUTED)
	chance_header.add_child(chance_title)
	_chance_label = Label.new()
	_chance_label.add_theme_color_override("font_color", COLOR_GOLD)
	_chance_label.add_theme_font_size_override("font_size", 16)
	chance_header.add_child(_chance_label)

	_chance_bar = ProgressBar.new()
	_chance_bar.custom_minimum_size = Vector2(0, 15)
	_chance_bar.max_value = 100.0
	_chance_bar.show_percentage = false
	_chance_bar.add_theme_stylebox_override("background", _make_progress_style(Color(0.10, 0.12, 0.09, 1.0)))
	_chance_bar.add_theme_stylebox_override("fill", _make_progress_style(COLOR_GOLD))
	right_box.add_child(_chance_bar)

	_cost_label = Label.new()
	_cost_label.add_theme_color_override("font_color", COLOR_GOLD)
	_cost_label.add_theme_font_size_override("font_size", 16)
	right_box.add_child(_cost_label)

	# Kapampangan learning bonus challenge. It only uses vocabulary
	# already encountered by this account and never spends Gold itself.
	_challenge_panel = PanelContainer.new()
	_challenge_panel.visible = false
	_challenge_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	right_box.add_child(_challenge_panel)

	var challenge_margin := _make_margin(_challenge_panel, 12, 9, 12, 9)
	var challenge_box := VBoxContainer.new()
	challenge_box.add_theme_constant_override("separation", 6)
	challenge_margin.add_child(challenge_box)

	var challenge_title := Label.new()
	challenge_title.text = "PANDAY'S CALL  ·  KAPAMPANGAN BONUS"
	challenge_title.add_theme_color_override("font_color", COLOR_GOLD)
	challenge_title.add_theme_font_size_override("font_size", 13)
	challenge_box.add_child(challenge_title)

	_challenge_word_label = Label.new()
	_challenge_word_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_word_label.add_theme_color_override("font_color", COLOR_TEXT)
	_challenge_word_label.add_theme_font_size_override("font_size", 15)
	challenge_box.add_child(_challenge_word_label)

	_challenge_hint_label = Label.new()
	_challenge_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_hint_label.add_theme_color_override("font_color", COLOR_MUTED)
	_challenge_hint_label.add_theme_font_size_override("font_size", 11)
	challenge_box.add_child(_challenge_hint_label)

	_challenge_choices = VBoxContainer.new()
	_challenge_choices.add_theme_constant_override("separation", 4)
	challenge_box.add_child(_challenge_choices)

	var cancel_challenge_button := _make_button("CANCEL STRIKE", Vector2(0, 30))
	cancel_challenge_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_challenge_button.pressed.connect(_cancel_challenge)
	challenge_box.add_child(cancel_challenge_button)

	main.add_child(_make_separator())

	# Footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	main.add_child(footer)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	footer.add_child(_status_label)

	var equipment_button := _make_button("MY EQUIPMENT", Vector2(142, 40))
	equipment_button.pressed.connect(_open_equipment)
	footer.add_child(equipment_button)

	_forge_button = _make_button("TEMPA  ·  UPGRADE", Vector2(190, 40))
	_forge_button.pressed.connect(_on_forge_pressed)
	footer.add_child(_forge_button)

	_rebuild_gear_list()


func _make_stat_card(heading_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	var margin := _make_margin(panel, 10, 7, 10, 7)
	var box := VBoxContainer.new()
	box.name = "StatVBox"
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_color_override("font_color", COLOR_MUTED)
	heading.add_theme_font_size_override("font_size", 11)
	box.add_child(heading)
	var value := Label.new()
	value.name = "Value"
	value.add_theme_color_override("font_color", COLOR_TEXT)
	value.add_theme_font_size_override("font_size", 17)
	box.add_child(value)
	return panel


func _make_margin(
	parent: Control,
	left: int,
	top: int,
	right: int,
	bottom: int
) -> MarginContainer:
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
	var path: String = BUTTON_SELECTED_PATH if selected else BUTTON_NORMAL_PATH
	var texture: Texture2D = load(path) as Texture2D
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


func _make_progress_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style


func _rebuild_gear_list() -> void:
	for child: Node in _gear_list.get_children():
		child.queue_free()
	_gear_buttons.clear()

	for gear_type: String in GEAR_ORDER:
		var info: Dictionary = BlacksmithRules.get_upgrade_info(gear_type)
		var level: int = int(info.get("current_level", 1))
		var button_text := "%s\nLEVEL %d / %d" % [str(info.get("name", gear_type.capitalize())), level, BlacksmithRules.MAX_GEAR_LEVEL]
		var button := _make_button(button_text, Vector2(0, 68))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("normal", _make_button_style(gear_type == _selected_gear))
		button.add_theme_stylebox_override("hover", _make_button_style(true))
		button.add_theme_stylebox_override("pressed", _make_button_style(true))
		button.pressed.connect(_select_gear.bind(gear_type))
		_gear_list.add_child(button)
		_gear_buttons[gear_type] = button


func _refresh() -> void:
	if not is_instance_valid(_gear_list):
		return

	_gold_label.text = "%s G" % _format_number(int(PlayerProgression.gold) if PlayerProgression != null else 0)
	_rebuild_gear_list()
	_refresh_details()


func _refresh_details() -> void:
	var info: Dictionary = BlacksmithRules.get_upgrade_info(_selected_gear)
	if info.is_empty():
		return

	var current_level: int = int(info.get("current_level", 1))
	var is_max: bool = bool(info.get("is_max_level", false))
	var stat_short: String = str(info.get("stat_short", "STAT"))
	var current_bonus: int = int(info.get("current_bonus", 0))
	var next_bonus: int = int(info.get("next_bonus", 0))
	var cost: int = int(info.get("cost", 0))
	var base_chance: float = float(info.get("base_success_chance", 0.0))

	_gear_title.text = str(info.get("name", _selected_gear.capitalize()))
	_gear_slot_label.text = "%s  ·  LEVEL %d / %d" % [str(info.get("slot", "GEAR")), current_level, BlacksmithRules.MAX_GEAR_LEVEL]
	_gear_description.text = str(info.get("description", ""))
	_current_bonus_label.text = "LEVEL %d" % current_level
	_current_stat_value.text = "+%d %s" % [current_bonus, stat_short]
	_next_stat_value.text = "MAXED" if is_max else "+%d %s" % [next_bonus, stat_short]
	_chance_label.text = "MAX LEVEL" if is_max else "%d%%" % int(round(base_chance))
	_chance_bar.value = base_chance
	_cost_label.text = "Cost: %s Gold" % _format_number(cost) if not is_max else "No further upgrades available."

	_forge_button.disabled = is_max or int(PlayerProgression.gold) < cost
	_forge_button.text = "MAX LEVEL" if is_max else ("NEED MORE GOLD" if int(PlayerProgression.gold) < cost else "TEMPA  ·  UPGRADE")

	if not _challenge_open:
		_challenge_panel.hide()
		if _status_label.text.is_empty():
			_status_label.text = str(info.get("flavor", "Choose a piece of gear to temper."))


func _select_gear(gear_type: String) -> void:
	if not BlacksmithRules.GEAR_DATA.has(gear_type):
		return
	_selected_gear = gear_type
	_reset_challenge()
	_status_label.text = str(BlacksmithRules.get_gear_definition(gear_type).get("flavor", ""))
	_refresh()


func _on_forge_pressed() -> void:
	if _challenge_open:
		if not _challenge_answered:
			_status_label.text = "Answer the forge call first, or close it to cancel."
			return
		_attempt_upgrade(_challenge_bonus)
		return

	var info: Dictionary = BlacksmithRules.get_upgrade_info(_selected_gear)
	if info.is_empty() or bool(info.get("is_max_level", false)):
		return
	if int(PlayerProgression.gold) < int(info.get("cost", 0)):
		_status_label.text = "Not enough Gold. No attempt has been made."
		return

	if _prepare_language_challenge():
		_challenge_open = true
		_challenge_answered = false
		_challenge_bonus = 0.0
		_challenge_panel.show()
		_forge_button.text = "STRIKE NOW"
		_forge_button.disabled = true
		_status_label.text = "Choose the correct meaning to steady the strike."
	else:
		# Early players with no encountered vocabulary can still temper gear.
		_attempt_upgrade(0.0)


func _prepare_language_challenge() -> bool:
	if not is_instance_valid(LanguageProgress) or not LanguageProgress.has_method("get_encountered_entries"):
		return false

	var eligible: Array[Resource] = []
	for entry: Resource in LanguageProgress.get_encountered_entries():
		var word: String = str(entry.get("kapampangan")).strip_edges()
		var meaning: String = str(entry.get("english")).strip_edges()
		var allowed: Variant = entry.get("allowed_types")
		if word.is_empty() or meaning.is_empty() or word == meaning:
			continue
		if allowed is PackedStringArray and not (allowed as PackedStringArray).has("multiple_choice"):
			continue
		eligible.append(entry)

	if eligible.size() < 3:
		return false

	eligible.shuffle()
	_challenge_entry = eligible[0]
	var correct_meaning: String = str(_challenge_entry.get("english"))
	var options: Array[String] = [correct_meaning]

	for index: int in range(1, eligible.size()):
		var other_meaning: String = str(eligible[index].get("english")).strip_edges()
		if not options.has(other_meaning):
			options.append(other_meaning)
		if options.size() >= 3:
			break

	if options.size() < 3:
		_challenge_entry = null
		return false

	options.shuffle()
	_challenge_word_label.text = "What does \"%s\" mean?" % str(_challenge_entry.get("kapampangan"))
	_challenge_hint_label.text = "Correct answer: +%d percentage points for this attempt only. A wrong answer gives no bonus." % int(BlacksmithRules.LANGUAGE_BONUS)

	for child: Node in _challenge_choices.get_children():
		child.queue_free()
	_challenge_option_buttons.clear()

	for option: String in options:
		var answer_button := _make_button(option, Vector2(0, 32))
		answer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		answer_button.pressed.connect(_on_challenge_answer.bind(option, correct_meaning))
		_challenge_choices.add_child(answer_button)
		_challenge_option_buttons.append(answer_button)

	return true


func _on_challenge_answer(selected_meaning: String, correct_meaning: String) -> void:
	if not _challenge_open or _challenge_answered:
		return

	_challenge_answered = true
	var correct: bool = selected_meaning == correct_meaning
	_challenge_bonus = BlacksmithRules.LANGUAGE_BONUS if correct else 0.0

	for button: Button in _challenge_option_buttons:
		button.disabled = true
		if button.text == correct_meaning:
			button.add_theme_color_override("font_color", Color(0.68, 0.90, 0.55, 1.0))
		elif button.text == selected_meaning and not correct:
			button.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45, 1.0))

	if correct:
		_challenge_hint_label.text = "Correct! The strike gains +%d%% chance for this attempt." % int(BlacksmithRules.LANGUAGE_BONUS)
		_status_label.text = "Mayap! Your knowledge steadies the hammer."
	else:
		_challenge_hint_label.text = "Not quite. Correct meaning: %s. No bonus this time." % correct_meaning
		_status_label.text = "The word escaped you, but you may still strike."

	var updated_info: Dictionary = BlacksmithRules.get_upgrade_info(_selected_gear, _challenge_bonus)
	var updated_chance: float = float(updated_info.get("success_chance", 0.0))
	_chance_label.text = "%d%%" % int(round(updated_chance))
	_chance_bar.value = updated_chance
	_forge_button.disabled = false
	_forge_button.text = "STRIKE NOW"

	# Choosing an answer is itself useful learning progress. Record it as
	# encountered so it can later appear in the language book and quizzes.
	if correct and is_instance_valid(LanguageProgress) and _challenge_entry != null:
		LanguageProgress.mark_encountered(str(_challenge_entry.get("id")))


func _attempt_upgrade(bonus: float) -> void:
	var result: Dictionary = BlacksmithRules.attempt_upgrade(_selected_gear, bonus)
	var attempted: bool = bool(result.get("attempted", false))
	var succeeded: bool = bool(result.get("success", false))
	var chance: float = float(result.get("chance", 0.0))
	var cost: int = int(result.get("cost", 0))

	_reset_challenge()
	_status_label.text = str(result.get("message", "The forge falls quiet."))

	if attempted:
		if succeeded:
			_status_label.text += "  Success chance was %d%%; %s Gold spent." % [int(round(chance)), _format_number(cost)]
		else:
			_status_label.text += "  Chance was %d%%; %s Gold spent." % [int(round(chance)), _format_number(cost)]

	_refresh()


func _cancel_challenge() -> void:
	if not _challenge_open:
		return
	_reset_challenge()
	_status_label.text = "Strike cancelled. No Gold was spent."
	_refresh()


func _reset_challenge() -> void:
	_challenge_open = false
	_challenge_answered = false
	_challenge_bonus = 0.0
	_challenge_entry = null
	if is_instance_valid(_challenge_panel):
		_challenge_panel.hide()
	if is_instance_valid(_forge_button):
		_forge_button.text = "TEMPA  ·  UPGRADE"
	if is_instance_valid(_challenge_choices):
		for child: Node in _challenge_choices.get_children():
			child.queue_free()
	_challenge_option_buttons.clear()


func _open_equipment() -> void:
	if not is_instance_valid(EquipmentMenuScene):
		push_warning("[BLACKSMITH] EquipmentMenu.tscn could not be loaded.")
		return

	var equipment := EquipmentMenuScene.instantiate()
	equipment.set("return_to_blacksmith", self)
	get_tree().root.add_child(equipment)
	visible = false


func _close_menu() -> void:
	if _closing:
		return
	_closing = true
	queue_free()


func _format_number(number: int) -> String:
	var source: String = str(number)
	var output: String = ""
	var digits: int = 0
	for index: int in range(source.length() - 1, -1, -1):
		output = source.substr(index, 1) + output
		digits += 1
		if digits % 3 == 0 and index > 0:
			output = "," + output
	return output
