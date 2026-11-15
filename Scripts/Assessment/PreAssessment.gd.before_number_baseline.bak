extends "res://Scripts/Assessment/PostAssessment.gd"

## One-time baseline after the controls tutorial.
## Six simple translation questions followed by four situational questions.
## Repeated targets use a new situation, and answers are not revealed.
## Six unique phrase IDs are shared with the Guardian boss.

const PRE_ASSESSMENT_VOCAB_IDS: Array[String] = [
	"mayap_a_abak",
	"mayap_a_gatpanapun",
	"mayap_a_bengi",
	"dakal_a_salamat",
	"ala_pung_nanu_man",
	"makilabas_ku_pu"
]

const TOTAL_QUESTIONS: int = 10

# Questions 1-6: one plain translation for EACH story-supported phrase.
# Questions 7-10: different situations to practise four of those same phrases.
# Keeping the first exposure of every ID in the first six is important:
# AssessmentComparison compares the first pre response per phrase ID with
# the first Guardian sentence-building response for that same ID.
# "english": display English meanings; "kapampangan": display phrases.
# Both formats use existing four-option answer buttons, never sentence-build.
const STORY_QUESTION_SPECS: Array[Dictionary] = [
	{
		"id": "mayap_a_abak",
		"prompt": "What does \"Mayap a abak\" mean?",
		"show": "english",
		"options": ["mayap_a_abak", "mayap_a_gatpanapun", "mayap_a_bengi", "ala_pung_nanu_man"]
	},
	{
		"id": "mayap_a_gatpanapun",
		"prompt": "How do you say \"Good afternoon\" in Kapampangan?",
		"show": "kapampangan",
		"options": ["mayap_a_gatpanapun", "mayap_a_abak", "mayap_a_bengi", "dakal_a_salamat"]
	},
	{
		"id": "mayap_a_bengi",
		"prompt": "What does \"Mayap a bengi\" mean?",
		"show": "english",
		"options": ["mayap_a_bengi", "mayap_a_abak", "mayap_a_gatpanapun", "makilabas_ku_pu"]
	},
	{
		"id": "dakal_a_salamat",
		"prompt": "How do you say \"Thank you very much\" in Kapampangan?",
		"show": "kapampangan",
		"options": ["dakal_a_salamat", "ala_pung_nanu_man", "makilabas_ku_pu", "mayap_a_abak"]
	},
	{
		"id": "ala_pung_nanu_man",
		"prompt": "What does \"Ala pung nanu man\" mean?",
		"show": "english",
		"options": ["ala_pung_nanu_man", "dakal_a_salamat", "makilabas_ku_pu", "mayap_a_bengi"]
	},
	{
		"id": "makilabas_ku_pu",
		"prompt": "How do you say \"Excuse me\" politely in Kapampangan?",
		"show": "kapampangan",
		"options": ["makilabas_ku_pu", "ala_pung_nanu_man", "dakal_a_salamat", "mayap_a_gatpanapun"]
	},
	{
		"id": "mayap_a_abak",
		"prompt": "You run into Ima early in the morning. Which Kapampangan greeting fits?",
		"show": "kapampangan",
		"options": ["mayap_a_abak", "mayap_a_gatpanapun", "mayap_a_bengi", "makilabas_ku_pu"]
	},
	{
		"id": "mayap_a_gatpanapun",
		"prompt": "You meet Chief at the training yard after lunch. Which greeting is appropriate?",
		"show": "kapampangan",
		"options": ["mayap_a_gatpanapun", "mayap_a_abak", "mayap_a_bengi", "ala_pung_nanu_man"]
	},
	{
		"id": "dakal_a_salamat",
		"prompt": "The blacksmith has prepared your equipment. You want to express strong gratitude. What do you say?",
		"show": "kapampangan",
		"options": ["dakal_a_salamat", "ala_pung_nanu_man", "makilabas_ku_pu", "mayap_a_bengi"]
	},
	{
		"id": "makilabas_ku_pu",
		"prompt": "Ale Pacing is blocking the narrow path. What can you say politely to pass?",
		"show": "kapampangan",
		"options": ["makilabas_ku_pu", "ala_pung_nanu_man", "dakal_a_salamat", "mayap_a_abak"]
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
	# Verify the six targets and all their boss sentence components first.
	for phrase_id: String in PRE_ASSESSMENT_VOCAB_IDS:
		var entry: VocabEntry = LanguageProgress.get_entry(phrase_id)
		if entry == null or entry.parts.size() < 2 or not entry.allowed_types.has("sentence_build"):
			push_error("[PRE-ASSESSMENT] Missing or unsupported story phrase: " + phrase_id)
			return []
		if entry.kapampangan.strip_edges().is_empty() or entry.english.strip_edges().is_empty():
			push_error("[PRE-ASSESSMENT] Missing translation for: " + phrase_id)
			return []
		for part_id: String in entry.parts:
			if LanguageProgress.get_entry(part_id) == null:
				push_error("[PRE-ASSESSMENT] Missing boss phrase component: " + part_id)
				return []

	var questions: Array[Dictionary] = []
	for spec: Dictionary in STORY_QUESTION_SPECS:
		var target_id: String = str(spec.get("id", ""))
		if not PRE_ASSESSMENT_VOCAB_IDS.has(target_id):
			push_error("[PRE-ASSESSMENT] Question target is not in the story phrase list: " + target_id)
			return []
		var target: VocabEntry = LanguageProgress.get_entry(target_id)
		var option_values: Variant = spec.get("options", [])
		if not (option_values is Array):
			return []
		var option_ids: Array[String] = []
		for raw_id: Variant in option_values:
			var option_id: String = str(raw_id)
			if not PRE_ASSESSMENT_VOCAB_IDS.has(option_id) or option_ids.has(option_id):
				push_error("[PRE-ASSESSMENT] Duplicate or unsupported answer option: " + option_id)
				return []
			option_ids.append(option_id)
		if option_ids.size() != 4 or not option_ids.has(target_id):
			push_error("[PRE-ASSESSMENT] Expected four choices including " + target_id)
			return []
		option_ids.shuffle()

		var show_english: bool = str(spec.get("show", "")) == "english"
		var question: QuizQuestion = QuizQuestion.new()
		question.quiz_type = QuizQuestion.QuizType.MULTIPLE_CHOICE if show_english else QuizQuestion.QuizType.TRANSLATE
		question.prompt = str(spec.get("prompt", ""))
		question.vocab_id = target.id
		question.tested_vocab_ids = [target.id]
		question.time_limit = 35.0
		question.hint = "" # No hints or correct-answer feedback in the baseline.
		question.pronunciation = ""
		question.answer_line = "%s = %s" % [target.kapampangan, target.english]

		for option_id: String in option_ids:
			var option_entry: VocabEntry = LanguageProgress.get_entry(option_id)
			if option_entry == null:
				push_error("[PRE-ASSESSMENT] Missing option: " + option_id)
				return []
			question.choices.append(option_entry.english if show_english else option_entry.kapampangan)
			question.choice_vocab_ids.append(option_id)
			if option_id == target_id:
				question.correct_index = question.choices.size() - 1

		questions.append(_make_question_metadata(question, _topic_key(target)))

	if questions.size() != TOTAL_QUESTIONS:
		push_error("[PRE-ASSESSMENT] Expected six translations and four situations (10 total).")
		return []
	return questions


func _show_intro() -> void:
	_active_screen = "intro"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "PRE-ASSESSMENT"
	_clear_body()

	# Keep the layout single-column. A previous two-card HBox compressed
	# the headings to a few pixels, causing one letter per line.
	_body.add_child(_make_baseline_message_card(
		"PURPOSE",
		"Your starting assessment",
		"This assessment records your familiarity with six Kapampangan "
		+ "expressions. Your responses provide a baseline for the Guardian "
		+ "learning comparison.",
		true
	))

	_body.add_child(_make_baseline_section_heading("ASSESSMENT STRUCTURE"))
	var structure_parts: Dictionary = _make_baseline_box()
	var structure_panel: PanelContainer = structure_parts["panel"] as PanelContainer
	var structure_content: VBoxContainer = structure_parts["content"] as VBoxContainer
	_body.add_child(structure_panel)

	structure_content.add_child(_make_baseline_stage_row(
		"01", "TRANSLATION", "6 QUESTIONS",
		"Identify meanings and translate six expressions."
	))
	var separator: HSeparator = HSeparator.new()
	separator.modulate = Color(0.40, 0.48, 0.38, 0.65)
	structure_content.add_child(separator)
	structure_content.add_child(_make_baseline_stage_row(
		"02", "SITUATIONAL USE", "4 QUESTIONS",
		"Choose the appropriate expression for everyday situations."
	))

	_body.add_child(_make_baseline_message_card(
		"INSTRUCTIONS",
		"Choose one answer per question",
		"Complete all ten questions. Your answers are recorded privately, "
		+ "and correct answers will not be shown during this assessment."
	))

	var ready: Label = _make_label(
		"%d / %d QUESTIONS READY" % [_questions.size(), TOTAL_QUESTIONS],
		12,
		Color(0.67, 0.83, 0.66, 1.0) if _questions.size() == TOTAL_QUESTIONS
		else Color(0.94, 0.69, 0.44, 1.0)
	)
	ready.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.add_child(ready)

	if _questions.size() != TOTAL_QUESTIONS:
		_body.add_child(_make_label(
			"Assessment content is incomplete. Check the Godot Output for missing vocabulary resources.",
			13, Color(0.94, 0.69, 0.44, 1.0)
		))

	# Mandatory baseline; the footer remains visible outside the scroll area.
	var begin_button: Button = _make_button(
		"START PRE-ASSESSMENT", _begin_assessment, 248.0
	)
	begin_button.custom_minimum_size.y = 50.0
	begin_button.disabled = _questions.size() != TOTAL_QUESTIONS

	# The panel is reused after other screens; always begin at the top.
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
	_report["assessment_format"] = "story_translation_then_situational_choices"
	_report["assessment_version"] = 3
	_report["unique_phrase_count"] = PRE_ASSESSMENT_VOCAB_IDS.size()
	_report["assessment_vocab_ids"] = PRE_ASSESSMENT_VOCAB_IDS.duplicate()

	var items: Array[Dictionary] = []
	for row: Dictionary in _responses:
		items.append({
			"vocab_id": str(row.get("vocab_id", "")),
			"topic_key": str(row.get("topic_key", "uncategorized")),
			"topic_name": str(row.get("topic_name", "Other Vocabulary")),
			"meaning": str(row.get("meaning", "")),
			"question_type": str(row.get("question_type", "multiple_choice")),
			"correct": bool(row.get("correct", false)),
			"score": clampf(float(row.get("score", 0.0)), 0.0, 1.0),
			"timed_out": bool(row.get("timed_out", false))
		})
	_report["assessment_items"] = items

	if SaveManager.save_pre_assessment_report(_report):
		_saved_successfully = true
		_show_pre_completion()
		# Don't send answers or word-order solutions in the pre-game email.
		_report["mistakes"] = []
		_report["vocabulary"] = []
		_report["assessment_items"] = [] # Never email vocab IDs paired with meanings.
		_report["recommendations"] = ["Continue through the lessons, then try the Guardian's sentence-building challenge."]
		await _send_email_report()
		if is_instance_valid(_pre_continue_button):
			_pre_continue_button.disabled = false
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
		_report["mistakes"] = []
		_report["vocabulary"] = []
		_report["assessment_items"] = [] # Never email vocab IDs paired with meanings.
		_report["recommendations"] = ["Continue through the lessons, then try the Guardian's sentence-building challenge."]
		await _send_email_report()
		if is_instance_valid(_pre_continue_button):
			_pre_continue_button.disabled = false
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
		"All ten responses have been recorded. You can continue to First Town and begin the learning adventure.",
		true
	))

	var summary_parts: Dictionary = _make_baseline_box()
	var summary_panel: PanelContainer = summary_parts["panel"] as PanelContainer
	var summary_content: VBoxContainer = summary_parts["content"] as VBoxContainer
	_body.add_child(summary_panel)
	summary_content.add_child(_make_baseline_section_heading("ASSESSMENT SUMMARY"))
	summary_content.add_child(_make_label(
		"%d / %d correct responses" % [
			int(_report.get("fully_correct_questions", 0)),
			int(_report.get("total_questions", 0))
		],
		22, Color(0.96, 0.93, 0.84, 1.0)
	))
	summary_content.add_child(_make_label(
		"6 unique phrases assessed · 6 translations and 4 situational questions.",
		14, Color(0.76, 0.81, 0.75, 1.0)
	))
	summary_content.add_child(_make_label(
		"Your first response for each phrase will be compared with its first construction during the Guardian battle. No answers are revealed here.",
		13, Color(0.69, 0.75, 0.69, 1.0)
	))

	var email_parts: Dictionary = _make_baseline_box()
	var email_panel: PanelContainer = email_parts["panel"] as PanelContainer
	var email_content: VBoxContainer = email_parts["content"] as VBoxContainer
	_body.add_child(email_panel)
	email_content.add_child(_make_baseline_section_heading("EMAIL DELIVERY"))
	_email_status_label = _make_label("Sending your initial assessment report...", 14, Color(0.76, 0.81, 0.75, 1.0))
	email_content.add_child(_email_status_label)

	_retry_email_button = _make_button("RETRY EMAIL", _send_email_report, 150.0)
	_retry_email_button.visible = false
	_pre_continue_button = _make_button("CONTINUE TO FIRST TOWN", close, 240.0)
	_pre_continue_button.disabled = true # Enabled after an email attempt, including failure.
	call_deferred("_reset_baseline_scroll")


func close() -> void:
	if not _saved_successfully and not SaveManager.has_pre_assessment():
		return
	super.close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
