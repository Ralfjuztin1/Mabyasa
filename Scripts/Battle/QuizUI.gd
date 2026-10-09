class_name QuizUI
extends Control

## Language-combat interface.
## Normal attacks use answer cards and the sword.
## Matching and boss sentence-building use separate mini-games.

signal answer_selected(payload: Variant)

const ANSWER_CARD_SCENE: PackedScene = preload("res://Scenes/Battle/AnswerCard.tscn")

const GOLD := Color(0.93, 0.80, 0.38)
const TEXT := Color(0.94, 0.92, 0.86)
const MUTED := Color(0.70, 0.72, 0.68)
const GOOD := Color(0.45, 0.92, 0.62)
const BAD := Color(0.95, 0.43, 0.40)

var current_question: QuizQuestion = null
var _resolving := false
var _elapsed := 0.0
var _time_limit := 20.0

@onready var _card: PanelContainer = $Card
@onready var _type_label: Label = $Card/RootBox/Header/TypeLabel
@onready var _timer_bar: ProgressBar = $Card/RootBox/TimerBar
@onready var _timer_label: Label = $Card/RootBox/Header/TimerLabel
@onready var _prompt_label: Label = $Card/RootBox/PromptLabel
@onready var _sub_prompt: Label = $Card/RootBox/SubPrompt
@onready var _content: Control = $Card/RootBox/Content
@onready var _sword_panel: PanelContainer = $Card/RootBox/Content/SwordPanel
@onready var _sword_label: Label = $Card/RootBox/Content/SwordPanel/SwordLabel
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

var _answer_cards: Array[AnswerCard] = []

var _match_pairs: Array[Dictionary] = []
var _match_left_selected := -1
var _match_mistakes := 0
var _match_left_buttons: Array[Button] = []
var _match_right_buttons: Array[Button] = []

var _sentence_order: Array[String] = []
var _sentence_source_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sentence_check_button.pressed.connect(_submit_sentence)


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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

	_sword_panel.visible = question.quiz_type not in [
		QuizQuestion.QuizType.MATCH,
		QuizQuestion.QuizType.SENTENCE_BUILD
	]

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
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	pivot_offset = size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func _build_standard_answers(question: QuizQuestion) -> void:
	# Fixed layout is stored in the scene. Only answer cards are created here.
	_sword_panel.anchor_left = 0.32
	_sword_panel.anchor_right = 0.68
	_sword_panel.anchor_top = 0.01
	_sword_panel.anchor_bottom = 0.27

	_standard_hint.visible = true
	_answer_grid.visible = true
	_answer_grid.columns = 3 if question.choices.size() <= 3 else 2

	var card_width := 250.0
	if question.choices.size() <= 2:
		card_width = 330.0

	for i in question.choices.size():
		var card: AnswerCard = ANSWER_CARD_SCENE.instantiate()
		_answer_grid.add_child(card)

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

	# Randomize display positions, but preserve each button's vocabulary ID.
	for index in left_indices:
		var button := _make_choice_button(question.match_left_texts[index])
		button.custom_minimum_size.y = 54
		button.set_meta("match_id", question.match_left_ids[index])
		button.pressed.connect(
			_on_match_left_pressed.bind(_match_left_buttons.size())
		)

		_match_left_buttons.append(button)
		_match_left_buttons_box.add_child(button)

	for index in right_indices:
		var button := _make_choice_button(question.match_right_texts[index])
		button.custom_minimum_size.y = 54
		button.set_meta("match_id", question.match_right_ids[index])
		button.pressed.connect(
			_on_match_right_pressed.bind(_match_right_buttons.size())
		)

		_match_right_buttons.append(button)
		_match_right_buttons_box.add_child(button)


func _build_sentence(question: QuizQuestion) -> void:
	_sub_prompt.text = "Build the sentence from the word cards. You can remove a card by tapping it."
	_sub_prompt.visible = true
	_sentence_root.visible = true
	_sentence_check_button.disabled = true

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
		button.pressed.connect(
			_on_sentence_token_pressed.bind(button)
		)

		_sentence_source_buttons[token_id] = button
		_sentence_bank.add_child(button)


func _on_card_drag_started(_card: AnswerCard) -> void:
	var tw := create_tween()
	tw.tween_property(
		_sword_panel,
		"modulate",
		Color(1.12, 1.08, 0.78),
		0.10
	)


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

	# The vocabulary IDs define the correct relationship.
	# UI positions are randomized separately.
	for i in current_question.match_left_ids.size():
		if current_question.match_left_ids[i] == left_id:
			correct = (
				i < current_question.match_right_ids.size()
				and current_question.match_right_ids[i] == right_id
			)
			break

	if correct:
		_match_pairs.append({
			"left_id": left_id,
			"right_id": right_id
		})

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

	_match_progress_label.text = "Matched: %d / %d" % [
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
	var token_text := str(button.text)

	_sentence_order.append(token_id)
	button.disabled = true
	button.modulate = Color(0.58, 0.60, 0.57)

	var placed := _make_choice_button(token_text)
	placed.custom_minimum_size = Vector2(120, 42)
	placed.modulate = Color(0.92, 0.82, 0.46)
	placed.pressed.connect(
		_remove_sentence_token.bind(token_id, placed, button)
	)

	_sentence_bar.add_child(placed)
	_sentence_check_button.disabled = _sentence_order.is_empty()


func _remove_sentence_token(
	token_id: String,
	placed: Button,
	source: Button
) -> void:
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
			_emit_answer({
				"index": -1,
				"elapsed": _time_limit,
				"timed_out": true
			})

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
	# Remove only per-question controls. The serialized scene layout stays intact.
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

	_standard_hint.visible = false
	_answer_grid.visible = false
	_match_root.visible = false
	_sentence_root.visible = false

	_sword_panel.modulate = Color.WHITE
	_sword_panel.scale = Vector2.ONE

	_answer_cards.clear()
	_match_pairs.clear()
	_match_left_selected = -1
	_match_mistakes = 0
	_match_left_buttons.clear()
	_match_right_buttons.clear()
	_sentence_order.clear()
	_sentence_check_button.disabled = true
	_sentence_source_buttons.clear()


func _sword_feedback(correct: bool) -> void:
	if not is_instance_valid(_sword_panel) or not _sword_panel.visible:
		return

	var tw := create_tween()

	if correct:
		tw.set_parallel(true)
		tw.tween_property(
			_sword_panel,
			"modulate",
			Color(0.70, 1.20, 0.78),
			0.10
		)
		tw.tween_property(
			_sword_panel,
			"scale",
			Vector2(1.07, 1.07),
			0.10
		)
		tw.chain().tween_property(
			_sword_panel,
			"scale",
			Vector2.ONE,
			0.16
		)
	else:
		tw.tween_property(
			_sword_panel,
			"modulate",
			Color(1.30, 0.60, 0.55),
			0.08
		)
		tw.tween_property(
			_sword_panel,
			"position:x",
			_sword_panel.position.x + 7.0,
			0.05
		)
		tw.tween_property(
			_sword_panel,
			"position:x",
			_sword_panel.position.x - 7.0,
			0.05
		)
		tw.tween_property(
			_sword_panel,
			"position:x",
			_sword_panel.position.x,
			0.05
		)

	await tw.finished
	_sword_panel.modulate = Color.WHITE


func _make_choice_button(label_text: String) -> Button:
	# Reuse the theme configured in QuizUI.tscn instead of constructing
	# new StyleBox resources for every question.
	var button := _choice_button_template.duplicate() as Button

	button.visible = true
	button.disabled = false
	button.text = label_text
	button.modulate = Color.WHITE

	return button
