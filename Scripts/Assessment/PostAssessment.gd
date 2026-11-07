extends CanvasLayer

## Stand-alone, data-driven post-assessment for MABYASA.
## This assessment does not update LanguageProgress mastery and does not alter combat.
## Topics are discovered from VocabEntry.lesson_group, with safe fallbacks.

signal closed

const QUIZ_UI_SCENE: PackedScene = preload("res://Scenes/Battle/QuizUI.tscn")
const QUESTION_FACTORY_SCRIPT: GDScript = preload("res://Scripts/Battle/QuestionFactory.gd")

const MAX_QUESTIONS: int = 12
const MIN_QUESTIONS: int = 3
const ASSESSABLE_TYPES: Array[String] = [
	"multiple_choice",
	"translate",
	"fill_blank",
	"match",
	"sentence_build"
]

## Paste the deployed Google Apps Script Web App URL ending in /exec here.
@export var gmail_web_app_url: String = ""

var _panel: PanelContainer
var _title_label: Label
var _body: VBoxContainer
var _footer: HBoxContainer
var _quiz_ui: Control
var _quiz_progress_label: Label
var _email_status_label: Label
var _retry_email_button: Button

var _questions: Array[Dictionary] = []
var _responses: Array[Dictionary] = []
var _report: Dictionary = {}
var _current_index: int = 0
var _current_question: QuizQuestion = null
var _processing_answer: bool = false
var _sending_email: bool = false
var _email_sent: bool = false
var _active_screen: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	_build_shell()
	_create_quiz_ui()


func open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_questions = _build_assessment_questions()
	_responses.clear()
	_report.clear()
	_current_index = 0
	_current_question = null
	_processing_answer = false
	_sending_email = false
	_email_sent = false
	_show_intro()


func close() -> void:
	if is_instance_valid(_quiz_ui):
		_quiz_ui.visible = false
		_quiz_ui.set_process(false)
	_current_question = null
	_processing_answer = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ============================================================
# UI SHELL
# ============================================================

func _build_shell() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.008, 0.014, 0.01, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "AssessmentPanel"
	_panel.custom_minimum_size = Vector2(960.0, 620.0)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54.0
	stack.add_child(header)

	var heading_box := VBoxContainer.new()
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_box)

	_title_label = _make_label("POST-ASSESSMENT", 25, Color(0.96, 0.93, 0.84, 1.0))
	heading_box.add_child(_title_label)
	heading_box.add_child(_make_label(
		"MABYASA · KAPAMPANGAN LEARNING REVIEW",
		12,
		Color(0.88, 0.70, 0.36, 1.0)
	))

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 2.0
	divider.color = Color(0.56, 0.42, 0.22, 1.0)
	stack.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)

	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 10)
	stack.add_child(_footer)


func _create_quiz_ui() -> void:
	# Keep the scene's existing QuizUIAnimated script. It inherits QuizUI.gd
	# and therefore preserves the normal quiz interactions and payload format.
	_quiz_ui = QUIZ_UI_SCENE.instantiate() as Control
	if not is_instance_valid(_quiz_ui):
		push_error("[POST ASSESSMENT] Could not instantiate QuizUI.tscn.")
		return

	_quiz_ui.name = "AssessmentQuizUI"
	_quiz_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_quiz_ui.visible = false
	add_child(_quiz_ui)

	if _quiz_ui.has_signal("answer_selected"):
		_quiz_ui.answer_selected.connect(_on_answer_selected)
	else:
		push_error("[POST ASSESSMENT] QuizUI has no answer_selected signal.")

	_quiz_progress_label = _make_label(
		"POST-ASSESSMENT",
		17,
		Color(0.93, 0.80, 0.38, 1.0)
	)
	_quiz_progress_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_quiz_progress_label.offset_top = 20.0
	_quiz_progress_label.offset_bottom = 52.0
	_quiz_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiz_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz_ui.add_child(_quiz_progress_label)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.043, 0.99)
	style.set_border_width_all(2)
	style.border_color = Color(0.72, 0.55, 0.29, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.09, 0.068, 1.0)
	style.set_border_width_all(1)
	style.border_color = Color(0.28, 0.34, 0.24, 1.0)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_label(
	text_value: String,
	font_size: int = 16,
	color: Color = Color(0.94, 0.92, 0.86, 1.0)
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(
	text_value: String,
	callback: Callable,
	minimum_width: float = 170.0,
	parent: Control = null
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(minimum_width, 44.0)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	button.add_theme_stylebox_override(
		"normal",
		_make_button_style(Color(0.13, 0.18, 0.12, 1.0), Color(0.52, 0.42, 0.24, 1.0))
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_button_style(Color(0.20, 0.26, 0.15, 1.0), Color(0.88, 0.70, 0.36, 1.0))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(Color(0.19, 0.16, 0.08, 1.0), Color(0.96, 0.79, 0.40, 1.0))
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_button_style(Color(0.075, 0.09, 0.075, 1.0), Color(0.20, 0.23, 0.18, 1.0))
	)
	button.pressed.connect(callback)
	if is_instance_valid(parent):
		parent.add_child(button)
	else:
		_footer.add_child(button)
	return button


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(1)
	style.border_color = border
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _clear_body() -> void:
	for child in _body.get_children():
		child.queue_free()
	for child in _footer.get_children():
		child.queue_free()
	_email_status_label = null
	_retry_email_button = null


func _add_section_title(text_value: String) -> void:
	_body.add_child(_make_label(text_value.to_upper(), 15, Color(0.88, 0.70, 0.36, 1.0)))


func _add_card(parent: Node, children: Array[Control]) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_card_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	for child in children:
		stack.add_child(child)
	parent.add_child(panel)
	return panel


# ============================================================
# ASSESSMENT QUESTION GENERATION
# ============================================================

func _build_assessment_questions() -> Array[Dictionary]:
	var eligible_entries: Array[VocabEntry] = []
	var entries_by_topic: Dictionary = {}

	for entry: VocabEntry in LanguageProgress.get_encountered_entries():
		if entry == null:
			continue
		if entry.id.strip_edges().is_empty():
			continue
		if entry.english.strip_edges().is_empty() or entry.kapampangan.strip_edges().is_empty():
			continue
		if entry.category == "particle":
			continue
		if entry.source_section == "__internal_sentence_component__":
			continue

		var has_supported_type := false
		for type_name: String in ASSESSABLE_TYPES:
			if entry.allowed_types.has(type_name):
				has_supported_type = true
				break

		if not has_supported_type:
			continue

		eligible_entries.append(entry)

		var topic_key := _topic_key(entry)
		if not entries_by_topic.has(topic_key):
			entries_by_topic[topic_key] = []

		(entries_by_topic[topic_key] as Array).append(entry)

	if eligible_entries.is_empty():
		return []

	var topic_keys: Array = entries_by_topic.keys()
	topic_keys.sort()

	var primary_by_topic: Dictionary = {}
	var extra_by_topic: Dictionary = {}

	for raw_topic_key in topic_keys:
		var topic_key := str(raw_topic_key)
		var topic_entries: Array[VocabEntry] = []

		for raw_entry in entries_by_topic[topic_key]:
			topic_entries.append(raw_entry as VocabEntry)

		var primary_questions: Array[Dictionary] = []
		var extra_questions: Array[Dictionary] = []

		# Generate preferred questions for each vocabulary entry.
		for entry: VocabEntry in topic_entries:
			var entry_candidates: Array[Dictionary] = []

			for type_name: String in [
				"multiple_choice",
				"translate",
				"fill_blank",
				"sentence_build"
			]:
				if not entry.allowed_types.has(type_name):
					continue

				var question: QuizQuestion = null

				if type_name == "sentence_build":
					question = _build_sentence_assessment_question(entry)
				else:
					question = QUESTION_FACTORY_SCRIPT._build_type(
						entry,
						type_name,
						topic_entries
					)

				if question == null:
					continue

				if type_name != "sentence_build" and question.choices.size() < 2:
					continue

				entry_candidates.append(
					_make_question_metadata(question, topic_key)
				)

			# IMPORTANT: Keep these inside the entry loop.
			entry_candidates.shuffle()

			if not entry_candidates.is_empty():
				primary_questions.append(entry_candidates[0])

				for extra_index in range(1, entry_candidates.size()):
					extra_questions.append(entry_candidates[extra_index])

		# Matching is generated once per topic.
		var has_matching_entries := false

		for entry: VocabEntry in topic_entries:
			if entry.allowed_types.has("match"):
				has_matching_entries = true
				break

		if has_matching_entries and topic_entries.size() >= 2:
			var match_question: QuizQuestion = QUESTION_FACTORY_SCRIPT._build_type(
				topic_entries[0],
				"match",
				topic_entries
			)

			if match_question != null and match_question.match_left_ids.size() >= 2:
				extra_questions.append(
					_make_question_metadata(match_question, topic_key)
				)

		primary_questions.shuffle()
		extra_questions.shuffle()

		primary_by_topic[topic_key] = primary_questions
		extra_by_topic[topic_key] = extra_questions

	# Round-robin selection across lesson topics.
	var selected: Array[Dictionary] = []
	var primary_indexes: Dictionary = {}

	for raw_topic_key in topic_keys:
		primary_indexes[str(raw_topic_key)] = 0

	var keep_going := true

	while selected.size() < MAX_QUESTIONS and keep_going:
		keep_going = false

		for raw_topic_key in topic_keys:
			var topic_key := str(raw_topic_key)
			var candidates: Array = primary_by_topic.get(topic_key, [])
			var candidate_index := int(primary_indexes.get(topic_key, 0))

			if candidate_index >= candidates.size():
				continue

			selected.append(candidates[candidate_index])
			primary_indexes[topic_key] = candidate_index + 1
			keep_going = true

			if selected.size() >= MAX_QUESTIONS:
				break

	# Fill remaining slots with additional question formats.
	var extra_indexes: Dictionary = {}

	for raw_topic_key in topic_keys:
		extra_indexes[str(raw_topic_key)] = 0

	keep_going = true

	while selected.size() < MAX_QUESTIONS and keep_going:
		keep_going = false

		for raw_topic_key in topic_keys:
			var topic_key := str(raw_topic_key)
			var candidates: Array = extra_by_topic.get(topic_key, [])
			var candidate_index := int(extra_indexes.get(topic_key, 0))

			if candidate_index >= candidates.size():
				continue

			selected.append(candidates[candidate_index])
			extra_indexes[topic_key] = candidate_index + 1
			keep_going = true

			if selected.size() >= MAX_QUESTIONS:
				break

	return selected



func _make_question_metadata(question: QuizQuestion, topic_key: String) -> Dictionary:
	return {
		"question": question,
		"topic_key": topic_key,
		"topic_name": _display_topic(topic_key)
	}


func _build_sentence_assessment_question(entry: VocabEntry) -> QuizQuestion:
	if entry == null or entry.parts.size() < 2:
		return null

	var question := QuizQuestion.new()
	question.quiz_type = QuizQuestion.QuizType.SENTENCE_BUILD
	question.prompt = "Build the Kapampangan phrase for:\n%s" % entry.english
	question.time_limit = 28.0 + float(maxi(entry.difficulty - 1, 0))
	question.vocab_id = entry.id
	question.tested_vocab_ids = [entry.id]
	question.hint = entry.hint
	question.pronunciation = entry.pronunciation
	question.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

	for part_id: String in entry.parts:
		var part := LanguageProgress.get_entry(part_id)
		if part == null or not LanguageProgress.is_encountered(part_id):
			return null
		question.sentence_token_ids.append(part.id)
		question.sentence_token_texts.append(part.kapampangan)

	var used_parts: Dictionary = {}
	for part_id: String in question.sentence_token_ids:
		used_parts[part_id] = true

	for distractor_id: String in entry.sentence_distractors:
		if used_parts.has(distractor_id):
			continue
		if not LanguageProgress.is_encountered(distractor_id):
			continue
		var distractor := LanguageProgress.get_entry(distractor_id)
		if distractor == null:
			continue
		question.sentence_distractor_ids.append(distractor.id)
		question.sentence_distractor_texts.append(distractor.kapampangan)
		used_parts[distractor.id] = true
		if question.sentence_distractor_ids.size() >= 2:
			break

	return question


func _topic_key(entry: VocabEntry) -> String:
	if entry == null:
		return "uncategorized"
	var value := entry.lesson_group.strip_edges()
	if value.is_empty():
		value = entry.source_section.strip_edges()
	if value.is_empty() or value.begins_with("__"):
		value = entry.category.strip_edges()
	if value.is_empty():
		value = "uncategorized"
	return value


func _display_topic(topic_key: String) -> String:
	var words: PackedStringArray = topic_key.replace("-", "_").split("_", false)
	var output: PackedStringArray = []
	for word: String in words:
		if not word.is_empty():
			output.append(word.capitalize())
	return " ".join(output) if not output.is_empty() else "Other Vocabulary"


# ============================================================
# INTRO AND QUESTION FLOW
# ============================================================

func _show_intro() -> void:
	_active_screen = "intro"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "POST-ASSESSMENT"
	_clear_body()

	var encountered_count := LanguageProgress.get_encountered_entries().size()
	var topic_names: Dictionary = {}
	for item: Dictionary in _questions:
		topic_names[str(item.get("topic_key", ""))] = true

	_body.add_child(_make_label(
		"This assessment checks vocabulary you have already encountered in MABYASA. It does not test lessons that have not yet been introduced.",
		17
	))
	_body.add_child(_make_label("Assessment overview", 18, Color(0.88, 0.70, 0.36, 1.0)))
	_body.add_child(_make_label("Encountered vocabulary entries: %d" % encountered_count, 15))
	_body.add_child(_make_label("Lesson groups represented: %d" % topic_names.size(), 15))
	_body.add_child(_make_label("Questions prepared: %d (maximum %d)" % [_questions.size(), MAX_QUESTIONS], 15))
	_body.add_child(_make_label(
		"The report groups results by lesson topic, question format, difficulty, and vocabulary item. Matching and sentence-building questions can award partial credit.",
		14,
		Color(0.72, 0.76, 0.69, 1.0)
	))

	if _questions.size() < MIN_QUESTIONS and not _questions.is_empty():
		_body.add_child(_make_label(
			"Only a small sample of questions can be generated from the vocabulary encountered so far. Discover more vocabulary before taking the assessment.",
			14,
			Color(0.94, 0.72, 0.34, 1.0)
		))
	if _questions.is_empty():
		_body.add_child(_make_label(
			"No assessment questions are available yet. Discover more vocabulary through NPC dialogue and lessons, then return here.",
			16,
			Color(0.96, 0.57, 0.43, 1.0)
		))

	_make_button("CLOSE", close, 140.0)
	var begin_button := _make_button("BEGIN ASSESSMENT", _begin_assessment, 220.0)
	begin_button.disabled = _questions.size() < MIN_QUESTIONS


func _begin_assessment() -> void:
	if _questions.size() < MIN_QUESTIONS:
		return
	_responses.clear()
	_current_index = 0
	_current_question = null
	_processing_answer = false
	_show_current_question()


func _show_current_question() -> void:
	if _current_index >= _questions.size():
		_finish_assessment()
		return

	_active_screen = "quiz"
	_panel.visible = false
	var question_data: Dictionary = _questions[_current_index]
	_current_question = question_data.get("question") as QuizQuestion
	if _current_question == null:
		_current_index += 1
		_show_current_question()
		return

	_quiz_progress_label.text = "POST-ASSESSMENT · QUESTION %02d / %02d" % [
		_current_index + 1,
		_questions.size()
	]
	_quiz_ui.visible = true
	_quiz_ui.call("start_quiz", _current_question)


func _on_answer_selected(payload: Variant) -> void:
	if _processing_answer or _current_question == null:
		return
	_processing_answer = true

	var result: AnswerResult = _current_question.evaluate_answer(payload)
	if result != null:
		var question_data: Dictionary = _questions[_current_index]
		_responses.append(_make_response(_current_question, payload, result, question_data))

	_current_question = null
	await get_tree().create_timer(0.22).timeout
	if not is_inside_tree() or _active_screen != "quiz":
		return
	_current_index += 1
	_processing_answer = false
	_show_current_question()


func _make_response(
	question: QuizQuestion,
	payload: Variant,
	result: AnswerResult,
	metadata: Dictionary
) -> Dictionary:
	var entry := LanguageProgress.get_entry(question.vocab_id)
	var topic_key := str(metadata.get("topic_key", _topic_key(entry)))
	var vocab_results: Dictionary = result.per_vocab_results.duplicate(true)
	if vocab_results.is_empty() and not question.vocab_id.is_empty():
		vocab_results[question.vocab_id] = result.correct

	return {
		"topic_key": topic_key,
		"topic_name": str(metadata.get("topic_name", _display_topic(topic_key))),
		"vocab_id": question.vocab_id,
		"vocabulary": entry.kapampangan if entry != null else question.vocab_id,
		"meaning": entry.english if entry != null else "",
		"difficulty": entry.difficulty if entry != null else 1,
		"question_type": question.get_kind_name(),
		"prompt": question.prompt,
		"player_answer": _format_player_answer(question, payload),
		"correct_answer": _format_correct_answer(question),
		"correct": result.correct,
		"score": clampf(result.score, 0.0, 1.0),
		"timed_out": result.timed_out,
		"elapsed_seconds": result.elapsed,
		"feedback": _format_feedback(question, result),
		"vocabulary_results": vocab_results
	}


func _format_player_answer(question: QuizQuestion, payload: Variant) -> String:
	var data: Dictionary = payload if payload is Dictionary else {}
	match question.quiz_type:
		QuizQuestion.QuizType.MULTIPLE_CHOICE, QuizQuestion.QuizType.FILL_BLANK, QuizQuestion.QuizType.TRANSLATE:
			var index := int(data.get("index", -1))
			if index >= 0 and index < question.choices.size():
				return question.choices[index]
			return "No answer submitted / timed out"
		QuizQuestion.QuizType.MATCH:
			var left_map: Dictionary = {}
			var right_map: Dictionary = {}
			for i in range(question.match_left_ids.size()):
				left_map[question.match_left_ids[i]] = question.match_left_texts[i] if i < question.match_left_texts.size() else question.match_left_ids[i]
			for i in range(question.match_right_ids.size()):
				right_map[question.match_right_ids[i]] = question.match_right_texts[i] if i < question.match_right_texts.size() else question.match_right_ids[i]
			var lines: PackedStringArray = []
			var raw_pairs: Variant = data.get("pairs", [])
			if raw_pairs is Array:
				for raw_pair in raw_pairs:
					if raw_pair is Dictionary:
						var pair: Dictionary = raw_pair
						var left_id := str(pair.get("left_id", ""))
						var right_id := str(pair.get("right_id", ""))
						lines.append("%s → %s" % [str(left_map.get(left_id, left_id)), str(right_map.get(right_id, right_id))])
			return "\n".join(lines) if not lines.is_empty() else "No pairs submitted"
		QuizQuestion.QuizType.SENTENCE_BUILD:
			return _format_sentence_order(question, data.get("order", []))
	return "Answer recorded"


func _format_correct_answer(question: QuizQuestion) -> String:
	match question.quiz_type:
		QuizQuestion.QuizType.MULTIPLE_CHOICE, QuizQuestion.QuizType.FILL_BLANK, QuizQuestion.QuizType.TRANSLATE:
			if question.correct_index >= 0 and question.correct_index < question.choices.size():
				return question.choices[question.correct_index]
			return question.answer_line
		QuizQuestion.QuizType.MATCH:
			var lines: PackedStringArray = []
			var count := mini(question.match_left_ids.size(), question.match_right_ids.size())
			for i in range(count):
				var left_text := question.match_left_texts[i] if i < question.match_left_texts.size() else question.match_left_ids[i]
				var right_text := question.match_right_texts[i] if i < question.match_right_texts.size() else question.match_right_ids[i]
				lines.append("%s → %s" % [left_text, right_text])
			return "\n".join(lines)
		QuizQuestion.QuizType.SENTENCE_BUILD:
			return " ".join(question.sentence_token_texts)
	return question.answer_line


func _format_sentence_order(question: QuizQuestion, raw_order: Variant) -> String:
	if not raw_order is Array:
		return "No sentence submitted"
	var text_by_id: Dictionary = {}
	for i in range(question.sentence_token_ids.size()):
		if i < question.sentence_token_texts.size():
			text_by_id[question.sentence_token_ids[i]] = question.sentence_token_texts[i]
	for i in range(question.sentence_distractor_ids.size()):
		if i < question.sentence_distractor_texts.size():
			text_by_id[question.sentence_distractor_ids[i]] = question.sentence_distractor_texts[i]
	var words: PackedStringArray = []
	for raw_id in raw_order:
		var word_id := str(raw_id)
		words.append(str(text_by_id.get(word_id, word_id)))
	return " ".join(words) if not words.is_empty() else "No sentence submitted"


func _format_feedback(question: QuizQuestion, result: AnswerResult) -> String:
	if result.timed_out:
		return "Time ran out before a complete answer was submitted. Review the correct answer and practise again."
	if result.score >= 0.999:
		return "All required parts were answered correctly."
	if question.quiz_type == QuizQuestion.QuizType.MATCH:
		return result.chosen_note if not result.chosen_note.is_empty() else "Review the correct pairs shown in the report."
	if question.quiz_type == QuizQuestion.QuizType.SENTENCE_BUILD:
		return result.chosen_note if not result.chosen_note.is_empty() else "Review the correct word order shown in the report."
	if not result.chosen_note.is_empty():
		return result.chosen_note
	return "The correct answer is: %s" % _format_correct_answer(question)


# ============================================================
# REPORT AGGREGATION
# ============================================================

func _finish_assessment() -> void:
	_active_screen = "report"
	_quiz_ui.visible = false
	_current_question = null
	_report = _build_report()
	_show_report()
	_send_email_report()


func _build_report() -> Dictionary:
	var total_questions := _responses.size()
	var earned_points := 0.0
	var fully_correct := 0
	var partial := 0
	var incorrect := 0
	var unanswered := 0
	var total_time := 0.0

	var topic_accumulator: Dictionary = {}
	var type_accumulator: Dictionary = {}
	var difficulty_accumulator: Dictionary = {}
	var vocab_accumulator: Dictionary = {}
	var mistakes: Array[Dictionary] = []

	for row: Dictionary in _responses:
		var score := clampf(float(row.get("score", 0.0)), 0.0, 1.0)
		earned_points += score
		total_time += float(row.get("elapsed_seconds", 0.0))
		if bool(row.get("timed_out", false)):
			unanswered += 1
		if score >= 0.999:
			fully_correct += 1
		elif score > 0.0:
			partial += 1
		else:
			incorrect += 1
		if score < 0.999:
			mistakes.append(row.duplicate(true))

		_add_score_to_bucket(type_accumulator, str(row.get("question_type", "unknown")), score)
		_add_score_to_bucket(difficulty_accumulator, str(row.get("difficulty", 1)), score)

		var raw_vocab_results: Variant = row.get("vocabulary_results", {})
		if raw_vocab_results is Dictionary:
			for raw_vocab_id in raw_vocab_results.keys():
				var vocab_id := str(raw_vocab_id)
				var entry := LanguageProgress.get_entry(vocab_id)
				if entry == null:
					continue
				var topic_key := _topic_key(entry)
				if not topic_accumulator.has(topic_key):
					topic_accumulator[topic_key] = {"attempts": 0, "correct": 0}
				var topic_bucket: Dictionary = topic_accumulator[topic_key]
				topic_bucket["attempts"] = int(topic_bucket.get("attempts", 0)) + 1
				if bool(raw_vocab_results[raw_vocab_id]):
					topic_bucket["correct"] = int(topic_bucket.get("correct", 0)) + 1
				topic_accumulator[topic_key] = topic_bucket

				if not vocab_accumulator.has(vocab_id):
					vocab_accumulator[vocab_id] = {"attempts": 0, "correct": 0}
				var vocab_bucket: Dictionary = vocab_accumulator[vocab_id]
				vocab_bucket["attempts"] = int(vocab_bucket.get("attempts", 0)) + 1
				if bool(raw_vocab_results[raw_vocab_id]):
					vocab_bucket["correct"] = int(vocab_bucket.get("correct", 0)) + 1
				vocab_accumulator[vocab_id] = vocab_bucket

	var accuracy := (earned_points / float(maxi(total_questions, 1))) * 100.0
	var topics: Array[Dictionary] = []
	for raw_topic in topic_accumulator.keys():
		var topic_key := str(raw_topic)
		var bucket: Dictionary = topic_accumulator[raw_topic]
		var attempts := int(bucket.get("attempts", 0))
		var correct_count := int(bucket.get("correct", 0))
		var percentage := _percent(correct_count, attempts)
		topics.append({
			"topic_key": topic_key,
			"topic_name": _display_topic(topic_key),
			"attempts": attempts,
			"correct": correct_count,
			"incorrect": attempts - correct_count,
			"accuracy_percent": percentage,
			"interpretation": _interpret_score(percentage, attempts)
		})
	topics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("topic_name", "")) < str(b.get("topic_name", "")))

	var question_types := _buckets_to_stats(type_accumulator, false)
	var difficulty_levels := _buckets_to_stats(difficulty_accumulator, true)

	var vocabulary: Array[Dictionary] = []
	for raw_vocab_id in vocab_accumulator.keys():
		var vocab_id := str(raw_vocab_id)
		var entry := LanguageProgress.get_entry(vocab_id)
		var bucket: Dictionary = vocab_accumulator[raw_vocab_id]
		var attempts := int(bucket.get("attempts", 0))
		var correct_count := int(bucket.get("correct", 0))
		vocabulary.append({
			"vocab_id": vocab_id,
			"kapampangan": entry.kapampangan if entry != null else vocab_id,
			"english": entry.english if entry != null else "",
			"topic_name": _display_topic(_topic_key(entry)) if entry != null else "Other Vocabulary",
			"attempts": attempts,
			"correct": correct_count,
			"accuracy_percent": _percent(correct_count, attempts)
		})
	vocabulary.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("accuracy_percent", 0.0)) < float(b.get("accuracy_percent", 0.0)))

	var recommendations := _build_recommendations(topics, question_types)
	var player_name := "Adventurer"
	if is_instance_valid(GameManager) and not str(GameManager.adventurer_name).strip_edges().is_empty():
		player_name = str(GameManager.adventurer_name).strip_edges()

	return {
		"player_name": player_name,
		"assessment_date": Time.get_datetime_string_from_system(),
		"total_questions": total_questions,
		"fully_correct_questions": fully_correct,
		"partial_questions": partial,
		"incorrect_questions": incorrect,
		"unanswered_questions": unanswered,
		"points_earned": snappedf(earned_points, 0.01),
		"points_possible": float(total_questions),
		"accuracy_percent": snappedf(accuracy, 0.01),
		"average_time_seconds": snappedf(total_time / float(maxi(total_questions, 1)), 0.1),
		"topics": topics,
		"question_types": question_types,
		"difficulty_levels": difficulty_levels,
		"vocabulary": vocabulary,
		"mistakes": mistakes,
		"recommendations": recommendations,
		"summary": _build_summary(accuracy, total_questions, fully_correct, partial, incorrect)
	}


func _add_score_to_bucket(buckets: Dictionary, key: String, score: float) -> void:
	if not buckets.has(key):
		buckets[key] = {"attempts": 0, "earned": 0.0}
	var bucket: Dictionary = buckets[key]
	bucket["attempts"] = int(bucket.get("attempts", 0)) + 1
	bucket["earned"] = float(bucket.get("earned", 0.0)) + score
	buckets[key] = bucket


func _buckets_to_stats(buckets: Dictionary, numeric_sort: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_key in buckets.keys():
		var key := str(raw_key)
		var bucket: Dictionary = buckets[raw_key]
		var attempts := int(bucket.get("attempts", 0))
		var earned := float(bucket.get("earned", 0.0))
		var percentage := earned / float(maxi(attempts, 1)) * 100.0
		result.append({
			"key": key,
			"label": _display_topic(key) if not numeric_sort else "Difficulty %s" % key,
			"attempts": attempts,
			"earned_points": snappedf(earned, 0.01),
			"possible_points": attempts,
			"accuracy_percent": snappedf(percentage, 0.01),
			"interpretation": _interpret_score(percentage, attempts)
		})
	if numeric_sort:
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("key", "1")) < int(b.get("key", "1")))
	else:
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("label", "")) < str(b.get("label", "")))
	return result


func _percent(correct_count: int, attempts: int) -> float:
	if attempts <= 0:
		return 0.0
	return snappedf(float(correct_count) / float(attempts) * 100.0, 0.01)


func _interpret_score(percentage: float, sample_size: int) -> String:
	if sample_size < 5:
		return "Limited sample"
	if percentage >= 90.0:
		return "Strong"
	if percentage >= 75.0:
		return "Proficient"
	if percentage >= 60.0:
		return "Developing"
	return "Needs practice"


func _build_recommendations(topics: Array[Dictionary], types: Array[Dictionary]) -> Array[String]:
	var recommendations: Array[String] = []
	for topic: Dictionary in topics:
		var attempts := int(topic.get("attempts", 0))
		var percentage := float(topic.get("accuracy_percent", 0.0))
		if attempts >= 3 and percentage < 75.0:
			recommendations.append(
				"Review %s: %d correct out of %d vocabulary checks. Revisit the lesson words and their meanings." % [
					str(topic.get("topic_name", "this topic")),
					int(topic.get("correct", 0)),
					attempts
				]
			)
	for type_data: Dictionary in types:
		var attempts := int(type_data.get("attempts", 0))
		var percentage := float(type_data.get("accuracy_percent", 0.0))
		if attempts >= 3 and percentage < 75.0:
			recommendations.append(
				"Practise %s questions: your current accuracy is %.1f%% across %d attempts." % [
					str(type_data.get("label", "this question type")),
					percentage,
					attempts
				]
			)
	if recommendations.is_empty():
		recommendations.append("The current sample does not show a reliable weak area. Continue reviewing the assessed vocabulary and practise different question formats.")
	return recommendations


func _build_summary(
	accuracy: float,
	total: int,
	correct_count: int,
	partial_count: int,
	incorrect_count: int
) -> String:
	var points := _report_points_from_responses()
	if total < 5:
		return "You completed %d questions and earned %.2f out of %d possible points. This is a limited sample, so use the breakdown as practice guidance rather than a firm proficiency judgment." % [total, points, total]
	return "You earned %.2f out of %d possible points (%.1f%%). You answered %d questions fully correctly, %d partially, and %d with no credit." % [points, total, accuracy, correct_count, partial_count, incorrect_count]


func _report_points_from_responses() -> float:
	var total := 0.0
	for row: Dictionary in _responses:
		total += float(row.get("score", 0.0))
	return snappedf(total, 0.01)


# ============================================================
# REPORT SCREEN
# ============================================================

func _show_report() -> void:
	_active_screen = "report"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "YOUR LEARNING REPORT"
	_clear_body()

	var accuracy := float(_report.get("accuracy_percent", 0.0))
	var total := int(_report.get("total_questions", 0))
	var earned := float(_report.get("points_earned", 0.0))
	var fully_correct := int(_report.get("fully_correct_questions", 0))
	var partial := int(_report.get("partial_questions", 0))
	var incorrect := int(_report.get("incorrect_questions", 0))
	var unanswered := int(_report.get("unanswered_questions", 0))

	_add_section_title("Overall Performance")
	var summary_card := PanelContainer.new()
	summary_card.add_theme_stylebox_override("panel", _make_card_style())
	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 14)
	summary_margin.add_theme_constant_override("margin_top", 12)
	summary_margin.add_theme_constant_override("margin_right", 14)
	summary_margin.add_theme_constant_override("margin_bottom", 12)
	summary_card.add_child(summary_margin)
	var summary_stack := VBoxContainer.new()
	summary_stack.add_theme_constant_override("separation", 6)
	summary_margin.add_child(summary_stack)
	var score_color := Color(0.48, 0.79, 0.52, 1.0) if accuracy >= 75.0 else Color(0.94, 0.72, 0.34, 1.0)
	summary_stack.add_child(_make_label("%.1f%% OVERALL ACCURACY" % accuracy, 26, score_color))
	summary_stack.add_child(_make_label("%.2f / %d points · %d questions" % [earned, total, total], 15))
	summary_stack.add_child(_make_label("Fully correct: %d   Partial: %d   No credit: %d   Timed out: %d" % [fully_correct, partial, incorrect, unanswered], 14, Color(0.72, 0.76, 0.69, 1.0)))
	summary_stack.add_child(_make_label("Average response time: %.1f seconds per question" % float(_report.get("average_time_seconds", 0.0)), 14, Color(0.72, 0.76, 0.69, 1.0)))
	summary_stack.add_child(_make_label(str(_report.get("summary", "")), 14))
	_body.add_child(summary_card)

	_add_section_title("Performance by lesson topic")
	for topic: Dictionary in _report.get("topics", []):
		_add_stat_card(
			str(topic.get("topic_name", "Topic")),
			"%d correct / %d vocabulary checks" % [int(topic.get("correct", 0)), int(topic.get("attempts", 0))],
			float(topic.get("accuracy_percent", 0.0)),
			str(topic.get("interpretation", ""))
		)

	_add_section_title("Performance by question type")
	for type_data: Dictionary in _report.get("question_types", []):
		_add_stat_card(
			_display_topic(str(type_data.get("key", "other"))),
			"%.2f / %d points" % [float(type_data.get("earned_points", 0.0)), int(type_data.get("possible_points", 0))],
			float(type_data.get("accuracy_percent", 0.0)),
			"%d questions · %s" % [int(type_data.get("attempts", 0)), str(type_data.get("interpretation", ""))]
		)

	_add_section_title("Difficulty breakdown")
	for difficulty: Dictionary in _report.get("difficulty_levels", []):
		_add_stat_card(
			str(difficulty.get("label", "Difficulty")),
			"%.2f / %d points" % [float(difficulty.get("earned_points", 0.0)), int(difficulty.get("possible_points", 0))],
			float(difficulty.get("accuracy_percent", 0.0)),
			"%d questions · %s" % [int(difficulty.get("attempts", 0)), str(difficulty.get("interpretation", ""))]
		)

	_add_section_title("Vocabulary to review")
	var vocabulary: Array = _report.get("vocabulary", [])
	var review_count := 0
	for vocab_item: Dictionary in vocabulary:
		if float(vocab_item.get("accuracy_percent", 0.0)) >= 100.0:
			continue
		review_count += 1
		var text_value := "%s = %s\n%s · %d/%d correct checks (%.1f%%)" % [
			str(vocab_item.get("kapampangan", "")),
			str(vocab_item.get("english", "")),
			str(vocab_item.get("topic_name", "")),
			int(vocab_item.get("correct", 0)),
			int(vocab_item.get("attempts", 0)),
			float(vocab_item.get("accuracy_percent", 0.0))
		]
		_add_card(_body, [_make_label(text_value, 14)])
	if review_count == 0:
		_body.add_child(_make_label("No vocabulary item in this sample needs additional review.", 14, Color(0.48, 0.79, 0.52, 1.0)))

	_add_section_title("Incorrect and partial responses")
	var mistakes: Array = _report.get("mistakes", [])
	if mistakes.is_empty():
		_body.add_child(_make_label("There were no incorrect or partial responses.", 14, Color(0.48, 0.79, 0.52, 1.0)))
	else:
		for mistake: Dictionary in mistakes:
			_add_mistake_card(mistake)

	_add_section_title("Recommended next steps")
	for recommendation: String in _report.get("recommendations", []):
		_body.add_child(_make_label("• " + recommendation, 14))

	_email_status_label = _make_label("Preparing email report...", 14, Color(0.88, 0.70, 0.36, 1.0))
	_body.add_child(_email_status_label)
	_retry_email_button = _make_button("RETRY EMAIL", _send_email_report, 150.0)
	_retry_email_button.visible = false
	_make_button("CLOSE", close, 120.0)


func _add_stat_card(
	title_text: String,
	detail_text: String,
	percentage: float,
	interpretation: String
) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.add_child(_make_label(title_text, 16, Color(0.96, 0.93, 0.84, 1.0)))
	var row := HBoxContainer.new()
	row.add_child(_make_label(detail_text, 13, Color(0.72, 0.76, 0.69, 1.0)))
	var percent_label := _make_label("%.1f%%" % percentage, 14, Color(0.88, 0.70, 0.36, 1.0))
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(percent_label)
	stack.add_child(row)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 9.0
	bar.max_value = 100.0
	bar.value = clampf(percentage, 0.0, 100.0)
	bar.show_percentage = false
	stack.add_child(bar)
	stack.add_child(_make_label(interpretation, 12, Color(0.72, 0.76, 0.69, 1.0)))
	_add_card(_body, [stack])


func _add_mistake_card(row: Dictionary) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.add_child(_make_label(
		"%s · %s · %.0f%% credit" % [
			str(row.get("topic_name", "Topic")),
			_display_topic(str(row.get("question_type", "question"))),
			float(row.get("score", 0.0)) * 100.0
		],
		13,
		Color(0.94, 0.72, 0.34, 1.0)
	))
	stack.add_child(_make_label(str(row.get("prompt", "")), 15, Color(0.96, 0.93, 0.84, 1.0)))
	stack.add_child(_make_label("Your answer: " + str(row.get("player_answer", "")), 13))
	stack.add_child(_make_label("Correct answer: " + str(row.get("correct_answer", "")), 13, Color(0.48, 0.79, 0.52, 1.0)))
	stack.add_child(_make_label("Feedback: " + str(row.get("feedback", "Review this answer.")), 13, Color(0.72, 0.76, 0.69, 1.0)))
	_add_card(_body, [stack])


# ============================================================
# EMAIL REPORT
# ============================================================

func _send_email_report() -> void:
	if SupabaseManager.current_user_id.is_empty():
		push_error("[EMAIL] No authenticated Supabase user.")
		return

	if not await SupabaseManager._ensure_fresh_token():
		push_error("[EMAIL] Could not refresh Supabase session.")
		return

	var access_token: String = SupabaseManager.session_token

	if access_token.is_empty():
		push_error("[EMAIL] Access token is empty.")
		return
	if _sending_email or _email_sent or _report.is_empty():
		return
	if gmail_web_app_url.strip_edges().is_empty():
		_set_email_status(
			"Email is not configured. Add your Google Apps Script Web App URL to PostAssessment.tscn in the Inspector.",
			false
		)
		return
	if not is_instance_valid(SupabaseManager):
		_set_email_status("SupabaseManager is unavailable.", false)
		return
	if SupabaseManager.current_user_id.is_empty() or SupabaseManager.current_user_email.strip_edges().is_empty():
		_set_email_status("No authenticated player email was found. Sign in before sending.", false)
		return

	_sending_email = true
	if is_instance_valid(_retry_email_button):
		_retry_email_button.disabled = true
		_retry_email_button.visible = false
	_set_email_status("Preparing secure email request...", true)

	var session_user_before := SupabaseManager.current_user_id
	var token_ready: bool = await SupabaseManager._ensure_fresh_token()
	if not token_ready or session_user_before != SupabaseManager.current_user_id:
		_sending_email = false
		_set_email_status("Your login session could not be verified. Sign in again, then retry.", false)
		return

	var request_body := {
		"access_token": SupabaseManager.session_token,
		"report": _report
	}
	var request_headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])

	_set_email_status("Sending the report to %s..." % SupabaseManager.current_user_email, true)
	var delivery: Dictionary = await _request_apps_script_manually(
		gmail_web_app_url.strip_edges(),
		request_headers,
		JSON.stringify(request_body)
	)
	_sending_email = false

	if not is_inside_tree():
		return
	if not bool(delivery.get("transport_ok", false)):
		_set_email_status("Email connection failed: " + str(delivery.get("message", "Unknown connection error")), false)
		return

	var response_code := int(delivery.get("http_code", 0))
	var response_text := str(delivery.get("body", "")).strip_edges()
	if response_text.is_empty():
		_set_email_status("Email service returned HTTP %d with an empty response." % response_code, false)
		print("[EMAIL] Empty response. HTTP code: ", response_code)
		return

	# Parse without JSON.parse_string() so unexpected HTML/text does not produce
	# a noisy engine parser error. The raw response preview is logged for debugging.
	var parser := JSON.new()
	var parse_error: Error = parser.parse(response_text)
	if parse_error != OK or not parser.data is Dictionary:
		print("[EMAIL] Response was not JSON. HTTP code: ", response_code)
		print("[EMAIL] Response preview: ", response_text.left(700))
		_set_email_status(
			"Email service returned an unexpected response (HTTP %d). Check Godot Output." % response_code,
			false
		)
		return

	var response_data: Dictionary = parser.data
	if response_code >= 200 and response_code < 300 and bool(response_data.get("success", false)):
		_email_sent = true
		_set_email_status("Report sent successfully to %s." % SupabaseManager.current_user_email, true)
		return

	var message := str(response_data.get("message", "HTTP %d" % response_code))
	var details := str(response_data.get("verification_error", ""))

	if not details.is_empty():
		message += "\nDetails: " + details

	print("[EMAIL] Supabase verification error: ", details)
	_set_email_status("Email was not sent: " + message, false)


func _request_apps_script_manually(
	endpoint: String,
	request_headers: PackedStringArray,
	request_body: String
) -> Dictionary:
	# Google Apps Script ContentService often responds to POST with a 302 and
	# moves the JSON response to script.googleusercontent.com. Disable automatic
	# redirects here so we can read Location and follow it ourselves with GET.
	var post_request := HTTPRequest.new()
	post_request.process_mode = Node.PROCESS_MODE_ALWAYS
	post_request.timeout = 30.0
	post_request.max_redirects = 0
	add_child(post_request)

	var request_error: Error = post_request.request(
		endpoint,
		request_headers,
		HTTPClient.METHOD_POST,
		request_body
	)
	if request_error != OK:
		post_request.queue_free()
		return {
			"transport_ok": false,
			"message": "Could not start POST request (error %d)." % int(request_error)
		}

	var first_response: Array = await post_request.request_completed
	post_request.queue_free()
	if first_response.size() < 4:
		return {"transport_ok": false, "message": "POST returned an incomplete HTTP response."}

	var first_result := int(first_response[0])
	var first_code := int(first_response[1])
	var first_headers: PackedStringArray = first_response[2]
	var first_body := (first_response[3] as PackedByteArray).get_string_from_utf8()
	print("[EMAIL] Apps Script POST HTTP status: ", first_code)

	var is_redirect := first_code >= 300 and first_code < 400
	# With max_redirects = 0, Godot may report RESULT_REDIRECT_LIMIT_REACHED
	# for the expected 302. Keep processing when a redirect status is present.
	if first_result != HTTPRequest.RESULT_SUCCESS and not is_redirect:
		return {
			"transport_ok": false,
			"message": "POST transport failed (result %d, HTTP %d)." % [first_result, first_code]
		}

	# A redirect is expected from Apps Script ContentService. Follow Location
	# with GET, since the redirected URL serves the already-generated response.
	if is_redirect:
		var redirect_url := ""
		for header_line: String in first_headers:
			var separator := header_line.find(":")
			if separator < 0:
				continue
			var header_name := header_line.substr(0, separator).strip_edges().to_lower()
			if header_name == "location":
				redirect_url = header_line.substr(separator + 1).strip_edges()
				break

		if redirect_url.is_empty():
			print("[EMAIL] Redirect response headers: ", first_headers)
			return {
				"transport_ok": false,
				"message": "Google redirected the response but did not provide a Location header."
			}

		print("[EMAIL] Following Apps Script response redirect with GET.")
		var get_request := HTTPRequest.new()
		get_request.process_mode = Node.PROCESS_MODE_ALWAYS
		get_request.timeout = 30.0
		get_request.max_redirects = 4
		add_child(get_request)

		request_error = get_request.request(
			redirect_url,
			PackedStringArray(["Accept: application/json"]),
			HTTPClient.METHOD_GET
		)
		if request_error != OK:
			get_request.queue_free()
			return {
				"transport_ok": false,
				"message": "Could not follow Google's response redirect (error %d)." % int(request_error)
			}

		var second_response: Array = await get_request.request_completed
		get_request.queue_free()
		if second_response.size() < 4:
			return {"transport_ok": false, "message": "Redirect returned an incomplete HTTP response."}

		var second_result := int(second_response[0])
		var second_code := int(second_response[1])
		var second_body := (second_response[3] as PackedByteArray).get_string_from_utf8()
		print("[EMAIL] Apps Script redirect response HTTP status: ", second_code)

		if second_result != HTTPRequest.RESULT_SUCCESS:
			print("[EMAIL] Redirect response preview: ", second_body.left(700))
			return {
				"transport_ok": false,
				"message": "Redirect transport failed (result %d, HTTP %d)." % [second_result, second_code]
			}
		return {
			"transport_ok": true,
			"http_code": second_code,
			"body": second_body
		}

	# If Apps Script did not redirect, parse the original response.
	return {
		"transport_ok": true,
		"http_code": first_code,
		"body": first_body
	}


func _set_email_status(message: String, success: bool) -> void:
	if is_instance_valid(_email_status_label):
		_email_status_label.text = message
		_email_status_label.add_theme_color_override(
			"font_color",
			Color(0.48, 0.79, 0.52, 1.0) if success else Color(0.94, 0.72, 0.34, 1.0)
		)
	if is_instance_valid(_retry_email_button):
		_retry_email_button.visible = not success
		_retry_email_button.disabled = false
