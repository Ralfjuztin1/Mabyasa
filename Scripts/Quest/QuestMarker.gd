extends Node3D


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var exclamation: Label3D = $Exclamation
@onready var question: Label3D = $Question


# ============================================================
# ANIMATION SETTINGS
# ============================================================

@export_category("Animation")

@export_range(0.01, 0.15, 0.01)
var float_height: float = 0.04

@export_range(0.5, 4.0, 0.1)
var float_speed: float = 1.8


# ============================================================
# DISPLAY SETTINGS
# ============================================================

@export_category("Quest Marker Display")

## How long a newly appeared quest marker stays visible.
## Time pauses while dialogue, cutscenes, or non-exploration states are active.
@export_range(1.0, 10.0, 0.5)
var visible_duration: float = 4.0


# ============================================================
# STATE
# ============================================================

## Semantic marker state from QuestManager: none, available, or turn_in.
var current_state: String = "none"

var animation_time: float = 0.0
var exclamation_base_y: float = 0.0
var question_base_y: float = 0.0
var _visible_time_remaining: float = 0.0
var _cutscene_controller: CutsceneController = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Continue running only this small display controller when menus pause the tree,
	# so the marker can hide immediately during dialogue/cutscenes.
	process_mode = Node.PROCESS_MODE_ALWAYS

	exclamation_base_y = exclamation.position.y
	question_base_y = question.position.y

	exclamation.visible = false
	question.visible = false

	_cutscene_controller = get_tree().get_first_node_in_group(
		"cutscene_controller"
	) as CutsceneController

	_connect_quest_signals()

	# Check once when the NPC enters the scene. An available marker appears
	# immediately and then expires after visible_duration seconds.
	call_deferred("_refresh_marker")


# ============================================================
# QUEST SIGNALS
# ============================================================

func _connect_quest_signals() -> void:
	if not is_instance_valid(QuestManager):
		return

	if not QuestManager.quest_started.is_connected(_on_quest_changed):
		QuestManager.quest_started.connect(_on_quest_changed)

	if not QuestManager.quest_objective_updated.is_connected(_on_quest_changed):
		QuestManager.quest_objective_updated.connect(_on_quest_changed)

	if not QuestManager.quest_completed.is_connected(_on_quest_changed):
		QuestManager.quest_completed.connect(_on_quest_changed)

	if not QuestManager.quest_validation_failed.is_connected(_on_quest_changed):
		QuestManager.quest_validation_failed.connect(_on_quest_changed)


func _exit_tree() -> void:
	if not is_instance_valid(QuestManager):
		return

	if QuestManager.quest_started.is_connected(_on_quest_changed):
		QuestManager.quest_started.disconnect(_on_quest_changed)

	if QuestManager.quest_objective_updated.is_connected(_on_quest_changed):
		QuestManager.quest_objective_updated.disconnect(_on_quest_changed)

	if QuestManager.quest_completed.is_connected(_on_quest_changed):
		QuestManager.quest_completed.disconnect(_on_quest_changed)

	if QuestManager.quest_validation_failed.is_connected(_on_quest_changed):
		QuestManager.quest_validation_failed.disconnect(_on_quest_changed)


func _on_quest_changed(
	_quest_id: String,
	_value_1: Variant = null,
	_value_2: Variant = null
) -> void:
	call_deferred("_refresh_marker")


# ============================================================
# REFRESH MARKER
# ============================================================

func _refresh_marker() -> void:
	if not is_instance_valid(QuestManager):
		_set_state("none")
		return

	var npc: Node = get_parent()

	if not is_instance_valid(npc):
		_set_state("none")
		return

	var npc_id: String = str(npc.get("npc_id")).strip_edges()

	if npc_id.is_empty():
		_set_state("none")
		return

	var new_state: String = QuestManager.get_npc_quest_marker(npc_id)
	_set_state(new_state)


# ============================================================
# SET MARKER STATE
# ============================================================

func _set_state(new_state: String) -> void:
	var state_changed: bool = new_state != current_state
	current_state = new_state

	if current_state not in ["available", "turn_in"]:
		_visible_time_remaining = 0.0
		_apply_marker_visibility(false)
		return

	# Start the timer only when this NPC's marker state actually changes.
	# This avoids every unrelated quest update flashing every NPC marker again.
	if state_changed:
		_visible_time_remaining = maxf(visible_duration, 0.1)

	_apply_marker_visibility(
		_visible_time_remaining > 0.0
		and not _is_marker_suppressed()
	)


# ============================================================
# DISPLAY SUPPRESSION
# ============================================================

func _is_marker_suppressed() -> bool:
	# The exploration HUD is hidden for dialogue, quizzes, combat, and pause.
	# World markers follow the same state rule.
	if is_instance_valid(GameManager):
		if GameManager.current_state != GameManager.GameState.EXPLORATION:
			return true

	# Also check the dialogue manager directly, as Dialogic can begin a timeline
	# a frame before the game state signal updates.
	if is_instance_valid(DialogueManager):
		if DialogueManager.is_dialogue_active:
			return true

	# Cutscenes can run while GameManager remains in EXPLORATION, so check the
	# cutscene controller as well.
	if not is_instance_valid(_cutscene_controller):
		_cutscene_controller = get_tree().get_first_node_in_group(
			"cutscene_controller"
		) as CutsceneController

	if is_instance_valid(_cutscene_controller):
		if _cutscene_controller.is_cutscene_active:
			return true

	return false


func _apply_marker_visibility(show_marker: bool) -> void:
	var can_show: bool = (
		show_marker
		and _visible_time_remaining > 0.0
		and not _is_marker_suppressed()
	)

	exclamation.visible = can_show and current_state == "available"
	question.visible = can_show and current_state == "turn_in"


# ============================================================
# ANIMATION AND TEMPORARY VISIBILITY
# ============================================================

func _process(delta: float) -> void:
	var suppressed: bool = _is_marker_suppressed()

	if suppressed:
		# Hide immediately but pause the countdown. If time remains, the marker
		# can reappear after the dialogue/cutscene ends.
		_apply_marker_visibility(false)
		return

	if _visible_time_remaining > 0.0:
		_visible_time_remaining = maxf(
			_visible_time_remaining - delta,
			0.0
		)

	_apply_marker_visibility(_visible_time_remaining > 0.0)

	if _visible_time_remaining <= 0.0:
		return

	animation_time += delta

	var movement: float = (
		sin(animation_time * float_speed)
		* float_height
	)

	if exclamation.visible:
		exclamation.position.y = (
			exclamation_base_y
			+ movement
		)

	if question.visible:
		question.position.y = (
			question_base_y
			+ movement
		)
