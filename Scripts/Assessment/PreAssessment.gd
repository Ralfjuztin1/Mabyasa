extends "res://Scripts/Assessment/PostAssessment.gd"

## One-time baseline after the controls tutorial.
## Only existing multiple-choice / translation question mechanics are used.
## These ten phrase IDs must match the ten configured in PairedBattleManager.gd.

const PRE_ASSESSMENT_VOCAB_IDS: Array[String] = [
	"mayap_a_abak",
	"mayap_a_gatpanapun",
	"ala_pung_nanu_man",
	"dakal_a_salamat",
	"mayap_a_bengi",
	"mayap_a_aldo",
	"malaus_kayu_pu",
	"makilabas_ku_pu",
	"mangan_ta_na",
	"ume_ta_na"
]

const BASELINE_QUIZ_SCRIPT: GDScript = preload(
	"res://Scripts/Assessment/PreAssessmentQuizUI.gd"
)

var _pre_continue_button: Button
var _saved_successfully: bool = false


func open_pre_assessment() -> void:
	open()


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
	var entries: Array[VocabEntry] = []
	for phrase_id: String in PRE_ASSESSMENT_VOCAB_IDS:
		var entry: VocabEntry = LanguageProgress.get_entry(phrase_id)
		if entry == null:
			push_error("[PRE-ASSESSMENT] Missing vocabulary: " + phrase_id)
			return []
		if entry.parts.size() < 2 or not entry.allowed_types.has("sentence_build"):
			push_error("[PRE-ASSESSMENT] Not a supported boss phrase: " + phrase_id)
			return []
		if entry.english.is_empty() or entry.kapampangan.is_empty():
			push_error("[PRE-ASSESSMENT] Missing translation for: " + phrase_id)
			return []
		for part_id: String in entry.parts:
			if LanguageProgress.get_entry(part_id) == null:
				push_error("[PRE-ASSESSMENT] Phrase has an unavailable part: " + part_id)
				return []
		entries.append(entry)

	# The existing QuestionFactory supplies normal 3-option choices.
	# _build_choice does not require the player to have encountered an entry.
	var result: Array[Dictionary] = []
	for index: int in range(entries.size()):
		var entry: VocabEntry = entries[index]
		var recognition: bool = index % 2 == 0
		var question: QuizQuestion = QUESTION_FACTORY_SCRIPT._build_choice(entry, recognition, entries)
		if question == null or question.choices.size() < 2:
			push_error("[PRE-ASSESSMENT] Cannot create normal question for: " + entry.id)
			return []
		question.hint = ""
		question.pronunciation = ""
		question.time_limit = 35.0
		result.append(_make_question_metadata(question, _topic_key(entry)))
	result.shuffle()
	return result


func _show_intro() -> void:
	_active_screen = "intro"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "INITIAL KNOWLEDGE CHECK"
	_clear_body()

	_body.add_child(_make_label(
		"Before your adventure, answer 10 short questions about Kapampangan phrases. "
		+ "No prior knowledge is expected. Make your best guess.", 17
	))
	_body.add_child(_make_label(
		"Choose the correct meaning or translation from the choices. "
		+ "Answers are recorded privately; no correct answers will be shown yet.", 14,
		Color(0.72, 0.76, 0.69, 1.0)
	))
	_body.add_child(_make_label(
		"Prepared: %d / %d questions" % [_questions.size(), PRE_ASSESSMENT_VOCAB_IDS.size()], 16
	))
	if _questions.size() != PRE_ASSESSMENT_VOCAB_IDS.size():
		_body.add_child(_make_label(
			"The 10 baseline questions could not be prepared. Check the Godot Output for a missing vocabulary resource.",
			14, Color(0.94, 0.72, 0.34, 1.0)
		))

	# Intentionally NO close/skip button: this baseline is mandatory.
	var begin_button := _make_button("BEGIN INITIAL ASSESSMENT", _begin_assessment, 260.0)
	begin_button.disabled = _questions.size() != PRE_ASSESSMENT_VOCAB_IDS.size()


func _show_current_question() -> void:
	# Preserve the parent's question lifecycle, but rename its progress banner.
	super._show_current_question()
	if _active_screen == "quiz" and is_instance_valid(_quiz_progress_label):
		_quiz_progress_label.text = "INITIAL ASSESSMENT · QUESTION %02d / %02d" % [
			_current_index + 1, _questions.size()
		]


func _finish_assessment() -> void:
	_active_screen = "report"
	_quiz_ui.visible = false
	_current_question = null
	_report = _build_report()
	_report["assessment_type"] = "pre"
	_report["assessment_format"] = "recognition_and_translation_choices"
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
	_title_label.text = "COULD NOT SAVE BASELINE"
	_clear_body()
	_body.add_child(_make_label(
		"Your answers are still in this session but were not saved to your account. Check your sign-in and retry.",
		17, Color(0.94, 0.72, 0.34, 1.0)
	))
	_make_button("RETRY SAVE", _retry_baseline_save, 200.0)


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
	_title_label.text = "INITIAL ASSESSMENT SAVED"
	_clear_body()
	_body.add_child(_make_label(
		"Your first answers have been saved. They will be compared with your FIRST Guardian battle attempt.", 17
	))
	_body.add_child(_make_label(
		"Recognition / translation: %d / %d fully correct" % [
			int(_report.get("fully_correct_questions", 0)),
			int(_report.get("total_questions", 0))
		], 19, Color(0.88, 0.70, 0.36, 1.0)
	))
	_body.add_child(_make_label(
		"No solutions are revealed before you play.", 14, Color(0.72, 0.76, 0.69, 1.0)
	))
	_email_status_label = _make_label("Sending your initial email...", 14)
	_body.add_child(_email_status_label)
	_retry_email_button = _make_button("RETRY EMAIL", _send_email_report, 150.0)
	_retry_email_button.visible = false
	_pre_continue_button = _make_button("CONTINUE TO FIRST TOWN", close, 230.0)
	_pre_continue_button.disabled = true # Unlock after email attempt finishes, even on failure.


func close() -> void:
	if not _saved_successfully and not SaveManager.has_pre_assessment():
		return
	super.close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
