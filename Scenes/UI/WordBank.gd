extends CanvasLayer

## Word Bank controller. Layout is authored in WordBank.tscn; this script manages state, data,
## and the state-driven styling (active filters, selected row, status colors).
##
## Sizing note: the project stretches the 1280x720 base viewport to 1920x1080 (a 1.5x scale), so every
## pixel value in this file and in the scenes is in base units. A 12 px font renders at about 18 px.
signal closed

enum ViewFilter { ALL, TO_LEARN, LEARNED }
enum SortMode { A_TO_Z, NEEDS_PRACTICE }

const INTERNAL_COMPONENT_SECTION := "__internal_sentence_component__"
const ALL_CATEGORIES_KEY := "__all_categories__"
const FAVORITES_PATH := "user://mabiyasa_word_bank.cfg"
## true = pixel font for the big word (capitals only, that is how the font is drawn).
## false = readable body font with normal upper/lower case.
const TITLE_PIXEL_FONT := true
const MASTERY_TARGET := 7
const ROW_HEIGHT := 46
const ENTRY_ROW_SCENE: PackedScene = preload("res://Scenes/UI/WordBankEntryRow.tscn")
const PART_CARD_SCENE: PackedScene = preload("res://Scenes/UI/WordBankPartCard.tscn")

# Scene paths (relative to this CanvasLayer).
const P_MAIN := "WordBankRoot/OuterFrame/OuterMargin/Main"
const P_SIDEBAR := P_MAIN + "/MainBody/WordListSidebar"
const P_DETAIL_FRAME := P_MAIN + "/MainBody/EntryDetailFrame"
const P_DETAIL := P_DETAIL_FRAME + "/DetailScroll/DetailMargin/Detail"
const P_PROGRESS := P_DETAIL + "/EntryProgressPanel/ProgressContent"
const P_STEPS := P_PROGRESS + "/ProgressOuter/ProgressLeft/ProgressSteps"

# Palette. The detail panel owns the gold; the sidebar stays in quiet greens and greys so the
# selected word is always the loudest thing on screen.
const C_BG := Color(0.035, 0.055, 0.041, 1.0)
const C_BG_DARK := Color(0.025, 0.038, 0.029, 1.0)
const C_BG_PANEL := Color(0.063, 0.094, 0.070, 1.0)
const C_BG_DETAIL := Color(0.106, 0.157, 0.125, 1.0)
const C_BG_NEXT := Color(0.102, 0.145, 0.114, 1.0)
const C_BG_ROW := Color(0.075, 0.110, 0.082, 1.0)
const C_BG_ROW_SELECTED := Color(0.133, 0.188, 0.149, 1.0)
const C_BG_SEGMENT_ACTIVE := Color(0.149, 0.212, 0.169, 1.0)
const C_BG_GOLD := Color(0.23, 0.18, 0.075, 1.0)
const C_GOLD := Color(0.94, 0.70, 0.25, 1.0)
const C_GOLD_DIM := Color(0.478, 0.384, 0.157, 1.0)
const C_DARK_TEXT := Color(0.10, 0.08, 0.02, 1.0)
const C_TEXT := Color(0.94, 0.92, 0.83, 1.0)
const C_TEXT_SOFT := Color(0.91, 0.88, 0.80, 1.0)
const C_MUTED := Color(0.66, 0.71, 0.63, 1.0)
const C_MUTED_SOFT := Color(0.71, 0.75, 0.69, 1.0)
const C_MUTED_DIM := Color(0.56, 0.60, 0.545, 1.0)
const C_BORDER := Color(0.22, 0.31, 0.23, 1.0)
const C_BORDER_SOFT := Color(0.125, 0.176, 0.137, 1.0)
const C_BORDER_CHIP := Color(0.18, 0.247, 0.20, 1.0)
const C_BORDER_ACTIVE := Color(0.29, 0.37, 0.31, 1.0)
const C_BORDER_STRONG := Color(0.43, 0.52, 0.45, 1.0)
const C_OUTLINE_EMPTY := Color(0.357, 0.439, 0.376, 1.0)
const C_GREEN := Color(0.43, 0.82, 0.60, 1.0)
const C_BLUE := Color(0.45, 0.73, 0.90, 1.0)
const C_CORAL := Color(0.91, 0.54, 0.43, 1.0)
const C_AMBER := Color(0.94, 0.72, 0.30, 1.0)
const C_CLEAR := Color(0, 0, 0, 0)

var _view_filter: ViewFilter = ViewFilter.ALL
var _sort_mode: SortMode = SortMode.A_TO_Z
var _active_category: String = ALL_CATEGORIES_KEY
var _selected_entry_id: String = ""
var _favorites: Dictionary = {}
var _current_entry: VocabEntry = null

@onready var _outer_frame: PanelContainer = $WordBankRoot/OuterFrame
@onready var _list_frame: PanelContainer = get_node(P_SIDEBAR + "/VocabularyListFrame")
@onready var _detail_frame: PanelContainer = get_node(P_DETAIL_FRAME)
@onready var _search_edit: LineEdit = get_node(P_SIDEBAR + "/SearchEdit")
@onready var _status_panel: PanelContainer = get_node(P_SIDEBAR + "/StatusPanel")
@onready var _all_button: Button = get_node(P_SIDEBAR + "/StatusPanel/StatusRow/AllButton")
@onready var _to_learn_button: Button = get_node(P_SIDEBAR + "/StatusPanel/StatusRow/ToLearnButton")
@onready var _learned_button: Button = get_node(P_SIDEBAR + "/StatusPanel/StatusRow/LearnedButton")
@onready var _category_flow: HFlowContainer = get_node(P_SIDEBAR + "/CategoryFlow")
@onready var _entries_container: VBoxContainer = get_node(P_SIDEBAR + "/VocabularyListFrame/ListOverlay/VocabularyScroll/EntriesContainer")
@onready var _empty_label: Label = get_node(P_SIDEBAR + "/VocabularyListFrame/ListOverlay/EmptyLabel")
@onready var _count_label: Label = get_node(P_SIDEBAR + "/ListHeader/CountLabel")
@onready var _sort_button: Button = get_node(P_SIDEBAR + "/ListHeader/SortButton")
@onready var _summary_label: Label = get_node(P_MAIN + "/Header/ProgressStack/SummaryLabel")
@onready var _learned_segments: HBoxContainer = get_node(P_MAIN + "/Header/ProgressStack/LearnedSegments")
@onready var _progress_legend: RichTextLabel = get_node(P_MAIN + "/Header/ProgressStack/ProgressLegend")
@onready var _close_button: Button = get_node(P_MAIN + "/Header/CloseButton")
@onready var _favorite_button: Button = get_node(P_DETAIL + "/DetailTop/FavoriteButton")
@onready var _hear_button: Button = get_node(P_DETAIL + "/MeaningRow/HearButton")
@onready var _meaning_spacer: Control = get_node(P_DETAIL + "/MeaningRow/MeaningSpacer")
@onready var _audio_status: Label = get_node(P_DETAIL + "/AudioStatus")
@onready var _detail_category_panel: PanelContainer = get_node(P_DETAIL + "/DetailTop/TagStack/DetailCategoryPanel")
@onready var _detail_category: Label = get_node(P_DETAIL + "/DetailTop/TagStack/DetailCategoryPanel/DetailCategory")
@onready var _detail_difficulty: Label = get_node(P_DETAIL + "/DetailTop/TagStack/DetailDifficulty")
@onready var _detail_title: Label = get_node(P_DETAIL + "/DetailTitle")
@onready var _detail_english: Label = get_node(P_DETAIL + "/MeaningRow/DetailEnglish")
@onready var _detail_pronunciation: Label = get_node(P_DETAIL + "/DetailPronunciation")
@onready var _detail_hint: Label = get_node(P_DETAIL + "/ExplanationRow/UsagePanel/UsageStack/UsageBox/DetailHint")
@onready var _detail_parts_heading: Label = get_node(P_DETAIL + "/ExplanationRow/PartsPanel/PartsStack/DetailPartsHeading")
@onready var _parts_panel: PanelContainer = get_node(P_DETAIL + "/ExplanationRow/PartsPanel")
@onready var _parts_flow: HFlowContainer = get_node(P_DETAIL + "/ExplanationRow/PartsPanel/PartsStack/PartsFlow")
@onready var _usage_panel: PanelContainer = get_node(P_DETAIL + "/ExplanationRow/UsagePanel")
@onready var _usage_box: PanelContainer = get_node(P_DETAIL + "/ExplanationRow/UsagePanel/UsageStack/UsageBox")
@onready var _progress_panel: PanelContainer = get_node(P_DETAIL + "/EntryProgressPanel")
@onready var _practice_count: Label = get_node(P_PROGRESS + "/ProgressOuter/Practice/PracticeCount")
@onready var _practice_bar: ProgressBar = get_node(P_PROGRESS + "/ProgressOuter/Practice/PracticeBar")
@onready var _practice_subtitle: Label = get_node(P_PROGRESS + "/ProgressOuter/Practice/PracticeSubtitle")
@onready var _feedback_label: Label = get_node(P_PROGRESS + "/FeedbackLabel")

var _progress_cards: Array = []
var _progress_icons: Array = []
var _progress_titles: Array = []
var _progress_descriptions: Array = []
var _entry_rows: Array[PanelContainer] = []
var _entry_row_ids: Array[String] = []
var _category_buttons: Array[Button] = []
var _category_button_keys: Array[String] = []
var _category_button_counts: Array[int] = []
var _voice_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_bind_ui()
	_load_favorites()
	visible = false

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "WordPronunciationPlayer"
	_voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_voice_player)

	if is_instance_valid(LanguageProgress):
		if not LanguageProgress.progress_changed.is_connected(_on_progress_changed):
			LanguageProgress.progress_changed.connect(_on_progress_changed)

	_refresh_entries(true)


func _bind_ui() -> void:
	if not TITLE_PIXEL_FONT:
		_detail_title.remove_theme_font_override("font")
	_search_edit.text_changed.connect(_on_search_changed)
	_all_button.pressed.connect(_set_filter.bind(ViewFilter.ALL))
	_to_learn_button.pressed.connect(_set_filter.bind(ViewFilter.TO_LEARN))
	_learned_button.pressed.connect(_set_filter.bind(ViewFilter.LEARNED))
	_sort_button.pressed.connect(_toggle_sort)
	_favorite_button.pressed.connect(_toggle_favorite)
	_hear_button.pressed.connect(_on_hear_pressed)
	_close_button.pressed.connect(close)

	# Progress stepper nodes are real scene nodes, so layout and text stay editable in the inspector.
	var steps := get_node(P_STEPS)
	for card_name: String in ["DiscoveredCard", "LearnedCard", "MasteredCard"]:
		var card := steps.get_node(card_name) as PanelContainer
		_progress_cards.append(card)
		_progress_icons.append(card.get_node("CardStack/ProgressIcon"))
		_progress_titles.append(card.get_node("CardStack/ProgressTitle"))
		_progress_descriptions.append(card.get_node("CardStack/ProgressDescription"))

	# Only stateful or shared styling is applied here. Base layout, spacing and sizes live in the scene.
	_outer_frame.add_theme_stylebox_override("panel", _style(C_BG, C_GOLD, 12, 2, 4, 4))
	# The list sits directly on the background (no frame) so the rows read as the only boxes on the left.
	_list_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# The detail frame is lighter than everything else and carries a dim gold border, so the eye lands there first.
	_detail_frame.add_theme_stylebox_override("panel", _style(C_BG_DETAIL, C_GOLD_DIM, 10, 1, 0, 0))
	_status_panel.add_theme_stylebox_override("panel", _style(C_BG_DARK, C_BORDER_SOFT, 9, 1, 3, 3))
	_detail_category_panel.add_theme_stylebox_override("panel", _style(C_BG_PANEL, C_BORDER, 12, 1, 10, 3))
	# "How it's built" and "How to use it": heading above, boxes below (like the design), not one big frame.
	_parts_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_usage_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_usage_box.add_theme_stylebox_override("panel", _style(C_BG_PANEL, C_BORDER, 8, 1, 12, 9))
	_progress_panel.add_theme_stylebox_override("panel", _style(C_BG_PANEL, C_BORDER, 9, 1, 16, 12))
	_practice_bar.add_theme_stylebox_override("background", _style(C_BG_DARK, C_BORDER, 3, 1, 0, 0))
	_practice_bar.add_theme_stylebox_override("fill", _style(C_GOLD, C_GOLD, 3, 0, 0, 0))
	_practice_bar.max_value = MASTERY_TARGET
	_feedback_label.add_theme_stylebox_override("normal", _style(C_BG_NEXT, C_CLEAR, 7, 0, 10, 6))

	# Progress dots are Labels drawn as circles (a Label can carry its own background stylebox).
	for icon in _progress_icons:
		var dot := icon as Label
		dot.custom_minimum_size = Vector2(28, 28)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 15)

	_style_search(_search_edit)
	_add_search_icon(_search_edit)
	_style_outline_button(_close_button)
	_style_primary_button(_hear_button)
	_style_button(_favorite_button, false, 12)
	_style_segment_button(_all_button, true)
	_style_segment_button(_to_learn_button, false)
	_style_segment_button(_learned_button, false)
	_sort_button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.5, 1.0))


func _exit_tree() -> void:
	if is_instance_valid(LanguageProgress):
		if LanguageProgress.progress_changed.is_connected(_on_progress_changed):
			LanguageProgress.progress_changed.disconnect(_on_progress_changed)


func open() -> void:
	visible = true
	_refresh_entries(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Label widths are only known after the first layout pass, so fit the title again then.
	await get_tree().process_frame
	_refit_title()


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_voice_player):
		_voice_player.stop()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_progress_changed() -> void:
	if visible:
		_refresh_entries(true)


# -----------------------------------------------------------------------------
# STYLE HELPERS
# -----------------------------------------------------------------------------

func _style(background: Color, border: Color, radius: int, border_width: int, pad_x: float = 8.0, pad_y: float = 6.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


func _set_button_colors(button: Button, normal: Color, hover: Color, pressed: Color) -> void:
	button.add_theme_color_override("font_color", normal)
	button.add_theme_color_override("font_focus_color", normal)
	button.add_theme_color_override("font_hover_color", hover)
	button.add_theme_color_override("font_pressed_color", pressed)
	button.add_theme_color_override("font_disabled_color", C_MUTED_DIM)


# Gold-tinted button. Used for Favorite, where "active" means favorited.
func _style_button(button: Button, active: bool, font_size: int = 12) -> void:
	_set_button_colors(button, C_TEXT, Color(1.0, 0.93, 0.72, 1.0), Color(1.0, 0.93, 0.72, 1.0))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _style(C_BG_GOLD if active else C_CLEAR, C_GOLD if active else C_BORDER_ACTIVE, 9, 1, 10, 4))
	button.add_theme_stylebox_override("hover", _style(Color(0.18, 0.20, 0.12, 1.0), C_GOLD, 9, 1, 10, 4))
	button.add_theme_stylebox_override("pressed", _style(Color(0.28, 0.22, 0.09, 1.0), C_GOLD, 9, 1, 10, 4))
	button.add_theme_stylebox_override("focus", _style(Color(0.18, 0.20, 0.12, 1.0), C_TEXT, 9, 1, 10, 4))
	button.add_theme_stylebox_override("disabled", _style(C_CLEAR, C_BORDER_SOFT, 9, 1, 10, 4))


# Solid gold call-to-action (Hear it).
func _style_primary_button(button: Button) -> void:
	_set_button_colors(button, C_DARK_TEXT, C_DARK_TEXT, C_DARK_TEXT)
	button.add_theme_stylebox_override("normal", _style(C_GOLD, C_GOLD, 9, 1, 14, 5))
	button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.78, 0.34, 1.0), Color(1.0, 0.78, 0.34, 1.0), 9, 1, 14, 5))
	button.add_theme_stylebox_override("pressed", _style(Color(0.82, 0.60, 0.18, 1.0), Color(0.82, 0.60, 0.18, 1.0), 9, 1, 14, 5))
	button.add_theme_stylebox_override("focus", _style(C_GOLD, C_TEXT, 9, 1, 14, 5))
	button.add_theme_stylebox_override("disabled", _style(C_BG_PANEL, C_BORDER, 9, 1, 14, 5))


# Transparent button with a gold outline (Close).
func _style_outline_button(button: Button) -> void:
	_set_button_colors(button, C_TEXT, Color(1.0, 0.93, 0.72, 1.0), Color(1.0, 0.93, 0.72, 1.0))
	button.add_theme_stylebox_override("normal", _style(C_CLEAR, C_GOLD, 9, 1, 10, 5))
	button.add_theme_stylebox_override("hover", _style(Color(0.2, 0.17, 0.08, 1.0), C_GOLD, 9, 1, 10, 5))
	button.add_theme_stylebox_override("pressed", _style(Color(0.28, 0.22, 0.09, 1.0), C_GOLD, 9, 1, 10, 5))
	button.add_theme_stylebox_override("focus", _style(C_CLEAR, C_TEXT, 9, 1, 10, 5))


# Segmented status tabs (All / To learn / Learned). Active is a soft green-grey, never gold.
func _style_segment_button(button: Button, active: bool) -> void:
	_set_button_colors(button, C_TEXT if active else C_MUTED, C_TEXT, C_TEXT)
	var active_box := _style(C_BG_SEGMENT_ACTIVE, C_BORDER_ACTIVE, 7, 1, 6, 4)
	button.add_theme_stylebox_override("normal", active_box if active else _style(C_CLEAR, C_CLEAR, 7, 1, 6, 4))
	button.add_theme_stylebox_override("hover", _style(Color(0.10, 0.15, 0.115, 1.0), C_CLEAR, 7, 1, 6, 4))
	button.add_theme_stylebox_override("pressed", active_box)
	button.add_theme_stylebox_override("focus", _style(C_BG_SEGMENT_ACTIVE if active else C_CLEAR, C_TEXT, 7, 1, 6, 4))


# Category chips. A chip with no matches stays visible (so the list does not jump) but is dimmed.
func _style_chip_button(button: Button, active: bool, dim: bool) -> void:
	_set_button_colors(button, C_TEXT if active else C_MUTED_SOFT, C_TEXT, C_TEXT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _style(C_BG_SEGMENT_ACTIVE if active else C_CLEAR, C_BORDER_STRONG if active else C_BORDER_CHIP, 13, 1, 9, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.10, 0.15, 0.115, 1.0), C_BORDER_ACTIVE, 13, 1, 9, 3))
	button.add_theme_stylebox_override("pressed", _style(C_BG_SEGMENT_ACTIVE, C_BORDER_STRONG, 13, 1, 9, 3))
	button.add_theme_stylebox_override("focus", _style(C_BG_SEGMENT_ACTIVE if active else C_CLEAR, C_TEXT, 13, 1, 9, 3))
	button.modulate = Color(1, 1, 1, 0.5 if (dim and not active) else 1.0)


func _style_search(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", C_TEXT)
	edit.add_theme_color_override("font_placeholder_color", C_MUTED_DIM)
	edit.add_theme_color_override("caret_color", C_GOLD)
	edit.add_theme_color_override("clear_button_color", C_MUTED)
	edit.add_theme_color_override("clear_button_color_pressed", C_TEXT)
	# Extra left margin leaves room for the magnifier icon.
	var normal := _style(C_BG_DARK, C_BORDER_CHIP, 9, 1, 10, 4)
	normal.content_margin_left = 32.0
	var focused := _style(C_BG_DARK, C_TEXT, 9, 1, 10, 4)
	focused.content_margin_left = 32.0
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focused)


# Draws a small magnifier into an image, so no icon asset is needed.
func _add_search_icon(edit: LineEdit) -> void:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(C_CLEAR)
	var center := Vector2(20, 20)
	var radius := 12.5
	for y in range(size):
		for x in range(size):
			var ring := absf(Vector2(x + 0.5, y + 0.5).distance_to(center) - radius)
			if ring < 2.0:
				image.set_pixel(x, y, Color(C_MUTED.r, C_MUTED.g, C_MUTED.b, clampf(2.0 - ring, 0.0, 1.0)))
	var handle_start := center + Vector2(1, 1).normalized() * (radius + 1.0)
	for step in range(0, 101):
		var point := handle_start.lerp(Vector2(42, 42), float(step) / 100.0)
		for offset_x in range(-2, 3):
			for offset_y in range(-2, 3):
				var px := int(point.x) + offset_x
				var py := int(point.y) + offset_y
				if px >= 0 and py >= 0 and px < size and py < size and Vector2(offset_x, offset_y).length() <= 2.2:
					image.set_pixel(px, py, C_MUTED)

	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(image)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = 0.0
	icon.anchor_right = 0.0
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = 10.0
	icon.offset_right = 26.0
	icon.offset_top = -8.0
	icon.offset_bottom = 8.0
	edit.add_child(icon)


func _row_style(selected: bool) -> StyleBoxFlat:
	return _style(C_BG_ROW_SELECTED if selected else C_BG_ROW, C_BORDER_STRONG if selected else C_BORDER_SOFT, 7, 1, 6, 2)


# -----------------------------------------------------------------------------
# FILTERS, SORTING, AND ENTRY LIST
# -----------------------------------------------------------------------------

func _set_filter(new_filter: ViewFilter) -> void:
	_view_filter = new_filter
	_refresh_entries(true)


func _on_search_changed(_text: String) -> void:
	# Chip counts follow the search, so chips are rebuilt on every change (the list is small).
	_refresh_entries(true)


func _on_category_pressed(category_key: String) -> void:
	_active_category = category_key
	_refresh_entries(false)


func _toggle_sort() -> void:
	_sort_mode = SortMode.NEEDS_PRACTICE if _sort_mode == SortMode.A_TO_Z else SortMode.A_TO_Z
	_sort_button.text = "↕  Sort: A to Z" if _sort_mode == SortMode.A_TO_Z else "↕  Sort: needs practice first"
	_refresh_entries(false)


func _normalize_category(raw_category: String) -> String:
	var normalized := raw_category.strip_edges().to_lower()
	return normalized if not normalized.is_empty() else "other"


func _category_label(raw_category: String) -> String:
	var cleaned := raw_category.strip_edges()
	return cleaned.capitalize() if not cleaned.is_empty() else "Other"


func _is_internal_entry(entry: VocabEntry) -> bool:
	return entry == null or entry.source_section == INTERNAL_COMPONENT_SECTION


func _get_displayable_entries(entries: Array[VocabEntry]) -> Array[VocabEntry]:
	var result: Array[VocabEntry] = []
	for entry: VocabEntry in entries:
		if not _is_internal_entry(entry):
			result.append(entry)
	return result


func _get_discovered_entries() -> Array[VocabEntry]:
	var empty_entries: Array[VocabEntry] = []
	if not is_instance_valid(LanguageProgress):
		return empty_entries
	return _get_displayable_entries(LanguageProgress.get_encountered_entries())


func _is_learned_or_mastered(entry: VocabEntry) -> bool:
	return LanguageProgress.is_learned(entry.id) or LanguageProgress.get_stage(entry.id) >= 3


func _apply_status_filter(entries: Array[VocabEntry]) -> Array[VocabEntry]:
	var result: Array[VocabEntry] = []
	for entry: VocabEntry in entries:
		var is_learned := _is_learned_or_mastered(entry)
		match _view_filter:
			ViewFilter.ALL:
				result.append(entry)
			ViewFilter.TO_LEARN:
				if not is_learned:
					result.append(entry)
			ViewFilter.LEARNED:
				if is_learned:
					result.append(entry)
	return result


func _practice_score(entry: VocabEntry) -> int:
	if not is_instance_valid(LanguageProgress):
		return 0
	if LanguageProgress.has_method("get_mastery"):
		var mastery: Dictionary = LanguageProgress.get_mastery(entry.id)
		return int(mastery.get("correct", 0))
	return LanguageProgress.get_stage(entry.id)


func _compare_entries(a: VocabEntry, b: VocabEntry) -> bool:
	if _sort_mode == SortMode.NEEDS_PRACTICE:
		var score_a := _practice_score(a)
		var score_b := _practice_score(b)
		if score_a != score_b:
			return score_a < score_b
	return a.kapampangan.to_lower() < b.kapampangan.to_lower()


## Builds the category chips. Chips come from every discovered word so they never disappear while
## searching; the counts come from the words that match the current search and status tab.
func _make_category_buttons(all_entries: Array[VocabEntry], matching_entries: Array[VocabEntry]) -> void:
	for child in _category_flow.get_children():
		_category_flow.remove_child(child)
		child.queue_free()
	_category_buttons.clear()
	_category_button_keys.clear()
	_category_button_counts.clear()

	var available: Dictionary = {}
	for entry: VocabEntry in all_entries:
		available[_normalize_category(entry.category)] = true

	var counts: Dictionary = {}
	for entry: VocabEntry in matching_entries:
		var key := _normalize_category(entry.category)
		counts[key] = int(counts.get(key, 0)) + 1

	if _active_category != ALL_CATEGORIES_KEY and not available.has(_active_category):
		_active_category = ALL_CATEGORIES_KEY

	_add_category_chip(ALL_CATEGORIES_KEY, "All types", matching_entries.size())

	var keys: Array = available.keys()
	keys.sort()
	for raw_key in keys:
		var key := str(raw_key)
		_add_category_chip(key, _category_label(key), int(counts.get(key, 0)))


func _add_category_chip(key: String, label: String, count: int) -> void:
	var button := Button.new()
	button.text = "%s  %d" % [label, count]
	button.custom_minimum_size = Vector2(0, 26)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_chip_button(button, _active_category == key, count == 0)
	button.pressed.connect(_on_category_pressed.bind(key))
	_category_flow.add_child(button)
	_category_buttons.append(button)
	_category_button_keys.append(key)
	_category_button_counts.append(count)


func _style_category_buttons() -> void:
	for index in range(_category_buttons.size()):
		_style_chip_button(_category_buttons[index], _category_button_keys[index] == _active_category, _category_button_counts[index] == 0)


func _matches_search(entry: VocabEntry, query: String) -> bool:
	if query.is_empty():
		return true
	var searchable := " ".join(PackedStringArray([
		entry.id,
		entry.kapampangan,
		entry.english,
		entry.category,
		entry.hint,
		entry.pronunciation
	])).to_lower()
	return searchable.contains(query)


func _refresh_entries(rebuild_categories: bool = true) -> void:
	if not is_instance_valid(_entries_container):
		return

	if not is_instance_valid(LanguageProgress):
		_summary_label.text = "Vocabulary unavailable"
		_count_label.text = "No vocabulary service"
		_empty_label.text = "LanguageProgress could not be found."
		_empty_label.visible = true
		_clear_entry_rows()
		_show_no_selection()
		return

	var discovered := _get_discovered_entries()
	var learned_count := 0
	var mastered_count := 0
	for entry: VocabEntry in discovered:
		if _is_learned_or_mastered(entry):
			learned_count += 1
		if LanguageProgress.get_stage(entry.id) >= 3:
			mastered_count += 1
	var to_learn_count := maxi(0, discovered.size() - learned_count)
	_summary_label.text = "%d of %d words learned" % [learned_count, discovered.size()]
	_update_overall_progress_segments(discovered, mastered_count, learned_count)
	_progress_legend.text = "[color=#f0b340]■[/color] %d mastered     [color=#6dd199]■[/color] %d learned     [color=#8f9a8b]□[/color] %d to learn" % [
		mastered_count, maxi(0, learned_count - mastered_count), to_learn_count
	]

	# Search narrows everything. Status tabs and category chips then each count against the
	# *other* filter, so a tab or chip never promises words that the other filter would hide.
	var query := _search_edit.text.strip_edges().to_lower()
	var searched: Array[VocabEntry] = []
	for entry: VocabEntry in discovered:
		if _matches_search(entry, query):
			searched.append(entry)

	var status_filtered := _apply_status_filter(searched)
	if rebuild_categories:
		_make_category_buttons(discovered, status_filtered)
	else:
		_style_category_buttons()

	var in_category: Array[VocabEntry] = []
	var visible_entries: Array[VocabEntry] = []
	for entry: VocabEntry in searched:
		if _active_category == ALL_CATEGORIES_KEY or _normalize_category(entry.category) == _active_category:
			in_category.append(entry)
	for entry: VocabEntry in status_filtered:
		if _active_category == ALL_CATEGORIES_KEY or _normalize_category(entry.category) == _active_category:
			visible_entries.append(entry)
	visible_entries.sort_custom(_compare_entries)

	_style_status_buttons(in_category)
	_clear_entry_rows()
	var preserve_id := _selected_entry_id
	_selected_entry_id = ""
	for entry: VocabEntry in visible_entries:
		if entry.id == preserve_id:
			_selected_entry_id = preserve_id
			break
	if _selected_entry_id.is_empty() and not visible_entries.is_empty():
		_selected_entry_id = visible_entries[0].id

	for entry: VocabEntry in visible_entries:
		_add_entry_row(entry)

	_count_label.text = "Showing %d of %d words" % [visible_entries.size(), discovered.size()]
	_empty_label.visible = visible_entries.is_empty()
	if visible_entries.is_empty():
		if discovered.is_empty():
			_empty_label.text = "No words collected yet. Talk to people or complete a lesson to discover vocabulary."
		elif status_filtered.is_empty() and _view_filter != ViewFilter.ALL and query.is_empty():
			_empty_label.text = "Nothing in this section yet. Try another tab or discover more words."
		else:
			_empty_label.text = "No words match. Try a shorter search, or switch back to all words and types."
		_show_no_selection()
	else:
		_show_entry(_selected_entry_id)


func _update_overall_progress_segments(entries: Array[VocabEntry], mastered_count: int, learned_count: int) -> void:
	# One segment per word for small collections; capped at ten so the meter stays readable.
	for child in _learned_segments.get_children():
		_learned_segments.remove_child(child)
		child.queue_free()

	var total_entries := entries.size()
	var segment_count := maxi(1, mini(total_entries, 10))
	var mastered_segments := 0
	var learned_segments := 0
	if total_entries > 0:
		mastered_segments = roundi(float(mastered_count) / float(total_entries) * float(segment_count))
		learned_segments = roundi(float(learned_count) / float(total_entries) * float(segment_count))
		learned_segments = maxi(mastered_segments, learned_segments)

	for index in range(segment_count):
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(14 if total_entries > 0 else 24, 9)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL if total_entries > 0 else Control.SIZE_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment_background := C_CLEAR
		var segment_border := C_OUTLINE_EMPTY
		if total_entries > 0 and index < mastered_segments:
			segment_background = C_GOLD
			segment_border = C_GOLD
		elif total_entries > 0 and index < learned_segments:
			segment_background = C_GREEN
			segment_border = C_GREEN
		segment.add_theme_stylebox_override("panel", _style(segment_background, segment_border, 3, 1, 0, 0))
		_learned_segments.add_child(segment)


func _style_status_buttons(scope: Array[VocabEntry]) -> void:
	var learned_count := 0
	for entry: VocabEntry in scope:
		if _is_learned_or_mastered(entry):
			learned_count += 1
	_all_button.text = "All  %d" % scope.size()
	_to_learn_button.text = "To learn  %d" % (scope.size() - learned_count)
	_learned_button.text = "Learned  %d" % learned_count
	_style_segment_button(_all_button, _view_filter == ViewFilter.ALL)
	_style_segment_button(_to_learn_button, _view_filter == ViewFilter.TO_LEARN)
	_style_segment_button(_learned_button, _view_filter == ViewFilter.LEARNED)


func _clear_entry_rows() -> void:
	for child in _entries_container.get_children():
		_entries_container.remove_child(child)
		child.queue_free()
	_entry_rows.clear()
	_entry_row_ids.clear()


func _add_entry_row(entry: VocabEntry) -> void:
	var row := ENTRY_ROW_SCENE.instantiate() as PanelContainer
	if row == null:
		push_error("[WORD BANK] Could not instantiate WordBankEntryRow.tscn")
		return
	var selected := entry.id == _selected_entry_id
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _row_style(selected))
	_entries_container.add_child(row)

	# Status icon in a small rounded box: amber dashed = to learn, green check = learned, gold star = mastered.
	var stage: int = LanguageProgress.get_stage(entry.id) if is_instance_valid(LanguageProgress) else 0
	var status_box := row.get_node("RowOverlay/RowContent/StatusBox") as PanelContainer
	var status_icon := status_box.get_node("StatusIcon") as Label
	var box_color := Color(0.169, 0.141, 0.063, 1.0)
	if stage >= 3:
		status_icon.text = "★"
		status_icon.add_theme_color_override("font_color", C_GOLD)
		box_color = Color(0.227, 0.196, 0.094, 1.0)
	elif _is_learned_or_mastered(entry):
		status_icon.text = "✓"
		status_icon.add_theme_color_override("font_color", C_GREEN)
		box_color = Color(0.106, 0.176, 0.129, 1.0)
	else:
		status_icon.text = "◌"
		status_icon.add_theme_color_override("font_color", C_AMBER)
	status_box.add_theme_stylebox_override("panel", _style(box_color, box_color, 8, 0, 0, 0))

	var word := row.get_node("RowOverlay/RowContent/Words/WordLabel") as Label
	word.text = entry.kapampangan + ("  ★" if _favorites.has(entry.id) else "")
	word.add_theme_color_override("font_color", C_TEXT if selected else C_TEXT_SOFT)
	var meaning := row.get_node("RowOverlay/RowContent/Words/MeaningLabel") as Label
	meaning.text = entry.english if not entry.english.strip_edges().is_empty() else "Meaning not available"
	(row.get_node("RowOverlay/RowContent/Side/CategoryLabel") as Label).text = _category_label(entry.category)
	var dots := row.get_node("RowOverlay/RowContent/Side/MasteryDots") as Label
	dots.text = _mastery_dots(stage)
	dots.add_theme_color_override("font_color", C_GOLD if stage > 0 else C_MUTED_DIM)
	var hit := row.get_node("RowOverlay/HitButton") as Button
	hit.pressed.connect(_on_entry_card_pressed.bind(entry.id))

	_entry_rows.append(row)
	_entry_row_ids.append(entry.id)


func _mastery_dots(stage: int) -> String:
	var text := ""
	for index in range(3):
		text += "■" if index < stage else "□"
	return text


func _on_entry_card_pressed(entry_id: String) -> void:
	_selected_entry_id = entry_id
	_update_entry_row_styles()
	_show_entry(entry_id)


func _update_entry_row_styles() -> void:
	# Rows are rebuilt on filter changes; selecting an entry only recolors the rows.
	for index in range(_entry_rows.size()):
		var is_selected := _entry_row_ids[index] == _selected_entry_id
		_entry_rows[index].add_theme_stylebox_override("panel", _row_style(is_selected))
		var word := _entry_rows[index].get_node("RowOverlay/RowContent/Words/WordLabel") as Label
		word.add_theme_color_override("font_color", C_TEXT if is_selected else C_TEXT_SOFT)


# -----------------------------------------------------------------------------
# DETAIL PANEL
# -----------------------------------------------------------------------------

## The word is the hero of the screen. Short words get the biggest size; long phrases step down
## so they still sit on one or two lines. Width is estimated for the body font (~0.58 em per glyph).
func _fit_title_size(text: String) -> void:
	var length := maxi(text.length(), 1)
	var base_size := 91
	if length > 16:
		base_size = 56
	elif length > 12:
		base_size = 69
	elif length > 8:
		base_size = 80
	var available := _detail_title.size.x
	if available < 200.0:
		available = get_viewport().get_visible_rect().size.x * 0.55
	var fit_size := int(available / (float(length) * (0.52 if TITLE_PIXEL_FONT else 0.58)))
	_detail_title.add_theme_font_size_override("font_size", clampi(mini(base_size, fit_size), 36, 96))


func _refit_title() -> void:
	if _current_entry != null:
		_fit_title_size(_current_entry.kapampangan)


## Short meanings sit on one line with the Hear it button right beside them; long ones wrap and the
## button moves to the end of the row.
func _update_meaning_layout(text: String) -> void:
	var is_long := text.length() > 24
	_detail_english.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if is_long else TextServer.AUTOWRAP_OFF
	_detail_english.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_long else Control.SIZE_SHRINK_BEGIN
	_meaning_spacer.visible = not is_long


func _show_no_selection() -> void:
	_current_entry = null
	_detail_title.text = "No matching words"
	_detail_title.add_theme_font_size_override("font_size", 44)
	_detail_english.text = "Try another category or search, or discover more vocabulary in Yatu Village."
	_update_meaning_layout(_detail_english.text)
	_detail_category.text = "No category"
	_detail_category_panel.add_theme_stylebox_override("panel", _style(C_BG_PANEL, C_BORDER, 12, 1, 10, 3))
	_detail_difficulty.text = ""
	_detail_pronunciation.text = ""
	_detail_pronunciation.visible = false
	_detail_hint.text = "Usage notes will appear here when you select an entry."
	_favorite_button.disabled = true
	_hear_button.disabled = true
	_audio_status.visible = false
	_parts_panel.visible = false
	_detail_parts_heading.visible = false
	_favorite_button.text = "★  Favorite"
	_style_button(_favorite_button, false, 12)
	_clear_parts()
	_update_progress_panel(false, false, 0, {})
	_feedback_label.visible = false


func _show_entry(entry_id: String) -> void:
	if not is_instance_valid(LanguageProgress):
		_show_no_selection()
		return
	var entry: VocabEntry = LanguageProgress.get_entry(entry_id)
	if entry == null or _is_internal_entry(entry):
		_show_no_selection()
		return

	_current_entry = entry
	_selected_entry_id = entry.id
	_detail_title.text = entry.kapampangan
	_fit_title_size(entry.kapampangan)
	_detail_english.text = entry.english.strip_edges() if not entry.english.strip_edges().is_empty() else "Meaning not available yet."
	_update_meaning_layout(_detail_english.text)
	_detail_category.text = _category_label(entry.category)
	_detail_category_panel.add_theme_stylebox_override("panel", _style(C_BG_PANEL, _category_color(entry.category), 12, 1, 10, 3))
	_detail_difficulty.text = _difficulty_text(entry.difficulty)
	_detail_pronunciation.text = "Pronunciation: " + entry.pronunciation if not entry.pronunciation.strip_edges().is_empty() else ""
	_detail_pronunciation.visible = not _detail_pronunciation.text.is_empty()
	_detail_hint.text = entry.hint.strip_edges() if not entry.hint.strip_edges().is_empty() else "No usage notes have been added for this entry yet."
	_favorite_button.disabled = false
	_favorite_button.text = "★  Favorited" if _favorites.has(entry.id) else "★  Favorite"
	_style_button(_favorite_button, _favorites.has(entry.id), 12)
	_hear_button.disabled = false
	_audio_status.visible = false
	_feedback_label.visible = false

	_update_parts(entry)
	var discovered := true
	if LanguageProgress.has_method("is_encountered"):
		discovered = LanguageProgress.is_encountered(entry.id)
	var learned := _is_learned_or_mastered(entry)
	var stage := LanguageProgress.get_stage(entry.id)
	var mastery: Dictionary = LanguageProgress.get_mastery(entry.id) if LanguageProgress.has_method("get_mastery") else {}
	_update_progress_panel(discovered, learned, stage, mastery)


func _difficulty_text(difficulty: int) -> String:
	var safe_difficulty := clampi(difficulty, 1, 5)
	var result := "Difficulty  "
	for index in range(5):
		result += "■" if index < safe_difficulty else "□"
	return result + "  %d / 5" % safe_difficulty


func _update_parts(entry: VocabEntry) -> void:
	_clear_parts()
	var visible_parts: Array[VocabEntry] = []
	for part_id: String in entry.parts:
		var part: VocabEntry = LanguageProgress.get_entry(part_id)
		if part == null or _is_internal_entry(part):
			continue
		visible_parts.append(part)

	_parts_panel.visible = not visible_parts.is_empty()
	_detail_parts_heading.visible = not visible_parts.is_empty()
	for index in range(visible_parts.size()):
		var part: VocabEntry = visible_parts[index]
		var accent := _category_color(part.category)

		# Each tile travels with its "+" so a "+" never wraps onto the start of a new line.
		var holder := HBoxContainer.new()
		holder.add_theme_constant_override("separation", 6)
		_parts_flow.add_child(holder)

		var part_card := PART_CARD_SCENE.instantiate() as PanelContainer
		if part_card == null:
			continue
		part_card.add_theme_stylebox_override("panel", _style(C_BG_PANEL, Color(accent.r, accent.g, accent.b, 0.55), 8, 1, 8, 7))
		holder.add_child(part_card)
		var category_label := part_card.get_node("CardStack/CategoryLabel") as Label
		category_label.text = _category_label(part.category).to_upper()
		category_label.add_theme_color_override("font_color", accent)
		(part_card.get_node("CardStack/WordLabel") as Label).text = part.kapampangan
		(part_card.get_node("CardStack/MeaningLabel") as Label).text = part.english
		(part_card.get_node("CardStack/OpenEntryButton") as Button).pressed.connect(_open_component_entry.bind(part.id))

		if index < visible_parts.size() - 1:
			var plus := Label.new()
			plus.text = "+"
			plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			plus.add_theme_font_size_override("font_size", 19)
			plus.add_theme_color_override("font_color", C_BORDER_STRONG)
			holder.add_child(plus)


func _clear_parts() -> void:
	for child in _parts_flow.get_children():
		_parts_flow.remove_child(child)
		child.queue_free()


func _category_color(category: String) -> Color:
	match category.to_lower():
		"greeting":
			return C_GREEN
		"phrase":
			return C_CORAL
		"particle":
			return C_GOLD
		_:
			return C_BLUE


func _open_component_entry(entry_id: String) -> void:
	_selected_entry_id = entry_id
	# The part may be hidden by the current search or tab, so clear them to make sure it shows.
	_search_edit.text = ""
	_view_filter = ViewFilter.ALL
	_active_category = ALL_CATEGORIES_KEY
	_refresh_entries(true)


func _update_progress_panel(discovered: bool, learned: bool, stage: int, mastery: Dictionary) -> void:
	var mastered := stage >= 3
	var statuses := [discovered, learned, mastered]
	var subtitles := ["You met this word", "You know what it means", "Mastered through battle practice"]
	var steps_parent := _progress_cards[0].get_parent() as HBoxContainer
	var line_one := steps_parent.get_node_or_null("ConnectionOne/Line") as ColorRect
	var line_two := steps_parent.get_node_or_null("ConnectionTwo/Line") as ColorRect
	if is_instance_valid(line_one):
		line_one.color = C_GREEN if learned else C_BORDER_CHIP
	if is_instance_valid(line_two):
		line_two.color = C_GOLD if mastered else C_BORDER_CHIP

	for index in range(_progress_cards.size()):
		var reached: bool = statuses[index]
		# Reached steps are filled circles (green check, gold star); the rest are outlined numbers.
		var icon := _progress_icons[index] as Label
		var dot_fill := C_CLEAR
		var dot_border := C_OUTLINE_EMPTY
		var dot_text := C_MUTED
		icon.text = str(index + 1)
		if reached:
			icon.text = "★" if index == 2 else "✓"
			dot_fill = C_GOLD if index == 2 else C_GREEN
			dot_border = dot_fill
			dot_text = C_DARK_TEXT
		icon.add_theme_color_override("font_color", dot_text)
		icon.add_theme_stylebox_override("normal", _style(dot_fill, dot_border, 14, 1, 0, 0))
		_progress_titles[index].add_theme_color_override("font_color", C_TEXT if reached else C_MUTED)
		_progress_descriptions[index].text = subtitles[index] if reached else ("Not yet reached" if index > 0 else "Not discovered")
		# The progress panel itself is the card; keep each stage visually open so the
		# three statuses read as a single journey instead of three separate widgets.
		_progress_cards[index].add_theme_stylebox_override("panel", _style(C_CLEAR, C_CLEAR, 0, 0, 2, 2))

	var correct := int(mastery.get("correct", 0))
	var wrong := int(mastery.get("wrong", 0))
	var seen := int(mastery.get("seen", 0))
	_practice_count.text = "%d / %d" % [mini(correct, MASTERY_TARGET), MASTERY_TARGET]
	_practice_bar.value = mini(correct, MASTERY_TARGET)
	_practice_subtitle.text = "%d attempts seen · %d incorrect" % [seen, wrong]

	# One clear "what to do next" line, so the progress panel always ends with an action.
	var remaining := maxi(1, MASTERY_TARGET - correct)
	if mastered:
		_feedback_label.text = "★  You've mastered this word. Nice work!"
	elif learned:
		_feedback_label.text = "→  Next: answer %d more correctly in battles to master this word." % remaining
	elif discovered:
		_feedback_label.text = "→  Next: finish a lesson or dialogue that teaches this word."
	else:
		_feedback_label.text = "→  Next: discover this word in dialogue or a lesson."
	_feedback_label.visible = true


# -----------------------------------------------------------------------------
# FAVORITES AND OPTIONAL PRONUNCIATION AUDIO
# -----------------------------------------------------------------------------

func _toggle_favorite() -> void:
	if _current_entry == null:
		return
	var entry_id := _current_entry.id
	if _favorites.has(entry_id):
		_favorites.erase(entry_id)
	else:
		_favorites[entry_id] = true
	_save_favorites()
	_favorite_button.text = "★  Favorited" if _favorites.has(entry_id) else "★  Favorite"
	_style_button(_favorite_button, _favorites.has(entry_id), 12)
	_refresh_entry_row_favorite(entry_id)


func _refresh_entry_row_favorite(entry_id: String) -> void:
	for index in range(_entry_row_ids.size()):
		if _entry_row_ids[index] == entry_id:
			# Rebuild to update the star in the vocabulary item label.
			_refresh_entries(false)
			return


func _load_favorites() -> void:
	var config := ConfigFile.new()
	if config.load(FAVORITES_PATH) != OK:
		return
	var items: Variant = config.get_value("word_bank", "favorites", [])
	if items is Array:
		for item in items:
			_favorites[str(item)] = true


func _save_favorites() -> void:
	var config := ConfigFile.new()
	config.load(FAVORITES_PATH)
	var items: Array[String] = []
	for key in _favorites.keys():
		items.append(str(key))
	config.set_value("word_bank", "favorites", items)
	var error := config.save(FAVORITES_PATH)
	if error != OK:
		push_warning("[WORD BANK] Could not save favorites. Error: %s" % error_string(error))


func _get_entry_audio(entry: VocabEntry) -> AudioStream:
	# Supports optional audio fields if the project adds one to VocabEntry later.
	for property_info in entry.get_property_list():
		var property_name := str(property_info.get("name", ""))
		if property_name in ["audio_clip", "pronunciation_audio", "audio_stream", "audio"]:
			var value: Variant = entry.get(property_name)
			if value is AudioStream:
				return value as AudioStream
	return null


func _on_hear_pressed() -> void:
	if _current_entry == null:
		return
	var stream := _get_entry_audio(_current_entry)
	if stream == null:
		_audio_status.text = "No pronunciation audio is assigned to this word yet."
		_audio_status.visible = true
		return
	_voice_player.stream = stream
	_voice_player.play()
	_audio_status.text = "Playing pronunciation..."
	_audio_status.visible = true
