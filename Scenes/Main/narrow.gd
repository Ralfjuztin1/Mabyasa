extends Area3D

@export var narrow_cutscene: CutsceneDirector
@export var story_flag: String = "narrow_path_litik"

## Optional prerequisites. FirstTown.tscn intentionally sets this to [].
## Do not require pacing_move: this scene itself handles asking Ale to step aside.
@export var required_flags: Array[String] = []
@export var required_quest_id: String = "go_to_chief_final_training"
@export_enum("None", "Active", "Completed", "Active or Completed")
var required_quest_state: int = 1

var triggered: bool = false
var player_inside: bool = false
var _running: bool = false
var _hint_shown_during_visit: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if QuestManager.has_dialogue_flag("ale_path_cleared"):
		triggered = true
		set_deferred("monitoring", false)


func _process(_delta: float) -> void:
	# A player already standing inside can activate the scene once
	# the final-training quest becomes available.
	if player_inside and not triggered and not _running:
		_try_play_when_unlocked()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_inside = true
		_hint_shown_during_visit = false
		if not _requirements_met():
			_show_early_hint_once()
		_try_play_when_unlocked()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_inside = false
		_hint_shown_during_visit = false


func _requirements_met() -> bool:
	# The quest is the gate. No separate movement cutscene is needed.
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
	if not is_instance_valid(narrow_cutscene):
		push_error("[NarrowTrigger] NarrowCutscene is not assigned.")
		return
	if not narrow_cutscene.can_play_sequence():
		return
	if get_tree().get_first_node_in_group("cutscene_controller") == null:
		push_error("[NarrowTrigger] CutsceneController is missing.")
		return

	_running = true
	set_deferred("monitoring", false)
	var played: bool = await narrow_cutscene.play_sequence()
	if played and QuestManager.has_dialogue_flag("ale_path_cleared"):
		triggered = true
		if not story_flag.is_empty():
			QuestManager.set_dialogue_flag(story_flag, true)
		print("[NarrowTrigger] Asked Ale to step aside. The route to Chief is clear.")
	else:
		# A failed/cancelled sequence must remain replayable.
		# Also recover if the dialogue ended without its completion signal.
		if played:
			push_warning("[NarrowTrigger] Ale dialogue ended without ale_path_cleared; allowing retry.")
		set_deferred("monitoring", true)
		if player_inside and not _requirements_met():
			_show_early_hint_once()
	_running = false


func _show_early_hint_once() -> void:
	if _hint_shown_during_visit:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	var town: Node = get_parent().get_parent()
	if not is_instance_valid(town) or not town.has_method("show_story_hint"):
		return

	var message: String = "I should finish my current task before going down this narrow path."
	if town.has_method("get_story_direction"):
		message = str(town.call("get_story_direction"))

	_hint_shown_during_visit = true
	town.call("show_story_hint", message)
