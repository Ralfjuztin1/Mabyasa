extends "res://Scripts/Battle/QuizUIAnimated.gd"

## Baseline assessment: retain the game's ORIGINAL selected-arrow hover artwork,
## but never reveal whether the chosen answer was right or wrong.
## Combat and boss quizzes are unaffected by this script.


func _is_boss_battle() -> bool:
	# Never apply the boss's red background flash to the pre-assessment.
	return false


func _make_choice_button(label_text: String) -> Button:
	var button: Button = super._make_choice_button(label_text)

	# The original QuizUI.tscn button template already contains the game's
	# arrow/selected-image hover style (Mabiyasa_Button_Selected.png).
	# Do NOT override "hover" or "hover_pressed": doing so hides that arrow.
	# Only neutralize the appearance of buttons when clicked/disabled.
	var normal_style: StyleBox = button.get_theme_stylebox("normal")
	if normal_style != null:
		var pressed_style: StyleBox = normal_style.duplicate() as StyleBox
		var disabled_style: StyleBox = normal_style.duplicate() as StyleBox
		if pressed_style != null:
			button.add_theme_stylebox_override("pressed", pressed_style)
		if disabled_style != null:
			button.add_theme_stylebox_override("disabled", disabled_style)

	return button


func _on_standard_answer_pressed(index: int, _chosen_button: Button) -> void:
	if _resolving or current_question == null:
		return
	if index < 0 or index >= current_question.choices.size():
		return

	_resolving = true
	for option: Button in _standard_buttons:
		option.disabled = true
		option.modulate = Color.WHITE

	# Record the answer without color-coded feedback, shaking or revealing
	# the answer key. The original arrow is shown only while hovering.
	_emit_answer({
		"index": index,
		"elapsed": _elapsed,
		"timed_out": false
	})
