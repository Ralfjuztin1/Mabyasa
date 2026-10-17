extends Area3D

@export var cutscene: CutsceneDirector
@export var story_flag: String = "pacing_move"

## Ale's movement scene should wait until the player has been sent to final training.
@export var required_flags: Array[String] = []
@export var required_quest_id: String = "go_to_chief_final_training"
@export_enum("None", "Active", "Completed", "Active or Completed")
var required_quest_state: int = 1

var triggered: bool = false
var player_inside: bool = false
var _running: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if not story_flag.is_empty() and QuestManager.has_dialogue_flag(story_flag):
		triggered = true
		set_deferred("monitoring", false)


func _process(_delta: float) -> void:
	if player_inside and not triggered and not _running:
		_try_play_when_unlocked()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_inside = true
		_try_play_when_unlocked()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_inside = false


func _requirements_met() -> bool:
	for flag_id: String in required_flags:
		if not flag_id.is_empty() and not QuestManager.has_dialogue_flag(flag_id):
			return false

	if required_quest_id.is_empty() or required_quest_state == 0:
		return true

	var active: bool = QuestManager.is_quest_active(required_quest_id)
	var completed: bool = QuestManager.is_quest_completed(required_quest_id)

	match required_quest_state:
		1:
			return active
		2:
			return completed
		3:
			return active or completed

	return true


func _try_play_when_unlocked() -> void:
	if triggered or _running or not player_inside:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	if not _requirements_met():
		return
	if not is_instance_valid(cutscene):
		push_error("[TriggerUletUlet] Cutscene is not assigned.")
		return
	if get_tree().get_first_node_in_group("cutscene_controller") == null:
		push_error("[TriggerUletUlet] CutsceneController is missing.")
		return

	_running = true
	triggered = true
	set_deferred("monitoring", false)
	await cutscene.play_sequence()

	if not story_flag.is_empty():
		QuestManager.set_dialogue_flag(story_flag, true)

	_running = false
	print("[TriggerUletUlet] Cutscene event completed.")
