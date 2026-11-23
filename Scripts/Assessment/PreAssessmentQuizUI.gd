extends "res://Scripts/Battle/QuizUIAnimated.gd"

## Blind baseline UI: no correct-answer colors, animations or retries.
## Unlike the regular matching UI, every pair is accepted exactly once,
## then evaluated privately after submission.


func _is_boss_battle() -> bool:
	return false


func _make_choice_button(label_text: String) -> Button:
	var button: Button = super._make_choice_button(label_text)
	# Retain original game's hovered arrow art; neutralize disabled/pressed states.
	var normal_style: StyleBox = button.get_theme_stylebox("normal")
	if normal_style != null:
		var pressed_style: StyleBox = normal_style.duplicate() as StyleBox
		var disabled_style: StyleBox = normal_style.duplicate() as StyleBox
		if pressed_style != null:
			button.add_theme_stylebox_override("pressed", pressed_style)
		if disabled_style != null:
			button.add_theme_stylebox_override("disabled", disabled_style)
	return button


func _build_match(question: QuizQuestion) -> void:
	super._build_match(question)
	_sub_prompt.text = "Select a time on the left, then its Kapampangan greeting on the right."


func _on_standard_answer_pressed(index: int, _chosen_button: Button) -> void:
	if _resolving or current_question == null:
		return
	if index < 0 or index >= current_question.choices.size():
		return
	_resolving = true
	for option: Button in _standard_buttons:
		option.disabled = true
		option.modulate = Color.WHITE
	_emit_answer({
		"index": index,
		"elapsed": _elapsed,
		"timed_out": false
	})


func _on_match_right_pressed(index: int) -> void:
	# Do NOT call super: normal matching reveals which pairs are correct
	# and lets players try again until they are right.
	if _resolving or current_question == null or _match_left_selected < 0:
		return
	if index < 0 or index >= _match_right_buttons.size():
		return
	var left_button: Button = _match_left_buttons[_match_left_selected]
	var right_button: Button = _match_right_buttons[index]
	if left_button.disabled or right_button.disabled:
		return

	_match_pairs.append({
		"left_id": str(left_button.get_meta("match_id")),
		"right_id": str(right_button.get_meta("match_id"))
	})
	# Neutral acknowledgement; never mark correct or incorrect.
	left_button.modulate = Color.WHITE
	right_button.modulate = Color.WHITE
	left_button.disabled = true
	right_button.disabled = true
	_match_left_selected = -1
	_update_match_progress(current_question)
	if _all_match_pairs_complete():
		_resolving = true
		_emit_answer({
			"pairs": _match_pairs.duplicate(true),
			"mistakes": 0,
			"elapsed": _elapsed,
			"timed_out": false
		})
