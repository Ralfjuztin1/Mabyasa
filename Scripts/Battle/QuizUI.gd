class_name QuizUI
extends Control

## Language-combat interface.
## Normal attacks keep the satisfying answer-card -> sword interaction.
## Matching and boss sentence-building use their own compact mini-games.

signal answer_selected(payload: Variant)

const ANSWER_CARD_SCENE: PackedScene = preload("res://Scenes/Battle/AnswerCard.tscn")

const GOLD := Color(0.93, 0.80, 0.38)
const TEXT := Color(0.94, 0.92, 0.86)
const MUTED := Color(0.70, 0.72, 0.68)
const PANEL := Color(0.055, 0.065, 0.06, 0.97)
const PANEL_ALT := Color(0.10, 0.115, 0.105, 0.98)
const GOOD := Color(0.45, 0.92, 0.62)
const BAD := Color(0.95, 0.43, 0.40)

var current_question: QuizQuestion = null
var _resolving := false
var _elapsed := 0.0
var _time_limit := 20.0

var _card: PanelContainer
var _type_label: Label
var _timer_bar: ProgressBar
var _timer_label: Label
var _prompt_label: Label
var _sub_prompt: Label
var _content: Control
var _sword_panel: PanelContainer
var _sword_label: Label

var _answer_cards: Array[AnswerCard] = []

var _match_pairs: Array[Dictionary] = []
var _match_left_selected := -1
var _match_mistakes := 0
var _match_left_buttons: Array[Button] = []
var _match_right_buttons: Array[Button] = []
var _match_progress_label: Label

var _sentence_order: Array[String] = []
var _sentence_bar: FlowContainer
var _sentence_bank: FlowContainer
var _sentence_check_button: Button
var _sentence_source_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()


func _process(delta: float) -> void:
	if not visible or _resolving or current_question == null:
		return

	_elapsed += delta
	var remaining := maxf(_time_limit - _elapsed, 0.0)
	_timer_bar.value = remaining / maxf(_time_limit, 0.01) * 100.0
	_timer_label.text = "%.1f" % remaining

	if remaining <= 3.0:
		_timer_label.add_theme_color_override("font_color", BAD)
		_timer_bar.modulate = BAD
	elif remaining <= 6.0:
		_timer_label.add_theme_color_override("font_color", GOLD)
		_timer_bar.modulate = GOLD
	else:
		_timer_label.add_theme_color_override("font_color", TEXT)
		_timer_bar.modulate = Color.WHITE

	if _elapsed >= _time_limit:
		_timeout()


func start_quiz(question: QuizQuestion) -> void:
	if question == null:
		return

	current_question = question
	_resolving = false
	_elapsed = 0.0
	_time_limit = maxf(question.time_limit, 5.0)
	_timer_bar.value = 100.0
	_timer_label.text = "%.1f" % _time_limit
	_timer_label.add_theme_color_override("font_color", TEXT)
	_timer_bar.modulate = Color.WHITE

	_type_label.text = question.get_type_label()
	_prompt_label.text = question.prompt
	_sub_prompt.text = ""
	_sub_prompt.visible = false
	_sword_panel.visible = question.quiz_type not in [QuizQuestion.QuizType.MATCH, QuizQuestion.QuizType.SENTENCE_BUILD]
	_clear_dynamic_content()

	match question.quiz_type:
		QuizQuestion.QuizType.MULTIPLE_CHOICE, QuizQuestion.QuizType.FILL_BLANK, QuizQuestion.QuizType.TRANSLATE:
			_build_standard_answers(question)
		QuizQuestion.QuizType.MATCH:
			_build_match(question)
		QuizQuestion.QuizType.SENTENCE_BUILD:
			_build_sentence(question)

	visible = true
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	pivot_offset = size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func _build_shell() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.015, 0.02, 0.018, 0.72)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	_card = PanelContainer.new()
	_card.anchor_left = 0.08
	_card.anchor_right = 0.92
	_card.anchor_top = 0.055
	_card.anchor_bottom = 0.94
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PANEL
	card_style.border_color = Color(0.60, 0.52, 0.30, 0.55)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 24
	card_style.shadow_color = Color(0, 0, 0, 0.45)
	card_style.shadow_size = 12
	_card.add_theme_stylebox_override("panel", card_style)
	add_child(_card)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	_card.add_child(root_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 32
	root_box.add_child(header)

	_type_label = _new_label(20, GOLD)
	_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_type_label)

	_timer_label = _new_label(17, TEXT)
	_timer_label.custom_minimum_size.x = 64
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_timer_label)

	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size.y = 8
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	_timer_bar.show_percentage = false
	var timer_bg := StyleBoxFlat.new()
	timer_bg.bg_color = Color(0.12, 0.12, 0.11, 1)
	timer_bg.set_corner_radius_all(4)
	var timer_fill := StyleBoxFlat.new()
	timer_fill.bg_color = GOLD
	timer_fill.set_corner_radius_all(4)
	_timer_bar.add_theme_stylebox_override("background", timer_bg)
	_timer_bar.add_theme_stylebox_override("fill", timer_fill)
	root_box.add_child(_timer_bar)

	_prompt_label = _new_label(27, TEXT)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size.y = 94
	root_box.add_child(_prompt_label)

	_sub_prompt = _new_label(16, MUTED)
	_sub_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_sub_prompt)

	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	root_box.add_child(_content)

	_sword_panel = PanelContainer.new()
	_sword_panel.anchor_left = 0.37
	_sword_panel.anchor_right = 0.63
	_sword_panel.anchor_top = 0.36
	_sword_panel.anchor_bottom = 0.66
	_sword_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sword_style := StyleBoxFlat.new()
	sword_style.bg_color = PANEL_ALT
	sword_style.border_color = Color(0.84, 0.72, 0.40, 0.90)
	sword_style.set_border_width_all(3)
	sword_style.set_corner_radius_all(12)
	sword_style.shadow_color = Color(0, 0, 0, 0.42)
	sword_style.shadow_size = 8
	_sword_panel.add_theme_stylebox_override("panel", sword_style)
	_content.add_child(_sword_panel)

	_sword_label = _new_label(25, GOLD)
	_sword_label.text = "⚔  DROP ANSWER HERE"
	_sword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sword_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sword_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sword_panel.add_child(_sword_label)


func _build_standard_answers(question: QuizQuestion) -> void:
	# The sword and answer cards occupy separate vertical zones.
	# They are intentionally NOT overlapped. The old layout placed the
	# choices over the drop zone because both controls shared the same area.
	_sword_panel.anchor_left = 0.32
	_sword_panel.anchor_right = 0.68
	_sword_panel.anchor_top = 0.01
	_sword_panel.anchor_bottom = 0.27

	var hint := _new_label(14, MUTED)
	hint.text = "Drag the correct answer into the sword"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.27
	hint.anchor_bottom = 0.33
	_content.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 3 if question.choices.size() <= 3 else 2
	grid.anchor_left = 0.03
	grid.anchor_right = 0.97
	grid.anchor_top = 0.35
	grid.anchor_bottom = 0.99
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)

	var card_width := 250.0
	if question.choices.size() <= 2:
		card_width = 330.0

	for i in question.choices.size():
		var card: AnswerCard = ANSWER_CARD_SCENE.instantiate()
		grid.add_child(card)
		card.custom_minimum_size = Vector2(card_width, 74)
		card.answer_index = i
		card.answer_text = question.choices[i]
		card.sword_drop_zone = _sword_panel
		card.drag_layer = _content
		card.dropped_on_sword.connect(_on_card_dropped)
		card.drag_started.connect(_on_card_drag_started)
		_answer_cards.append(card)


func _build_match(question: QuizQuestion) -> void:
	_sub_prompt.text = "Tap a Kapampangan phrase, then tap its English meaning."
	_sub_prompt.visible = true

	var wrapper := VBoxContainer.new()
	wrapper.anchor_left = 0.05
	wrapper.anchor_right = 0.95
	wrapper.anchor_top = 0.03
	wrapper.anchor_bottom = 0.97
	wrapper.add_theme_constant_override("separation", 7)
	_content.add_child(wrapper)

	_match_progress_label = _new_label(15, MUTED)
	_match_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrapper.add_child(_match_progress_label)
	_update_match_progress(question)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	wrapper.add_child(columns)

	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 8)
	columns.add_child(left_box)

	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 8)
	columns.add_child(right_box)

	var left_title := _new_label(15, GOLD)
	left_title.text = "KAPAMPANGAN"
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_box.add_child(left_title)

	var right_title := _new_label(15, GOLD)
	right_title.text = "ENGLISH"
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_box.add_child(right_title)

	var left_indices: Array[int] = []
	for i in question.match_left_ids.size():
		left_indices.append(i)
	left_indices.shuffle()

	var right_indices: Array[int] = []
	for i in question.match_right_ids.size():
		right_indices.append(i)
	right_indices.shuffle()

	for index in left_indices:
		var button := _make_choice_button(question.match_left_texts[index])
		button.custom_minimum_size.y = 54
		button.set_meta("match_id", question.match_left_ids[index])
		button.pressed.connect(_on_match_left_pressed.bind(_match_left_buttons.size()))
		_match_left_buttons.append(button)
		left_box.add_child(button)

	for index in right_indices:
		var button := _make_choice_button(question.match_right_texts[index])
		button.custom_minimum_size.y = 54
		button.set_meta("match_id", question.match_right_ids[index])
		button.pressed.connect(_on_match_right_pressed.bind(_match_right_buttons.size()))
		_match_right_buttons.append(button)
		right_box.add_child(button)


func _build_sentence(question: QuizQuestion) -> void:
	_sub_prompt.text = "Build the sentence from the word cards. You can remove a card by tapping it."
	_sub_prompt.visible = true

	var wrapper := VBoxContainer.new()
	wrapper.anchor_left = 0.04
	wrapper.anchor_right = 0.96
	wrapper.anchor_top = 0.02
	wrapper.anchor_bottom = 0.98
	wrapper.add_theme_constant_override("separation", 9)
	_content.add_child(wrapper)

	var label := _new_label(15, GOLD)
	label.text = "YOUR SENTENCE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrapper.add_child(label)

	var sentence_panel := PanelContainer.new()
	sentence_panel.custom_minimum_size.y = 96
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.085, 1)
	style.border_color = Color(0.65, 0.56, 0.32, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	sentence_panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(sentence_panel)

	_sentence_bar = FlowContainer.new()
	_sentence_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	_sentence_bar.add_theme_constant_override("h_separation", 7)
	_sentence_bar.add_theme_constant_override("v_separation", 7)
	sentence_panel.add_child(_sentence_bar)

	var bank_label := _new_label(15, MUTED)
	bank_label.text = "WORD CARDS"
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrapper.add_child(bank_label)

	_sentence_bank = FlowContainer.new()
	_sentence_bank.alignment = FlowContainer.ALIGNMENT_CENTER
	_sentence_bank.add_theme_constant_override("h_separation", 9)
	_sentence_bank.add_theme_constant_override("v_separation", 9)
	_sentence_bank.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_sentence_bank)

	_sentence_check_button = _make_action_button("⚔  STRIKE")
	_sentence_check_button.custom_minimum_size = Vector2(210, 48)
	_sentence_check_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sentence_check_button.disabled = true
	_sentence_check_button.pressed.connect(_submit_sentence)
	wrapper.add_child(_sentence_check_button)

	var token_ids: Array[String] = []
	var token_texts: Dictionary = {}
	for i in question.sentence_token_ids.size():
		var id := question.sentence_token_ids[i]
		if token_ids.has(id):
			continue
		token_ids.append(id)
		token_texts[id] = question.sentence_token_texts[i]

	for i in question.sentence_distractor_ids.size():
		var id := question.sentence_distractor_ids[i]
		if token_ids.has(id):
			continue
		token_ids.append(id)
		token_texts[id] = question.sentence_distractor_texts[i]

	token_ids.shuffle()
	for token_id in token_ids:
		var button := _make_choice_button(str(token_texts[token_id]))
		button.custom_minimum_size = Vector2(120, 48)
		button.set_meta("token_id", token_id)
		button.pressed.connect(_on_sentence_token_pressed.bind(button))
		_sentence_source_buttons[token_id] = button
		_sentence_bank.add_child(button)


func _on_card_drag_started(_card: AnswerCard) -> void:
	var tw := create_tween()
	tw.tween_property(_sword_panel, "modulate", Color(1.12, 1.08, 0.78), 0.10)


func _on_card_dropped(card: AnswerCard) -> void:
	if _resolving:
		return
	_resolving = true
	for answer_card in _answer_cards:
		answer_card.lock()

	var center := _sword_panel.get_global_rect().get_center()
	card.fly_to(center)
	await get_tree().create_timer(0.20).timeout
	if not is_instance_valid(self) or current_question == null:
		return

	var correct := card.answer_index == current_question.correct_index
	await _sword_feedback(correct)
	_emit_answer({
		"index": card.answer_index,
		"elapsed": _elapsed,
		"timed_out": false
	})


func _on_match_left_pressed(index: int) -> void:
	if _resolving:
		return
	if index < 0 or index >= _match_left_buttons.size():
		return
	var button := _match_left_buttons[index]
	if button.disabled:
		return

	for candidate in _match_left_buttons:
		if not candidate.disabled:
			candidate.modulate = Color.WHITE

	if _match_left_selected == index:
		_match_left_selected = -1
		return

	_match_left_selected = index
	button.modulate = Color(1.05, 1.00, 0.72)


func _on_match_right_pressed(index: int) -> void:
	if _resolving or _match_left_selected < 0:
		return
	if index < 0 or index >= _match_right_buttons.size():
		return

	var left_button := _match_left_buttons[_match_left_selected]
	var right_button := _match_right_buttons[index]
	if left_button.disabled or right_button.disabled:
		return

	var left_id := str(left_button.get_meta("match_id"))
	var right_id := str(right_button.get_meta("match_id"))
	var correct := false

	for i in current_question.match_left_ids.size():
		if current_question.match_left_ids[i] == left_id:
			correct = i < current_question.match_right_ids.size() and current_question.match_right_ids[i] == right_id
			break

	if correct:
		_match_pairs.append({"left_id": left_id, "right_id": right_id})
		left_button.disabled = true
		right_button.disabled = true
		left_button.modulate = GOOD
		right_button.modulate = GOOD
		left_button.text = "✓  " + left_button.text
		right_button.text = "✓  " + right_button.text
	else:
		_match_mistakes += 1
		left_button.modulate = BAD
		right_button.modulate = BAD
		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(left_button) and not left_button.disabled:
			left_button.modulate = Color.WHITE
		if is_instance_valid(right_button) and not right_button.disabled:
			right_button.modulate = Color.WHITE

	_match_left_selected = -1
	_update_match_progress(current_question)

	if _all_match_pairs_complete():
		_resolving = true
		await get_tree().create_timer(0.18).timeout
		_emit_answer({
			"pairs": _match_pairs.duplicate(true),
			"mistakes": _match_mistakes,
			"elapsed": _elapsed,
			"timed_out": false
		})


func _update_match_progress(question: QuizQuestion) -> void:
	if not is_instance_valid(_match_progress_label):
		return
	_match_progress_label.text = "Matched: %d / %d" % [_match_pairs.size(), question.match_left_ids.size()]


func _all_match_pairs_complete() -> bool:
	return current_question != null and _match_pairs.size() >= current_question.match_left_ids.size()


func _on_sentence_token_pressed(button: Button) -> void:
	if _resolving or not is_instance_valid(button) or button.disabled:
		return

	var token_id := str(button.get_meta("token_id"))
	var token_text := str(button.text)
	_sentence_order.append(token_id)
	button.disabled = true
	button.modulate = Color(0.58, 0.60, 0.57)

	var placed := _make_choice_button(token_text)
	placed.custom_minimum_size = Vector2(120, 42)
	placed.modulate = Color(0.92, 0.82, 0.46)
	placed.pressed.connect(_remove_sentence_token.bind(token_id, placed, button))
	_sentence_bar.add_child(placed)
	_sentence_check_button.disabled = _sentence_order.is_empty()


func _remove_sentence_token(token_id: String, placed: Button, source: Button) -> void:
	if _resolving:
		return
	var index := _sentence_order.find(token_id)
	if index >= 0:
		_sentence_order.remove_at(index)
	if is_instance_valid(placed):
		placed.queue_free()
	if is_instance_valid(source):
		source.disabled = false
		source.modulate = Color.WHITE
	_sentence_check_button.disabled = _sentence_order.is_empty()


func _submit_sentence() -> void:
	if _resolving or _sentence_order.is_empty():
		return
	_resolving = true
	_emit_answer({
		"order": _sentence_order.duplicate(),
		"elapsed": _elapsed,
		"timed_out": false
	})


func _timeout() -> void:
	if _resolving or current_question == null:
		return
	_resolving = true

	match current_question.quiz_type:
		QuizQuestion.QuizType.MULTIPLE_CHOICE, QuizQuestion.QuizType.FILL_BLANK, QuizQuestion.QuizType.TRANSLATE:
			_emit_answer({"index": -1, "elapsed": _time_limit, "timed_out": true})
		QuizQuestion.QuizType.MATCH:
			_emit_answer({
				"pairs": _match_pairs.duplicate(true),
				"mistakes": _match_mistakes,
				"elapsed": _time_limit,
				"timed_out": true
			})
		QuizQuestion.QuizType.SENTENCE_BUILD:
			_emit_answer({
				"order": _sentence_order.duplicate(),
				"elapsed": _time_limit,
				"timed_out": true
			})


func _emit_answer(payload: Dictionary) -> void:
	answer_selected.emit(payload)
	_hide_quiz()


func _hide_quiz() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): visible = false)


func _clear_dynamic_content() -> void:
	for child in _content.get_children():
		if child == _sword_panel:
			continue
		child.queue_free()

	_answer_cards.clear()
	_match_pairs.clear()
	_match_left_selected = -1
	_match_mistakes = 0
	_match_left_buttons.clear()
	_match_right_buttons.clear()
	_match_progress_label = null
	_sentence_order.clear()
	_sentence_bar = null
	_sentence_bank = null
	_sentence_check_button = null
	_sentence_source_buttons.clear()


func _sword_feedback(correct: bool) -> void:
	if not is_instance_valid(_sword_panel) or not _sword_panel.visible:
		return

	var tw := create_tween()
	if correct:
		tw.set_parallel(true)
		tw.tween_property(_sword_panel, "modulate", Color(0.70, 1.20, 0.78), 0.10)
		tw.tween_property(_sword_panel, "scale", Vector2(1.07, 1.07), 0.10)
		tw.chain().tween_property(_sword_panel, "scale", Vector2.ONE, 0.16)
	else:
		tw.tween_property(_sword_panel, "modulate", Color(1.30, 0.60, 0.55), 0.08)
		tw.tween_property(_sword_panel, "position:x", _sword_panel.position.x + 7.0, 0.05)
		tw.tween_property(_sword_panel, "position:x", _sword_panel.position.x - 7.0, 0.05)
		tw.tween_property(_sword_panel, "position:x", _sword_panel.position.x, 0.05)
	await tw.finished
	_sword_panel.modulate = Color.WHITE


func _make_choice_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.11, 0.105, 0.98)
	normal.border_color = Color(0.56, 0.52, 0.42, 0.50)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.15, 0.14, 0.11, 1)
	hover.border_color = GOLD

	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.20, 0.18, 0.11, 1)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _make_action_button(label_text: String) -> Button:
	var button := _make_choice_button(label_text)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _new_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.text = ""
	return label
