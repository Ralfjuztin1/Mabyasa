extends "res://Scripts/Battle/QuizUIAnimated.gd"

## Uses the existing normal-question visuals without revealing correct answers.
## This is only used by the mandatory baseline, never by combat.

func _on_standard_answer_pressed(index: int, _chosen_button: Button) -> void:
	if _resolving or current_question == null:
		return
	if index < 0 or index >= current_question.choices.size():
		return

	_resolving = true
	for option: Button in _standard_buttons:
		option.disabled = true

	_emit_answer({
		"index": index,
		"elapsed": _elapsed,
		"timed_out": false
	})
