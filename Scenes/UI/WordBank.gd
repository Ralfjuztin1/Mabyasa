extends CanvasLayer

signal closed

enum BankFilter {
	DISCOVERED,
	LEARNED
}

const INTERNAL_COMPONENT_SECTION: String = "__internal_sentence_component__"

var _current_filter: BankFilter = BankFilter.DISCOVERED
var _selected_entry_id: String = ""

var _entry_list: ItemList
var _search_edit: LineEdit
var _discovered_button: Button
var _learned_button: Button
var _count_label: Label
var _empty_label: Label

var _detail_title: Label
var _detail_english: Label
var _detail_meta: Label
var _detail_pronunciation: Label
var _detail_hint: Label
var _detail_parts: Label
var _detail_mastery: Label
var _parts_heading: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_build_ui()
	visible = false

	if is_instance_valid(LanguageProgress):
		if not LanguageProgress.progress_changed.is_connected(_on_progress_changed):
			LanguageProgress.progress_changed.connect(_on_progress_changed)

	_refresh_entries()


func _exit_tree() -> void:
	if is_instance_valid(LanguageProgress):
		if LanguageProgress.progress_changed.is_connected(_on_progress_changed):
			LanguageProgress.progress_changed.disconnect(_on_progress_changed)


func open() -> void:
	visible = true
	_refresh_entries()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_progress_changed() -> void:
	if visible:
		_refresh_entries()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "BackgroundDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.008, 0.018, 0.012, 0.88)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "WordBankPanel"
	panel.custom_minimum_size = Vector2(1060, 630)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _make_style(
		Color(0.035, 0.055, 0.041, 0.98),
		Color(0.76, 0.62, 0.33, 0.95),
		12,
		2
	))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main.add_child(header)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 2)
	header.add_child(title_column)

	var title := Label.new()
	title.text = "WORD BANK"
	title.add_theme_color_override("font_color", Color(0.96, 0.83, 0.51))
	title.add_theme_font_size_override("font_size", 30)
	title_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Your collected Kapampangan words and phrases"
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.76, 0.68))
	subtitle.add_theme_font_size_override("font_size", 14)
	title_column.add_child(subtitle)

	_count_label = Label.new()
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", Color(0.88, 0.81, 0.61))
	_count_label.add_theme_font_size_override("font_size", 14)
	header.add_child(_count_label)

	var close_button := Button.new()
	close_button.text = "CLOSE  ✕"
	close_button.custom_minimum_size = Vector2(105, 40)
	_style_button(close_button, false)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.68, 0.56, 0.31, 0.55))
	main.add_child(separator)

	# Search and filters
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	main.add_child(controls)

	_search_edit = LineEdit.new()
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.custom_minimum_size = Vector2(260, 42)
	_search_edit.placeholder_text = "Search Kapampangan or English..."
	_search_edit.clear_button_enabled = true
	_search_edit.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
	_search_edit.add_theme_color_override("font_placeholder_color", Color(0.58, 0.63, 0.56))
	_search_edit.add_theme_stylebox_override("normal", _make_style(
		Color(0.018, 0.03, 0.022, 1),
		Color(0.34, 0.42, 0.32, 0.9),
		5,
		1
	))
	_search_edit.text_changed.connect(_on_search_changed)
	controls.add_child(_search_edit)

	_discovered_button = Button.new()
	_discovered_button.text = "DISCOVERED"
	_discovered_button.custom_minimum_size = Vector2(130, 42)
	_style_button(_discovered_button, true)
	_discovered_button.pressed.connect(_set_discovered_filter)
	controls.add_child(_discovered_button)

	_learned_button = Button.new()
	_learned_button.text = "LEARNED"
	_learned_button.custom_minimum_size = Vector2(110, 42)
	_style_button(_learned_button, false)
	_learned_button.pressed.connect(_set_learned_filter)
	controls.add_child(_learned_button)

	# Two-column content
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	main.add_child(content)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(380, 0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _make_style(
		Color(0.018, 0.03, 0.023, 0.96),
		Color(0.25, 0.34, 0.25, 0.85),
		8,
		1
	))
	content.add_child(list_panel)

	# A single Control child lets us place the empty-state label over the list
	# without adding multiple direct children to PanelContainer.
	var list_overlay := Control.new()
	list_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(list_overlay)

	var list_margin := MarginContainer.new()
	list_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_margin.add_theme_constant_override("margin_left", 8)
	list_margin.add_theme_constant_override("margin_top", 8)
	list_margin.add_theme_constant_override("margin_right", 8)
	list_margin.add_theme_constant_override("margin_bottom", 8)
	list_overlay.add_child(list_margin)

	_entry_list = ItemList.new()
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_list.select_mode = ItemList.SELECT_SINGLE
	_entry_list.auto_height = false
	_entry_list.add_theme_color_override("font_color", Color(0.92, 0.92, 0.84))
	_entry_list.add_theme_color_override("font_selected_color", Color(1.0, 0.91, 0.67))
	_entry_list.add_theme_stylebox_override("panel", _make_style(
		Color(0.018, 0.03, 0.023, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		0
	))
	_entry_list.item_selected.connect(_on_entry_selected)
	list_margin.add_child(_entry_list)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_style(
		Color(0.055, 0.075, 0.052, 0.92),
		Color(0.31, 0.39, 0.26, 0.85),
		8,
		1
	))
	content.add_child(detail_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)

	var detail_margin := MarginContainer.new()
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_theme_constant_override("margin_left", 20)
	detail_margin.add_theme_constant_override("margin_top", 18)
	detail_margin.add_theme_constant_override("margin_right", 20)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	detail_scroll.add_child(detail_margin)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 9)
	detail_margin.add_child(detail)

	_detail_title = Label.new()
	_detail_title.text = "Select a word"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_color_override("font_color", Color(0.96, 0.83, 0.51))
	_detail_title.add_theme_font_size_override("font_size", 28)
	detail.add_child(_detail_title)

	_detail_english = Label.new()
	_detail_english.text = "Your word's meaning will appear here."
	_detail_english.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_english.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_detail_english.add_theme_font_size_override("font_size", 20)
	detail.add_child(_detail_english)

	_detail_meta = Label.new()
	_detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_meta.add_theme_color_override("font_color", Color(0.78, 0.81, 0.68))
	detail.add_child(_detail_meta)

	_detail_mastery = Label.new()
	_detail_mastery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_mastery.add_theme_color_override("font_color", Color(0.88, 0.75, 0.42))
	detail.add_child(_detail_mastery)

	_detail_pronunciation = Label.new()
	_detail_pronunciation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_pronunciation.add_theme_color_override("font_color", Color(0.72, 0.84, 0.72))
	detail.add_child(_detail_pronunciation)

	var hint_title := Label.new()
	hint_title.text = "NOTES"
	hint_title.add_theme_color_override("font_color", Color(0.88, 0.75, 0.42))
	hint_title.add_theme_font_size_override("font_size", 15)
	detail.add_child(hint_title)

	_detail_hint = Label.new()
	_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_hint.add_theme_color_override("font_color", Color(0.87, 0.88, 0.81))
	detail.add_child(_detail_hint)

	_parts_heading = Label.new()
	_parts_heading.text = "PHRASE COMPONENTS"
	_parts_heading.add_theme_color_override("font_color", Color(0.88, 0.75, 0.42))
	_parts_heading.add_theme_font_size_override("font_size", 15)
	detail.add_child(_parts_heading)

	_detail_parts = Label.new()
	_detail_parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_parts.add_theme_color_override("font_color", Color(0.87, 0.88, 0.81))
	detail.add_child(_detail_parts)

	_empty_label = Label.new()
	_empty_label.text = "No discovered words yet. Talk to people and learn phrases to fill your Word Bank."
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.73))
	_empty_label.add_theme_font_size_override("font_size", 17)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_label.visible = false
	list_overlay.add_child(_empty_label)

	var footer := Label.new()
	footer.text = "Words appear here when encountered in dialogue or learned through lessons. Press Esc to close."
	footer.add_theme_color_override("font_color", Color(0.62, 0.68, 0.6))
	footer.add_theme_font_size_override("font_size", 12)
	main.add_child(footer)


func _make_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


func _style_button(button: Button, active: bool) -> void:
	var normal_bg: Color = (
		Color(0.27, 0.22, 0.10, 1.0)
		if active
		else Color(0.06, 0.09, 0.06, 1.0)
	)
	var normal_border: Color = (
		Color(0.91, 0.73, 0.36, 1.0)
		if active
		else Color(0.38, 0.46, 0.34, 0.9)
	)
	button.add_theme_color_override("font_color", Color(0.94, 0.91, 0.79))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.68))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_style(
		normal_bg, normal_border, 5, 1
	))
	button.add_theme_stylebox_override("hover", _make_style(
		Color(0.24, 0.22, 0.12, 1.0), Color(0.91, 0.73, 0.36, 1.0), 5, 1
	))
	button.add_theme_stylebox_override("pressed", _make_style(
		Color(0.36, 0.29, 0.12, 1.0), Color(0.98, 0.82, 0.44, 1.0), 5, 1
	))


func _set_discovered_filter() -> void:
	_current_filter = BankFilter.DISCOVERED
	_update_filter_button_styles()
	_refresh_entries()


func _set_learned_filter() -> void:
	_current_filter = BankFilter.LEARNED
	_update_filter_button_styles()
	_refresh_entries()


func _update_filter_button_styles() -> void:
	_style_button(
		_discovered_button,
		_current_filter == BankFilter.DISCOVERED
	)
	_style_button(
		_learned_button,
		_current_filter == BankFilter.LEARNED
	)


func _on_search_changed(_new_text: String) -> void:
	_refresh_entries()


func _is_internal_entry(entry: VocabEntry) -> bool:
	return (
		entry == null
		or entry.source_section == INTERNAL_COMPONENT_SECTION
	)


func _get_displayable_entries(entries: Array[VocabEntry]) -> Array[VocabEntry]:
	var result: Array[VocabEntry] = []
	for entry: VocabEntry in entries:
		if not _is_internal_entry(entry):
			result.append(entry)
	return result


func _refresh_entries() -> void:
	if not is_instance_valid(_entry_list):
		return

	_entry_list.clear()
	_selected_entry_id = ""

	if not is_instance_valid(LanguageProgress):
		_count_label.text = "Vocabulary unavailable"
		_empty_label.visible = true
		_detail_title.text = "Word Bank unavailable"
		_detail_english.text = "LanguageProgress could not be found."
		return

	var discovered: Array[VocabEntry] = _get_displayable_entries(
		LanguageProgress.get_encountered_entries()
	)
	var learned: Array[VocabEntry] = _get_displayable_entries(
		LanguageProgress.get_learned_entries()
	)
	_count_label.text = "%d discovered  ·  %d learned" % [
		discovered.size(),
		learned.size()
	]

	var entries: Array[VocabEntry] = (
		discovered
		if _current_filter == BankFilter.DISCOVERED
		else learned
	)

	entries.sort_custom(
		func(a: VocabEntry, b: VocabEntry) -> bool:
			return a.kapampangan.to_lower() < b.kapampangan.to_lower()
	)

	var query := _search_edit.text.strip_edges().to_lower()

	for entry: VocabEntry in entries:
		if not query.is_empty():
			var searchable := (
				entry.kapampangan.to_lower()
				+ " "
				+ entry.english.to_lower()
				+ " "
				+ entry.category.to_lower()
			)
			if not searchable.contains(query):
				continue

		var english_text := (
			entry.english.strip_edges()
			if not entry.english.strip_edges().is_empty()
			else "Meaning not available"
		)
		var row_text := "%s  —  %s" % [
			entry.kapampangan,
			english_text
		]
		var index := _entry_list.add_item(row_text)
		_entry_list.set_item_metadata(index, entry.id)

	_empty_label.visible = _entry_list.item_count == 0

	if _entry_list.item_count > 0:
		_entry_list.select(0)
		_selected_entry_id = str(_entry_list.get_item_metadata(0))
		_show_entry(_selected_entry_id)
	else:
		_show_no_selection()


func _on_entry_selected(index: int) -> void:
	var entry_id := str(_entry_list.get_item_metadata(index))
	_selected_entry_id = entry_id
	_show_entry(entry_id)


func _show_no_selection() -> void:
	_detail_title.text = "No matching words"
	_detail_english.text = "Try another search, or learn more words by speaking with people around Yatu Village."
	_detail_meta.text = ""
	_detail_mastery.text = ""
	_detail_pronunciation.text = ""
	_detail_hint.text = ""
	_detail_parts.text = ""
	_parts_heading.visible = false
	_detail_parts.visible = false


func _show_entry(entry_id: String) -> void:
	if not is_instance_valid(LanguageProgress):
		return

	var entry: VocabEntry = LanguageProgress.get_entry(entry_id)
	if entry == null or _is_internal_entry(entry):
		_show_no_selection()
		return

	_detail_title.text = entry.kapampangan
	_detail_english.text = (
		entry.english.strip_edges()
		if not entry.english.strip_edges().is_empty()
		else "Meaning not available yet."
	)
	_detail_meta.text = "%s  ·  Difficulty %d" % [
		entry.category.capitalize(),
		entry.difficulty
	]

	var is_learned: bool = LanguageProgress.is_learned(entry.id)
	_detail_mastery.text = (
		"Status: Learned"
		if is_learned
		else "Status: Discovered"
	)

	var stage: int = LanguageProgress.get_stage(entry.id)
	var stage_name: String = "Not tested in battle"
	match stage:
		1:
			stage_name = "Beginning"
		2:
			stage_name = "Practicing"
		3:
			stage_name = "Mastered"
	_detail_mastery.text += "  ·  Battle mastery: " + stage_name

	_detail_pronunciation.text = (
		"Pronunciation: " + entry.pronunciation
		if not entry.pronunciation.strip_edges().is_empty()
		else ""
	)
	_detail_pronunciation.visible = not _detail_pronunciation.text.is_empty()

	_detail_hint.text = (
		entry.hint.strip_edges()
		if not entry.hint.strip_edges().is_empty()
		else "No extra notes for this entry yet."
	)

	var parts_text := PackedStringArray()
	for part_id: String in entry.parts:
		var part: VocabEntry = LanguageProgress.get_entry(part_id)
		if part == null or _is_internal_entry(part):
			continue

		var part_meaning := (
			part.english.strip_edges()
			if not part.english.strip_edges().is_empty()
			else "Meaning not available"
		)
		parts_text.append("• %s — %s" % [
			part.kapampangan,
			part_meaning
		])

	_detail_parts.text = "\n".join(parts_text)
	_parts_heading.visible = not parts_text.is_empty()
	_detail_parts.visible = not parts_text.is_empty()
