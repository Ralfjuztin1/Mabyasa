extends Area3D

## Place this near the existing SecondTown well.
## Available only after the Elder's 7-10 counting lesson.

const QUEST_ID: String = "st_elder_well"
const TARGET_ID: String = "st_ancient_well_inspected"

@onready var _prompt: Label3D = $Prompt
@onready var _clue: Label3D = $Clue

var _player_near: bool = false
var _clue_ticks: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.hide()
	_clue.hide()


func _process(delta: float) -> void:
	_prompt.visible = _player_near and _can_inspect() and GameManager.current_state == GameManager.GameState.EXPLORATION
	if _clue_ticks > 0.0:
		_clue_ticks -= delta
		if _clue_ticks <= 0.0:
			_clue.hide()


func _can_inspect() -> bool:
	return (
		QuestManager.is_quest_active(QUEST_ID)
		and QuestManager.has_dialogue_flag("st_elder_lesson_done")
		and QuestManager.get_current_step(QUEST_ID) == 1
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or not _can_inspect():
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	if not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return
	get_viewport().set_input_as_handled()
	_prompt.hide()
	_clue.text = "The old carvings point toward the ruins.\nThe second flower may be there."
	_clue.show()
	_clue_ticks = 7.0
	QuestManager.set_dialogue_flag("st_well_clue_found", true)
	GameEvents.object_interacted.emit(TARGET_ID)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_prompt.hide()
