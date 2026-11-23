@tool
extends EditorScript

## Run from Godot Script Editor: File -> Run.
## Works with the original 20-question PreAssessment and the earlier 5-question
## patch, as long as function boundaries have not been renamed.
## Changes only PreAssessment.gd. The ZIP also supplies PreAssessmentQuizUI.gd.

const TARGET: String = "res://Scripts/Assessment/PreAssessment.gd"
const MARKER: String = "# MABIYASA_FIVE_CHALLENGE_PRE_V2"


const CONSTANTS: String = """# MABIYASA_NUMBER_BASELINE_V1
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

"""

const BUILD_QUESTIONS: String = """func _build_assessment_questions() -> Array[Dictionary]:
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


"""

const INTRO: String = """func _show_intro() -> void:
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


"""

const FINISH: String = """func _finish_assessment() -> void:
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


"""

const RETRY: String = """func _retry_baseline_save() -> void:
	if _saved_successfully:
		return
	if SaveManager.save_pre_assessment_report(_report):
		_saved_successfully = true
		_show_pre_completion()
	else:
		_show_save_error()


"""

const COMPLETION: String = """func _show_pre_completion() -> void:
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


"""

func _run() -> void:
	if not FileAccess.file_exists(TARGET):
		push_error("[5 CHALLENGES] Missing: " + TARGET)
		return
	var original: String = FileAccess.get_file_as_string(TARGET)
	if original.is_empty():
		push_error("[5 CHALLENGES] Could not read PreAssessment.gd")
		return
	if original.contains(MARKER):
		print("[5 CHALLENGES] Already installed.")
		return

	var revised: String = original
	revised = _replace_between(revised,
		"## One-time baseline after the controls tutorial.",
		"const PRE_ASSESSMENT_VOCAB_IDS: Array[String] = [",
		"## Five quick baseline challenges with seven scored vocabulary checks.\n"
		+ "## Three time greetings, two expressions and two numbers.\n\n")
	# Earlier 5-question patch used a different heading.
	if revised.is_empty():
		revised = _replace_between(original,
			"## Five-item screening baseline after the controls tutorial.",
			"const PRE_ASSESSMENT_VOCAB_IDS: Array[String] = [",
			"## Five quick baseline challenges with seven scored vocabulary checks.\n"
			+ "## Three time greetings, two expressions and two numbers.\n\n")
	if revised.is_empty(): return

	revised = _replace_between(revised,
		"# MABIYASA_NUMBER_BASELINE_V1",
		"const BASELINE_QUIZ_SCRIPT: GDScript = preload(",
		CONSTANTS)
	if revised.is_empty(): return

	revised = _replace_between(revised,
		"func _build_assessment_questions() -> Array[Dictionary]:",
		"func _show_intro() -> void:",
		BUILD_QUESTIONS)
	if revised.is_empty(): return

	revised = _replace_between(revised,
		"func _show_intro() -> void:",
		"func _reset_baseline_scroll() -> void:",
		INTRO)
	if revised.is_empty(): return

	revised = _replace_between(revised,
		"func _finish_assessment() -> void:",
		"func _show_save_error() -> void:",
		FINISH)
	if revised.is_empty(): return

	revised = _replace_between(revised,
		"func _retry_baseline_save() -> void:",
		"func _show_pre_completion() -> void:",
		RETRY)
	if revised.is_empty(): return

	revised = _replace_between(revised,
		"func _show_pre_completion() -> void:",
		"func close() -> void:",
		COMPLETION)
	if revised.is_empty(): return

	if (not revised.contains("const TOTAL_QUESTIONS: int = 5")
		or not revised.contains("greeting_match.quiz_type = QuizQuestion.QuizType.MATCH")
		or not revised.contains("SaveManager.save_pre_assessment_report(_report)")
		or revised.contains("await _send_email_report()")
		or revised.contains("EMAIL DELIVERY")):
		push_error("[5 CHALLENGES] Script validation failed; original untouched.")
		return

	var backup_path: String = TARGET + ".before_5_challenges.bak"
	if not FileAccess.file_exists(backup_path):
		var backup: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
		if backup == null:
			push_error("[5 CHALLENGES] Could not create backup; original untouched.")
			return
		backup.store_string(original)
		backup.close()

	var output: FileAccess = FileAccess.open(TARGET, FileAccess.WRITE)
	if output == null:
		push_error("[5 CHALLENGES] Could not write " + TARGET)
		return
	output.store_string(revised)
	output.close()
	EditorInterface.get_resource_filesystem().scan()
	print("[5 CHALLENGES] Installed 1 greeting matching screen, 2 expressions, 2 numbers.")
	print("[5 CHALLENGES] 7 individual check results, no pre-test email.")
	print("[5 CHALLENGES] Backup: " + backup_path)
	print("[5 CHALLENGES] Restart Godot to reload the updated code.")

func _replace_between(source: String, start_text: String, end_text: String, new_text: String) -> String:
	if source.count(start_text) != 1 or source.count(end_text) != 1:
		push_warning("[5 CHALLENGES] Unexpected section: " + start_text.left(65))
		return ""
	var a: int = source.find(start_text)
	var b: int = source.find(end_text, a + start_text.length())
	if a < 0 or b <= a:
		push_error("[5 CHALLENGES] Invalid section order: " + start_text.left(65))
		return ""
	return source.substr(0, a) + new_text + source.substr(b)
