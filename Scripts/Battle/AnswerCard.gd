class_name AnswerCard
extends PanelContainer

## A draggable answer choice card. Purely presentational + drag physics —
## it only ever reports "the player dropped me on the sword." QuizUI
## decides what's correct and what happens next.
##
## Uses manual dragging rather than Godot's built-in _get_drag_data
## system, so the card itself can be smoothly tweened while dragging,
## snapping back, and flying into the sword.
##
## Once a drag starts, motion/release are read from _input() instead of
## gui_input: the card gets reparented to the drag layer on press, and
## Godot drops GUI mouse focus from a node that leaves the tree, so
## gui_input would stop firing mid-drag.

signal drag_started(card: AnswerCard)
signal drag_cancelled(card: AnswerCard)
signal dropped_on_sword(card: AnswerCard)

@export var answer_text: String = "":
	set(value):
		answer_text = value
		if is_instance_valid(label):
			label.text = value

## Index into the question's choices array — QuizUI sets this right
## after instancing the card.
var answer_index: int = -1

## Set by QuizUI right after instancing, before the card can be dragged.
var sword_drop_zone: Control = null
var drag_layer: Control = null

@onready var label: Label = $Margin/Label

const SCALE_NORMAL := Vector2.ONE
const SCALE_DRAGGING := Vector2(1.08, 1.08)
const RETURN_DURATION := 0.28

var _dragging: bool = false
var _locked: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _origin_parent: Node = null
var _origin_index: int = 0
var _placeholder: Control = null
var _origin_global_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)

	if is_instance_valid(label):
		label.text = answer_text

	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## Called once this card has been used (or another card was), so it
## can't be dragged while the sword animation/resolution plays out.
func lock() -> void:
	_locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_gui_input(event: InputEvent) -> void:
	if _locked or _dragging:
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_start_drag()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() + _drag_offset

	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		get_viewport().set_input_as_handled()
		_end_drag()


func _start_drag() -> void:
	_dragging = true
	_drag_offset = global_position - get_global_mouse_position()
	_origin_parent = get_parent()
	_origin_index = get_index()
	_origin_global_position = global_position

	if drag_layer and is_instance_valid(drag_layer):
		var start_pos := global_position
		var start_size := size

		# Leave an empty slot behind so the other cards stay put while
		# this one is being dragged (containers would otherwise reflow).
		_placeholder = Control.new()
		_placeholder.custom_minimum_size = start_size
		_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_origin_parent.add_child(_placeholder)
		_origin_parent.move_child(_placeholder, _origin_index)

		_origin_parent.remove_child(self)
		drag_layer.add_child(self)
		size = start_size
		global_position = start_pos

	var tw := create_tween()
	tw.tween_property(self, "scale", SCALE_DRAGGING, 0.14)

	drag_started.emit(self)


func _end_drag() -> void:
	_dragging = false

	var over_sword := false

	if sword_drop_zone and is_instance_valid(sword_drop_zone):
		over_sword = sword_drop_zone.get_global_rect().has_point(
			get_global_mouse_position()
		)

	if over_sword:
		lock()
		dropped_on_sword.emit(self)
	else:
		drag_cancelled.emit(self)
		_return_to_origin()


func _return_to_origin() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", SCALE_NORMAL, RETURN_DURATION)
	tw.tween_property(self, "global_position", _origin_global_position, RETURN_DURATION)
	tw.chain().tween_callback(func(): call_deferred("_reparent_to_origin"))


func _reparent_to_origin() -> void:
	if not is_instance_valid(_origin_parent):
		return

	get_parent().remove_child(self)

	if is_instance_valid(_placeholder):
		_origin_parent.remove_child(_placeholder)
		_placeholder.queue_free()
		_placeholder = null

	_origin_parent.add_child(self)
	_origin_parent.move_child(self, _origin_index)
	scale = SCALE_NORMAL


## Called by QuizUI once the drop is confirmed: carries the card the
## rest of the way into the middle of the sword, shrinking and fading
## as it's "absorbed."
func fly_to(target_center: Vector2, duration: float = 0.22) -> void:
	var target_top_left := target_center - size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", target_top_left, duration)
	tw.tween_property(self, "scale", Vector2(0.75, 0.75), duration)
	tw.tween_property(self, "modulate:a", 0.0, duration)
