extends Node

const DIALOGUE_PATH: String = "res://Scenes/Characters/NPC/Dialogic/"
const DIALOGUE_CAMERA_DISTANCE: float = 0.5
const CAMERA_TWEEN_TIME: float = 0.35

var current_npc: Node = null
var current_dialogue_entry: NPCDialogueEntry = null
var is_dialogue_active: bool = false

var player_was_physics_processing: bool = true
var player_was_input_processing: bool = true

var npc_was_physics_processing: bool = true
var npc_was_unhandled_input_processing: bool = true

var player_camera_distance: float = 5.2


func _ready() -> void:
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)


func start_dialogue(npc: Node) -> void:
	if is_dialogue_active:
		return

	if not is_instance_valid(npc):
		return

	current_npc = npc
	current_dialogue_entry = null

	var dialogue_path: String = _get_dialogue_for_npc(npc)

	if dialogue_path.is_empty():
		push_warning(
			"[DIALOGUE] NPC has no valid dialogue: "
			+ str(npc.npc_name)
		)
		current_npc = null
		return

	print("[DIALOGUE] Starting: ", dialogue_path)

	Dialogic.start(dialogue_path)


# ============================================================
# DIALOGUE SELECTION
# ============================================================

func _get_dialogue_for_npc(npc: Node) -> String:
	# NPCs can hold many NPCDialogueEntry resources.
	# The valid entry with the highest priority wins.
	if "dialogue_entries" in npc:
		var entries = npc.dialogue_entries
		var best_entry: NPCDialogueEntry = null

		if entries is Array:
			for entry in entries:
				if not entry is NPCDialogueEntry:
					continue

				if not _dialogue_entry_matches(entry, npc):
					continue

				if entry.timeline_path.is_empty():
					continue

				if best_entry == null or entry.priority > best_entry.priority:
					best_entry = entry

		if best_entry != null:
			current_dialogue_entry = best_entry

			print(
				"[DIALOGUE] Selected entry priority ",
				best_entry.priority,
				": ",
				best_entry.timeline_path
			)

			return _normalize_dialogue_path(
				best_entry.timeline_path
			)

	# Legacy fallback.
	if "dialogue_id" in npc:
		var legacy_dialogue: String = str(npc.dialogue_id)

		if not legacy_dialogue.is_empty():
			return _normalize_dialogue_path(legacy_dialogue)

	return ""


func _dialogue_entry_matches(
	entry: NPCDialogueEntry,
	npc: Node
) -> bool:
	# A one-time entry is no longer valid after it has finished once.
	if entry.play_once:
		var play_once_flag: String = _get_play_once_flag_id(
			npc,
			entry
		)

		if QuestManager.has_dialogue_flag(play_once_flag):
			return false

	match entry.condition:
		NPCDialogueEntry.ConditionType.ALWAYS:
			return true

		NPCDialogueEntry.ConditionType.QUEST_NOT_STARTED:
			if entry.quest_id.is_empty():
				return false

			return (
				not QuestManager.is_quest_active(entry.quest_id)
				and not QuestManager.is_quest_completed(entry.quest_id)
			)

		NPCDialogueEntry.ConditionType.QUEST_ACTIVE:
			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_quest_active(entry.quest_id)

		NPCDialogueEntry.ConditionType.QUEST_COMPLETED:
			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_quest_completed(entry.quest_id)

		NPCDialogueEntry.ConditionType.QUEST_VALIDATION_UNDER:
			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_count_under(entry.quest_id)

		NPCDialogueEntry.ConditionType.QUEST_VALIDATION_OVER:
			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_count_over(entry.quest_id)

		NPCDialogueEntry.ConditionType.DIALOGUE_FLAG:
			if entry.flag_id.is_empty():
				return false

			return QuestManager.has_dialogue_flag(entry.flag_id)

	return false


func _get_play_once_flag_id(
	npc: Node,
	entry: NPCDialogueEntry
) -> String:
	if not entry.play_once_id.strip_edges().is_empty():
		return "dialogue_once_" + entry.play_once_id.strip_edges()

	var npc_id: String = "npc"

	if "npc_id" in npc:
		npc_id = str(npc.npc_id)

	var timeline: String = _normalize_dialogue_path(
		entry.timeline_path
	)

	return "dialogue_once_" + npc_id + "_" + timeline


func _mark_dialogue_entry_played() -> void:
	if not is_instance_valid(current_npc):
		return

	if current_dialogue_entry == null:
		return

	if not current_dialogue_entry.play_once:
		return

	var flag_id: String = _get_play_once_flag_id(
		current_npc,
		current_dialogue_entry
	)

	QuestManager.set_dialogue_flag(flag_id)

	print(
		"[DIALOGUE] Play-once entry consumed: ",
		flag_id
	)


func _normalize_dialogue_path(
	dialogue_reference: String
) -> String:
	var reference: String = dialogue_reference.strip_edges()

	if reference.is_empty():
		return ""

	if reference.begins_with("res://"):
		if reference.to_lower().ends_with(".dtl"):
			return reference

		return reference + ".dtl"

	if reference.to_lower().ends_with(".dtl"):
		reference = reference.trim_suffix(".dtl")

	return DIALOGUE_PATH + reference + ".dtl"


# ============================================================
# DIALOGIC SIGNALS
# ============================================================

func _on_dialogic_signal(argument: Variant) -> void:
	var signal_name := str(argument)

	print(
		"[DIALOGUE] Signal received: ",
		signal_name
	)

	if signal_name.begins_with("start_"):
		var quest_id := signal_name.trim_prefix("start_")

		if not quest_id.is_empty():
			QuestManager.start_quest(quest_id)

		return

	if signal_name.begins_with("set_flag_"):
		var flag_id := signal_name.trim_prefix("set_flag_")

		if not flag_id.is_empty():
			QuestManager.set_dialogue_flag(flag_id)

		return


# ============================================================
# DIALOGUE START
# ============================================================

func _on_dialogue_started() -> void:
	is_dialogue_active = true

	GameManager.set_game_state(GameManager.GameState.DIALOGUE)

	var player := get_tree().get_first_node_in_group("player")

	if player:
		player_was_physics_processing = player.is_physics_processing()
		player_was_input_processing = player.is_processing_input()

		player.set_physics_process(false)
		player.set_process_input(false)

		_zoom_camera_in(player)

	if is_instance_valid(current_npc):
		npc_was_physics_processing = current_npc.is_physics_processing()
		npc_was_unhandled_input_processing = (
			current_npc.is_processing_unhandled_input()
		)

		current_npc.set_physics_process(false)
		current_npc.set_process_unhandled_input(false)

		if "velocity" in current_npc:
			current_npc.velocity = Vector3.ZERO

		if current_npc.has_node("InteractionPrompt"):
			current_npc.get_node("InteractionPrompt").visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	print("[DIALOGUE] Dialogue started.")


# ============================================================
# DIALOGUE END
# ============================================================

func _on_dialogue_ended() -> void:
	is_dialogue_active = false

	# Mark the selected dialogue entry as consumed only after
	# Dialogic actually reaches the end of the timeline.
	_mark_dialogue_entry_played()

	if is_instance_valid(current_npc):
		GameEvents.npc_talked.emit(current_npc.npc_id)

	var player := get_tree().get_first_node_in_group("player")

	if player:
		_zoom_camera_out(player)

		player.set_physics_process(player_was_physics_processing)
		player.set_process_input(player_was_input_processing)

	if is_instance_valid(current_npc):
		current_npc.set_physics_process(npc_was_physics_processing)
		current_npc.set_process_unhandled_input(
			npc_was_unhandled_input_processing
		)

	current_npc = null
	current_dialogue_entry = null

	GameManager.set_game_state(GameManager.GameState.EXPLORATION)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	print("[DIALOGUE] Dialogue ended.")


# ============================================================
# CAMERA
# ============================================================

func _get_player_spring_arm(player: Node) -> SpringArm3D:
	if player.has_node("Head/SpringArm3D"):
		return player.get_node("Head/SpringArm3D") as SpringArm3D

	return null


func _zoom_camera_in(player: Node) -> void:
	var spring_arm := _get_player_spring_arm(player)

	if not spring_arm:
		return

	player_camera_distance = spring_arm.spring_length

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		spring_arm,
		"spring_length",
		DIALOGUE_CAMERA_DISTANCE,
		CAMERA_TWEEN_TIME
	)


func _zoom_camera_out(player: Node) -> void:
	var spring_arm := _get_player_spring_arm(player)

	if not spring_arm:
		return

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		spring_arm,
		"spring_length",
		player_camera_distance,
		CAMERA_TWEEN_TIME
	)
