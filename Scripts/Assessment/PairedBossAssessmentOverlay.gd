extends "res://Scripts/Battle/BossAssessmentOverlay.gd"

const COMPARISON_SCRIPT: GDScript = preload(
	"res://Scripts/Assessment/AssessmentComparison.gd"
)
const EMAIL_SENDER_SCRIPT: GDScript = preload(
	"res://Scripts/Assessment/AssessmentEmailSender.gd"
)

const ASSESSMENT_BOSS_ID: String = "forest_ylang_guardian"

var _post_email_pending: bool = false


func present(victory: bool, report: Dictionary, boss_name: String) -> void:
	super.present(victory, report, boss_name)

	if (
		BattleManager.current_enemy == null
		or BattleManager.current_enemy.enemy_id != ASSESSMENT_BOSS_ID
	):
		return

	var previous_attempts: Array[Dictionary] = SaveManager.get_boss_assessment_attempts()
	var previous_report: Dictionary = {}
	if not previous_attempts.is_empty():
		var previous_entry: Dictionary = previous_attempts.back()
		var previous_value: Variant = previous_entry.get("report", {})
		if previous_value is Dictionary:
			previous_report = (previous_value as Dictionary).duplicate(true)

	var attempt_data: Dictionary = SaveManager.record_boss_assessment_attempt(
		report,
		victory
	)
	var attempt_number := int(attempt_data.get("attempt_number", 1))

	var pre_report: Dictionary = SaveManager.get_pre_assessment_report()
	var comparison: Dictionary = COMPARISON_SCRIPT.build(pre_report, report)

	var retry_comparison: Dictionary = {}
	if not previous_report.is_empty():
		retry_comparison = COMPARISON_SCRIPT.compare_attempts(
			previous_report,
			report
		)

	_show_comparison_panel(
		attempt_number,
		victory,
		comparison,
		retry_comparison
	)

	# Only the first boss attempt is the official post-assessment email.
	if attempt_number == 1:
		var sender := EMAIL_SENDER_SCRIPT.new()
		sender.name = "PostAssessmentEmailSender"
		add_child(sender)
		sender.completed.connect(_on_post_email_completed)
		_post_email_pending = true
		sender.send_post_assessment_report(
			_build_email_report(report, comparison),
			comparison,
			victory,
			attempt_number
		)


func _show_comparison_panel(
	attempt_number: int,
	victory: bool,
	comparison: Dictionary,
	retry_comparison: Dictionary
) -> void:
	var content := find_child("Content", true, false) as VBoxContainer
	if content == null:
		push_warning("[PAIRED ASSESSMENT] Could not find overlay Content container.")
		return

	var panel := PanelContainer.new()
	panel.name = "LearningComparisonPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.105, 0.078, 1.0)
	style.border_width_left = 3
	style.border_color = Color(0.76, 0.59, 0.29, 1.0)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var heading := Label.new()
	heading.text = "LEARNING COMPARISON · ATTEMPT %d · %s" % [
		attempt_number,
		"VICTORY" if victory else "DEFEAT"
	]
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.88, 0.70, 0.36, 1.0))
	stack.add_child(heading)

	var matched := int(comparison.get("matched_count", 0))
	if matched > 0:
		var change := float(comparison.get("change_points", 0.0))
		var change_text := ("+" if change > 0.05 else "") + "%.1f" % change
		var summary := Label.new()
		summary.text = "Baseline %.1f%%  →  This attempt %.1f%%  (%s percentage points) · %d matched phrases" % [
			float(comparison.get("pre_accuracy", 0.0)),
			float(comparison.get("post_accuracy", 0.0)),
			change_text,
			matched
		]
		summary.add_theme_font_size_override("font_size", 13)
		summary.add_theme_color_override("font_color", Color(0.92, 0.91, 0.83, 1.0))
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(summary)

		var counts := Label.new()
		counts.text = "Newly learned: %d   Improved: %d   Retained: %d   Needs practice: %d   Inconsistent: %d" % [
			int(comparison.get("newly_learned", 0)),
			int(comparison.get("improved", 0)),
			int(comparison.get("retained", 0)),
			int(comparison.get("needs_practice", 0)),
			int(comparison.get("inconsistent", 0))
		]
		counts.add_theme_font_size_override("font_size", 11)
		counts.add_theme_color_override("font_color", Color(0.72, 0.76, 0.69, 1.0))
		counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(counts)
	else:
		var no_match := Label.new()
		no_match.text = "No matched baseline answers were available for this attempt. The boss answers were still saved."
		no_match.add_theme_font_size_override("font_size", 12)
		no_match.add_theme_color_override("font_color", Color(0.94, 0.72, 0.34, 1.0))
		no_match.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(no_match)

	if not retry_comparison.is_empty():
		var retry_label := Label.new()
		retry_label.text = "Since the previous attempt: %d improved · %d newly correct · %d still need practice." % [
			int(retry_comparison.get("improved", 0)) + int(retry_comparison.get("newly_learned", 0)),
			int(retry_comparison.get("newly_learned", 0)),
			int(retry_comparison.get("needs_practice", 0))
		]
		retry_label.add_theme_font_size_override("font_size", 11)
		retry_label.add_theme_color_override("font_color", Color(0.88, 0.70, 0.36, 1.0))
		retry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(retry_label)

	var insights: Array = comparison.get("insights", [])
	if not insights.is_empty():
		var insight := Label.new()
		insight.text = str(insights[0])
		insight.add_theme_font_size_override("font_size", 11)
		insight.add_theme_color_override("font_color", Color(0.82, 0.84, 0.76, 1.0))
		insight.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(insight)

	content.add_child(panel)
	# Place the comparison directly after the three result cards.
	content.move_child(panel, mini(3, content.get_child_count() - 1))


func _build_email_report(boss_report: Dictionary, comparison: Dictionary) -> Dictionary:
	var rows_value: Variant = boss_report.get("rows", [])
	var rows: Array = rows_value if rows_value is Array else []

	var earned_points: float = 0.0
	var fully_correct: int = 0
	var partial: int = 0
	var incorrect: int = 0
	var total_time: float = 0.0
	var mistakes: Array[Dictionary] = []
	var vocabulary: Array[Dictionary] = []
	var topic_buckets: Dictionary = {}

	for raw_row: Variant in rows:
		if not raw_row is Dictionary:
			continue

		var row: Dictionary = raw_row
		var score := clampf(
			float(row.get("score", float(row.get("score_percent", 0)) / 100.0)),
			0.0,
			1.0
		)
		earned_points += score

		if score >= 0.999:
			fully_correct += 1
		elif score > 0.0:
			partial += 1
		else:
			incorrect += 1

		var topic_key := str(row.get("topic_key", "common_greetings"))
		var topic_name := str(row.get("topic_name", "Common Greetings"))

		if not topic_buckets.has(topic_key):
			topic_buckets[topic_key] = {
				"topic_name": topic_name,
				"attempts": 0,
				"correct": 0,
				"earned": 0.0
			}

		var bucket: Dictionary = topic_buckets[topic_key]
		bucket["attempts"] = int(bucket["attempts"]) + 1
		bucket["earned"] = float(bucket["earned"]) + score
		if score >= 0.999:
			bucket["correct"] = int(bucket["correct"]) + 1
		topic_buckets[topic_key] = bucket

		var vocab_id := str(row.get("vocab_id", ""))
		if not vocab_id.is_empty():
			vocabulary.append({
				"vocab_id": vocab_id,
				"kapampangan": str(row.get("correct_sentence", "")),
				"english": str(row.get("english_meaning", "")),
				"topic_name": topic_name,
				"attempts": 1,
				"correct": 1 if score >= 0.999 else 0,
				"accuracy_percent": score * 100.0
			})

		if score < 0.999:
			var raw_mistakes: Variant = row.get("mistakes", [])
			var mistake_lines: Array = raw_mistakes if raw_mistakes is Array else []
			mistakes.append({
				"topic_name": topic_name,
				"question_type": "sentence_build",
				"prompt": "Build the Kapampangan phrase for: " + str(row.get("english_meaning", "the target phrase")),
				"player_answer": str(row.get("submitted_sentence", "(no answer submitted)")),
				"correct_answer": str(row.get("correct_sentence", "")),
				"feedback": " ".join(mistake_lines),
				"score": score,
				"timed_out": bool(row.get("timed_out", false))
			})

	var total := rows.size()
	var possible := float(total)
	var accuracy := earned_points / float(maxi(total, 1)) * 100.0

	var topics: Array[Dictionary] = []
	for raw_bucket: Variant in topic_buckets.values():
		var topic: Dictionary = raw_bucket
		var attempts := maxi(int(topic.get("attempts", 0)), 1)
		var topic_accuracy := float(topic.get("earned", 0.0)) / float(attempts) * 100.0
		topics.append({
			"topic_name": str(topic.get("topic_name", "Topic")),
			"attempts": attempts,
			"correct": int(topic.get("correct", 0)),
			"accuracy_percent": topic_accuracy,
			"interpretation": "Strong" if topic_accuracy >= 90.0 else "Developing" if topic_accuracy >= 60.0 else "Needs practice"
		})

	var insights_value: Variant = comparison.get("insights", [])
	var insights: Array = insights_value if insights_value is Array else []
	var recommendations: Array[String] = []
	for insight: Variant in insights:
		if recommendations.size() >= 3:
			break
		recommendations.append(str(insight))

	return {
		"assessment_type": "post",
		"player_name": str(GameManager.adventurer_name) if is_instance_valid(GameManager) else "Adventurer",
		"assessment_date": Time.get_datetime_string_from_system(),
		"total_questions": total,
		"fully_correct_questions": fully_correct,
		"partial_questions": partial,
		"incorrect_questions": incorrect,
		"points_earned": earned_points,
		"points_possible": possible,
		"accuracy_percent": accuracy,
		"average_time_seconds": 0.0,
		"topics": topics,
		"question_types": [{
			"label": "Sentence Building",
			"attempts": total,
			"correct": fully_correct,
			"earned_points": earned_points,
			"possible_points": possible,
			"accuracy_percent": accuracy,
			"interpretation": "Boss assessment"
		}],
		"difficulty_levels": [],
		"vocabulary": vocabulary,
		"mistakes": mistakes,
		"recommendations": recommendations,
		"summary": "The player completed %d boss assessment question(s), earning %.2f out of %.0f points (%.1f%%)." % [
			total,
			earned_points,
			possible,
			accuracy
		],
		"battle_words_correct": int(boss_report.get("words_correct", 0)),
		"battle_words_total": int(boss_report.get("words_total", 0)),
		"battle_mistake_count": int(boss_report.get("mistake_count", 0))
	}


func _on_finish_pressed() -> void:
	if _post_email_pending:
		return
	super._on_finish_pressed()


func _on_post_email_completed(success: bool, message: String) -> void:
	_post_email_pending = false
	if success:
		print("[PAIRED ASSESSMENT] Official post-assessment email sent.")
	else:
		push_warning("[PAIRED ASSESSMENT] Post-assessment email failed: " + message)
