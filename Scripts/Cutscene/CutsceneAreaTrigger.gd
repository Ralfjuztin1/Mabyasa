extends Area3D

## Generic proximity trigger for any CutsceneDirector.
## The director owns all story requirements and the completion flag.
## This trigger waits while the player remains inside if requirements are
## not met yet, so it can activate as soon as the required flags are set.

@export_category("Cutscene")
@export var director: CutsceneDirector
@export var player_group: StringName = &"player"
@export var disable_after_success: bool = true

var _player_inside: bool = false
var _starting: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if not is_instance_valid(director):
		push_warning("[CUTSCENE TRIGGER] Assign a CutsceneDirector to: " + name)


func _process(_delta: float) -> void:
	if not _player_inside or _starting:
		return
	if not is_instance_valid(director):
		return
	if not director.can_play_sequence():
		return

	_start_director()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(player_group):
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(player_group):
		_player_inside = false


func _start_director() -> void:
	if _starting or not is_instance_valid(director):
		return
	if not director.can_play_sequence():
		return

	_starting = true
	var completed_successfully: bool = await director.play_sequence()
	_starting = false

	if completed_successfully and disable_after_success:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
