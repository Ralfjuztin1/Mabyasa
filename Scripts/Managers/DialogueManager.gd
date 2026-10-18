extends Node


const DIALOGUE_PATH: String = (
	"res://Scenes/Characters/NPC/Dialogic/"
)
const BATTLE_SCREEN_SCENE: PackedScene = preload(
	"res://Scenes/Battle/BattleScreen.tscn"
)

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


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	Dialogic.timeline_started.connect(
		_on_dialogue_started
	)

	Dialogic.timeline_ended.connect(
		_on_dialogue_ended
	)

	Dialogic.signal_event.connect(
		_on_dialogic_signal
	)

	if not BattleManager.battle_ended.is_connected(
		_on_chief_training_battle_ended
	):
		BattleManager.battle_ended.connect(
			_on_chief_training_battle_ended
		)


# ============================================================
# START DIALOGUE
# ============================================================

func start_dialogue(
	npc: Node
) -> void:

	if is_dialogue_active:
		return

	if not is_instance_valid(npc):
		return

	current_npc = npc
	current_dialogue_entry = null


	var dialogue_path: String = (
		_get_dialogue_for_npc(npc)
	)

	if dialogue_path.is_empty():

		push_warning(
			"[DIALOGUE] NPC has no valid dialogue: "
			+ str(npc.npc_name)
		)

		current_npc = null
		return


	print(
		"[DIALOGUE] Starting: ",
		dialogue_path
	)

	Dialogic.start(
		dialogue_path
	)


# ============================================================
# DIALOGUE SELECTION
# ============================================================

func _get_dialogue_for_npc(
	npc: Node
) -> String:

	if "dialogue_entries" in npc:

		var entries: Variant = (
			npc.dialogue_entries
		)

		var best_entry: NPCDialogueEntry = null

		if entries is Array:

			for raw_entry: Variant in (
				entries as Array
			):

				if not raw_entry is NPCDialogueEntry:
					continue

				var entry: NPCDialogueEntry = (
					raw_entry as NPCDialogueEntry
				)

				if not _dialogue_entry_matches(
					entry,
					npc
				):
					continue

				if entry.timeline_path.is_empty():
					continue

				if (
					best_entry == null
					or entry.priority
						> best_entry.priority
				):
					best_entry = entry


		if best_entry != null:

			current_dialogue_entry = (
				best_entry
			)

			print(
				"[DIALOGUE] Selected entry priority ",
				best_entry.priority,
				": ",
				best_entry.timeline_path
			)

			return _normalize_dialogue_path(
				best_entry.timeline_path
			)


	# --------------------------------------------------------
	# LEGACY FALLBACK
	# --------------------------------------------------------

	if "dialogue_id" in npc:

		var legacy_dialogue: String = str(
			npc.dialogue_id
		)

		if not legacy_dialogue.is_empty():

			return _normalize_dialogue_path(
				legacy_dialogue
			)


	return ""


# ============================================================
# DIALOGUE CONDITIONS
# ============================================================

func _dialogue_entry_matches(
	entry: NPCDialogueEntry,
	npc: Node
) -> bool:

	if entry.play_once:

		var play_once_flag: String = (
			_get_play_once_flag_id(
				npc,
				entry
			)
		)

		if QuestManager.has_dialogue_flag(
			play_once_flag
		):
			return false


	match entry.condition:

		NPCDialogueEntry.ConditionType.ALWAYS:
			return true


		NPCDialogueEntry.ConditionType.QUEST_NOT_STARTED:

			if entry.quest_id.is_empty():
				return false

			return (
				not QuestManager.is_quest_active(
					entry.quest_id
				)
				and not QuestManager.is_quest_completed(
					entry.quest_id
				)
			)


		NPCDialogueEntry.ConditionType.QUEST_ACTIVE:

			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_quest_active(
				entry.quest_id
			)


		NPCDialogueEntry.ConditionType.QUEST_COMPLETED:

			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_quest_completed(
				entry.quest_id
			)


		NPCDialogueEntry.ConditionType.QUEST_VALIDATION_UNDER:

			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_count_under(
				entry.quest_id
			)


		NPCDialogueEntry.ConditionType.QUEST_VALIDATION_OVER:

			if entry.quest_id.is_empty():
				return false

			return QuestManager.is_count_over(
				entry.quest_id
			)


		NPCDialogueEntry.ConditionType.DIALOGUE_FLAG:

			if entry.flag_id.is_empty():
				return false

			return QuestManager.has_dialogue_flag(
				entry.flag_id
			)


	return false


# ============================================================
# PLAY-ONCE FLAG
# ============================================================

func _get_play_once_flag_id(
	npc: Node,
	entry: NPCDialogueEntry
) -> String:

	if not entry.play_once_id.strip_edges().is_empty():

		return (
			"dialogue_once_"
			+ entry.play_once_id.strip_edges()
		)


	var npc_id: String = "npc"

	if "npc_id" in npc:
		npc_id = str(
			npc.npc_id
		)


	var timeline: String = (
		_normalize_dialogue_path(
			entry.timeline_path
		)
	)

	return (
		"dialogue_once_"
		+ npc_id
		+ "_"
		+ timeline
	)


# ============================================================
# MARK PLAY-ONCE ENTRY
# ============================================================

func _mark_dialogue_entry_played() -> void:

	if not is_instance_valid(
		current_npc
	):
		return

	if current_dialogue_entry == null:
		return

	if not current_dialogue_entry.play_once:
		return


	var flag_id: String = (
		_get_play_once_flag_id(
			current_npc,
			current_dialogue_entry
		)
	)

	QuestManager.set_dialogue_flag(
		flag_id
	)

	print(
		"[DIALOGUE] Play-once entry consumed: ",
		flag_id
	)


# ============================================================
# NORMALIZE DIALOGUE PATH
# ============================================================

func _normalize_dialogue_path(
	dialogue_reference: String
) -> String:

	var reference: String = dialogue_reference.strip_edges()

	if reference.is_empty():
		return ""


	# Resolve Godot resource UIDs to their actual file paths.
	if reference.begins_with("uid://"):

		var uid_id: int = ResourceUID.text_to_id(reference)

		if (
			uid_id == ResourceUID.INVALID_ID
			or not ResourceUID.has_id(uid_id)
		):
			push_error(
				"[DIALOGUE] Invalid timeline UID: "
				+ reference
			)
			return ""

		reference = ResourceUID.get_id_path(uid_id)

		if reference.is_empty():
			push_error(
				"[DIALOGUE] Could not resolve timeline UID: "
				+ dialogue_reference
			)
			return ""


	# A full resource path is already resolved.
	if reference.begins_with("res://"):

		if reference.to_lower().ends_with(".dtl"):
			return reference

		return reference + ".dtl"


	# Remove the extension before adding the Dialogic folder.
	if reference.to_lower().ends_with(".dtl"):

		reference = reference.trim_suffix(".dtl")


	# Support timeline names without a full path.
	return (
		DIALOGUE_PATH
		+ reference
		+ ".dtl"
	)


# ============================================================
# DIALOGIC SIGNALS
# ============================================================

func _on_dialogic_signal(argument: Variant) -> void:

	var signal_name: String = str(
		argument
	).strip_edges()


	# Dialogic may pass the signal as:
	# learn_mayap_a_abak
	#
	# or:
	# [signal arg="learn_mayap_a_abak"]
	#
	# Normalize both formats.

	if signal_name.begins_with(
		"[signal arg=\""
	) and signal_name.ends_with(
		"\"]"
	):

		signal_name = signal_name.trim_prefix(
			"[signal arg=\""
		)

		signal_name = signal_name.trim_suffix(
			"\"]"
		)


	print(
		"[DIALOGUE] Normalized signal: ",
		signal_name
	)
	# ========================================================
	# TIME CONTROL
	# ========================================================

	# Direct time signals: change_time_morning, change_time_afternoon,
	# change_time_night, or advance_time.
	if signal_name.begins_with("change_time_"):
		var target_time: String = (
			signal_name
			.trim_prefix("change_time_")
			.to_lower()
		)

		TimeManager.set_time(target_time)
		return

	if signal_name == "advance_time":
		TimeManager.advance_time()
		return

	# ========================================================
	# QUEST
	# ========================================================

	if signal_name.begins_with(
		"start_"
	):

		var quest_id: String = (
			signal_name.trim_prefix(
				"start_"
			)
		)

		if not quest_id.is_empty():

			QuestManager.start_quest(
				quest_id
			)

		return


	# ========================================================
	# STORY FLAGS + STORY-TRIGGERED TIME CHANGES
	# ========================================================

	if signal_name.begins_with("set_flag_"):
		var flag_id: String = signal_name.trim_prefix("set_flag_")

		if not flag_id.is_empty():
			# Keep the existing story flag behavior.
			QuestManager.set_dialogue_flag(flag_id)

			# Translate story flags into actual TimeManager states.
			# The game states are morning, afternoon, and night.
			match flag_id:
				"request_time_morning":
					TimeManager.set_time("morning")

				"request_time_afternoon":
					TimeManager.set_time("afternoon")

				"request_time_night":
					# Use the same canonical name for the request flag and time state: night.
					TimeManager.set_time("night")

				"sleep_transition_requested":
					# Sleeping starts the next morning in the current story flow.
					TimeManager.set_time("morning")

		return


	# ========================================================
	# QUEST PUZZLE / SCRIPTED OBJECTIVE
	# Example signal: solve_ale_path_cleared
	# ========================================================

	if signal_name.begins_with("solve_"):

		var puzzle_id: String = (
			signal_name.trim_prefix("solve_")
		)

		if not puzzle_id.is_empty() and GameEvents:
			GameEvents.puzzle_solved.emit(puzzle_id)

		return


	# ========================================================
	# VOCABULARY ENCOUNTERED
	# ========================================================
	# Encountered means the player has seen/heard the word.
	# It does not unlock the word for battle.
	# ========================================================

	if signal_name.begins_with(
		"encounter_"
	):

		var vocab_ids: String = (
			signal_name.trim_prefix(
				"encounter_"
			)
		)

		if (
			not vocab_ids.is_empty()
			and LanguageProgress
		):

			LanguageProgress.mark_encountered(
				vocab_ids
			)

		return


	# ========================================================
	# VOCABULARY LEARNED
	# ========================================================
	#
	# Example:
	#
	# [signal arg="learn_mayap_a_abak"]
	#
	# This:
	# - marks it encountered
	# - marks it learned
	# - exposes phrase parts
	# - saves the account
	# - allows battle to use it
	#
	# ========================================================

	if signal_name.begins_with(
		"learn_"
	):

		var vocab_ids: String = (
			signal_name.trim_prefix(
				"learn_"
			)
		)

		if (
			not vocab_ids.is_empty()
			and LanguageProgress
		):

			LanguageProgress.mark_learned(
				vocab_ids
			)

		return


# ============================================================
# DIALOGUE START
# ============================================================

func _on_dialogue_started() -> void:

	is_dialogue_active = true

	GameManager.set_game_state(
		GameManager.GameState.DIALOGUE
	)


	var player: Node = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)


	if player:

		player_was_physics_processing = (
			player.is_physics_processing()
		)

		player_was_input_processing = (
			player.is_processing_input()
		)

		player.set_physics_process(false)
		player.set_process_input(false)

		_zoom_camera_in(
			player
		)


	if is_instance_valid(
		current_npc
	):

		npc_was_physics_processing = (
			current_npc.is_physics_processing()
		)

		npc_was_unhandled_input_processing = (
			current_npc.is_processing_unhandled_input()
		)


		current_npc.set_physics_process(
			false
		)

		current_npc.set_process_unhandled_input(
			false
		)


		if "velocity" in current_npc:

			current_npc.velocity = (
				Vector3.ZERO
			)


		if current_npc.has_node(
			"InteractionPrompt"
		):

			current_npc.get_node(
				"InteractionPrompt"
			).visible = false


	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE
	)

	print(
		"[DIALOGUE] Dialogue started."
	)


# ============================================================
# DIALOGUE END
# ============================================================

func _on_dialogue_ended() -> void:

	is_dialogue_active = false

	_mark_dialogue_entry_played()

	# Keep the NPC reference before clearing dialogue state.
	# Chief's training battle starts only after the dialogue
	# and camera restoration finish.
	var finished_npc: Node = current_npc

	# Recovery safety net: once the healed-retry dialogue has finished,
	# re-arm the scripted battle even if a stale battle-start flag survived.
	# The timeline-path check makes this apply only to Chief's training dialogue.
	var is_chief_training_retry: bool = (
		is_instance_valid(finished_npc)
		and "npc_id" in finished_npc
		and str(finished_npc.npc_id) == "Chief"
		and current_dialogue_entry != null
		and current_dialogue_entry.timeline_path.contains("chief_training_start")
		and QuestManager.has_dialogue_flag("chief_training_healed")
		and not QuestManager.has_dialogue_flag("chief_training_battle_completed")
	)

	if is_chief_training_retry:
		QuestManager.set_dialogue_flag("training_battle_requested", true)
		QuestManager.set_dialogue_flag("chief_training_battle_started", false)
		QuestManager.set_dialogue_flag("chief_training_battle_lost", false)
		QuestManager.set_dialogue_flag("chief_training_healed", false)

	var should_start_chief_training: bool = (
		is_instance_valid(finished_npc)
		and "npc_id" in finished_npc
		and str(finished_npc.npc_id) == "Chief"
		and QuestManager.has_dialogue_flag(
			"training_battle_requested"
		)
		and not QuestManager.has_dialogue_flag(
			"chief_training_battle_started"
		)
	)

	if (
		is_instance_valid(current_npc)
		and "npc_id" in current_npc
	):
		GameEvents.npc_talked.emit(
			current_npc.npc_id
		)

	var player: Node = (
		get_tree().get_first_node_in_group("player")
	)

	if player:

		_zoom_camera_out(player)

		player.set_physics_process(
			player_was_physics_processing
		)

		player.set_process_input(
			player_was_input_processing
		)

	if is_instance_valid(current_npc):

		current_npc.set_physics_process(
			npc_was_physics_processing
		)

		current_npc.set_process_unhandled_input(
			npc_was_unhandled_input_processing
		)

	current_npc = null
	current_dialogue_entry = null

	GameManager.set_game_state(
		GameManager.GameState.EXPLORATION
	)

	Input.set_mouse_mode(
		Input.MOUSE_MODE_CAPTURED
	)

	print("[DIALOGUE] Dialogue ended.")

	if should_start_chief_training:
		_start_chief_training_battle(
			finished_npc
		)


# ============================================================
# START CHIEF TRAINING BATTLE
# ============================================================

func _start_chief_training_battle(
	chief_npc: Node
) -> void:

	if BattleManager.battle_active:
		return

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:

		push_error(
			"[DIALOGUE] Cannot start Chief training: "
			+ "current scene is null."
		)

		return

	var enemy_data: EnemyData = EnemyData.new()

	enemy_data.enemy_id = "chief_training"
	enemy_data.display_name = "Chief"
	enemy_data.max_hp = 50
	enemy_data.max_barrier = 20
	enemy_data.atk = 25
	enemy_data.exp_reward = 250
	enemy_data.gold_reward = 100
	enemy_data.is_boss = false


	# Reuse Chief's NPC frames for the battle portrait when available.
	var chief_frames: SpriteFrames = null

	if (
		is_instance_valid(chief_npc)
		and "npc_frames" in chief_npc
	):
		chief_frames = (
			chief_npc.get("npc_frames") as SpriteFrames
		)

	if chief_frames != null:

		enemy_data.battle_sprite_frames = chief_frames
		enemy_data.battle_sprite_animation = &"idle_right"
		enemy_data.battle_attack_animation = &""
		enemy_data.battle_hit_animation = &""


	var battle_screen: CanvasLayer = (
		BATTLE_SCREEN_SCENE.instantiate() as CanvasLayer
	)

	if battle_screen == null:

		push_error(
			"[DIALOGUE] Could not create the Chief "
			+ "training battle screen."
		)

		return


	current_scene.add_child(battle_screen)

	BattleManager.start_battle(enemy_data)


	# Only lock the battle-start flag if a battle actually began.
	if not BattleManager.battle_active:

		battle_screen.queue_free()

		push_error(
			"[DIALOGUE] Chief training battle did not start."
		)

		return


	QuestManager.set_dialogue_flag(
		"chief_training_battle_started",
		true
	)

	print("[DIALOGUE] Chief training battle started.")


# ============================================================
# CHIEF TRAINING BATTLE END
# ============================================================

func _on_chief_training_battle_ended(
	victory: bool
) -> void:

	# This handler runs for every battle, so ignore everything
	# except Chief's scripted training battle.
	if BattleManager.current_enemy == null:
		return

	if (
		BattleManager.current_enemy.enemy_id
		!= "chief_training"
	):
		return


	# --------------------------------------------------------
	# DEFEAT
	# --------------------------------------------------------

	if not victory:

		# Prevent an immediate retry. The player must heal at
		# the Big Tree and speak to Chief again.
		QuestManager.set_dialogue_flag(
			"training_battle_requested",
			false
		)

		QuestManager.set_dialogue_flag(
			"chief_training_battle_started",
			false
		)

		QuestManager.set_dialogue_flag(
			"chief_training_battle_completed",
			false
		)

		QuestManager.set_dialogue_flag(
			"chief_training_battle_lost",
			true
		)

		QuestManager.set_dialogue_flag(
			"chief_training_healed",
			false
		)

		print(
			"[DIALOGUE] Chief training lost; "
			+ "heal at the Big Tree before retrying."
		)

		return


	# --------------------------------------------------------
	# VICTORY
	# --------------------------------------------------------

	# Clear the request so the next conversation doesn't
	# accidentally start another training battle.
	QuestManager.set_dialogue_flag(
		"training_battle_requested",
		false
	)

	QuestManager.set_dialogue_flag(
		"chief_training_battle_started",
		true
	)

	QuestManager.set_dialogue_flag(
		"chief_training_battle_completed",
		true
	)

	# Remove the loss-recovery state after victory.
	QuestManager.set_dialogue_flag(
		"chief_training_battle_lost",
		false
	)

	QuestManager.set_dialogue_flag(
		"chief_training_healed",
		false
	)


	# BattleManager emits enemy_killed before battle_ended, so
	# first_training_battle should already be completed here.
	if QuestManager.is_quest_completed(
		"first_training_battle"
	):

		QuestManager.start_quest(
			"return_to_chief_after_training"
		)

	else:

		push_warning(
			"[DIALOGUE] Chief was defeated, but "
			+ "first_training_battle is not marked complete. "
			+ "Check the quest objective target."
		)


# ============================================================
# CAMERA
# ============================================================

func _get_player_spring_arm(
	player: Node
) -> SpringArm3D:

	if player.has_node(
		"Head/SpringArm3D"
	):

		return (
			player.get_node(
				"Head/SpringArm3D"
			) as SpringArm3D
		)

	return null


func _zoom_camera_in(
	player: Node
) -> void:

	var spring_arm: SpringArm3D = (
		_get_player_spring_arm(
			player
		)
	)

	if spring_arm == null:
		return


	player_camera_distance = (
		spring_arm.spring_length
	)


	var tween: Tween = (
		create_tween()
	)

	tween.set_trans(
		Tween.TRANS_QUAD
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		spring_arm,
		"spring_length",
		DIALOGUE_CAMERA_DISTANCE,
		CAMERA_TWEEN_TIME
	)


func _zoom_camera_out(
	player: Node
) -> void:

	var spring_arm: SpringArm3D = (
		_get_player_spring_arm(
			player
		)
	)

	if spring_arm == null:
		return


	var tween: Tween = (
		create_tween()
	)

	tween.set_trans(
		Tween.TRANS_QUAD
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		spring_arm,
		"spring_length",
		player_camera_distance,
		CAMERA_TWEEN_TIME
	)
