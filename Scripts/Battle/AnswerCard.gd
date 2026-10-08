class_name AnswerCard
extends PanelContainer

signal drag_started(card: AnswerCard)
signal drag_cancelled(card: AnswerCard)
signal dropped_on_sword(card: AnswerCard)

@export var answer_text: String = "":
	set(value):
		answer_text = value
		if is_instance_valid(label):
			label.text = value

var answer_index := -1
var sword_drop_zone: Control = null
var drag_layer: Control = null

const NORMAL_SCALE := Vector2.ONE
const HOVER_SCALE := Vector2(1.03, 1.03)
const DRAG_SCALE := Vector2(1.08, 1.08)

var _dragging := false
var _locked := false
var _drag_offset := Vector2.ZERO
var _origin_parent: Node = null
var _origin_index := 0
var _origin_global_position := Vector2.ZERO
var _placeholder: Control = null
var _origin_z_index := 0

@onready var label: Label = $Margin/Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if is_instance_valid(label):
		label.text = answer_text


func lock() -> void:
	_locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_mouse_entered() -> void:
	if _locked or _dragging:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", HOVER_SCALE, 0.10)


func _on_mouse_exited() -> void:
	if _dragging:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", NORMAL_SCALE, 0.10)


func _on_gui_input(event: InputEvent) -> void:
	if _locked or _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_start_drag()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() + _drag_offset
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		_end_drag()


func _start_drag() -> void:
	_dragging = true
	_drag_offset = global_position - get_global_mouse_position()
	_origin_parent = get_parent()
	_origin_index = get_index()
	_origin_global_position = global_position
	_origin_z_index = z_index
	z_index = 50

	if is_instance_valid(drag_layer) and is_instance_valid(_origin_parent):
		var start_position := global_position
		var start_size := size
		_placeholder = Control.new()
		_placeholder.custom_minimum_size = start_size
		_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_origin_parent.add_child(_placeholder)
		_origin_parent.move_child(_placeholder, _origin_index)
		_origin_parent.remove_child(self)
		drag_layer.add_child(self)
		size = start_size
		global_position = start_position

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", DRAG_SCALE, 0.10)
	drag_started.emit(self)


func _end_drag() -> void:
	_dragging = false
	var over_sword := false
	if is_instance_valid(sword_drop_zone):
		over_sword = sword_drop_zone.get_global_rect().has_point(get_global_mouse_position())

	if over_sword:
		lock()
		dropped_on_sword.emit(self)
	else:
		drag_cancelled.emit(self)
		_return_to_origin()


func _return_to_origin() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", NORMAL_SCALE, 0.20)
	tw.tween_property(self, "global_position", _origin_global_position, 0.20)
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
	scale = NORMAL_SCALE
	z_index = _origin_z_index


func fly_to(target_center: Vector2, duration: float = 0.20) -> void:
	var target := target_center - size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", target, duration)
	tw.tween_property(self, "scale", Vector2(0.72, 0.72), duration)
	tw.tween_property(self, "modulate:a", 0.0, duration)
