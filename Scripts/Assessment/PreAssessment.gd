extends "res://Scripts/Assessment/PostAssessment.gd"

## Five quick baseline challenges with seven scored vocabulary checks.
## Three time greetings, two expressions and two numbers.

const PRE_ASSESSMENT_VOCAB_IDS: Array[String] = [
	"mayap_a_abak",
	"mayap_a_gatpanapun",
	"mayap_a_bengi",
	"dakal_a_salamat",
	"ala_pung_nanu_man",
	"makilabas_ku_pu"
]

# MABIYASA_NUMBER_BASELINE_V1
const NUMBER_BANK: GDScript = preload("res://Scripts/Assessment/NumberPreAssessmentBank.gd")
const TOTAL_QUESTIONS: int = 5
# MABIYASA_FIVE_CHALLENGE_PRE_V2
const TIME_GREETING_IDS: Array[String] = [
	"mayap_a_abak", "mayap_a_gatpanapun", "mayap_a_bengi"
]
const ASSESSED_STORY_IDS: Array[String] = [
	"mayap_a_abak", "mayap_a_gatpanapun", "mayap_a_bengi",
	"dakal_a_salamat", "makilabas_ku_pu"
]
const ASSESSED_NUMBER_IDS: Array[String] = ["atlo_or_atlu", "walo_or_walu"]
const EXPRESSION_QUESTION_SPECS: Array[Dictionary] = [
	{
		"id": "dakal_a_salamat",
		"prompt": "A friend gives you a helpful gift. How do you thank them warmly?",
		"options": ["dakal_a_salamat", "ala_pung_nanu_man", "makilabas_ku_pu", "mayap_a_bengi"]
	},
	{
		"id": "makilabas_ku_pu",
		"prompt": "Someone is standing in your way. What can you say politely to pass?",
		"options": ["makilabas_ku_pu", "dakal_a_salamat", "ala_pung_nanu_man", "mayap_a_abak"]
	}
]

const BASELINE_QUIZ_SCRIPT: GDScript = preload(
	"res://Scripts/Assessment/PreAssessmentQuizUI.gd"
)

var _pre_continue_button: Button
var _saved_successfully: bool = false


func _ready() -> void:
	# Run after the world player controller and the quiz UI. The player's
	# Alt-key handler can recapture the cursor when Alt is released.
	super._ready()
	process_priority = 2000
	set_process(true)


func _process(_delta: float) -> void:
	# The pre-assessment includes an intro and a completion screen where
	# QuizUI is hidden. Keep the cursor visible throughout every phase.
	# Stop enforcing this as soon as the assessment is closed.
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_pre_assessment() -> void:
	open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _create_quiz_ui() -> void:
	# PostAssessment builds the CanvasLayer shell; we swap only its quiz script.
	_quiz_ui = QUIZ_UI_SCENE.instantiate() as Control
	if not is_instance_valid(_quiz_ui):
		push_error("[PRE-ASSESSMENT] QuizUI.tscn could not be instantiated.")
		return
	_quiz_ui.set_script(BASELINE_QUIZ_SCRIPT)
	_quiz_ui.name = "PreAssessmentQuizUI"
	_quiz_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_quiz_ui.visible = false
	add_child(_quiz_ui)
	_quiz_ui.answer_selected.connect(_on_answer_selected)

	_quiz_progress_label = _make_label("INITIAL ASSESSMENT", 17, Color(0.93, 0.80, 0.38, 1.0))
	_quiz_progress_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_quiz_progress_label.offset_top = 20.0
	_quiz_progress_label.offset_bottom = 52.0
	_quiz_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiz_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz_ui.add_child(_quiz_progress_label)


func _build_assessment_questions() -> Array[Dictionary]:
	# Every baseline phrase must already exist in the Guardian's data bank.
	for phrase_id: String in ASSESSED_STORY_IDS:
		var entry: VocabEntry = LanguageProgress.get_entry(phrase_id)
		if entry == null or entry.parts.size() < 2 or not entry.allowed_types.has("sentence_build"):
			push_error("[PRE-ASSESSMENT] Missing Guardian phrase: " + phrase_id)
			return []
		if entry.kapampangan.strip_edges().is_empty() or entry.english.strip_edges().is_empty():
			push_error("[PRE-ASSESSMENT] Missing translation for: " + phrase_id)
			return []
		for part_id: String in entry.parts:
			if LanguageProgress.get_entry(part_id) == null:
				push_error("[PRE-ASSESSMENT] Missing phrase component: " + part_id)
				return []

	var questions: Array[Dictionary] = []

	# Challenge 1 contains THREE independently recorded greeting matches.
	# QuizQuestion's MATCH score tracks each vocab ID via per_vocab_results.
	var greeting_match: QuizQuestion = QuizQuestion.new()
	greeting_match.quiz_type = QuizQuestion.QuizType.MATCH
	greeting_match.vocab_id = TIME_GREETING_IDS[0]
	greeting_match.prompt = "Match each time of day with its Kapampangan greeting."
	greeting_match.time_limit = 65.0
	greeting_match.hint = ""
	greeting_match.answer_line = "" # Never reveal baseline answers.
	var situations: Array[String] = ["7 AM - Morning", "2 PM - Afternoon", "7 PM - Evening"]
	for i: int in range(TIME_GREETING_IDS.size()):
		var phrase_id: String = TIME_GREETING_IDS[i]
		var entry: VocabEntry = LanguageProgress.get_entry(phrase_id)
		greeting_match.match_left_ids.append(phrase_id)
		greeting_match.match_left_texts.append(situations[i])
		greeting_match.match_right_ids.append(phrase_id)
		greeting_match.match_right_texts.append(entry.kapampangan)
		greeting_match.tested_vocab_ids.append(phrase_id)
	questions.append({
		"question": greeting_match,
		"topic_key": "time_greetings",
		"topic_name": "Time Greetings"
	})

	# Challenges 2-3 test gratitude and polite requests in context.
	for spec: Dictionary in EXPRESSION_QUESTION_SPECS:
		var target_id: String = str(spec["id"])
		var target: VocabEntry = LanguageProgress.get_entry(target_id)
		if target == null:
			return []
		var option_ids: Array[String] = []
		for raw_id: Variant in spec["options"]:
			var option_id: String = str(raw_id)
			if not PRE_ASSESSMENT_VOCAB_IDS.has(option_id) or option_ids.has(option_id):
				push_error("[PRE-ASSESSMENT] Invalid expression choice: " + option_id)
				return []
			option_ids.append(option_id)
		if option_ids.size() != 4 or not option_ids.has(target_id):
			push_error("[PRE-ASSESSMENT] Expression must offer four valid answers.")
			return []
		option_ids.shuffle()
		var expression: QuizQuestion = QuizQuestion.new()
		expression.quiz_type = QuizQuestion.QuizType.TRANSLATE
		expression.prompt = str(spec["prompt"])
		expression.vocab_id = target.id
		expression.tested_vocab_ids = [target.id]
		expression.time_limit = 35.0
		expression.hint = ""
		expression.answer_line = ""
		for option_id: String in option_ids:
			var option_entry: VocabEntry = LanguageProgress.get_entry(option_id)
			if option_entry == null:
				push_error("[PRE-ASSESSMENT] Missing option entry: " + option_id)
				return []
			expression.choices.append(option_entry.kapampangan)
			expression.choice_vocab_ids.append(option_id)
			if option_id == target_id:
				expression.correct_index = expression.choices.size() - 1
		questions.append(_make_question_metadata(expression, _topic_key(target)))

	# Challenges 4-5 sample the low and high ends of the number lessons.
	# Reuse the existing verified number bank; other ten-number content stays intact.
	var number_questions: Array[Dictionary] = NUMBER_BANK.build_questions()
	if number_questions.size() != 10:
		push_error("[PRE-ASSESSMENT] Number bank incomplete (10 source items required).")
		return []
	for number_index: int in [2, 7]: # Three and eight.
		questions.append(number_questions[number_index])

	if questions.size() != TOTAL_QUESTIONS:
		push_error("[PRE-ASSESSMENT] Expected five challenges: 1 match + 2 expressions + 2 numbers.")
		return []
	return questions


func _show_intro() -> void:
	_active_screen = "intro"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "PRE-ASSESSMENT"
	_clear_body()

	_body.add_child(_make_baseline_message_card(
		"BEFORE YOUR ADVENTURE",
		"Five quick challenges",
		"Check what you already know about Kapampangan greetings, polite expressions, "
		+ "and numbers. Your starting results are saved for comparison with the Guardians.",
		true
	))

	_body.add_child(_make_baseline_section_heading("WHAT YOU'LL DO"))
	var parts: Dictionary = _make_baseline_box()
	var panel: PanelContainer = parts["panel"] as PanelContainer
	var content: VBoxContainer = parts["content"] as VBoxContainer
	_body.add_child(panel)
	content.add_child(_make_baseline_stage_row(
		"01", "TIME GREETINGS", "1 MATCHING CHALLENGE",
		"Connect morning, afternoon and evening with their greetings."
	))
	var divider: HSeparator = HSeparator.new()
	divider.modulate = Color(0.40, 0.48, 0.38, 0.65)
	content.add_child(divider)
	content.add_child(_make_baseline_stage_row(
		"02", "POLITE EXPRESSIONS", "2 QUESTIONS",
		"Choose what to say when thanking someone or asking to pass."
	))
	content.add_child(_make_baseline_stage_row(
		"03", "NUMBERS 1-10", "2 QUESTIONS",
		"Recognize one lower and one higher number."
	))

	_body.add_child(_make_baseline_message_card(
		"INSTRUCTIONS",
		"Finish five short challenges",
		"In the matching challenge, choose a time on the left, then a greeting on the right. "
		+ "Your matches are final. No correct answers are revealed during the pre-test."
	))

	var ready: Label = _make_label(
		"%d / %d CHALLENGES READY" % [_questions.size(), TOTAL_QUESTIONS],
		12,
		Color(0.67, 0.83, 0.66, 1.0) if _questions.size() == TOTAL_QUESTIONS
		else Color(0.94, 0.69, 0.44, 1.0)
	)
	ready.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.add_child(ready)

	if _questions.size() != TOTAL_QUESTIONS:
		_body.add_child(_make_label(
			"Assessment content is incomplete. Check the Godot Output for missing vocabulary.",
			13, Color(0.94, 0.69, 0.44, 1.0)
		))

	var begin_button: Button = _make_button(
		"START PRE-ASSESSMENT", _begin_assessment, 248.0
	)
	begin_button.custom_minimum_size.y = 50.0
	begin_button.disabled = _questions.size() != TOTAL_QUESTIONS
	call_deferred("_reset_baseline_scroll")


func _reset_baseline_scroll() -> void:
	var scroll: ScrollContainer = _panel.find_child("ContentScroll", true, false) as ScrollContainer
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 0


func _make_baseline_section_heading(caption: String) -> Label:
	var label: Label = _make_label(caption, 12, Color(0.88, 0.70, 0.36, 1.0))
	return label


func _make_baseline_box(featured: bool = false) -> Dictionary:
	# All nodes are built with stock Godot controls; no external UI helpers.
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = _make_card_style()
	style.bg_color = Color(0.077, 0.109, 0.080, 1.0) if featured else Color(0.052, 0.077, 0.058, 1.0)
	style.border_color = Color(0.52, 0.43, 0.24, 1.0) if featured else Color(0.23, 0.31, 0.23, 1.0)
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	return {"panel": panel, "content": content}


func _make_baseline_message_card(
	kicker: String,
	heading: String,
	description: String,
	featured: bool = false
) -> PanelContainer:
	var parts: Dictionary = _make_baseline_box(featured)
	var panel: PanelContainer = parts["panel"] as PanelContainer
	var content: VBoxContainer = parts["content"] as VBoxContainer
	content.add_child(_make_label(kicker, 11, Color(0.88, 0.70, 0.36, 1.0)))
	content.add_child(_make_label(heading, 21 if featured else 17, Color(0.96, 0.93, 0.84, 1.0)))
	content.add_child(_make_label(description, 14, Color(0.76, 0.81, 0.75, 1.0)))
	return panel


func _make_baseline_stage_row(
	number: String,
	heading: String,
	count_text: String,
	description: String
) -> HBoxContainer:
	# Fixed-width number and an EXPANDING text column. This is deliberately
	# not two side-by-side cards: narrow Godot HBox children broke the old text.
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)

	var number_label: Label = _make_label(number, 23, Color(0.88, 0.70, 0.36, 1.0))
	number_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	number_label.custom_minimum_size.x = 40.0
	number_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(number_label)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)

	var title: Label = _make_label(
		heading + "  ·  " + count_text,
		15, Color(0.96, 0.93, 0.84, 1.0)
	)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(title)

	var subtitle: Label = _make_label(
		description,
		13, Color(0.76, 0.81, 0.75, 1.0)
	)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(subtitle)
	return row


func _show_current_question() -> void:
	# Preserve the parent's question lifecycle, but rename its progress banner.
	super._show_current_question()
	if _active_screen == "quiz" and is_instance_valid(_quiz_progress_label):
		_quiz_progress_label.text = "PRE-ASSESSMENT · QUESTION %02d / %02d" % [
			_current_index + 1, _questions.size()
		]


func _finish_assessment() -> void:
	_active_screen = "report"
	_quiz_ui.visible = false
	_current_question = null
	_report = _build_report()
	_report["assessment_type"] = "pre"
	_report["assessment_format"] = "five_challenges_three_greeting_matches_two_expressions_two_numbers"
	_report["assessment_version"] = 6
	_report["challenge_count"] = TOTAL_QUESTIONS
	_report["individual_check_count"] = 7
	_report["unique_phrase_count"] = ASSESSED_STORY_IDS.size()
	_report["assessment_vocab_ids"] = ASSESSED_STORY_IDS.duplicate()
	_report["assessment_number_vocab_ids"] = ASSESSED_NUMBER_IDS.duplicate()

	# The first screen has three separate evidence points. Expand its MATCH
	# per-vocab results so AssessmentComparison can join each greeting to Boss 1.
	# All five challenges still count as five screens in the general report.
	var items: Array[Dictionary] = []
	for row: Dictionary in _responses:
		var row_type: String = str(row.get("question_type", ""))
		var raw_results: Variant = row.get("vocabulary_results", {})
		if row_type == "match" and raw_results is Dictionary:
			var per_vocab: Dictionary = raw_results
			for phrase_id: String in TIME_GREETING_IDS:
				var entry: VocabEntry = LanguageProgress.get_entry(phrase_id)
				var correct: bool = bool(per_vocab.get(phrase_id, false))
				items.append({
					"vocab_id": phrase_id,
					"topic_key": _topic_key(entry),
					"topic_name": _display_topic(_topic_key(entry)),
					"meaning": entry.english if entry != null else "",
					"question_type": "match",
					"correct": correct,
					"score": 1.0 if correct else 0.0,
					"timed_out": bool(row.get("timed_out", false))
				})
		else:
			items.append({
				"vocab_id": str(row.get("vocab_id", "")),
				"topic_key": str(row.get("topic_key", "uncategorized")),
				"topic_name": str(row.get("topic_name", "Other Vocabulary")),
				"meaning": str(row.get("meaning", "")),
				"question_type": row_type,
				"correct": bool(row.get("correct", false)),
				"score": clampf(float(row.get("score", 0.0)), 0.0, 1.0),
				"timed_out": bool(row.get("timed_out", false))
			})
	_report["assessment_items"] = items
	_report["question_results"] = NUMBER_BANK.blind_email_question_rows(_responses)

	if SaveManager.save_pre_assessment_report(_report):
		_saved_successfully = true
		_show_pre_completion()
	else:
		_show_save_error()


func _show_save_error() -> void:
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "SAVE NOT COMPLETED"
	_clear_body()
	_body.add_child(_make_baseline_message_card(
		"ACCOUNT SAVE REQUIRED",
		"Your baseline has not been saved",
		"Your responses remain available in this session, but could not be written to your account. "
		+ "Check your sign-in or connection, then retry.",
		true
	))
	_make_button("RETRY SAVE", _retry_baseline_save, 190.0)
	call_deferred("_reset_baseline_scroll")


func _retry_baseline_save() -> void:
	if _saved_successfully:
		return
	if SaveManager.save_pre_assessment_report(_report):
		_saved_successfully = true
		_show_pre_completion()
	else:
		_show_save_error()


func _show_pre_completion() -> void:
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "PRE-ASSESSMENT COMPLETE"
	_clear_body()

	_body.add_child(_make_baseline_message_card(
		"BASELINE RECORDED",
		"Your starting results are saved",
		"Five quick challenges completed. You can now continue to First Town.",
		true
	))

	var parts: Dictionary = _make_baseline_box()
	var panel: PanelContainer = parts["panel"] as PanelContainer
	var content: VBoxContainer = parts["content"] as VBoxContainer
	_body.add_child(panel)
	content.add_child(_make_baseline_section_heading("ASSESSMENT SUMMARY"))
	var correct_checks: int = 0
	var raw_items: Variant = _report.get("assessment_items", [])
	if raw_items is Array:
		for raw_item: Variant in raw_items:
			if raw_item is Dictionary:
				var check_item: Dictionary = raw_item
				if bool(check_item.get("correct", false)):
					correct_checks += 1
	content.add_child(_make_label(
		"%d / 7 individual checks correct" % correct_checks,
		22, Color(0.96, 0.93, 0.84, 1.0)
	))
	content.add_child(_make_label(
		"3 time greetings + 2 polite expressions + 2 numbers · 5 challenge screens.",
		14, Color(0.76, 0.81, 0.75, 1.0)
	))
	content.add_child(_make_label(
		"This quick baseline samples prior knowledge; it does not prove mastery. "
		+ "Correct answers are not shown.",
		13, Color(0.69, 0.75, 0.69, 1.0)
	))

	_pre_continue_button = _make_button("CONTINUE TO FIRST TOWN", close, 240.0)
	_pre_continue_button.disabled = false
	call_deferred("_reset_baseline_scroll")


# Explicitly disable inherited email sending on the pre-assessment only.
func _send_email_report() -> void:
	return


func close() -> void:
	if not _saved_successfully and not SaveManager.has_pre_assessment():
		return
	super.close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
