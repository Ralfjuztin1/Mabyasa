class_name FeedbackCard
extends PanelContainer

signal dismissed

var _title: Label
var _answer: Label
var _chosen: Label
var _hint: Label
var _button: Button
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.40
	anchor_bottom = 0.40
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = -300
	offset_right = 300
	offset_top = 0
	offset_bottom = 0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.055, 0.98)
	style.set_border_width_all(2)
	style.border_color = Color(0.78, 0.66, 0.36, 0.90)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	_title = _make_label(box, 28)
	_answer = _make_label(box, 22)
	_chosen = _make_label(box, 17)
	_hint = _make_label(box, 17)

	_button = Button.new()
	_button.text = "Got it"
	_button.custom_minimum_size = Vector2(160, 44)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_button_pressed)
	box.add_child(_button)


func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(500, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	parent.add_child(label)
	return label


func show_result(result: AnswerResult) -> void:
	_busy = false
	_title.text = "Time to learn this one" if result.timed_out else ("Almost!" if result.score > 0.0 else "Not quite")
	_answer.text = "Answer:  %s" % result.answer_line
	_chosen.text = result.chosen_note
	_chosen.visible = not result.chosen_note.strip_edges().is_empty()

	var lesson := result.hint
	if not result.pronunciation.is_empty():
		lesson += ("\n" if not lesson.is_empty() else "") + "Pronunciation: %s" % result.pronunciation
	if result.question_kind == "sentence_build" and result.score > 0.0 and result.score < 1.0:
		lesson += ("\n" if not lesson.is_empty() else "") + "You were partly there. Try the exact order next time."
	_hint.text = lesson
	_hint.visible = not lesson.strip_edges().is_empty()

	visible = true
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	await get_tree().process_frame
	pivot_offset = size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(self, "scale", Vector2.ONE, 0.20)
	_button.grab_focus()


func _on_button_pressed() -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	visible = false
	dismissed.emit()
