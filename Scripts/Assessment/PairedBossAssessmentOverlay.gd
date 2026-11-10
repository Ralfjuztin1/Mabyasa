extends "res://Scripts/Battle/BossAssessmentOverlay.gd"

## This IS the Guardian's official post-assessment; no separate quiz is opened.
## The first battle attempt is official. Later attempts are practice reports.

const COMPARISON_SCRIPT: GDScript = preload("res://Scripts/Assessment/AssessmentComparison.gd")
const EMAIL_SENDER_SCRIPT: GDScript = preload("res://Scripts/Assessment/AssessmentEmailSender.gd")

var _post_email_pending: bool = false
var _official_email_sent: bool = false
var _email_status_label: Label = null
var _email_retry_button: Button = null
var _email_report_payload: Dictionary = {}
var _email_comparison_payload: Dictionary = {}
var _email_victory: bool = false
var _email_attempt_number: int = 1


func present(victory: bool, report: Dictionary, boss_name: String) -> void:
	super.present(victory, report, boss_name)

	if BattleManager.current_enemy == null or BattleManager.current_enemy.enemy_id != "forest_ylang_guardian":
		return

	var previous_attempts: Array[Dictionary] = SaveManager.get_boss_assessment_attempts()
	var previous_report: Dictionary = {}
	if not previous_attempts.is_empty():
		var previous: Dictionary = previous_attempts.back()
		if previous.get("report", {}) is Dictionary:
			previous_report = (previous.get("report", {}) as Dictionary).duplicate(true)

	var saved_attempt: Dictionary = SaveManager.record_boss_assessment_attempt(report, victory)
	if saved_attempt.is_empty():
		push_error("[GUARDIAN ASSESSMENT] Could not save boss attempt; official email not sent.")
		_append_message("Could not save the boss assessment. Check account connection and Godot Output.")
		return

	var attempt_number: int = int(saved_attempt.get("attempt_number", previous_attempts.size() + 1))
	var pre_report: Dictionary = SaveManager.get_pre_assessment_report()
	var comparison: Dictionary = COMPARISON_SCRIPT.build(pre_report, report)
	var retry_comparison: Dictionary = {}
	if not previous_report.is_empty():
		retry_comparison = COMPARISON_SCRIPT.compare_attempts(previous_report, report)

	_show_comparison(attempt_number, victory, comparison, retry_comparison)

	if attempt_number == 1:
		_email_report_payload = _build_email_report(report, comparison, victory)
		_email_comparison_payload = comparison.duplicate(true)
		_email_victory = victory
		_email_attempt_number = 1
		if SaveManager.is_official_post_email_sent():
			_official_email_sent = true
			_set_email_status("Official result email already marked as sent.", true)
		else:
			_send_official_email()
	else:
		_set_email_status("Practice attempt: no additional official email.", true)


func _send_official_email() -> void:
	if _post_email_pending or _official_email_sent or _email_report_payload.is_empty():
		return

	_post_email_pending = true
	_set_email_status("Sending the official Guardian assessment email...", true)
	if is_instance_valid(_email_retry_button):
		_email_retry_button.hide()

	var sender := EMAIL_SENDER_SCRIPT.new()
	sender.name = "OfficialPostAssessmentEmailSender"
	add_child(sender)
	sender.completed.connect(_on_post_email_completed)
	sender.send_post_assessment_report(
		_email_report_payload,
		_email_comparison_payload,
		_email_victory,
		_email_attempt_number
	)


func _retry_official_email() -> void:
	if not _post_email_pending and not _official_email_sent:
		_send_official_email()


func _set_email_status(message: String, ok: bool) -> void:
	if is_instance_valid(_email_status_label):
		_email_status_label.text = message
		_email_status_label.add_theme_color_override(
			"font_color",
			Color(0.67, 0.89, 0.68) if ok else Color(0.97, 0.62, 0.49)
		)



func _append_message(message: String) -> void:
	var content := find_child("Content", true, false) as VBoxContainer
	if content == null:
		return
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)


func _show_comparison(
	attempt_number: int,
	victory: bool,
	comparison: Dictionary,
	retry_comparison: Dictionary
) -> void:
	var content := find_child("Content", true, false) as VBoxContainer
	if content == null:
		push_warning("[GUARDIAN ASSESSMENT] Missing comparison Content node.")
		return

	var panel := PanelContainer.new()
	panel.name = "LearningComparisonPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.075, 0.105, 0.078, 1.0)
	background.border_width_left = 3
	background.border_color = Color(0.76, 0.59, 0.29, 1.0)
	background.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	_add_line(stack, "GUARDIAN LEARNING COMPARISON · ATTEMPT %d · %s" % [
		attempt_number, "VICTORY" if victory else "DEFEAT"
	], 15, Color(0.88, 0.70, 0.36))

	if attempt_number == 1:
		_add_line(stack, "Official first post-assessment", 12, Color(0.72, 0.76, 0.69))
	else:
		_add_line(stack, "Practice attempt · official first-attempt results unchanged", 12, Color(0.72, 0.76, 0.69))

	var matched: int = int(comparison.get("matched_count", 0))
	if matched <= 0:
		_add_line(stack, "No matching baseline answers were available. The battle was saved, but no learning comparison can be made.", 13)
	else:
		_add_line(stack,
			"Before gameplay: %d/%d recognized or translated · Guardian: %d/%d fully constructed" % [
				int(comparison.get("pre_correct", 0)), matched,
				int(comparison.get("post_correct", 0)), matched
			], 13)
		_add_line(stack,
			"Corrected: %d   Applied again: %d   Still weak: %d   Recognition gap: %d" % [
				int(comparison.get("improved", 0)), int(comparison.get("retained", 0)),
				int(comparison.get("needs_practice", 0)), int(comparison.get("recognition_gap", 0))
			], 12)
		_add_line(stack, "Different question formats: these are skill outcomes, not a direct percentage improvement.",
			11, Color(0.72, 0.76, 0.69))

	if not retry_comparison.is_empty() and int(retry_comparison.get("matched_count", 0)) > 0:
		_add_line(stack, "Since the previous attempt: %d newly correct, %d still weak or inconsistent." % [
			int(retry_comparison.get("improved", 0)),
			int(retry_comparison.get("needs_practice", 0)) + int(retry_comparison.get("recognition_gap", 0))
		], 12, Color(0.88, 0.70, 0.36))

	# Keep the main comparison compact so the existing battle review and
	# CONTINUE/RETURN buttons remain visible at lower screen resolutions.
	# Put detailed coaching inside the existing scrolling review body.
	var advice_value: Variant = comparison.get("recommendations", [])
	var review_body := find_child("ReviewBody", true, false) as VBoxContainer
	if advice_value is Array and is_instance_valid(review_body):
		var advice_box := VBoxContainer.new()
		advice_box.name = "GuardianLearningRecommendations"
		_add_line(advice_box, "PRACTISE NEXT", 13, Color(0.88, 0.70, 0.36))
		for advice: Variant in (advice_value as Array):
			_add_line(advice_box, "• " + str(advice), 11)
		review_body.add_child(advice_box)
		review_body.move_child(advice_box, 0)

	_email_status_label = Label.new()
	_email_status_label.name = "OfficialEmailStatus"
	_email_status_label.text = "Preparing assessment email status..."
	_email_status_label.add_theme_font_size_override("font_size", 12)
	_email_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_email_status_label)

	_email_retry_button = Button.new()
	_email_retry_button.name = "RetryOfficialAssessmentEmail"
	_email_retry_button.text = "RETRY OFFICIAL EMAIL"
	_email_retry_button.visible = false
	_email_retry_button.pressed.connect(_retry_official_email)
	stack.add_child(_email_retry_button)

	content.add_child(panel)
	content.move_child(panel, mini(3, content.get_child_count() - 1))


func _add_line(stack: VBoxContainer, value: String, font_size: int = 12, color: Color = Color(0.90, 0.91, 0.84)) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)


func _build_email_report(boss_report: Dictionary, comparison: Dictionary, victory: bool) -> Dictionary:
	# Keep the same report schema expected by the working Google Apps Script.
	# Dedupe repeated combat questions: one official result per phrase.
	var raw: Variant = boss_report.get("rows", [])
	var rows: Array = raw if raw is Array else []
	var seen: Dictionary = {}
	var unique: Array[Dictionary] = []
	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var id: String = str(row.get("vocab_id", ""))
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		unique.append(row)

	var fully_correct: int = 0
	var partial: int = 0
	var incorrect: int = 0
	var earned: float = 0.0
	var vocabulary: Array[Dictionary] = []
	var mistakes: Array[Dictionary] = []
	for row: Dictionary in unique:
		var score: float = clampf(float(row.get("score", float(row.get("score_percent", 0.0)) / 100.0)), 0.0, 1.0)
		earned += score
		if bool(row.get("correct", false)):
			fully_correct += 1
		elif score > 0.0:
			partial += 1
		else:
			incorrect += 1

		vocabulary.append({
			"vocab_id": str(row.get("vocab_id", "")),
			"kapampangan": str(row.get("correct_sentence", "")),
			"english": str(row.get("english_meaning", "")),
			"topic_name": str(row.get("topic_name", "Common Greetings")),
			"attempts": 1,
			"correct": 1 if bool(row.get("correct", false)) else 0,
			"accuracy_percent": score * 100.0
		})

		if not bool(row.get("correct", false)) and mistakes.size() < 5:
			var parts_value: Variant = row.get("mistakes", [])
			var feedback: String = "Review the correct word order."
			if parts_value is Array and not (parts_value as Array).is_empty():
				feedback = str((parts_value as Array)[0])
			mistakes.append({
				"topic_name": str(row.get("topic_name", "Common Greetings")),
				"question_type": "sentence_build",
				"prompt": "Build the phrase for: " + str(row.get("english_meaning", "")),
				"player_answer": str(row.get("submitted_sentence", "")),
				"correct_answer": str(row.get("correct_sentence", "")),
				"feedback": feedback,
				"score": score,
				"timed_out": bool(row.get("timed_out", false))
			})

	var insight_values: Variant = comparison.get("insights", [])
	var insights: Array = insight_values if insight_values is Array else []
	var summary: String = "Guardian %s. %d/%d first-attempt phrase constructions fully correct." % [
		"victory" if victory else "defeat", fully_correct, unique.size()
	]
	if not insights.is_empty():
		summary += " " + str(insights[0])
	if insights.size() > 1:
		summary += " " + str(insights[1])

	# Actual construction accuracy by lesson, never a fabricated zero.
	var topic_buckets: Dictionary = {}
	for row: Dictionary in unique:
		var topic_name: String = str(row.get("topic_name", "Common Greetings"))
		if not topic_buckets.has(topic_name):
			topic_buckets[topic_name] = {"count": 0, "correct": 0}
		var bucket: Dictionary = topic_buckets[topic_name]
		bucket["count"] = int(bucket["count"]) + 1
		if bool(row.get("correct", false)):
			bucket["correct"] = int(bucket["correct"]) + 1
		topic_buckets[topic_name] = bucket

	var topic_rows: Array[Dictionary] = []
	for raw_name: Variant in topic_buckets.keys():
		if topic_rows.size() >= 3:
			break
		var bucket: Dictionary = topic_buckets[raw_name]
		var count: int = int(bucket["count"])
		var correct_count: int = int(bucket["correct"])
		topic_rows.append({
			"topic_name": str(raw_name),
			"attempts": count,
			"correct": correct_count,
			"accuracy_percent": float(correct_count) * 100.0 / float(maxi(count, 1)),
			"interpretation": "Guardian sentence construction"
		})

	var recommendation_values: Variant = comparison.get("recommendations", [])
	var recommendations: Array[String] = []
	if recommendation_values is Array:
		for item: Variant in (recommendation_values as Array):
			if recommendations.size() >= 3:
				break
			recommendations.append(str(item))

	return {
		"assessment_type": "post",
		"player_name": str(GameManager.adventurer_name) if is_instance_valid(GameManager) else "Adventurer",
		"assessment_date": Time.get_datetime_string_from_system(),
		"total_questions": unique.size(),
		"fully_correct_questions": fully_correct,
		"partial_questions": partial,
		"incorrect_questions": incorrect,
		"unanswered_questions": 0,
		"points_earned": earned,
		"points_possible": float(unique.size()),
		"accuracy_percent": float(fully_correct) * 100.0 / float(maxi(unique.size(), 1)),
		"average_time_seconds": 0.0,
		"topics": topic_rows,
		"question_types": [{"label": "Guardian sentence construction", "attempts": unique.size(), "correct": fully_correct, "accuracy_percent": float(fully_correct) * 100.0 / float(maxi(unique.size(), 1)), "interpretation": "Construction skill"}],
		"difficulty_levels": [],
		"vocabulary": vocabulary,
		"mistakes": mistakes,
		"recommendations": recommendations,
		"summary": summary,
		"boss_outcome": "victory" if victory else "defeat",
		"total_combat_questions": int(boss_report.get("total_sentences", 0)),
		"matched_baseline_questions": int(comparison.get("matched_count", 0)),
		"corrected_from_baseline": int(comparison.get("improved", 0)),
		"recognition_gaps": int(comparison.get("recognition_gap", 0))
	}


func _on_finish_pressed() -> void:
	if _post_email_pending:
		return
	super._on_finish_pressed()


func _on_post_email_completed(success: bool, message: String) -> void:
	_post_email_pending = false
	if success:
		_official_email_sent = true
		var saved: bool = SaveManager.mark_official_post_email_sent()
		_set_email_status(
			"Official assessment email sent." if saved else "Email sent, but delivery status could not be saved.",
			true
		)
		print("[GUARDIAN ASSESSMENT] Official first-attempt email sent.")
	else:
		_set_email_status("Email failed: " + message, false)
		if is_instance_valid(_email_retry_button):
			_email_retry_button.show()
		push_warning("[GUARDIAN ASSESSMENT] Email not sent: " + message)
