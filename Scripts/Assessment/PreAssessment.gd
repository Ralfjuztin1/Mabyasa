extends "res://Scripts/Assessment/PostAssessment.gd"

## Mandatory baseline assessment launched after the controls tutorial.
## It uses the same sentence-building format as the designated boss.

const PRE_ASSESSMENT_VOCAB_IDS: Array[String] = [
	"mayap_a_abak",
	"mayap_a_gatpanapun",
	"ala_pung_nanu_man",
	"dakal_a_salamat"
]

var _pre_continue_button: Button


func open_pre_assessment() -> void:
	open()


func _build_assessment_questions() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []

	for vocab_id: String in PRE_ASSESSMENT_VOCAB_IDS:
		var entry: VocabEntry = LanguageProgress.get_entry(vocab_id)
		if entry == null:
			push_warning("[PRE-ASSESSMENT] Missing vocabulary: " + vocab_id)
			continue

		var question := _build_pre_sentence_question(entry)
		if question == null:
			push_warning("[PRE-ASSESSMENT] Could not build question: " + vocab_id)
			continue

		selected.append(_make_question_metadata(question, _topic_key(entry)))

	return selected


func _build_pre_sentence_question(entry: VocabEntry) -> QuizQuestion:
	if entry == null or entry.parts.size() < 2:
		return null

	var question := QuizQuestion.new()
	question.quiz_type = QuizQuestion.QuizType.SENTENCE_BUILD
	question.prompt = "Build the Kapampangan phrase for:\n%s" % entry.english
	question.time_limit = 30.0
	question.vocab_id = entry.id
	question.tested_vocab_ids = [entry.id]
	question.hint = ""
	question.pronunciation = ""
	question.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

	for part_id: String in entry.parts:
		var part: VocabEntry = LanguageProgress.get_entry(part_id)
		if part == null:
			return null
		question.sentence_token_ids.append(part.id)
		question.sentence_token_texts.append(part.kapampangan)

	var used: Dictionary = {}
	for part_id: String in question.sentence_token_ids:
		used[part_id] = true

	if entry.sentence_distractors != null:
		for distractor_id: String in entry.sentence_distractors:
			if used.has(distractor_id):
				continue
			var distractor: VocabEntry = LanguageProgress.get_entry(distractor_id)
			if distractor == null:
				continue
			question.sentence_distractor_ids.append(distractor.id)
			question.sentence_distractor_texts.append(distractor.kapampangan)
			used[distractor.id] = true
			if question.sentence_distractor_ids.size() >= 3:
				break

	return question


func _show_intro() -> void:
	_active_screen = "intro"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "INITIAL KNOWLEDGE CHECK"
	_clear_body()

	_body.add_child(_make_label(
		"This short assessment records what you already know before "
		+ "playing the Kapampangan learning adventure.",
		17
	))
	_body.add_child(_make_label("Assessment overview", 18, Color(0.88, 0.70, 0.36, 1.0)))
	_body.add_child(_make_label("Questions prepared: %d" % _questions.size(), 15))
	_body.add_child(_make_label(
		"Build each phrase using the words provided. Your answers will be "
		+ "saved as your baseline. Correct answers will not be revealed here.",
		14,
		Color(0.72, 0.76, 0.69, 1.0)
	))

	if _questions.size() < MIN_QUESTIONS:
		_body.add_child(_make_label(
			"The initial assessment could not load enough vocabulary questions. "
			+ "Check the four configured VocabEntry resources.",
			14,
			Color(0.94, 0.72, 0.34, 1.0)
		))

	_make_button("CLOSE", close, 120.0)
	var begin_button := _make_button("BEGIN INITIAL ASSESSMENT", _begin_assessment, 260.0)
	begin_button.disabled = _questions.size() < MIN_QUESTIONS


func _finish_assessment() -> void:
	_active_screen = "report"
	_quiz_ui.visible = false
	_current_question = null
	_report = _build_report()
	_report["assessment_type"] = "pre"

	var assessment_items: Array[Dictionary] = []
	for response: Dictionary in _responses:
		assessment_items.append({
			"vocab_id": str(response.get("vocab_id", "")),
			"topic_key": str(response.get("topic_key", "uncategorized")),
			"topic_name": str(response.get("topic_name", "Other Vocabulary")),
			"meaning": str(response.get("meaning", "")),
			"score": clampf(float(response.get("score", 0.0)), 0.0, 1.0),
			"timed_out": bool(response.get("timed_out", false))
		})
	_report["assessment_items"] = assessment_items

	if not SaveManager.save_pre_assessment_report(_report):
		push_error("[PRE-ASSESSMENT] Could not save the baseline report.")

	_show_pre_completion()
	await _send_email_report()

	if is_instance_valid(_pre_continue_button):
		_pre_continue_button.disabled = false


func _show_pre_completion() -> void:
	_active_screen = "report"
	_panel.visible = true
	_quiz_ui.visible = false
	_title_label.text = "INITIAL ASSESSMENT RECORDED"
	_clear_body()

	_body.add_child(_make_label(
		"Your initial Kapampangan knowledge has been recorded. "
		+ "This baseline will be compared with your answers during the "
		+ "Forest Guardian boss assessment.",
		17
	))

	_body.add_child(_make_label(
		"Initial accuracy: %.1f%% · %d questions"
		% [
			float(_report.get("accuracy_percent", 0.0)),
			int(_report.get("total_questions", 0))
		],
		20,
		Color(0.88, 0.70, 0.36, 1.0)
	))

	_body.add_child(_make_label(
		"Correct answers are not shown now so the later assessment remains fair.",
		14,
		Color(0.72, 0.76, 0.69, 1.0)
	))

	_email_status_label = _make_label(
		"Sending your initial assessment report...",
		14,
		Color(0.88, 0.70, 0.36, 1.0)
	)
	_body.add_child(_email_status_label)

	_retry_email_button = _make_button("RETRY EMAIL", _send_email_report, 150.0)
	_retry_email_button.visible = false

	_pre_continue_button = _make_button(
		"CONTINUE TO FIRST TOWN",
		close,
		230.0
	)
	_pre_continue_button.disabled = true


func _unhandled_input(event: InputEvent) -> void:
	# The tutorial flow requires this baseline. Do not allow Escape to bypass it.
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
