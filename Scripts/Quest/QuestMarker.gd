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
# STATE
# ============================================================

var current_state: String = "none"

var animation_time: float = 0.0

var exclamation_base_y: float
var question_base_y: float


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	exclamation_base_y = exclamation.position.y
	question_base_y = question.position.y

	exclamation.visible = false
	question.visible = false

	_connect_quest_signals()

	# Check once when the NPC enters the scene.
	call_deferred("_refresh_marker")


# ============================================================
# QUEST SIGNALS
# ============================================================

func _connect_quest_signals() -> void:
	if QuestManager == null:
		return

	if not QuestManager.quest_started.is_connected(
		_on_quest_changed
	):
		QuestManager.quest_started.connect(
			_on_quest_changed
		)

	if not QuestManager.quest_objective_updated.is_connected(
		_on_quest_changed
	):
		QuestManager.quest_objective_updated.connect(
			_on_quest_changed
		)

	if not QuestManager.quest_completed.is_connected(
		_on_quest_changed
	):
		QuestManager.quest_completed.connect(
			_on_quest_changed
		)

	if not QuestManager.quest_validation_failed.is_connected(
		_on_quest_changed
	):
		QuestManager.quest_validation_failed.connect(
			_on_quest_changed
		)


func _on_quest_changed(
	_quest_id: String,
	_value_1 = null,
	_value_2 = null
) -> void:
	call_deferred("_refresh_marker")


# ============================================================
# REFRESH MARKER
# ============================================================

func _refresh_marker() -> void:
	if QuestManager == null:
		_set_state("none")
		return

	var npc: Node = get_parent()

	if npc == null:
		_set_state("none")
		return

	var npc_id: String = str(
		npc.get("npc_id")
	)

	if npc_id.is_empty():
		_set_state("none")
		return

	var new_state: String = (
		QuestManager.get_npc_quest_marker(npc_id)
	)

	_set_state(new_state)


# ============================================================
# SET MARKER
# ============================================================

func _set_state(new_state: String) -> void:
	current_state = new_state

	match new_state:
		"available":
			exclamation.visible = true
			question.visible = false

		"turn_in":
			exclamation.visible = false
			question.visible = true

		_:
			exclamation.visible = false
			question.visible = false


# ============================================================
# ANIMATION
# ============================================================

func _process(delta: float) -> void:
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
