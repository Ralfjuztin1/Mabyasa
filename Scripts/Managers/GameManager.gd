extends Node


signal game_paused(is_paused: bool)
signal hud_visibility_changed(is_visible: bool)
signal state_changed(new_state: GameState)


enum GameState {
	EXPLORATION,
	DIALOGUE,
	QUIZ,
	COMBAT,
	PAUSED
}


var active_user_email: String = ""
var adventurer_name: String = "Adventurer"
var should_load_save: bool = false

# Invalidates deferred save jobs and cloud-load continuations whenever the
# active account changes. Prevents delayed work from one session affecting another.
var _session_generation: int = 0
var _session_ready: bool = false

var current_state: GameState = (
	GameState.EXPLORATION
)

var current_level_path: String = (
	"res://Scenes/Main/FirstTown.tscn"
)


var quest_save_queued: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	get_tree().set_auto_accept_quit(
		false
	)


	if QuestManager:

		QuestManager.quest_started.connect(
			_on_quest_state_changed
		)

		QuestManager.quest_objective_updated.connect(
			_on_quest_state_changed
		)

		QuestManager.quest_completed.connect(
			_on_quest_state_changed
		)

		QuestManager.dialogue_flag_changed.connect(
			_on_dialogue_flag_changed
		)


# ============================================================
# WINDOW CLOSE
# ============================================================

func _notification(
	what: int
) -> void:

	if what == NOTIFICATION_WM_CLOSE_REQUEST:

		_perform_emergency_save_and_quit()


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(
	event: InputEvent
) -> void:

	if event.is_action_pressed(
		"ui_cancel"
	):

		toggle_pause()


# ============================================================
# PAUSE
# ============================================================

func toggle_pause() -> void:

	if current_state in [
		GameState.DIALOGUE,
		GameState.COMBAT,
		GameState.QUIZ
	]:

		return


	if (
		TutorialManager
		and TutorialManager.current_active_step
			== "intro"
	):

		return


	var tree: SceneTree = (
		get_tree()
	)

	tree.paused = not tree.paused


	if tree.paused:

		_apply_state(
			GameState.PAUSED
		)

	else:

		_apply_state(
			GameState.EXPLORATION
		)


func set_game_state(
	new_state: GameState
) -> void:

	if (
		get_tree().paused
		and new_state != GameState.PAUSED
	):

		return


	_apply_state(
		new_state
	)


func _apply_state(
	new_state: GameState
) -> void:

	current_state = new_state

	state_changed.emit(
		current_state
	)


	match current_state:

		GameState.EXPLORATION:

			hud_visibility_changed.emit(
				true
			)

			game_paused.emit(
				false
			)


		GameState.PAUSED:

			hud_visibility_changed.emit(
				false
			)

			game_paused.emit(
				true
			)


		GameState.DIALOGUE:

			hud_visibility_changed.emit(
				false
			)


		GameState.QUIZ:

			hud_visibility_changed.emit(
				false
			)


		GameState.COMBAT:

			hud_visibility_changed.emit(
				false
			)


# ============================================================
# QUEST SAVE SIGNALS
# ============================================================

func _on_quest_state_changed(
	_quest_id: String,
	_value_1: Variant = null,
	_value_2: Variant = null
) -> void:

	request_save()


func _on_dialogue_flag_changed(
	_flag_id: String
) -> void:

	request_save()


# ============================================================
# PUBLIC SAVE REQUEST
# ============================================================
#
# LanguageProgress calls this whenever:
#
# - encountered changes
# - learned changes
# - mastery changes
#
# That means language progress is saved automatically.
# ============================================================

func request_save() -> void:

	_queue_quest_save()


# ============================================================
# QUEUE SAVE
# ============================================================

func _queue_quest_save() -> void:

	# Do not queue account saves until a real authenticated account is active.
	if (
		not _session_ready
		or active_user_email.is_empty()
		or not SupabaseManager
		or SupabaseManager.current_user_id.is_empty()
	):
		return

	if quest_save_queued:
		return

	quest_save_queued = true
	var queued_generation: int = _session_generation
	var queued_user_id: String = SupabaseManager.current_user_id

	call_deferred(
		"_save_progress",
		queued_generation,
		queued_user_id
	)


# ============================================================
# SAVE PROGRESS
# ============================================================

func _save_progress(
	queued_generation: int,
	queued_user_id: String
) -> void:

	# A deferred save from a previous account must not run after a switch.
	# Do not clear quest_save_queued for a newer session's queued job.
	if queued_generation != _session_generation:
		return

	quest_save_queued = false

	# Re-check account identity because login/logout may have happened after
	# the deferred callback was queued.
	if (
		not _session_ready
		or active_user_email.is_empty()
		or not SupabaseManager
		or SupabaseManager.current_user_id.is_empty()
		or SupabaseManager.current_user_id != queued_user_id
	):
		return


	# --------------------------------------------------------
	# NO ACCOUNT
	# --------------------------------------------------------

	if active_user_email.is_empty():

		print(
			"⚠️ [GAME MANAGER] Save requested "
			+ "but no account is active."
		)

		return


	# --------------------------------------------------------
	# PLAYER
	# --------------------------------------------------------

	var player: Node = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)


	if not is_instance_valid(
		player
	):

		print(
			"⚠️ [GAME MANAGER] Player unavailable."
		)

		return


	if not player is CharacterBody3D:

		push_warning(
			"[GAME MANAGER] Player is not CharacterBody3D."
		)

		return


	# --------------------------------------------------------
	# SAVE
	# --------------------------------------------------------

	if not SaveManager:

		push_warning(
			"[GAME MANAGER] SaveManager unavailable."
		)

		return


	SaveManager.save_game(
		player as CharacterBody3D,
		current_level_path
	)

	print(
		"💾 [GAME MANAGER] Account progress saved for: ",
		active_user_email
	)


# ============================================================
# EMERGENCY SAVE
# ============================================================

func _perform_emergency_save_and_quit() -> void:

	print(
		"❖ Window close requested. Saving..."
	)


	var tree: SceneTree = (
		get_tree()
	)


	var player: Node = (
		tree.get_first_node_in_group(
			"player"
		)
	)


	var current_scene: Node = (
		tree.current_scene
	)


	if (
		is_instance_valid(player)
		and player is CharacterBody3D
		and SaveManager
		and _session_ready
		and not active_user_email.is_empty()
		and SupabaseManager
		and not SupabaseManager.current_user_id.is_empty()
	):

		if (
			current_scene
			and current_scene.scene_file_path
				!= "res://Scenes/UI/GameMenu.tscn"
		):

			SaveManager.save_game(
				player as CharacterBody3D,
				current_level_path
			)


	# Give the final cloud upload a moment to finish before quitting.
	if SupabaseManager:

		await SupabaseManager.wait_until_idle(3.0)


	tree.quit()


# ============================================================
# SESSION INITIALIZATION
# ============================================================

func initialize_session(
	email: String
) -> void:

	# Each invocation is a new session generation. If another login/logout
	# happens while the cloud fetch is awaiting a response, this invocation
	# will stop before it writes or loads anything.
	_session_generation += 1
	var session_generation: int = _session_generation
	var normalized_email: String = email.strip_edges().to_lower()
	_session_ready = false

	active_user_email = ""
	adventurer_name = "Adventurer"
	_reset_runtime_state()
	active_user_email = normalized_email

	# Local files and Supabase rows are keyed by authenticated user ID.
	if (
		not SupabaseManager
		or SupabaseManager.current_user_id.is_empty()
	):
		push_error(
			"[GAME MANAGER] No authenticated Supabase user ID. "
			+ "Not loading or saving any account data."
		)
		active_user_email = ""
		return

	var session_user_id: String = SupabaseManager.current_user_id
	SupabaseManager.current_user_email = normalized_email

	# Use the name returned from this account's Supabase user metadata.
	var account_name: String = SupabaseManager.current_adventurer_name.strip_edges()
	if not account_name.is_empty():
		adventurer_name = account_name

	# Cloud save first. Capture account ID above and validate it again after
	# await, because the player may log out or switch accounts while waiting.
	var cloud_data: Dictionary = await SupabaseManager.fetch_save_from_cloud()
	if (
		session_generation != _session_generation
		or active_user_email != normalized_email
		or not SupabaseManager
		or SupabaseManager.current_user_id != session_user_id
	):
		return

	if not cloud_data.is_empty():
		SaveManager.write_raw_save_data(cloud_data)
		print(
			"☁️ [GAME MANAGER] Cloud account save restored for: ",
			normalized_email
		)


	# --------------------------------------------------------
	# ACCOUNT SAVE
	# --------------------------------------------------------

	if (
		session_generation == _session_generation
		and SupabaseManager
		and SupabaseManager.current_user_id == session_user_id
		and SaveManager
		and SaveManager.has_save()
	):

		should_load_save = true


		var data: Dictionary = (
			SaveManager.load_game()
		)


		# ----------------------------------------------------
		# TUTORIAL
		# ----------------------------------------------------

		if TutorialManager:

			var tutorial_completed: bool = bool(
				data.get(
					"tutorial_completed",
					false
				)
			)


			if tutorial_completed:

				TutorialManager.current_active_step = (
					"finished"
				)


				for key: String in (
					TutorialManager.progress.keys()
				):

					TutorialManager.progress[key] = true

			else:

				TutorialManager.current_active_step = (
					"intro"
				)


			TutorialManager.update_permissions()


		print(
			"📂 [GAME MANAGER] Loaded existing "
			+ "account session: ",
			active_user_email
		)


	# --------------------------------------------------------
	# NEW ACCOUNT
	# --------------------------------------------------------

	else:

		# Never label an abandoned load as the current account's fresh session.
		if session_generation != _session_generation or not SupabaseManager or SupabaseManager.current_user_id != session_user_id:
			return

		should_load_save = false


		if TutorialManager:

			TutorialManager.reset_tutorial()


		print(
			"✨ [GAME MANAGER] Fresh account session: ",
			active_user_email
		)

	# Saving is enabled only after this account's cloud/local save decision and
	# all state restoration are finished.
	_session_ready = true


# ============================================================
# CLEAR SESSION
# ============================================================

func clear_session_data() -> void:

	# Invalidate deferred saves and any pending cloud-load continuation.
	_session_generation += 1
	_session_ready = false

	# Block any further saves first.
	active_user_email = ""
	adventurer_name = "Adventurer"


	# --------------------------------------------------------
	# SUPABASE
	# --------------------------------------------------------
	#
	# Clears the user ID, tokens and any queued cloud save.
	# --------------------------------------------------------

	if SupabaseManager:

		SupabaseManager.clear_session()


	_reset_runtime_state()


	print(
		"🔄 [GAME MANAGER] Account session cleared."
	)


# ============================================================
# RESET RUNTIME STATE
# ============================================================
#
# Resets every manager that holds per-account data. Used on
# logout AND at the start of every login, so nothing can carry
# over from one account to the next.
# ============================================================

func _reset_runtime_state() -> void:

	should_load_save = false
	quest_save_queued = false
	current_state = GameState.EXPLORATION
	get_tree().paused = false

	current_level_path = (
		"res://Scenes/Main/FirstTown.tscn"
	)

	# LANGUAGE
	if LanguageProgress:

		LanguageProgress.reset()

	# INVENTORY
	if InventoryManager:
		InventoryManager.reset_for_account()

	# TUTORIAL
	if TutorialManager:

		TutorialManager.reset_tutorial()


	# PLAYER
	if PlayerProgression:

		_reset_player_progression()


	# TIME
	if TimeManager:

		TimeManager.current_index = 0


	# QUESTS + DIALOGUE FLAGS
	if QuestManager:

		QuestManager.active_quests.clear()
		QuestManager.completed_quests.clear()
		QuestManager.dialogue_flags.clear()


func _reset_player_progression() -> void:

	# PlayerProgression.load_save_data({}) returns immediately when the
	# data is empty, so it can NOT be used to reset. Reset the saved
	# fields directly (defaults match PlayerProgression.gd).

	PlayerProgression.level = 1
	PlayerProgression.current_exp = 0
	PlayerProgression.gold = 0
	PlayerProgression.active_pet_id = ""
	PlayerProgression.current_hp = -1

	for gear_key: String in PlayerProgression.gear_levels.keys():

		PlayerProgression.gear_levels[gear_key] = 1

	PlayerProgression.stats_changed.emit()
	PlayerProgression.hp_changed.emit()
