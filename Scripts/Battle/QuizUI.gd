class_name QuizUI
extends Control

## The sword-and-cards quiz overlay. Owns presentation only — it has no
## idea what BattleManager is. Call start_quiz(question), listen for
## answer_selected(index); what that index means (correct/incorrect,
## damage, etc.) is entirely up to whoever's listening.

signal answer_selected(index: int)

const ANSWER_CARD_SCENE: PackedScene = preload("res://Scenes/Battle/AnswerCard.tscn")

@onready var scrim: ColorRect = $Scrim
@onready var sword_panel: Panel = $SwordArea/SwordPanel
@onready var sword_drop_zone: Control = $SwordArea/SwordPanel
@onready var quiz_type_label: Label = $SwordArea/SwordPanel/Margin/VBox/QuizTypeLabel
@onready var question_label: Label = $QuestionArea/QuestionLabel
@onready var cards_grid: GridContainer = $CardsArea/CardsCenter/CardsGrid
@onready var drag_layer: Control = $DragLayer

var current_question: QuizQuestion = null

var _sword_idle_color: Color = Color.WHITE
var _resolving: bool = false


func _ready() -> void:
	visible = false
	_sword_idle_color = sword_panel.modulate


## Called by whoever owns this UI (e.g. BattleScreen) when a question
## needs answering. Spawns fresh cards each time.
func start_quiz(question: QuizQuestion) -> void:
	current_question = question
	_resolving = false

	quiz_type_label.text = question.get_type_label()
	question_label.text = question.prompt
	sword_panel.modulate = _sword_idle_color
	sword_panel.scale = Vector2.ONE

	_clear_cards()
	_spawn_cards(question.choices)

	visible = true

	# Scale animations pivot from the center rather than the top-left.
	pivot_offset = size * 0.5
	sword_panel.pivot_offset = sword_panel.size * 0.5

	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func _clear_cards() -> void:
	# Cards being dragged (or already dropped on the sword) live in the
	# drag layer, not the grid — clear both, or old cards linger.
	for child in cards_grid.get_children():
		cards_grid.remove_child(child)
		child.queue_free()

	for child in drag_layer.get_children():
		drag_layer.remove_child(child)
		child.queue_free()


func _spawn_cards(choices: Array[String]) -> void:
	for i in choices.size():
		var card: AnswerCard = ANSWER_CARD_SCENE.instantiate()
		cards_grid.add_child(card)
		card.answer_index = i
		card.answer_text = choices[i]
		card.sword_drop_zone = sword_drop_zone
		card.drag_layer = drag_layer
		card.drag_started.connect(_on_any_card_drag_started)
		card.drag_cancelled.connect(_on_any_card_drag_cancelled)
		card.dropped_on_sword.connect(_on_card_dropped_on_sword)


func _lock_all_cards() -> void:
	for child in cards_grid.get_children():
		if child is AnswerCard:
			child.lock()


func _on_any_card_drag_started(_card: AnswerCard) -> void:
	# Simple "ready to receive" glow while any card is being dragged,
	# rather than precise hover-distance detection.
	var tw := create_tween()
	tw.tween_property(sword_panel, "modulate", Color(1.15, 1.1, 0.75), 0.15)


func _on_any_card_drag_cancelled(_card: AnswerCard) -> void:
	var tw := create_tween()
	tw.tween_property(sword_panel, "modulate", _sword_idle_color, 0.15)


func _on_card_dropped_on_sword(card: AnswerCard) -> void:
	if _resolving:
		return

	_resolving = true
	_lock_all_cards()

	card.fly_to(sword_drop_zone.get_global_rect().get_center(), 0.2)
	await get_tree().create_timer(0.22).timeout

	if not is_instance_valid(self):
		return

	if current_question.quiz_type == QuizQuestion.QuizType.FILL_BLANK:
		question_label.text = current_question.prompt.replace(
			"____", "[ %s ]" % card.answer_text
		)
		await get_tree().create_timer(0.35).timeout

	var correct: bool = card.answer_index == current_question.correct_index
	await _play_sword_feedback(correct)

	answer_selected.emit(card.answer_index)
	_hide_quiz()


func _play_sword_feedback(correct: bool) -> void:
	var tw := create_tween()

	if correct:
		tw.tween_property(sword_panel, "modulate", Color(0.75, 1.4, 0.85), 0.12)
		tw.tween_property(sword_panel, "scale", Vector2(1.08, 1.08), 0.12)
		tw.tween_property(sword_panel, "scale", Vector2.ONE, 0.18)
	else:
		var base_x := sword_panel.position.x
		tw.tween_property(sword_panel, "modulate", Color(1.5, 0.6, 0.55), 0.1)
		tw.tween_property(sword_panel, "position:x", base_x + 6.0, 0.05)
		tw.tween_property(sword_panel, "position:x", base_x - 6.0, 0.05)
		tw.tween_property(sword_panel, "position:x", base_x, 0.05)

	await tw.finished


func _hide_quiz() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false)
