class_name QuizUI
extends Control

## Mabiyasa language-combat quiz interface.
## Presentation and input only: BattleManager still validates answers and combat.
## Standard questions use clear click-to-answer buttons; matching and sentence
## construction keep their current input model and payload format.

signal answer_selected(payload: Variant)

const GOLD := Color(0.93, 0.80, 0.38)
const TEXT := Color(0.94, 0.92, 0.86)
const MUTED := Color(0.70, 0.72, 0.68)
const GOOD := Color(0.55, 0.92, 0.48)
const BAD := Color(0.96, 0.43, 0.36)
const DISABLED_TINT := Color(0.62, 0.65, 0.59)

const CARD_MAX_WIDTH := 900.0
const CARD_MAX_HEIGHT := 620.0
const CARD_EDGE_MARGIN := 24.0
const ANSWER_MAX_WIDTH := 680.0
const ANSWER_BUTTON_HEIGHT := 54.0
const ANSWER_BUTTON_GAP := 10

var current_question: QuizQuestion = null
var _resolving := false
var _elapsed := 0.0
var _time_limit := 20.0
var _last_timer_tenth := -1
var _last_timer_band := -1
var _transition_tween: Tween

@onready var _card: PanelContainer = $Card
@onready var _type_label: Label = $Card/RootBox/Header/TypeLabel
@onready var _timer_bar: ProgressBar = $Card/RootBox/TimerBar
@onready var _timer_label: Label = $Card/RootBox/Header/TimerLabel
@onready var _prompt_label: Label = $Card/RootBox/PromptLabel
@onready var _sub_prompt: Label = $Card/RootBox/SubPrompt
@onready var _content: Control = $Card/RootBox/Content
@onready var _sword_panel: PanelContainer = $Card/RootBox/Content/SwordPanel
@onready var _standard_hint: Label = $Card/RootBox/Content/StandardHint
@onready var _answer_grid: GridContainer = $Card/RootBox/Content/AnswerGrid
@onready var _match_root: VBoxContainer = $Card/RootBox/Content/MatchRoot
@onready var _match_progress_label: Label = $Card/RootBox/Content/MatchRoot/MatchProgressLabel
@onready var _match_left_buttons_box: VBoxContainer = $Card/RootBox/Content/MatchRoot/MatchColumns/LeftColumn/LeftButtons
@onready var _match_right_buttons_box: VBoxContainer = $Card/RootBox/Content/MatchRoot/MatchColumns/RightColumn/RightButtons
@onready var _sentence_root: VBoxContainer = $Card/RootBox/Content/SentenceRoot
@onready var _sentence_bar: FlowContainer = $Card/RootBox/Content/SentenceRoot/SentencePanel/SentenceBar
@onready var _sentence_bank: FlowContainer = $Card/RootBox/Content/SentenceRoot/SentenceBank
@onready var _sentence_check_button: Button = $Card/RootBox/Content/SentenceRoot/SentenceCheckButton
@onready var _choice_button_template: Button = $ButtonTemplates/ChoiceButtonTemplate

var _standard_buttons: Array[Button] = []
var _match_pairs: Array[Dictionary] = []
var _match_left_selected := -1
var _match_mistakes := 0
var _match_left_buttons: Array[Button] = []
var _match_right_buttons: Array[Button] = []
var _sentence_order: Array[String] = []
var _sentence_source_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1001
	mouse_filter = Control.MOUSE_FILTER_STOP

	_sentence_check_button.pressed.connect(_submit_sentence)
	get_viewport().size_changed.connect(_layout_card)
	_setup_base_style()
	call_deferred("_layout_card")


func _setup_base_style() -> void:
	# The scene provides the detailed dark-green/gold StyleBoxes. These overrides
	# set readable type and click behaviour without creating textures each frame.
	_type_label.add_theme_color_override("font_color", GOLD)
	_timer_label.add_theme_color_override("font_color", TEXT)
	_prompt_label.add_theme_color_override("font_color", TEXT)
	_prompt_label.add_theme_font_size_override("font_size", 32)
	_sub_prompt.add_theme_color_override("font_color", MUTED)
	_match_progress_label.add_theme_color_override("font_color", GOLD)
	_standard_hint.visible = false
	_sword_panel.visible = false
	_choice_button_template.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _layout_card() -> void:
	if not is_instance_valid(_card):
		return

	var viewport_size := get_viewport_rect().size
	var target_width := minf(CARD_MAX_WIDTH, viewport_size.x - CARD_EDGE_MARGIN * 2.0)
	var target_height := minf(CARD_MAX_HEIGHT, viewport_size.y - CARD_EDGE_MARGIN * 2.0)
	target_width = maxf(target_width, 460.0)
	target_height = maxf(target_height, 420.0)

	_card.offset_left = -target_width * 0.5
	_card.offset_right = target_width * 0.5
	_card.offset_top = -target_height * 0.5
	_card.offset_bottom = target_height * 0.5


func _process(delta: float) -> void:
	if not visible:
		return

	# Keep the pointer visible during the quiz, even if world input tries to
	# recapture it. This is a single inexpensive state check.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _resolving or current_question == null:
		return

	_elapsed += delta
	var remaining := maxf(_time_limit - _elapsed, 0.0)
	_timer_bar.value = remaining / maxf(_time_limit, 0.01) * 100.0

	# Timer text and warning colours update only when their visible state changes.
	var shown_tenth := int(ceil(remaining * 10.0))
	if shown_tenth != _last_timer_tenth:
		_last_timer_tenth = shown_tenth
		_timer_label.text = "%.1f" % remaining

	var band := 0
	if remaining <= 3.0:
		band = 2
	elif remaining <= 6.0:
		band = 1

	if band != _last_timer_band:
		_last_timer_band = band
		match band:
			2:
				_timer_label.add_theme_color_override("font_color", BAD)
				_timer_bar.modulate = BAD
			1:
				_timer_label.add_theme_color_override("font_color", GOLD)
				_timer_bar.modulate = GOLD
			_:
				_timer_label.add_theme_color_override("font_color", TEXT)
				_timer_bar.modulate = Color.WHITE

	if _elapsed >= _time_limit:
		_timeout()


func start_quiz(question: QuizQuestion) -> void:
	if question == null:
		return

	if _transition_tween != null and _transition_tween.is_running():
		_transition_tween.kill()

	current_question = question
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resolving = false
	_elapsed = 0.0
	_last_timer_tenth = -1
	_last_timer_band = -1
	_time_limit = maxf(question.time_limit, 5.0)

	_layout_card()
	_timer_bar.value = 100.0
	_timer_label.text = "%.1f" % _time_limit
	_timer_label.add_theme_color_override("font_color", TEXT)
	_timer_bar.modulate = Color.WHITE
	_type_label.text = question.get_type_label().to_upper()
	_prompt_label.text = question.prompt

	# Short vocabulary prompts get more emphasis; long instructions stay readable.
	_prompt_label.add_theme_font_size_override(
		"font_size",
		36 if question.prompt.length() <= 24 else 27
	)

	_sub_prompt.text = "Choose the correct answer."
	_sub_prompt.visible = true
	_sword_panel.visible = false
	_standard_hint.visible = false

	_clear_dynamic_content()

	match question.quiz_type:
		QuizQuestion.QuizType.MULTIPLE_CHOICE, \
		QuizQuestion.QuizType.FILL_BLANK, \
		QuizQuestion.QuizType.TRANSLATE:
			_build_standard_answers(question)
		QuizQuestion.QuizType.MATCH:
			_build_match(question)
		QuizQuestion.QuizType.SENTENCE_BUILD:
			_build_sentence(question)

	visible = true
	set_process(true)
	call_deferred("_focus_first_choice")
	modulate.a = 0.0
	_card.scale = Vector2(0.985, 0.985)
	_card.pivot_offset = _card.size * 0.5

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_transition_tween.tween_property(_card, "scale", Vector2.ONE, 0.18)


func _focus_first_choice() -> void:
	# Keyboard users start on the first available action; mouse input still works.
	if not visible or _resolving:
		return
	if not _standard_buttons.is_empty():
		_standard_buttons[0].grab_focus()
	elif not _match_left_buttons.is_empty():
		_match_left_buttons[0].grab_focus()
	elif not _sentence_source_buttons.is_empty():
		var first_button: Variant = _sentence_source_buttons.values()[0]
		if first_button is Button:
			(first_button as Button).grab_focus()


func _build_standard_answers(question: QuizQuestion) -> void:
	# Simple stacked options match the new quiz concept and are easier to use
	# than dragging a card to a small target. Payload remains {index, elapsed, timed_out}.
	_answer_grid.visible = true
	_answer_grid.columns = 1
	_answer_grid.add_theme_constant_override("v_separation", ANSWER_BUTTON_GAP)
	_answer_grid.anchor_left = 0.5
	_answer_grid.anchor_right = 0.5
	_answer_grid.anchor_top = 0.02
	_answer_grid.anchor_bottom = 0.98

	var usable_width := maxf(_content.size.x - 64.0, 360.0)
	var grid_width := minf(ANSWER_MAX_WIDTH, usable_width)
	_answer_grid.offset_left = -grid_width * 0.5
	_answer_grid.offset_right = grid_width * 0.5
	_answer_grid.offset_top = 0.0
	_answer_grid.offset_bottom = 0.0

	for index in question.choices.size():
		var button := _make_choice_button(question.choices[index])
		button.custom_minimum_size = Vector2(0.0, ANSWER_BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 19)
		button.set_meta("answer_index", index)
		button.pressed.connect(_on_standard_answer_pressed.bind(index, button))
		_answer_grid.add_child(button)
		_standard_buttons.append(button)


func _on_standard_answer_pressed(index: int, chosen_button: Button) -> void:
	if _resolving or current_question == null:
		return
	if index < 0 or index >= current_question.choices.size():
		return

	_resolving = true
	var correct_index := current_question.correct_index

	# Freeze choices and give immediate, clear feedback before sending the answer.
	for i in _standard_buttons.size():
		var button := _standard_buttons[i]
		button.disabled = true
		if i == correct_index:
			button.modulate = GOOD
		elif button == chosen_button:
			button.modulate = BAD
		else:
			button.modulate = DISABLED_TINT

	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(self) or current_question == null:
		return

	_emit_answer({
		"index": index,
		"elapsed": _elapsed,
		"timed_out": false
	})


func _build_match(question: QuizQuestion) -> void:
	_sub_prompt.text = "Choose a Kapampangan phrase, then its English meaning."
	_sub_prompt.visible = true
	_match_root.visible = true
	_update_match_progress(question)

	var left_indices: Array[int] = []
	for i in question.match_left_ids.size():
		left_indices.append(i)
	left_indices.shuffle()

	var right_indices: Array[int] = []
	for i in question.match_right_ids.size():
		right_indices.append(i)
	right_indices.shuffle()

	for index in left_indices:
		if index >= question.match_left_texts.size() or index >= question.match_left_ids.size():
			continue
		var button := _make_choice_button(question.match_left_texts[index])
		button.custom_minimum_size = Vector2(0.0, 50.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("match_id", question.match_left_ids[index])
		button.pressed.connect(_on_match_left_pressed.bind(_match_left_buttons.size()))
		_match_left_buttons.append(button)
		_match_left_buttons_box.add_child(button)

	for index in right_indices:
		if index >= question.match_right_texts.size() or index >= question.match_right_ids.size():
			continue
		var button := _make_choice_button(question.match_right_texts[index])
		button.custom_minimum_size = Vector2(0.0, 50.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("match_id", question.match_right_ids[index])
		button.pressed.connect(_on_match_right_pressed.bind(_match_right_buttons.size()))
		_match_right_buttons.append(button)
		_match_right_buttons_box.add_child(button)


func _build_sentence(question: QuizQuestion) -> void:
	_sub_prompt.text = "Tap words to build the sentence; tap a placed word to remove it."
	_sub_prompt.visible = true
	_sentence_root.visible = true
	_sentence_check_button.disabled = true

	var token_ids: Array[String] = []
	var token_texts: Dictionary = {}

	for i in question.sentence_token_ids.size():
		if i >= question.sentence_token_texts.size():
			continue
		var id := question.sentence_token_ids[i]
		if token_ids.has(id):
			continue
		token_ids.append(id)
		token_texts[id] = question.sentence_token_texts[i]

	for i in question.sentence_distractor_ids.size():
		if i >= question.sentence_distractor_texts.size():
			continue
		var id := question.sentence_distractor_ids[i]
		if token_ids.has(id):
			continue
		token_ids.append(id)
		token_texts[id] = question.sentence_distractor_texts[i]

	token_ids.shuffle()
	for token_id in token_ids:
		var button := _make_choice_button(str(token_texts[token_id]))
		button.custom_minimum_size = Vector2(112.0, 44.0)
		button.set_meta("token_id", token_id)
		button.pressed.connect(_on_sentence_token_pressed.bind(button))
		_sentence_source_buttons[token_id] = button
		_sentence_bank.add_child(button)


func _on_match_left_pressed(index: int) -> void:
	if _resolving or index < 0 or index >= _match_left_buttons.size():
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
			correct = (
				i < current_question.match_right_ids.size()
				and current_question.match_right_ids[i] == right_id
			)
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
	if current_question != null:
		_update_match_progress(current_question)

	if _all_match_pairs_complete():
		_resolving = true
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self) or current_question == null:
			return
		_emit_answer({
			"pairs": _match_pairs.duplicate(true),
			"mistakes": _match_mistakes,
			"elapsed": _elapsed,
			"timed_out": false
		})


func _update_match_progress(question: QuizQuestion) -> void:
	_match_progress_label.text = "MATCHED  %d / %d" % [
		_match_pairs.size(),
		question.match_left_ids.size()
	]


func _all_match_pairs_complete() -> bool:
	return (
		current_question != null
		and _match_pairs.size() >= current_question.match_left_ids.size()
	)


func _on_sentence_token_pressed(button: Button) -> void:
	if _resolving or not is_instance_valid(button) or button.disabled:
		return

	var token_id := str(button.get_meta("token_id"))
	var token_text := button.text
	_sentence_order.append(token_id)
	button.disabled = true
	button.modulate = Color(0.62, 0.66, 0.58)

	var placed := _make_choice_button(token_text)
	placed.custom_minimum_size = Vector2(112.0, 40.0)
	placed.modulate = Color(0.96, 0.84, 0.47)
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
		QuizQuestion.QuizType.MULTIPLE_CHOICE, \
		QuizQuestion.QuizType.FILL_BLANK, \
		QuizQuestion.QuizType.TRANSLATE:
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
	set_process(false)
	answer_selected.emit(payload)
	_hide_quiz()


func _hide_quiz() -> void:
	if _transition_tween != null and _transition_tween.is_running():
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_transition_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	set_process(false)


func _clear_dynamic_content() -> void:
	var containers: Array[Node] = [
		_answer_grid,
		_match_left_buttons_box,
		_match_right_buttons_box,
		_sentence_bar,
		_sentence_bank
	]

	for container in containers:
		for child in container.get_children():
			child.free()

	_standard_buttons.clear()
	_answer_grid.visible = false
	_match_root.visible = false
	_sentence_root.visible = false
	_sword_panel.visible = false
	_standard_hint.visible = false
	_match_pairs.clear()
	_match_left_selected = -1
	_match_mistakes = 0
	_match_left_buttons.clear()
	_match_right_buttons.clear()
	_sentence_order.clear()
	_sentence_check_button.disabled = true
	_sentence_source_buttons.clear()


func _make_choice_button(label_text: String) -> Button:
	# Reuse the one scene-configured style template rather than allocating new
	# StyleBox resources for each answer.
	var button := _choice_button_template.duplicate() as Button
	button.visible = true
	button.disabled = false
	button.text = label_text
	button.modulate = Color.WHITE
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
