extends "res://Scripts/Battle/BossAssessmentOverlay.gd"

const NUMBERS_EMAIL_SENDER: GDScript = preload("res://Scripts/Assessment/SecondTownNumberEmailSender.gd")
const BOSS_ID: String = "second_town_number_guardian"

var _email_status: Label = null
var _email_retry: Button = null
var _email_pending: bool = false
var _email_sent: bool = false
var _official_report: Dictionary = {}
var _official_victory: bool = false

func _ready() -> void:
	super._ready()
	var footer: HBoxContainer = find_child("Footer", true, false) as HBoxContainer
	if footer != null:
		_email_status = Label.new()
		_email_status.name = "NumbersEmailStatus"
		_email_status.text = "Number assessment: preparing..."
		_email_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_email_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_email_status.add_theme_font_size_override("font_size", 13)
		footer.add_child(_email_status)
		footer.move_child(_email_status, 0)

		_email_retry = Button.new()
		_email_retry.name = "NumbersEmailRetry"
		_email_retry.text = "RETRY EMAIL"
		_email_retry.hide()
		_email_retry.pressed.connect(_send_official_email)
		footer.add_child(_email_retry)
		footer.move_child(_email_retry, 1)

func present(victory: bool, report: Dictionary, boss_name: String) -> void:
	super.present(victory, report, boss_name)
	title_label.text = "NUMBERS BOSS REVIEW"
	subtitle_label.text = "BOSS TRIAL  ·  %s  ·  NUMBERS 1-10" % boss_name.to_upper()
	var words_card: Node = find_child("WordsCard", true, false)
	if words_card != null:
		var words_caption: Label = words_card.find_child("CaptionLabel", true, false) as Label
		if words_caption != null:
			words_caption.text = "CORRECT ANSWERS"
	var submitted_caption: Label = find_child("YourAnswerCaption", true, false) as Label
	if submitted_caption != null:
		submitted_caption.text = "YOUR ANSWER"
	var correct_caption: Label = find_child("CorrectSentenceCaption", true, false) as Label
	if correct_caption != null:
		correct_caption.text = "CORRECT ANSWER"
	var meaning_caption: Label = find_child("MeaningCaption", true, false) as Label
	if meaning_caption != null:
		meaning_caption.text = "QUESTION"

	# Number-boss attempts live in their own namespace; Boss 1 data is never
	# read or overwritten. The FIRST attempt stays official, even on defeat.
	var progress: Dictionary = SaveManager.get_assessment_progress()
	var raw_attempts: Variant = progress.get("numbers_boss_attempts", [])
	var attempts: Array = (raw_attempts as Array).duplicate(true) if raw_attempts is Array else []
	attempts.append({
		"attempt_number": attempts.size() + 1,
		"victory": victory,
		"date": Time.get_datetime_string_from_system(true),
		"report": report.duplicate(true)
	})
	progress["numbers_boss_attempts"] = attempts

	if not progress.has("numbers_boss_official"):
		progress["numbers_boss_official"] = report.duplicate(true)
		progress["numbers_boss_official_victory"] = victory
		progress["numbers_boss_email_sent"] = false

	if not SaveManager.save_assessment_progress(progress):
		_set_email_status("Could not save the number assessment; email not attempted.", false)
		return

	_email_sent = bool(progress.get("numbers_boss_email_sent", false))
	var raw_official: Variant = progress.get("numbers_boss_official", {})
	_official_report = (raw_official as Dictionary).duplicate(true) if raw_official is Dictionary else {}
	_official_victory = bool(progress.get("numbers_boss_official_victory", victory))

	if _email_sent:
		_set_email_status("Numbers assessment email already sent.", true)
	elif _official_report.is_empty():
		_set_email_status("No official numbers assessment found.", false)
	else:
		_send_official_email()

func _show_result(index: int, animate: bool = true) -> void:
	super._show_result(index, animate)
	if _rows.is_empty():
		return
	var row: Dictionary = _rows[_review_index]
	# The review still has Next/Previous and a progress bar, but no 3/10 labels.
	review_counter_label.text = "%s  ·  %s" % [
		str(row.get("lesson", "NUMBERS")), str(row.get("phase", "REVIEW"))
	]

func _build_learning_tip(row: Dictionary, is_correct: bool, timed_out: bool) -> String:
	var tip: String = str(row.get("learning_tip", "Count carefully, then choose the learned Kapampangan number."))
	if timed_out:
		return "Time ran out. " + tip
	if is_correct:
		return "Correct. " + tip
	return "Review: " + tip

func _build_email_report(original: Dictionary, victory: bool) -> Dictionary:
	var raw_rows: Variant = original.get("rows", [])
	var rows: Array = raw_rows if raw_rows is Array else []
	var total: int = rows.size()
	var correct_count: int = 0
	var time_sum: float = 0.0
	var vocabulary: Array[Dictionary] = []
	var mistakes: Array[Dictionary] = []
	var by_phase: Dictionary = {}
	var by_lesson: Dictionary = {}

	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var is_correct: bool = bool(row.get("correct", false))
		var phase: String = str(row.get("phase", "NUMBERS"))
		var bucket: Dictionary = by_phase.get(phase, {"attempts": 0, "correct": 0})
		bucket["attempts"] = int(bucket["attempts"]) + 1
		bucket["correct"] = int(bucket["correct"]) + (1 if is_correct else 0)
		by_phase[phase] = bucket
		var lesson: String = str(row.get("lesson", "MIXED"))
		var lesson_bucket: Dictionary = by_lesson.get(lesson, {"attempts": 0, "correct": 0})
		lesson_bucket["attempts"] = int(lesson_bucket["attempts"]) + 1
		lesson_bucket["correct"] = int(lesson_bucket["correct"]) + (1 if is_correct else 0)
		by_lesson[lesson] = lesson_bucket
		if is_correct:
			correct_count += 1
		time_sum += float(row.get("time_seconds", 0.0))
		vocabulary.append({
			"vocab_id": str(row.get("vocab_id", "")),
			"question_id": str(row.get("question_id", "")),
			"kapampangan": str(row.get("correct_sentence", "")),
			"english": str(row.get("prompt", "")),
			"topic_name": lesson.capitalize() + " - Numbers",
			"attempts": 1,
			"correct": 1 if is_correct else 0,
			"accuracy_percent": 100.0 if is_correct else 0.0
		})
		if not is_correct:
			mistakes.append({
				"topic_name": lesson.capitalize() + " - Numbers",
				"question_type": "multiple_choice",
				"prompt": str(row.get("prompt", "")),
				"player_answer": str(row.get("submitted_sentence", "")),
				"correct_answer": str(row.get("correct_sentence", "")),
				"feedback": str(row.get("learning_tip", "")),
				"score": 0.0,
				"timed_out": bool(row.get("timed_out", false))
			})

	var topics: Array[Dictionary] = []
	for lesson_name: String in ["MERCHANT", "FARMER", "ELDER", "MIXED"]:
		if not by_lesson.has(lesson_name):
			continue
		var bucket: Dictionary = by_lesson[lesson_name]
		var count: int = int(bucket["attempts"])
		var right: int = int(bucket["correct"])
		topics.append({
			"topic_name": lesson_name.capitalize() + " - Numbers",
			"attempts": count,
			"correct": right,
			"accuracy_percent": float(right) / float(maxi(count, 1)) * 100.0,
			"interpretation": "Kapampangan numbers"
		})

	var question_types: Array[Dictionary] = []
	for phase_name: String in ["RECOGNITION", "REASONING", "RECALL"]:
		if not by_phase.has(phase_name):
			continue
		var bucket: Dictionary = by_phase[phase_name]
		var count: int = int(bucket["attempts"])
		var right: int = int(bucket["correct"])
		question_types.append({
			"label": phase_name.capitalize(),
			"attempts": count,
			"correct": right,
			"accuracy_percent": float(right) / float(maxi(count, 1)) * 100.0,
			"interpretation": "Kapampangan numbers"
		})

	return {
		"assessment_type": "numbers_boss",
		"assessment_group": "cardinal_numbers",
		"boss_id": BOSS_ID,
		"lesson": "numbers_1_to_10",
		"player_name": str(GameManager.adventurer_name),
		"assessment_date": Time.get_datetime_string_from_system(),
		"total_questions": total,
		"fully_correct_questions": correct_count,
		"partial_questions": 0,
		"incorrect_questions": total - correct_count,
		"unanswered_questions": 0,  # Do not grade unattempted turns as mistakes.
		"core_questions_planned": 10,
		"core_questions_answered": mini(total, 10),
		"repeat_questions_answered": maxi(total - 10, 0),
		"points_earned": float(correct_count),
		"points_possible": float(total),
		"accuracy_percent": float(correct_count) / float(maxi(total, 1)) * 100.0,
		"average_time_seconds": time_sum / float(maxi(total, 1)),
		"topics": topics,
		"question_types": question_types,
		"difficulty_levels": [],
		"vocabulary": vocabulary,
		"question_results": rows.duplicate(true),
		"baseline_number_targets": ["metung", "adwa", "atlo_or_atlu", "apat", "lima", "anam", "pito_or_pitu", "walo_or_walu", "siyam", "apulo_or_apulu"],
		"mistakes": mistakes,
		"recommendations": ["Review any missed numbers across the Merchant, Farmer, and Elder lessons."],
		"summary": "Second Town Guardian: %d of %d attempted questions correct; %s. Numbers 1-10 were used." % [correct_count, total, "victory" if victory else "defeat"],
		"boss_outcome": "victory" if victory else "defeat",
		"total_combat_questions": total,
		"matched_baseline_questions": 0,
		"corrected_from_baseline": 0,
		"recognition_gaps": total - correct_count
	}

func _send_official_email() -> void:
	if _email_sent or _email_pending or _official_report.is_empty():
		return
	_email_pending = true
	_set_email_status("Sending numbers assessment email...", true)
	if is_instance_valid(_email_retry):
		_email_retry.hide()
	var sender: Node = NUMBERS_EMAIL_SENDER.new()
	sender.name = "NumbersBossAssessmentEmailSender"
	add_child(sender)
	sender.connect("completed", Callable(self, "_on_email_completed"))
	sender.call("send_numbers_assessment_report", _build_email_report(_official_report, _official_victory), _official_victory)

func _on_email_completed(success: bool, message: String) -> void:
	_email_pending = false
	if success:
		_email_sent = true
		var progress: Dictionary = SaveManager.get_assessment_progress()
		progress["numbers_boss_email_sent"] = true
		var saved: bool = SaveManager.save_assessment_progress(progress)
		_set_email_status("Numbers assessment email sent." if saved else "Email sent, but could not save delivery status.", saved)
	else:
		_set_email_status("Email failed: " + message, false)
		if is_instance_valid(_email_retry):
			_email_retry.show()

func _set_email_status(message: String, ok: bool) -> void:
	if is_instance_valid(_email_status):
		_email_status.text = message
		_email_status.add_theme_color_override("font_color", Color(0.68, 0.93, 0.70) if ok else Color(1.0, 0.66, 0.58))

func _on_finish_pressed() -> void:
	if _email_pending:
		_set_email_status("Email sending: wait until a result is shown.", true)
		return
	super._on_finish_pressed()
