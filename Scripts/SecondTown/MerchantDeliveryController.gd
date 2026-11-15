extends Node

## Merchant deliveries only. Other Second Town chapter quests are untouched.
## Compatible with the previous SecondTownQuests controller if it exists locally.

const QUEST_ID: String = "st_merchant_orders"
const LESSON_FLAG: String = "st_merchant_delivery_lesson_done"
const LESSON_EVENT: String = "merchant counting lesson"
const REPORT_EVENT: String = "Merchant"
const UI: PackedScene = preload("res://Scenes/SecondTown/MerchantDeliveryUI.tscn")
const DIALOGUE_FOLDER: String = "SecondTownSceneDialogues/"
const TARGETS = [
	{"id": "berto", "name": "Berto", "count": 1, "event": "Berto"},
	{"id": "mila", "name": "Mila", "count": 2, "event": "Mila"},
	{"id": "nena", "name": "Nena", "count": 3, "event": "Nena"}
]

var _pending_action: String = ""
var _panel: CanvasLayer = null
var _player: Node = null
var _was_physics: bool = true
var _was_input: bool = true
var _was_unhandled: bool = true
var _prior_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _refresh_elapsed: float = 0.0


func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	QuestManager.quest_objective_updated.connect(_on_objective_changed)
	QuestManager.quest_completed.connect(_on_quest_completed)
	call_deferred("_initialize_delivery_quest")


func _initialize_delivery_quest() -> void:
	if QuestManager.get_quest(QUEST_ID) == null:
		push_error("[MERCHANT] Missing Data/Quests/st_merchant_orders.tres")
		return
	if QuestManager.is_quest_completed(QUEST_ID):
		_update_npc_dialogues()
		return

	# A previous local version used this same ID for a 1-step sorting quiz.
	# Migrate only that unfinished version; don't reset completed saves.
	if QuestManager.is_quest_active(QUEST_ID):
		var active: Dictionary = QuestManager.active_quests[QUEST_ID]
		var existing_steps: Array = active.get("objectives", [])
		var quest: QuestData = QuestManager.get_quest(QUEST_ID)
		if existing_steps.size() != quest.steps.size():
			QuestManager.active_quests.erase(QUEST_ID)
			QuestManager.start_quest(QUEST_ID)
			push_warning("[MERCHANT] Restarted the old incomplete merchant sorting quest as deliveries.")
	else:
		QuestManager.start_quest(QUEST_ID)
	_update_npc_dialogues()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0.0
		_update_npc_dialogues()


func _step() -> int:
	return QuestManager.get_current_step(QUEST_ID)


func _update_npc_dialogues() -> void:
	var npc_root: Node = get_parent().get_node_or_null("npc")
	if not is_instance_valid(npc_root):
		return

	var merchant_dialogue: String = "merchant_quest"
	if QuestManager.is_quest_completed(QUEST_ID):
		merchant_dialogue = "merchant_done"
	elif QuestManager.is_quest_active(QUEST_ID):
		if _step() == 4:
			merchant_dialogue = "merchant_turnin"
		elif _step() > 0:
			merchant_dialogue = "merchant_progress"
	_set_dialogue(npc_root, "merchant", merchant_dialogue)

	for i: int in range(TARGETS.size()):
		var entry: Dictionary = TARGETS[i]
		var name: String = str(entry["id"])
		var variant: String = "st_delivery_" + name + "_wait"
		if QuestManager.is_quest_completed(QUEST_ID) or _step() > i + 1:
			variant = "st_delivery_" + name + "_done"
		elif _step() == i + 1:
			variant = "st_delivery_" + name
		_set_dialogue(npc_root, name, variant)


func _set_dialogue(npc_root: Node, npc_name: String, dialogue_name: String) -> void:
	var npc: Node = npc_root.get_node_or_null(npc_name)
	if not is_instance_valid(npc):
		return
	var target: String = DIALOGUE_FOLDER + dialogue_name
	if str(npc.get("dialogue_id")) != target:
		npc.set("dialogue_id", target)


func _on_objective_changed(quest_id: String, _step_index: int, _step_data: QuestStep) -> void:
	if quest_id == QUEST_ID:
		_update_npc_dialogues()
		GameManager.request_save()


func _on_quest_completed(quest_id: String, _quest_data: QuestData) -> void:
	if quest_id == QUEST_ID:
		_update_npc_dialogues()
		GameManager.request_save()


func _on_dialogic_signal(raw_signal: Variant) -> void:
	var event: String = str(raw_signal).strip_edges()
	if not QuestManager.is_quest_active(QUEST_ID):
		return
	if event == "st_merchant_delivery_lesson" and _step() == 0:
		_pending_action = "lesson"
	elif event == "st_merchant_delivery_report" and _step() == 4:
		_pending_action = "report"
	else:
		for i: int in range(TARGETS.size()):
			var entry: Dictionary = TARGETS[i]
			if event == "st_merchant_delivery_" + str(entry["id"]) and _step() == i + 1:
				_pending_action = str(entry["id"])
				break


func _on_timeline_ended() -> void:
	if _pending_action.is_empty():
		return
	call_deferred("_finish_dialogue_action")


func _finish_dialogue_action() -> void:
	for _i: int in range(12):
		await get_tree().process_frame
		if not DialogueManager.is_dialogue_active:
			break
	if not is_inside_tree() or _pending_action.is_empty():
		return
	if DialogueManager.is_dialogue_active or is_instance_valid(_panel):
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	var action: String = _pending_action
	_pending_action = ""
	if action == "report":
		GameEvents.puzzle_solved.emit(REPORT_EVENT)
		GameManager.request_save()
		return
	_show_panel(action)


func _show_panel(action: String) -> void:
	_player = get_tree().get_first_node_in_group("player")
	_prior_mouse_mode = Input.mouse_mode
	if is_instance_valid(_player):
		_was_physics = _player.is_physics_processing()
		_was_input = _player.is_processing_input()
		_was_unhandled = _player.is_processing_unhandled_input()
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)
	GameManager.set_game_state(GameManager.GameState.DIALOGUE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_panel = UI.instantiate() as CanvasLayer
	_panel.connect("lesson_finished", Callable(self, "_lesson_finished"))
	_panel.connect("delivery_finished", Callable(self, "_delivery_finished"))
	_panel.connect("closed", Callable(self, "_close_panel"))
	get_tree().root.add_child(_panel)

	if action == "lesson":
		_panel.call("show_lesson")
		return
	for entry: Dictionary in TARGETS:
		if str(entry["id"]) == action:
			_panel.call("show_delivery", action, str(entry["name"]), int(entry["count"]))
			return
	_close_panel()


func _lesson_finished() -> void:
	if not QuestManager.is_quest_active(QUEST_ID) or _step() != 0:
		return
	if not QuestManager.has_dialogue_flag(LESSON_FLAG):
		LanguageProgress.mark_learned("metung+adwa+atlo_or_atlu")
		QuestManager.set_dialogue_flag(LESSON_FLAG, true)
	GameEvents.puzzle_solved.emit(LESSON_EVENT)
	GameManager.request_save()


func _delivery_finished(recipient_id: String) -> void:
	for i: int in range(TARGETS.size()):
		var entry: Dictionary = TARGETS[i]
		if str(entry["id"]) != recipient_id:
			continue
		if QuestManager.is_quest_active(QUEST_ID) and _step() == i + 1:
			GameEvents.object_interacted.emit(str(entry["event"]))
			GameManager.request_save()
		return


func _close_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if is_instance_valid(_player):
		_player.set_physics_process(_was_physics)
		_player.set_process_input(_was_input)
		_player.set_process_unhandled_input(_was_unhandled)
	_player = null
	if GameManager.current_state == GameManager.GameState.DIALOGUE and not DialogueManager.is_dialogue_active:
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)
	Input.set_mouse_mode(_prior_mouse_mode)


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_close_panel()
