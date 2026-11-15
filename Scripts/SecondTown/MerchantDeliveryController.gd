extends Node

## The merchant lesson and deliveries happen in the town using world-space
## basket objects. The SecondTown scene remains untouched: this controller
## is attached by SecondTownQuestController and creates recipients at runtime.

const QUEST_ID: String = "st_merchant_orders"
const LESSON_FLAG: String = "st_merchant_delivery_lesson_done"
const LESSON_EVENT: String = "merchant counting lesson"
const REPORT_EVENT: String = "Merchant"
const WORLD_BASKETS: PackedScene = preload("res://Scenes/SecondTown/MerchantWorldBaskets.tscn")
const BASE_NPC: PackedScene = preload("res://Scenes/Characters/NPC/BaseNPC.tscn")
const DIALOGUE_FOLDER: String = "SecondTownSceneDialogues/"
const TARGETS = [
	{"id": "berto", "name": "Berto", "count": 1, "event": "Berto", "position": Vector3(-48.0, 0.60, 17.0)},
	{"id": "mila", "name": "Mila", "count": 2, "event": "Mila", "position": Vector3(-26.0, 0.60, 12.0)},
	{"id": "nena", "name": "Nena", "count": 3, "event": "Nena", "position": Vector3(6.0, 0.60, 12.0)}
]
const NPC_ANIMATIONS: Array[String] = [
	"idle_front", "idle_back", "idle_left", "idle_right",
	"walk_front", "walk_back", "walk_left", "walk_right"
]

var _pending_action: String = ""
var _world_scene: Node3D = null
var _player: Node = null
var _was_physics: bool = true
var _was_input: bool = true
var _was_unhandled: bool = true
var _prior_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _refresh_elapsed: float = 0.0
var _opening_action: bool = false


func _ready() -> void:
	_ensure_delivery_npcs()
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# Depend on the completed NPC interaction, not only Dialogic [signal].
	# DialogueManager emits this after the final dialogue line.
	GameEvents.npc_talked.connect(_on_npc_talked)
	QuestManager.quest_objective_updated.connect(_on_objective_changed)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.quest_started.connect(_on_quest_started)
	call_deferred("_initialize_delivery_quest")
	print("[MERCHANT] Delivery controller ready; listening for NPC conversations")


func _ensure_delivery_npcs() -> void:
	var npc_root: Node3D = get_parent().get_node_or_null("npc") as Node3D
	if not is_instance_valid(npc_root):
		push_error("[MERCHANT] Missing SecondTown/npc root; cannot spawn recipients.")
		return
	# The quest's NPC identifier is human-readable, so the existing Quest HUD
	# displays exactly "Talk to Merchant" and resolves its waypoint correctly.
	var merchant_npc: Node = npc_root.get_node_or_null("merchant")
	if is_instance_valid(merchant_npc):
		merchant_npc.set("npc_id", "Merchant")

	for entry: Dictionary in TARGETS:
		var recipient_id: String = str(entry["id"])
		var npc: CharacterBody3D = npc_root.get_node_or_null(recipient_id) as CharacterBody3D
		if npc == null:
			npc = BASE_NPC.instantiate() as CharacterBody3D
			if npc == null:
				push_error("[MERCHANT] Could not instantiate BaseNPC for " + recipient_id)
				continue
			npc.name = recipient_id
			npc.position = entry["position"]
			npc.set("npc_name", str(entry["name"]))
			npc.set("npc_id", str(entry["event"]))
			npc.set("dialogue_id", DIALOGUE_FOLDER + "st_delivery_" + recipient_id + "_wait")
			npc.set("dialogue_entries", [])
			npc.set("can_wander", false)
			var sprite_path: String = "res://Assets/SecondTown/" + recipient_id + "_placeholder.png"
			if ResourceLoader.exists(sprite_path):
				var art: Texture2D = load(sprite_path) as Texture2D
				if art != null:
					var frames: SpriteFrames = SpriteFrames.new()
					if frames.has_animation(&"default"):
						frames.remove_animation(&"default")
					for anim: String in NPC_ANIMATIONS:
						frames.add_animation(anim)
						frames.set_animation_loop(anim, true)
						frames.set_animation_speed(anim, 5.0)
						frames.add_frame(anim, art)
					npc.set("npc_frames", frames)
			npc_root.add_child(npc)
			print("[MERCHANT] Spawned recipient: ", recipient_id)
		else:
			# Existing NPCs (from a local editor installation) also need to use
			# the same IDs as the tracking / validation objectives.
			npc.set("npc_id", str(entry["event"]))
			npc.set("dialogue_entries", [])
			npc.set("can_wander", false)


func _on_quest_started(quest_id: String, _quest_data: QuestData) -> void:
	if quest_id == QUEST_ID:
		_update_npc_dialogues()


func _initialize_delivery_quest() -> void:
	if QuestManager.get_quest(QUEST_ID) == null:
		push_error("[MERCHANT] Missing quest resource: st_merchant_orders")
		return
	if QuestManager.is_quest_completed(QUEST_ID):
		_update_npc_dialogues()
		return
	# The arrival scene owns when the quest chain begins.
	if QuestManager.has_dialogue_flag("st_litik_arrival_seen") and not QuestManager.is_quest_active(QUEST_ID):
		QuestManager.start_quest(QUEST_ID)
	_update_npc_dialogues()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0.0
		_update_npc_dialogues()
		# Dialogic and DialogueManager sometimes finish on different frames.
		# Retain the lesson request until exploration has been restored.
		if not _pending_action.is_empty() and not _opening_action:
			if not DialogueManager.is_dialogue_active and GameManager.current_state == GameManager.GameState.EXPLORATION:
				call_deferred("_finish_dialogue_action")


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
		var recipient_id: String = str(entry["id"])
		var variant: String = "st_delivery_" + recipient_id + "_wait"
		if QuestManager.is_quest_completed(QUEST_ID) or _step() > i + 1:
			variant = "st_delivery_" + recipient_id + "_done"
		elif QuestManager.is_quest_active(QUEST_ID) and _step() == i + 1:
			variant = "st_delivery_" + recipient_id
		_set_dialogue(npc_root, recipient_id, variant)


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


# Reliable lesson/delivery launch: DialogueManager emits npc_talked when it
# finishes an NPC's conversation. The Dialogic signal in a .dtl is optional.
# QuestManager receives this event first, so counted "talk_npc" objectives
# have their interaction count registered before we queue the visual UI.
func _on_npc_talked(npc_id: String) -> void:
	if not is_inside_tree() or QuestManager.is_quest_completed(QUEST_ID):
		return

	# Restore the quest if the player arrived with a save that omitted its start.
	if not QuestManager.is_quest_active(QUEST_ID):
		if not QuestManager.has_dialogue_flag("st_litik_arrival_seen"):
			return
		QuestManager.start_quest(QUEST_ID)

	var next_action: String = ""
	if npc_id == "Merchant":
		if _step() == 0 and not QuestManager.has_dialogue_flag(LESSON_FLAG):
			next_action = "lesson"
		elif _step() == 4:
			next_action = "report"
	else:
		for index: int in range(TARGETS.size()):
			var entry: Dictionary = TARGETS[index]
			if npc_id == str(entry["event"]) and _step() == index + 1:
				next_action = str(entry["id"])
				break

	if next_action.is_empty():
		return

	_pending_action = next_action
	print("[MERCHANT] Finished talking to ", npc_id, "; opening action: ", next_action)
	call_deferred("_finish_dialogue_action")


func _on_timeline_ended() -> void:
	if not _pending_action.is_empty():
		call_deferred("_finish_dialogue_action")


func _finish_dialogue_action() -> void:
	if _opening_action or _pending_action.is_empty() or not is_inside_tree():
		return
	_opening_action = true
	# Wait for the *real* dialogue to finish; the timeline_ended signal alone
	# can fire before the player and exploration controls are restored.
	for _i: int in range(120):
		if not is_inside_tree():
			_opening_action = false
			return
		if not DialogueManager.is_dialogue_active and GameManager.current_state == GameManager.GameState.EXPLORATION:
			break
		await get_tree().process_frame
	_opening_action = false
	if not is_inside_tree() or _pending_action.is_empty():
		return
	if DialogueManager.is_dialogue_active or is_instance_valid(_world_scene):
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	var action: String = _pending_action
	_pending_action = ""
	if action == "report":
		GameEvents.puzzle_solved.emit(REPORT_EVENT)
		GameManager.request_save()
		return
	print("[MERCHANT] Launching in-world baskets: ", action)
	_show_world_action(action)

func _show_world_action(action: String) -> void:
	_player = get_tree().get_first_node_in_group("player")
	_prior_mouse_mode = Input.mouse_mode
	if is_instance_valid(_player):
		_was_physics = _player.is_physics_processing()
		_was_input = _player.is_processing_input()
		_was_unhandled = _player.is_processing_unhandled_input()
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)

	var npc_root: Node = get_parent().get_node_or_null("npc")
	if not is_instance_valid(npc_root):
		push_error("[MERCHANT] Missing town NPC root for the world basket scene")
		_restore_world_input()
		return

	var actor_name: String = "merchant" if action == "lesson" else action
	var npc: Node3D = npc_root.get_node_or_null(actor_name) as Node3D
	if not is_instance_valid(npc):
		push_error("[MERCHANT] Missing NPC: " + actor_name)
		_restore_world_input()
		return

	GameManager.set_game_state(GameManager.GameState.DIALOGUE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_world_scene = WORLD_BASKETS.instantiate() as Node3D
	_world_scene.connect("lesson_finished", Callable(self, "_lesson_finished"))
	_world_scene.connect("delivery_finished", Callable(self, "_delivery_finished"))
	_world_scene.connect("closed", Callable(self, "_close_world_action"))
	get_parent().add_child(_world_scene)

	if action == "lesson":
		_world_scene.call("start_lesson", npc, _player)
		return
	for entry: Dictionary in TARGETS:
		if str(entry["id"]) == action:
			_world_scene.call("start_delivery", npc, _player, action, str(entry["name"]), int(entry["count"]))
			return
	_close_world_action()

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


func _close_world_action() -> void:
	if is_instance_valid(_world_scene):
		# Restore the original exploration camera before removing the world props.
		if _world_scene.has_method("restore_camera"):
			_world_scene.call("restore_camera")
		_world_scene.queue_free()
	_world_scene = null
	_restore_world_input()


func _restore_world_input() -> void:
	if is_instance_valid(_player):
		_player.set_physics_process(_was_physics)
		_player.set_process_input(_was_input)
		_player.set_process_unhandled_input(_was_unhandled)
	_player = null
	if GameManager.current_state == GameManager.GameState.DIALOGUE and not DialogueManager.is_dialogue_active:
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)
	Input.set_mouse_mode(_prior_mouse_mode)


func _exit_tree() -> void:
	if is_instance_valid(_world_scene):
		_close_world_action()
