extends Node

## Second Town storyline and number lessons, using the existing BaseNPC,
## QuestManager, Dialogic and CutsceneController systems.
## Place this as SecondTown/SecondTownQuests (as in the previous quest pack).

const LESSON_UI: PackedScene = preload("res://Scenes/SecondTown/SecondTownQuestUI.tscn")
const INTRO_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/SecondTownSceneDialogues/litik_arrival.dtl"
const WELL_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/SecondTownSceneDialogues/litik_well_discovery.dtl"
const INTRO_FLAG: String = "st_litik_arrival_seen"
const WELL_FLAG: String = "st_litik_well_discovery_seen"
const TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"

const QUEST_MERCHANT: String = "st_merchant_orders"
const QUEST_FARMER: String = "st_farmer_supplies"
const QUEST_ELDER: String = "st_elder_well"

const QUESTS: Dictionary = {
	"merchant": "st_merchant_orders",
	"farmer": "st_farmer_supplies",
	"elder": "st_elder_well"
}
const PUZZLE_IDS: Dictionary = {
	"merchant": "st_merchant_orders_sorted",
	"farmer": "st_farmer_supplies_prepared",
	"elder": "st_elder_records_read"
}
const VOCAB_IDS: Dictionary = {
	"merchant": "metung+adwa+atlo_or_atlu",
	"farmer": "apat+lima+anam",
	"elder": "pito_or_pitu+walo_or_walu+siyam+apulo_or_apulu"
}

var _pending_lesson: String = ""
var _lesson_layer: CanvasLayer = null
var _player: Node = null
var _old_physics: bool = true
var _old_input: bool = true
var _old_unhandled_input: bool = true
var _old_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _story_busy: bool = false


func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	QuestManager.quest_started.connect(_on_quest_changed)
	QuestManager.quest_completed.connect(_on_quest_changed)
	QuestManager.quest_objective_updated.connect(_on_objective_changed)
	QuestManager.dialogue_flag_changed.connect(_on_dialogue_flag_changed)
	_refresh_dialogues()

	# Main emits this after the world and the player's spawn are both ready.
	var main: Node = get_tree().current_scene
	if is_instance_valid(main) and main.has_signal("loading_completed"):
		main.connect("loading_completed", Callable(self, "_on_second_town_loaded"))
	else:
		# Also works when SecondTown.tscn is run directly for debugging.
		call_deferred("_on_second_town_loaded")


func _on_second_town_loaded() -> void:
	if not is_inside_tree():
		return
	var main: Node = get_tree().current_scene
	if is_instance_valid(main) and main.has_signal("loading_completed"):
		if GameManager.current_level_path != TOWN_PATH:
			return
	if not QuestManager.has_dialogue_flag(INTRO_FLAG):
		call_deferred("_play_arrival_cutscene")
	else:
		_ensure_quest_chain()
		_refresh_dialogues()


func _play_arrival_cutscene() -> void:
	if _story_busy or QuestManager.has_dialogue_flag(INTRO_FLAG):
		return
	if not is_inside_tree() or DialogueManager.is_dialogue_active:
		return
	_story_busy = true
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var director: CutsceneController = get_tree().get_first_node_in_group("cutscene_controller") as CutsceneController
	if is_instance_valid(director):
		if director.is_cutscene_active:
			_story_busy = false
			return
		if director.begin_cutscene():
			await director.wait(0.35)
			if ResourceLoader.exists(INTRO_TIMELINE):
				await director.play_dialogue(INTRO_TIMELINE)
			director.end_cutscene()
		else:
			await _play_simple_timeline(INTRO_TIMELINE)
	else:
		await _play_simple_timeline(INTRO_TIMELINE)

	if not is_inside_tree():
		return
	QuestManager.set_dialogue_flag(INTRO_FLAG, true)
	_ensure_quest_chain()
	_refresh_dialogues()
	GameManager.request_save()
	_story_busy = false


func _on_dialogue_flag_changed(flag_id: String) -> void:
	if flag_id == "st_well_clue_found" and not QuestManager.has_dialogue_flag(WELL_FLAG):
		call_deferred("_play_well_discovery")


func _play_well_discovery() -> void:
	if _story_busy or QuestManager.has_dialogue_flag(WELL_FLAG):
		return
	_story_busy = true
	# Wait for the well's interaction event to finish updating the quest.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var director: CutsceneController = get_tree().get_first_node_in_group("cutscene_controller") as CutsceneController
	if is_instance_valid(director) and not director.is_cutscene_active:
		if director.begin_cutscene():
			await director.play_dialogue(WELL_TIMELINE)
			director.end_cutscene()
		else:
			await _play_simple_timeline(WELL_TIMELINE)
	else:
		await _play_simple_timeline(WELL_TIMELINE)
	if is_inside_tree():
		QuestManager.set_dialogue_flag(WELL_FLAG, true)
		GameManager.request_save()
	_story_busy = false


func _play_simple_timeline(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("[SECOND TOWN] Missing storyline dialogue: " + path)
		return
	Dialogic.start(path)
	await Dialogic.timeline_ended


func _ensure_quest_chain() -> void:
	if not QuestManager.has_dialogue_flag(INTRO_FLAG):
		return
	for quest_id: String in [QUEST_MERCHANT, QUEST_FARMER, QUEST_ELDER]:
		if QuestManager.is_quest_completed(quest_id):
			continue
		if not QuestManager.is_quest_active(quest_id):
			if QuestManager.get_quest(quest_id) == null:
				push_error("[SECOND TOWN] Quest resource missing: " + quest_id)
				return
			QuestManager.start_quest(quest_id)
		return


func _on_quest_changed(_quest_id: String, _quest_data: QuestData) -> void:
	_ensure_quest_chain()
	_refresh_dialogues()
	GameManager.request_save()


func _on_objective_changed(_quest_id: String, _step_index: int, _step: QuestStep) -> void:
	_refresh_dialogues()
	GameManager.request_save()


func _refresh_dialogues() -> void:
	var npc_root: Node = get_parent().get_node_or_null("npc")
	if not is_instance_valid(npc_root):
		return
	_set_npc_dialogue(npc_root, "merchant",
		"merchant_done" if QuestManager.is_quest_completed(QUEST_MERCHANT) else "merchant_quest")

	var farmer_state: String = "farmer_locked"
	if QuestManager.is_quest_completed(QUEST_FARMER):
		farmer_state = "farmer_done"
	elif QuestManager.is_quest_completed(QUEST_MERCHANT):
		farmer_state = "farmer_quest"
	_set_npc_dialogue(npc_root, "farmer", farmer_state)

	var elder_state: String = "elder_locked"
	if QuestManager.is_quest_completed(QUEST_ELDER):
		elder_state = "elder_done"
	elif QuestManager.is_quest_completed(QUEST_FARMER):
		elder_state = "elder_inspect" if QuestManager.has_dialogue_flag("st_elder_lesson_done") else "elder_quest"
	_set_npc_dialogue(npc_root, "elder", elder_state)


func _set_npc_dialogue(npc_root: Node, name: String, dialogue_name: String) -> void:
	var npc: Node = npc_root.get_node_or_null(name)
	if not is_instance_valid(npc):
		return
	var target_path: String = "SecondTownSceneDialogues/" + dialogue_name
	if str(npc.get("dialogue_id")) != target_path:
		npc.set("dialogue_id", target_path)


func _on_dialogic_signal(argument: Variant) -> void:
	var value: String = str(argument).strip_edges()
	if not value.begins_with("secondtown_open_"):
		return
	var chapter: String = value.trim_prefix("secondtown_open_")
	if not QUESTS.has(chapter):
		return
	var quest_id: String = str(QUESTS[chapter])
	if not QuestManager.is_quest_active(quest_id) or _story_busy:
		return
	_pending_lesson = chapter


func _on_dialogue_ended() -> void:
	if not _pending_lesson.is_empty():
		call_deferred("_launch_pending_lesson")


func _launch_pending_lesson() -> void:
	# Dialogic's timeline_ended fires before all of DialogueManager's cleanup.
	for _i: int in range(8):
		await get_tree().process_frame
		if not DialogueManager.is_dialogue_active:
			break
	if _pending_lesson.is_empty() or not is_inside_tree():
		return
	if DialogueManager.is_dialogue_active or _story_busy or is_instance_valid(_lesson_layer):
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	var chapter: String = _pending_lesson
	_pending_lesson = ""
	_player = get_tree().get_first_node_in_group("player")
	_old_mouse_mode = Input.mouse_mode
	if is_instance_valid(_player):
		_old_physics = _player.is_physics_processing()
		_old_input = _player.is_processing_input()
		_old_unhandled_input = _player.is_processing_unhandled_input()
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)

	GameManager.set_game_state(GameManager.GameState.DIALOGUE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_lesson_layer = LESSON_UI.instantiate() as CanvasLayer
	_lesson_layer.connect("lesson_completed", Callable(self, "_lesson_completed"))
	_lesson_layer.connect("lesson_closed", Callable(self, "_close_lesson"))
	get_tree().root.add_child(_lesson_layer)
	_lesson_layer.call("start_chapter", chapter)


func _lesson_completed(chapter: String) -> void:
	if not QUESTS.has(chapter):
		return
	var quest_id: String = str(QUESTS[chapter])
	if not QuestManager.is_quest_active(quest_id):
		return
	var flag: String = "st_" + chapter + "_lesson_done"
	if not QuestManager.has_dialogue_flag(flag):
		LanguageProgress.mark_learned(str(VOCAB_IDS[chapter]))
		QuestManager.set_dialogue_flag(flag, true)
	GameEvents.puzzle_solved.emit(str(PUZZLE_IDS[chapter]))
	_refresh_dialogues()
	GameManager.request_save()


func _close_lesson() -> void:
	if is_instance_valid(_lesson_layer):
		_lesson_layer.queue_free()
	_lesson_layer = null
	if is_instance_valid(_player):
		_player.set_physics_process(_old_physics)
		_player.set_process_input(_old_input)
		_player.set_process_unhandled_input(_old_unhandled_input)
	_player = null
	if GameManager.current_state == GameManager.GameState.DIALOGUE and not DialogueManager.is_dialogue_active:
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)
	Input.set_mouse_mode(_old_mouse_mode)


func _exit_tree() -> void:
	if is_instance_valid(_lesson_layer):
		_close_lesson()
