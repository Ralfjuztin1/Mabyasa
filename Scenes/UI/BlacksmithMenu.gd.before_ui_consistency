extends CanvasLayer

## Blacksmith UI for Mabiyasa. Keeps the project's existing Sprout Lands UI theme
## and delegates all costs, chance rolls, gear changes, and saving to BlacksmithRules.

const BlacksmithRules = preload("res://Scripts/Core/BlacksmithRules.gd")
const ForgeDisplayScript = preload("res://Scripts/UI/BlacksmithForgeDisplay.gd")
const EquipmentMenuScene: PackedScene = preload("res://Scenes/UI/EquipmentMenu.tscn")
const STRIKE_SOUND_PATH: String = "res://Assets/Audio/Blacksmith/forge_strike.wav"
const SUCCESS_SOUND_PATH: String = "res://Assets/Audio/Blacksmith/upgrade_success.wav"
const FAILURE_SOUND_PATH: String = "res://Assets/Audio/Blacksmith/upgrade_failure.wav"

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
const COLOR_SUCCESS: Color = Color(0.68, 0.90, 0.55, 1.0)
const COLOR_FAILURE: Color = Color(0.95, 0.55, 0.45, 1.0)
const GEAR_ORDER: Array[String] = ["sword", "armor", "helmet"]

var _theme: Theme
var _gear_list: VBoxContainer
var _gold_label: Label
var _gear_title: Label
var _gear_slot_label: Label
var _gear_description: Label
var _current_bonus_label: Label
var _chance_label: Label
var _chance_bar: ProgressBar
var _cost_label: Label
var _status_label: Label
var _forge_button: Button
var _close_button: Button
var _equipment_button: Button
var _challenge_panel: PanelContainer
var _challenge_word_label: Label
var _challenge_hint_label: Label
var _challenge_choices: VBoxContainer
var _gear_buttons: Dictionary = {}
var _current_stat_value: Label
var _next_stat_value: Label
var _forge_stage_panel: PanelContainer
var _forge_display: Control
var _sfx_player: AudioStreamPlayer

var _result_overlay: ColorRect
var _result_panel: PanelContainer
var _result_title: Label
var _result_detail: Label
var _result_before_value: Label
var _result_after_value: Label
var _result_stat_caption: Label
var _result_level_label: Label
var _result_total_stat_label: Label
var _result_continue_button: Button

var _selected_gear: String = "sword"
var _challenge_open: bool = false
var _challenge_answered: bool = false
var _challenge_bonus: float = 0.0
var _challenge_entry: Resource = null
var _challenge_option_buttons: Array[Button] = []
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _was_paused: bool = false
var _owns_pause: bool = false
var _closing: bool = false
var _forge_animating: bool = false
var _result_tween: Tween
var _upgrade_bonus_before: int = 0
var _upgrade_total_stat_before: int = 0
var _upgrade_stat_short: String = "STAT"
var _upgrade_stat_label: String = "Stat"
var _upgrade_stat_key: String = ""
var _upgrade_old_level: int = 1
var _upgrade_new_level: int = 1
var _upgrade_chance: float = 0.0
var _upgrade_cost: int = 0
var _upgrade_success: bool = false
var _upgrade_message: String = ""


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_mouse_mode = Input.mouse_mode
	_was_paused = get_tree().paused
	_owns_pause = not _was_paused

	_build_theme()
	_build_interface()
	_refresh()

	if is_instance_valid(PlayerProgression):
		if not PlayerProgression.stats_changed.is_connected(_refresh):
			PlayerProgression.stats_changed.connect(_refresh)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _owns_pause:
		get_tree().paused = true


func _exit_tree() -> void:
	if is_instance_valid(PlayerProgression) and PlayerProgression.stats_changed.is_connected(_refresh):
		PlayerProgression.stats_changed.disconnect(_refresh)
	if _owns_pause and is_inside_tree() and get_tree().paused:
		get_tree().paused = _was_paused
	if is_inside_tree() and not get_tree().paused:
		Input.set_mouse_mode(_previous_mouse_mode)


func _input(event: InputEvent) -> void:
	var root: Control = get_node_or_null("Root") as Control
	if root == null or not root.is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		if _forge_animating:
			get_viewport().set_input_as_handled()
			return
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
	frame.custom_minimum_size = Vector2(1030, 640)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(frame)

	var frame_margin := _make_margin(frame, 24, 20, 24, 16)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	frame_margin.add_child(main)

	# Header uses the same title, gold accents, textured button, and frame as EquipmentMenu.
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

	_close_button = _make_button("CLOSE  X", Vector2(96, 38))
	_close_button.pressed.connect(_close_menu)
	header.add_child(_close_button)
	main.add_child(_make_separator())

	# Main columns: gear selection on the left, detail/upgrade controls on the right.
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
	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(left_spacer)

	var rules_note := Label.new()
	rules_note.text = "A failed strike spends Gold, but never destroys your gear."
	rules_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_note.add_theme_color_override("font_color", COLOR_MUTED)
	rules_note.add_theme_font_size_override("font_size", 11)
	left_box.add_child(rules_note)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_DETAIL))
	body.add_child(right_panel)

	var right_margin := _make_margin(right_panel, 18, 12, 18, 10)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 7)
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
	_gear_description.custom_minimum_size = Vector2(0, 34)
	_gear_description.add_theme_color_override("font_color", COLOR_MUTED)
	right_box.add_child(_gear_description)
	right_box.add_child(_make_separator())

	var stats_heading := Label.new()
	stats_heading.text = "TEMPERING PREVIEW"
	stats_heading.add_theme_color_override("font_color", COLOR_GOLD)
	stats_heading.add_theme_font_size_override("font_size", 14)
	right_box.add_child(stats_heading)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	right_box.add_child(stats_row)
	var current_box := _make_stat_card("CURRENT GEAR BONUS")
	current_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(current_box)
	_current_stat_value = current_box.find_child("Value", true, false) as Label
	var next_box := _make_stat_card("AFTER SUCCESS")
	next_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(next_box)
	_next_stat_value = next_box.find_child("Value", true, false) as Label

	# This space is only shown during the forging animation, so it does not crowd the quiz.
	_forge_stage_panel = PanelContainer.new()
	_forge_stage_panel.visible = false
	_forge_stage_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	right_box.add_child(_forge_stage_panel)
	var forge_margin := _make_margin(_forge_stage_panel, 6, 5, 6, 5)
	_forge_display = Control.new()
	_forge_display.name = "ForgeDisplay"
	_forge_display.set_script(ForgeDisplayScript)
	_forge_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forge_display.custom_minimum_size = Vector2(0, 108)
	forge_margin.add_child(_forge_display)

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
	_cost_label.add_theme_font_size_override("font_size", 15)
	right_box.add_child(_cost_label)

	# Kapampangan bonus quiz remains before any forging/Gold deduction.
	_challenge_panel = PanelContainer.new()
	_challenge_panel.visible = false
	_challenge_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	right_box.add_child(_challenge_panel)
	var challenge_margin := _make_margin(_challenge_panel, 10, 7, 10, 7)
	var challenge_box := VBoxContainer.new()
	challenge_box.add_theme_constant_override("separation", 5)
	challenge_margin.add_child(challenge_box)

	var challenge_title := Label.new()
	challenge_title.text = "PANDAY'S CALL  ·  KAPAMPANGAN BONUS"
	challenge_title.add_theme_color_override("font_color", COLOR_GOLD)
	challenge_title.add_theme_font_size_override("font_size", 12)
	challenge_box.add_child(challenge_title)
	_challenge_word_label = Label.new()
	_challenge_word_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_word_label.add_theme_color_override("font_color", COLOR_TEXT)
	_challenge_word_label.add_theme_font_size_override("font_size", 14)
	challenge_box.add_child(_challenge_word_label)
	_challenge_hint_label = Label.new()
	_challenge_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_hint_label.add_theme_color_override("font_color", COLOR_MUTED)
	_challenge_hint_label.add_theme_font_size_override("font_size", 11)
	challenge_box.add_child(_challenge_hint_label)
	_challenge_choices = VBoxContainer.new()
	_challenge_choices.add_theme_constant_override("separation", 3)
	challenge_box.add_child(_challenge_choices)
	var cancel_challenge_button := _make_button("CANCEL STRIKE", Vector2(0, 29))
	cancel_challenge_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_challenge_button.pressed.connect(_cancel_challenge)
	challenge_box.add_child(cancel_challenge_button)

	main.add_child(_make_separator())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	main.add_child(footer)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	footer.add_child(_status_label)
	_equipment_button = _make_button("MY EQUIPMENT", Vector2(142, 40))
	_equipment_button.pressed.connect(_open_equipment)
	footer.add_child(_equipment_button)
	_forge_button = _make_button("TEMPA  ·  UPGRADE", Vector2(190, 40))
	_forge_button.pressed.connect(_on_forge_pressed)
	footer.add_child(_forge_button)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "ForgeSFX"
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = -5.0
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)

	_build_result_overlay(root)
	_rebuild_gear_list()


func _build_result_overlay(root: Control) -> void:
	_result_overlay = ColorRect.new()
	_result_overlay.name = "ForgeResultOverlay"
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0.015, 0.02, 0.015, 0.0)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.visible = false
	root.add_child(_result_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.add_child(center)

	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(500, 300)
	_result_panel.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(_result_panel)

	var margin := _make_margin(_result_panel, 24, 20, 24, 20)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_color_override("font_color", COLOR_GOLD)
	_result_title.add_theme_font_size_override("font_size", 25)
	stack.add_child(_result_title)
	_result_detail = Label.new()
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_detail.add_theme_color_override("font_color", COLOR_MUTED)
	_result_detail.add_theme_font_size_override("font_size", 13)
	stack.add_child(_result_detail)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 10)
	stack.add_child(stat_row)
	var before_card := _make_result_stat_card(stat_row, "BEFORE")
	_result_before_value = before_card.find_child("Value", true, false) as Label
	var after_card := _make_result_stat_card(stat_row, "AFTER")
	_result_after_value = after_card.find_child("Value", true, false) as Label
	_result_stat_caption = Label.new()
	_result_stat_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_stat_caption.add_theme_color_override("font_color", COLOR_GOLD)
	_result_stat_caption.add_theme_font_size_override("font_size", 12)
	stack.add_child(_result_stat_caption)
	_result_level_label = Label.new()
	_result_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_level_label.add_theme_color_override("font_color", COLOR_GOLD)
	_result_level_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(_result_level_label)
	_result_total_stat_label = Label.new()
	_result_total_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_total_stat_label.add_theme_color_override("font_color", COLOR_TEXT)
	_result_total_stat_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(_result_total_stat_label)
	_result_continue_button = _make_button("CONTINUE", Vector2(160, 40))
	_result_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_continue_button.pressed.connect(_dismiss_result_overlay)
	stack.add_child(_result_continue_button)


func _make_result_stat_card(parent: HBoxContainer, heading_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	parent.add_child(card)
	var margin := _make_margin(card, 10, 9, 10, 9)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = heading_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", COLOR_MUTED)
	heading.add_theme_font_size_override("font_size", 11)
	box.add_child(heading)
	var value := Label.new()
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", COLOR_TEXT)
	value.add_theme_font_size_override("font_size", 20)
	box.add_child(value)
	return card


func _make_stat_card(heading_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	var margin := _make_margin(panel, 10, 7, 10, 7)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_color_override("font_color", COLOR_MUTED)
	heading.add_theme_font_size_override("font_size", 10)
	box.add_child(heading)
	var value := Label.new()
	value.name = "Value"
	value.add_theme_color_override("font_color", COLOR_TEXT)
	value.add_theme_font_size_override("font_size", 16)
	box.add_child(value)
	return panel


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
		var button_text: String = "%s\nLEVEL %d / %d" % [str(info.get("name", gear_type.capitalize())), level, BlacksmithRules.MAX_GEAR_LEVEL]
		var button := _make_button(button_text, Vector2(0, 68))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("normal", _make_button_style(gear_type == _selected_gear))
		button.add_theme_stylebox_override("hover", _make_button_style(true))
		button.add_theme_stylebox_override("pressed", _make_button_style(true))
		button.pressed.connect(_select_gear.bind(gear_type))
		button.disabled = _forge_animating
		_gear_list.add_child(button)
		_gear_buttons[gear_type] = button


func _refresh() -> void:
	if not is_instance_valid(_gear_list) or not is_instance_valid(_forge_button):
		return
	if is_instance_valid(PlayerProgression):
		_gold_label.text = "%s G" % _format_number(int(PlayerProgression.gold))
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
	var chance: float = float(info.get("base_success_chance", 0.0))
	var has_progression: bool = is_instance_valid(PlayerProgression)
	var gold: int = int(PlayerProgression.gold) if has_progression else 0

	_gear_title.text = str(info.get("name", _selected_gear.capitalize()))
	_gear_slot_label.text = "%s  ·  LEVEL %d / %d" % [str(info.get("slot", "GEAR")), current_level, BlacksmithRules.MAX_GEAR_LEVEL]
	_gear_description.text = str(info.get("description", ""))
	_current_bonus_label.text = "LEVEL %d" % current_level
	_current_stat_value.text = "+%d %s" % [current_bonus, stat_short]
	_next_stat_value.text = "MAXED" if is_max else "+%d %s" % [next_bonus, stat_short]
	_chance_label.text = "MAX LEVEL" if is_max else "%d%%" % int(round(chance))
	_chance_bar.value = chance
	_cost_label.text = "Cost: %s Gold" % _format_number(cost) if not is_max else "No further upgrades available."

	_forge_button.text = "MAX LEVEL" if is_max else ("NEED MORE GOLD" if gold < cost else "TEMPA  ·  UPGRADE")
	_forge_button.disabled = _forge_animating or is_max or not has_progression or gold < cost or _challenge_open and not _challenge_answered
	_equipment_button.disabled = _forge_animating
	_close_button.disabled = _forge_animating
	for gear_type: String in _gear_buttons:
		var gear_button: Button = _gear_buttons[gear_type] as Button
		if is_instance_valid(gear_button):
			gear_button.disabled = _forge_animating
	if not _challenge_open and _status_label.text.is_empty():
		_status_label.text = str(info.get("flavor", "Choose a piece of gear to temper."))


func _select_gear(gear_type: String) -> void:
	if _forge_animating or not BlacksmithRules.GEAR_DATA.has(gear_type):
		return
	_selected_gear = gear_type
	if _challenge_open:
		_reset_challenge()
	_status_label.text = str(BlacksmithRules.get_gear_definition(gear_type).get("flavor", ""))
	_refresh()


func _on_forge_pressed() -> void:
	if _forge_animating:
		return
	if _challenge_open:
		if not _challenge_answered:
			_status_label.text = "Answer the forge call first, or cancel to leave without spending Gold."
			return
		_attempt_upgrade(_challenge_bonus)
		return

	var info: Dictionary = BlacksmithRules.get_upgrade_info(_selected_gear)
	if info.is_empty() or bool(info.get("is_max_level", false)):
		return
	if not is_instance_valid(PlayerProgression) or int(PlayerProgression.gold) < int(info.get("cost", 0)):
		_status_label.text = "Not enough Gold. No attempt has been made."
		return

	if _prepare_language_challenge():
		_challenge_open = true
		_challenge_answered = false
		_challenge_bonus = 0.0
		_challenge_panel.show()
		_forge_button.text = "ANSWER TO TEMPER"
		_forge_button.disabled = true
		_status_label.text = "Answer correctly for a temporary success-chance bonus."
	else:
		# Accounts with too few encountered vocabulary entries can still upgrade gear.
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
	var correct_meaning: String = str(_challenge_entry.get("english")).strip_edges()
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
	_challenge_hint_label.text = "Correct answer: +%d percentage points for this attempt only." % int(BlacksmithRules.LANGUAGE_BONUS)
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
	if not _challenge_open or _challenge_answered or _forge_animating:
		return
	_challenge_answered = true
	var correct: bool = selected_meaning == correct_meaning
	_challenge_bonus = BlacksmithRules.LANGUAGE_BONUS if correct else 0.0
	for button: Button in _challenge_option_buttons:
		button.disabled = true
		if button.text == correct_meaning:
			button.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif button.text == selected_meaning and not correct:
			button.add_theme_color_override("font_color", COLOR_FAILURE)
	if correct:
		_challenge_hint_label.text = "Correct! +%d%% chance for this attempt." % int(BlacksmithRules.LANGUAGE_BONUS)
		_status_label.text = "Mayap! Your knowledge steadies the hammer."
		if is_instance_valid(LanguageProgress) and _challenge_entry != null:
			LanguageProgress.mark_encountered(str(_challenge_entry.get("id")))
	else:
		_challenge_hint_label.text = "Not quite. The meaning is: %s. No bonus this time." % correct_meaning
		_status_label.text = "The word escaped you, but you may still strike."
	var updated_info: Dictionary = BlacksmithRules.get_upgrade_info(_selected_gear, _challenge_bonus)
	var updated_chance: float = float(updated_info.get("success_chance", 0.0))
	_chance_label.text = "%d%%" % int(round(updated_chance))
	_chance_bar.value = updated_chance
	_forge_button.disabled = false
	_forge_button.text = "TEMPA  ·  STRIKE"


func _attempt_upgrade(bonus: float) -> void:
	if _forge_animating:
		return
	var before_info: Dictionary = BlacksmithRules.get_upgrade_info(_selected_gear, bonus)
	if before_info.is_empty():
		return

	_upgrade_old_level = int(before_info.get("current_level", 1))
	_upgrade_bonus_before = BlacksmithRules.get_current_gear_bonus(_selected_gear)
	_upgrade_stat_key = str(before_info.get("stat_key", ""))
	_upgrade_stat_short = str(before_info.get("stat_short", "STAT"))
	_upgrade_stat_label = str(before_info.get("stat_label", "Stat"))
	_upgrade_total_stat_before = BlacksmithRules.get_current_player_stat(_upgrade_stat_key)
	_upgrade_success = false
	_upgrade_chance = float(before_info.get("success_chance", 0.0))
	_upgrade_cost = int(before_info.get("cost", 0))

	# Lock input before making the one authoritative upgrade attempt.
	_forge_animating = true
	_refresh()
	_status_label.text = "The panday raises the hammer..."
	var result: Dictionary = BlacksmithRules.attempt_upgrade(_selected_gear, bonus)
	if not bool(result.get("attempted", false)):
		_forge_animating = false
		_reset_challenge()
		_status_label.text = str(result.get("message", "The forge falls quiet."))
		_refresh()
		return

	_upgrade_success = bool(result.get("success", false))
	_upgrade_chance = float(result.get("chance", _upgrade_chance))
	_upgrade_cost = int(result.get("cost", _upgrade_cost))
	_upgrade_old_level = int(result.get("old_level", _upgrade_old_level))
	_upgrade_new_level = int(result.get("new_level", _upgrade_old_level))
	_upgrade_message = str(result.get("message", "The forge falls quiet."))
	_reset_challenge()
	_refresh()
	await _play_forge_sequence()


func _play_forge_sequence() -> void:
	_forge_stage_panel.show()
	_result_overlay.hide()
	_forge_display.call("set_forge_state", 0, 0.0, 0)
	_chance_bar.value = 0.0
	_chance_label.text = "%d%%" % int(round(_upgrade_chance))

	# 3 sequential strikes: each has an impact sound, a visual swing, sparks, and bar motion.
	for strike: int in range(1, 4):
		_forge_display.call("set_forge_state", strike, 0.0, 0)
		_play_sfx(STRIKE_SOUND_PATH)
		var target_chance: float = _upgrade_chance * float(strike) / 3.0
		var strike_tween := create_tween()
		strike_tween.set_parallel(true)
		strike_tween.tween_property(_forge_display, "animation_progress", 1.0, 0.34)
		strike_tween.tween_property(_chance_bar, "value", target_chance, 0.34)
		strike_tween.set_parallel(false)
		strike_tween.tween_callback(func() -> void: _forge_display.call("set_forge_state", strike, 1.0, 0))
		await strike_tween.finished
		await get_tree().create_timer(0.16).timeout

	_forge_display.call("set_forge_state", 3, 1.0, 1 if _upgrade_success else -1)
	_play_sfx(SUCCESS_SOUND_PATH if _upgrade_success else FAILURE_SOUND_PATH)
	await get_tree().create_timer(0.20).timeout
	await _show_upgrade_result()


func _show_upgrade_result() -> void:
	_forge_stage_panel.hide()
	_result_overlay.visible = true
	_result_overlay.color = Color(0.015, 0.02, 0.015, 0.0)
	_result_title.text = "UPGRADE SUCCESSFUL!" if _upgrade_success else "TEMPERING FAILED"
	_result_title.add_theme_color_override("font_color", COLOR_SUCCESS if _upgrade_success else COLOR_FAILURE)
	_result_detail.text = "%s Gold spent  ·  %d%% success chance" % [_format_number(_upgrade_cost), int(round(_upgrade_chance))]
	_result_before_value.text = "+%d %s" % [_upgrade_bonus_before, _upgrade_stat_short]
	_result_after_value.text = "+%d %s" % [_upgrade_bonus_before, _upgrade_stat_short]
	_result_stat_caption.text = "%s gear bonus" % _upgrade_stat_label
	_result_level_label.text = "LEVEL %d  →  LEVEL %d" % [_upgrade_old_level, _upgrade_new_level] if _upgrade_success else "LEVEL %d  ·  UNCHANGED" % _upgrade_old_level
	var after_total: int = BlacksmithRules.get_current_player_stat(_upgrade_stat_key)
	if _upgrade_success:
		_result_total_stat_label.text = "Total %s: %d → %d" % [_upgrade_stat_label, _upgrade_total_stat_before, after_total]
	else:
		_result_total_stat_label.text = "Your gear is safe. No level was lost."
	_result_continue_button.disabled = true
	_result_panel.scale = Vector2(0.94, 0.94)
	_result_panel.pivot_offset = _result_panel.size / 2.0
	_result_overlay.color = Color(0.015, 0.02, 0.015, 0.0)
	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(_result_overlay, "color", Color(0.015, 0.02, 0.015, 0.86), 0.22)
	reveal.tween_property(_result_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.set_parallel(false)
	await reveal.finished

	var bonus_after: int = BlacksmithRules.get_current_gear_bonus(_selected_gear)
	if _upgrade_success:
		var count_tween := create_tween()
		count_tween.tween_method(_set_animated_bonus.bind(bonus_after), float(_upgrade_bonus_before), float(bonus_after), 0.55)
		await count_tween.finished
		_result_continue_button.disabled = false
	else:
		_result_after_value.text = "UNCHANGED"
	_result_continue_button.disabled = false
	_status_label.text = _upgrade_message
	_refresh()


func _set_animated_bonus(value: float, final_bonus: int) -> void:
	_result_after_value.text = "+%d %s" % [int(round(value)), _upgrade_stat_short]
	if is_equal_approx(value, float(final_bonus)):
		_result_after_value.add_theme_color_override("font_color", COLOR_SUCCESS)


func _dismiss_result_overlay() -> void:
	if not is_instance_valid(_result_overlay) or not _forge_animating:
		return
	if _result_tween and _result_tween.is_running():
		_result_tween.kill()
	_result_tween = create_tween()
	_result_tween.tween_property(_result_overlay, "color", Color(0.015, 0.02, 0.015, 0.0), 0.18)
	await _result_tween.finished
	_result_overlay.hide()
	_forge_display.call("set_forge_state", 0, 0.0, 0)
	_forge_animating = false
	_result_title.add_theme_color_override("font_color", COLOR_GOLD)
	_result_after_value.add_theme_color_override("font_color", COLOR_TEXT)
	_refresh()


func _play_sfx(resource_path: String) -> void:
	if not is_instance_valid(_sfx_player):
		return

	# Load audio only at runtime. Missing or not-yet-imported optional sound
	# assets must never prevent this menu script from parsing.
	if not ResourceLoader.exists(resource_path):
		return

	var stream: AudioStream = load(resource_path) as AudioStream
	if stream == null:
		return

	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.play()


func _cancel_challenge() -> void:
	if not _challenge_open or _forge_animating:
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
	if _forge_animating or _challenge_open:
		return
	if EquipmentMenuScene == null:
		push_warning("[BLACKSMITH] EquipmentMenu.tscn could not be loaded.")
		return
	var equipment := EquipmentMenuScene.instantiate()
	equipment.set("return_to_blacksmith", self)
	get_tree().root.add_child(equipment)
	visible = false


func _close_menu() -> void:
	if _closing or _forge_animating:
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
