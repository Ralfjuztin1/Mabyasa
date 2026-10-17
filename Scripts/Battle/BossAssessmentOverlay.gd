extends Control

## Sequential, learner-focused post-boss review.
## Battle/combat logic remains in BattleManager; this script only presents its report.

signal finished(victory: bool)

const GOLD: Color = Color(0.88, 0.70, 0.36, 1.0)
const CREAM: Color = Color(0.96, 0.93, 0.84, 1.0)
const MUTED: Color = Color(0.69, 0.72, 0.65, 1.0)
const GREEN: Color = Color(0.48, 0.79, 0.52, 1.0)
const RED: Color = Color(0.93, 0.48, 0.39, 1.0)
const AMBER: Color = Color(0.94, 0.72, 0.34, 1.0)

var title_label: Label
var subtitle_label: Label
var outcome_label: Label
var accuracy_value: Label
var words_value: Label
var mistakes_value: Label
var review_panel: PanelContainer
var empty_state_panel: PanelContainer
var review_counter_label: Label
var review_state_label: Label
var review_progress: ProgressBar
var your_answer_label: Label
var correct_sentence_label: Label
var meaning_label: Label
var lesson_label: Label
var extra_mistakes_label: Label
var previous_button: Button
var next_button: Button
var finish_button: Button

var _controls_ready: bool = false
var _victory: bool = false
var _finish_clicked: bool = false
var _rows: Array[Dictionary] = []
var _review_index: int = 0
var _transition_tween: Tween
var _defeat_splash_generation: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	title_label = _find_control("TitleLabel") as Label
	subtitle_label = _find_control("SubtitleLabel") as Label
	outcome_label = _find_control("OutcomeLabel") as Label
	accuracy_value = _find_card_value("AccuracyCard")
	words_value = _find_card_value("WordsCard")
	mistakes_value = _find_card_value("MistakesCard")
	review_panel = _find_control("ReviewPanel") as PanelContainer
	empty_state_panel = _find_control("EmptyStatePanel") as PanelContainer
	review_counter_label = _find_control("ReviewCounterLabel") as Label
	review_state_label = _find_control("ReviewStateLabel") as Label
	review_progress = _find_control("ReviewProgress") as ProgressBar
	your_answer_label = _find_control("YourAnswerLabel") as Label
	correct_sentence_label = _find_control("CorrectSentenceLabel") as Label
	meaning_label = _find_control("MeaningLabel") as Label
	lesson_label = _find_control("LessonLabel") as Label
	extra_mistakes_label = _find_control("ExtraMistakesLabel") as Label
	previous_button = _find_control("PreviousButton") as Button
	next_button = _find_control("NextButton") as Button
	finish_button = _find_control("FinishButton") as Button

	var required_controls: Array = [
		title_label, subtitle_label, outcome_label,
		accuracy_value, words_value, mistakes_value,
		review_panel, empty_state_panel, review_counter_label,
		review_state_label, review_progress, your_answer_label,
		correct_sentence_label, meaning_label, lesson_label,
		extra_mistakes_label, previous_button, next_button, finish_button
	]
	for control: Variant in required_controls:
		if control == null:
			push_error(
				"[BOSS ASSESSMENT] Missing controls in BossAssessmentOverlay.tscn. "
				+ "Restore the matching scene and script files from the package."
			)
			return

	_controls_ready = true
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	finish_button.pressed.connect(_on_finish_pressed)


func _find_control(control_name: String) -> Node:
	return find_child(control_name, true, false)


func _find_card_value(card_name: String) -> Label:
	var card: Node = _find_control(card_name)
	if card == null:
		return null
	return card.find_child("ValueLabel", true, false) as Label


func present(victory: bool, report: Dictionary, boss_name: String) -> void:
	if not _controls_ready:
		push_error("[BOSS ASSESSMENT] Cannot present because the overlay controls are not ready.")
		return

	_victory = victory
	_finish_clicked = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_label.text = "BATTLE REVIEW"
	subtitle_label.text = "BOSS TRIAL  ·  %s" % boss_name.to_upper()
	outcome_label.text = "BOSS DEFEATED" if victory else "YOU WERE DEFEATED · LEARN AND RETURN"
	outcome_label.add_theme_color_override("font_color", GREEN if victory else RED)

	var accuracy: int = clampi(int(report.get("accuracy_percent", 0)), 0, 100)
	var words_correct: int = int(report.get("words_correct", 0))
	var words_total: int = int(report.get("words_total", 0))
	var mistake_count: int = int(report.get("mistake_count", 0))
	accuracy_value.text = "%d%%" % accuracy
	words_value.text = "%d / %d" % [words_correct, words_total]
	mistakes_value.text = str(mistake_count)
	mistakes_value.add_theme_color_override("font_color", RED if mistake_count > 0 else GREEN)

	_rows.clear()
	var raw_rows: Variant = report.get("rows", [])
	if raw_rows is Array:
		for raw_row: Variant in raw_rows:
			if raw_row is Dictionary:
				var row_data: Dictionary = raw_row
				_rows.append(row_data.duplicate(true))

	_review_index = 0
	if _rows.is_empty():
		review_panel.hide()
		empty_state_panel.show()
		review_counter_label.text = "NO RESPONSES TO REVIEW"
		review_progress.max_value = 1.0
		review_progress.value = 0.0
		previous_button.disabled = true
		next_button.disabled = true
		finish_button.disabled = false
		finish_button.text = "CONTINUE" if victory else "RETURN TO CHECKPOINT"
	else:
		review_panel.show()
		empty_state_panel.hide()
		_show_result(0, false)

	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.20)
	if not _rows.is_empty() and not next_button.disabled:
		next_button.grab_focus()
	else:
		finish_button.grab_focus()

	# Make defeat unmistakable before the learner review appears underneath.
	# The reveal is presentation-only and does not alter the checkpoint flow.
	if not victory:
		call_deferred("_play_defeat_splash", boss_name)


func _play_defeat_splash(boss_name: String) -> void:
	_defeat_splash_generation += 1
	var generation: int = _defeat_splash_generation
	var splash := Control.new()
	splash.name = "BossDefeatSplash"
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.z_index = 100
	splash.modulate.a = 0.0
	add_child(splash)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.055, 0.008, 0.012, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590.0, 250.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.025, 0.028, 0.99)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = RED
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.scale = Vector2(0.82, 0.82)
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var kicker := Label.new()
	kicker.text = "MABIYASA  ·  BOSS TRIAL"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", GOLD)
	kicker.add_theme_font_size_override("font_size", 13)
	stack.add_child(kicker)

	var title := Label.new()
	title.text = "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", RED)
	title.add_theme_font_size_override("font_size", 48)
	stack.add_child(title)

	var detail := Label.new()
	detail.text = "%s has overcome you.\nReview your phrases, then return stronger." % boss_name
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", CREAM)
	detail.add_theme_font_size_override("font_size", 16)
	stack.add_child(detail)

	var appear := create_tween()
	appear.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	appear.tween_property(splash, "modulate:a", 1.0, 0.18)
	appear.parallel().tween_property(panel, "scale", Vector2.ONE, 0.24)
	await appear.finished
	if not is_instance_valid(splash) or generation != _defeat_splash_generation:
		return

	await get_tree().create_timer(1.45).timeout
	if not is_instance_valid(splash) or generation != _defeat_splash_generation:
		return

	var fade := create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(splash, "modulate:a", 0.0, 0.28)
	await fade.finished
	if is_instance_valid(splash):
		splash.queue_free()


func _show_result(index: int, animate: bool = true) -> void:
	if _rows.is_empty():
		return

	_review_index = clampi(index, 0, _rows.size() - 1)
	var row: Dictionary = _rows[_review_index]
	var is_correct: bool = bool(row.get("correct", false))
	var timed_out: bool = bool(row.get("timed_out", false))
	var score_percent: int = clampi(int(row.get("score_percent", 0)), 0, 100)

	review_counter_label.text = "RESULT %02d  /  %02d" % [_review_index + 1, _rows.size()]
	review_progress.max_value = maxi(_rows.size(), 1)
	review_progress.value = _review_index + 1

	if timed_out and not is_correct:
		review_state_label.text = "TIME RAN OUT"
		review_state_label.add_theme_color_override("font_color", AMBER)
	elif is_correct:
		review_state_label.text = "CORRECT  ·  %d%%" % score_percent
		review_state_label.add_theme_color_override("font_color", GREEN)
	else:
		review_state_label.text = "LET'S FIX THIS  ·  %d%%" % score_percent
		review_state_label.add_theme_color_override("font_color", RED)

	your_answer_label.text = str(row.get("submitted_sentence", "(no answer submitted)"))
	correct_sentence_label.text = str(row.get("correct_sentence", "—"))
	meaning_label.text = str(row.get("english_meaning", "Meaning not recorded."))
	lesson_label.text = _build_learning_tip(row, is_correct, timed_out)

	var raw_mistakes: Variant = row.get("mistakes", [])
	var mistakes: Array = raw_mistakes if raw_mistakes is Array else []
	if mistakes.size() > 1:
		extra_mistakes_label.text = "There are %d more word placements to check. Use the correct sentence above as your model." % (mistakes.size() - 1)
		extra_mistakes_label.show()
	else:
		extra_mistakes_label.hide()

	previous_button.disabled = _review_index <= 0
	next_button.disabled = _review_index >= _rows.size() - 1
	finish_button.disabled = _victory and _review_index < _rows.size() - 1
	finish_button.text = "CONTINUE" if _victory else "RETURN TO CHECKPOINT"

	if animate:
		if is_instance_valid(_transition_tween) and _transition_tween.is_running():
			_transition_tween.kill()
		review_panel.modulate.a = 0.45
		_transition_tween = create_tween()
		_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition_tween.tween_property(review_panel, "modulate:a", 1.0, 0.16)
	else:
		review_panel.modulate.a = 1.0

	if animate:
		if not next_button.disabled:
			next_button.grab_focus()
		else:
			finish_button.grab_focus()


func _build_learning_tip(row: Dictionary, is_correct: bool, timed_out: bool) -> String:
	if is_correct:
		return "Why it works: your words are in the expected order. Read the phrase once and connect it to the meaning so you can recall both next time."

	if timed_out:
		return "Practice tip: build the phrase slowly, one word at a time. Aim for the correct order first; speed comes after you remember the pattern."

	var raw_mistakes: Variant = row.get("mistakes", [])
	var mistakes: Array = raw_mistakes if raw_mistakes is Array else []
	if mistakes.is_empty():
		return "Study the corrected sentence, say it aloud, then try rebuilding it from memory. Focus on the word order rather than speed."

	var first_mistake: String = str(mistakes[0])
	var regex := RegEx.new()
	regex.compile("^Position ([0-9]+): expected '([^']*)', got '([^']*)'\\.$")
	var match_result := regex.search(first_mistake)
	if match_result != null:
		var position: String = match_result.get_string(1)
		var expected: String = match_result.get_string(2)
		var chosen: String = match_result.get_string(3)
		return (
			"Focus on word %s: you placed “%s”, but the phrase needs “%s” here. "
			+ "Compare that position with the corrected sentence, then read the full phrase aloud."
		) % [position, chosen, expected]

	regex.compile("^Position ([0-9]+): expected '([^']*)', but no word was placed\\.$")
	match_result = regex.search(first_mistake)
	if match_result != null:
		return "Word %s is missing. Find “%s” in the corrected sentence, then read the phrase from left to right." % [match_result.get_string(1), match_result.get_string(2)]

	regex.compile("^Extra word at position ([0-9]+): '([^']*)'\\.$")
	match_result = regex.search(first_mistake)
	if match_result != null:
		return "You added “%s” at word %s. Check whether every selected word belongs in the target phrase, then compare the final order." % [match_result.get_string(2), match_result.get_string(1)]

	return (
		"Focus point: %s. Read the corrected sentence, notice how the words are ordered, "
		+ "then try saying it without looking."
	) % first_mistake


func _on_previous_pressed() -> void:
	if _review_index > 0:
		_show_result(_review_index - 1)


func _on_next_pressed() -> void:
	if _review_index < _rows.size() - 1:
		_show_result(_review_index + 1)


func _on_finish_pressed() -> void:
	# On defeat, returning must always remain available, regardless of review index.
	if _finish_clicked or (_victory and finish_button.disabled):
		return
	_finish_clicked = true
	finish_button.disabled = true
	finished.emit(_victory)


func show_checkpoint_error(message: String) -> void:
	# Called by BattleScreen if the checkpoint manager could not restore.
	# Keep the review open, display the reason, and allow another attempt.
	_finish_clicked = false
	if is_instance_valid(finish_button):
		finish_button.disabled = false
		finish_button.text = "RETRY CHECKPOINT"
	if is_instance_valid(outcome_label):
		outcome_label.text = "CHECKPOINT RESTORE FAILED · RETRY"
		outcome_label.add_theme_color_override("font_color", RED)
	if is_instance_valid(lesson_label):
		lesson_label.text = message
