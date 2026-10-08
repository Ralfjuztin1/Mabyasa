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
var should_load_save: bool = false

var current_state: GameState = GameState.EXPLORATION

var current_level_path: String = "res://Scenes/Main/FirstTown.tscn"

# Prevent multiple save operations in the same frame.
var quest_save_queued: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().set_auto_accept_quit(false)

	# --------------------------------------------------------
	# QUEST SAVE SIGNALS
	# --------------------------------------------------------

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

		# IMPORTANT:
		# Dialogue flags are also part of quest save data.
		# This makes one-time story cutscenes save automatically.
		QuestManager.dialogue_flag_changed.connect(
			_on_dialogue_flag_changed
		)


# ============================================================
# WINDOW CLOSE
# ============================================================

func _notification(what: int) -> void:

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_perform_emergency_save_and_quit()


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_cancel"):
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

	# Prevent pausing while the tutorial welcome intro box is open.
	if (
		TutorialManager
		and TutorialManager.current_active_step == "intro"
	):
		return

	var tree := get_tree()

	tree.paused = not tree.paused

	if tree.paused:
		_apply_state(GameState.PAUSED)
	else:
		_apply_state(GameState.EXPLORATION)


func set_game_state(
	new_state: GameState
) -> void:

	if (
		get_tree().paused
		and new_state != GameState.PAUSED
	):
		return

	_apply_state(new_state)


func _apply_state(
	new_state: GameState
) -> void:

	current_state = new_state

	state_changed.emit(
		current_state
	)

	match current_state:

		GameState.EXPLORATION:
			hud_visibility_changed.emit(true)
			game_paused.emit(false)

		GameState.PAUSED:
			hud_visibility_changed.emit(false)
			game_paused.emit(true)

		GameState.DIALOGUE:
			hud_visibility_changed.emit(false)

		GameState.QUIZ:
			hud_visibility_changed.emit(false)

		GameState.COMBAT:
			hud_visibility_changed.emit(false)


# ============================================================
# QUEST SAVE HANDLING
# ============================================================

func _on_quest_state_changed(
	_quest_id: String,
	_value_1 = null,
	_value_2 = null
) -> void:

	_queue_quest_save()


# ============================================================
# DIALOGUE FLAG SAVE HANDLING
# ============================================================

func _on_dialogue_flag_changed(
	_flag_id: String
) -> void:

	# Story flags such as:
	# scene_2_litik_intro
	# scene_3_apu
	#
	# are stored inside QuestManager's save data.
	#
	# Save immediately after a story flag changes.

	_queue_quest_save()


# ============================================================
# QUEUE SAVE
# ============================================================

func request_save() -> void:
	## Public save request used by language progress and other systems.
	_queue_quest_save()


func _queue_quest_save() -> void:

	if quest_save_queued:
		return

	quest_save_queued = true

	# Wait until the current event/cutscene/dialogue
	# finishes its current frame.
	call_deferred(
		"_save_progress"
	)


# ============================================================
# SAVE PROGRESS
# ============================================================

func _save_progress() -> void:

	quest_save_queued = false

	# --------------------------------------------------------
	# NO ACCOUNT
	# --------------------------------------------------------

	if active_user_email.is_empty():

		print(
			"⚠️ [GAME MANAGER] Progress changed but no user is logged in."
		)

		return


	# --------------------------------------------------------
	# FIND PLAYER
	# --------------------------------------------------------

	var player := (
		get_tree().get_first_node_in_group("player")
	)

	if not is_instance_valid(player):

		print(
			"⚠️ [GAME MANAGER] Progress changed but player is unavailable."
		)

		return


	# --------------------------------------------------------
	# SAVEMANAGER
	# --------------------------------------------------------

	if not SaveManager:

		push_warning(
			"[GAME MANAGER] SaveManager is unavailable."
		)

		return


	# --------------------------------------------------------
	# SAVE
	# --------------------------------------------------------

	SaveManager.save_game(
		player,
		current_level_path
	)

	print(
		"💾 [GAME MANAGER] Progress automatically saved for: ",
		active_user_email
	)


# ============================================================
# EMERGENCY SAVE
# ============================================================

func _perform_emergency_save_and_quit() -> void:

	print(
		"❖ Window close requested. Performing emergency save..."
	)

	var tree := get_tree()

	var player := (
		tree.get_first_node_in_group("player")
	)

	var current_scene := tree.current_scene

	if (
		is_instance_valid(player)
		and SaveManager
	):

		if (
			current_scene
			and current_scene.scene_file_path
			!= "res://Scenes/UI/GameMenu.tscn"
		):

			SaveManager.save_game(
				player,
				current_level_path
			)

	tree.quit()


# ============================================================
# SESSION INITIALIZATION
# ============================================================

func initialize_session(
	email: String
) -> void:

	# Always clear the previous account before loading this account.
	if LanguageProgress:
		LanguageProgress.reset()

	active_user_email = (
		email.strip_edges().to_lower()
	)

	# --------------------------------------------------------
	# SYNC EMAIL WITH SUPABASE MANAGER
	# --------------------------------------------------------

	if SupabaseManager:

		SupabaseManager.current_user_email = (
			active_user_email
		)


	# --------------------------------------------------------
	# DOWNLOAD CLOUD SAVE FIRST
	# --------------------------------------------------------
	#
	# Important:
	# We must get this user's cloud save before checking
	# the local save.
	#
	# This allows the same account to continue its progress
	# on another computer.
	#

	if SupabaseManager:

		var cloud_data: Dictionary = (
			await SupabaseManager.fetch_save_from_cloud()
		)

		if not cloud_data.is_empty():

			SaveManager.write_raw_save_data(
				cloud_data
			)

			print(
				"☁️ [GAME MANAGER] Cloud save restored for: ",
				active_user_email
			)


	# --------------------------------------------------------
	# LOAD ACCOUNT SAVE
	# --------------------------------------------------------

	if (
		SaveManager
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

			if data.get(
				"tutorial_completed",
				false
			):

				TutorialManager.current_active_step = (
					"finished"
				)

				for key in TutorialManager.progress.keys():

					TutorialManager.progress[key] = true

			else:

				TutorialManager.current_active_step = (
					"intro"
				)

			TutorialManager.update_permissions()


		print(
			"📂 [GAME MANAGER] Loaded existing account session: ",
			active_user_email
		)


	# --------------------------------------------------------
	# NEW ACCOUNT
	# --------------------------------------------------------

	else:

		should_load_save = false

		if TutorialManager:

			TutorialManager.reset_tutorial()


		print(
			"✨ [GAME MANAGER] Fresh account session: ",
			active_user_email
		)


# ============================================================
# CLEAR SESSION
# ============================================================

func clear_session_data() -> void:

	should_load_save = false

	current_level_path = (
		"res://Scenes/Main/FirstTown.tscn"
	)

	active_user_email = ""

	quest_save_queued = false


	# --------------------------------------------------------
	# SUPABASE
	# --------------------------------------------------------

	if SupabaseManager:

		SupabaseManager.current_user_email = ""

		SupabaseManager.current_user_id = ""

		SupabaseManager.session_token = ""


	# --------------------------------------------------------
	# TUTORIAL
	# --------------------------------------------------------

	if TutorialManager:

		TutorialManager.reset_tutorial()


	# --------------------------------------------------------
	# PLAYER PROGRESSION
	# --------------------------------------------------------

	if PlayerProgression:

		PlayerProgression.load_save_data({})

	# Language learning belongs to the logged-in account.
	if LanguageProgress:
		LanguageProgress.reset()


	# --------------------------------------------------------
	# TIME
	# --------------------------------------------------------

	if TimeManager:

		TimeManager.current_index = 0


	# --------------------------------------------------------
	# QUESTS + STORY FLAGS
	# --------------------------------------------------------

	if QuestManager:

		QuestManager.active_quests.clear()

		QuestManager.completed_quests.clear()

		# IMPORTANT:
		# Without this, logging out and logging into another
		# account during the same game session could leave the
		# previous account's story flags in memory.

		QuestManager.dialogue_flags.clear()

	print(
		"🔄 [GAME MANAGER] Account session cleared."
	)
