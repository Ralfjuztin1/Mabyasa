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

	if quest_save_queued:
		return

	quest_save_queued = true

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


	tree.quit()


# ============================================================
# SESSION INITIALIZATION
# ============================================================

func initialize_session(
	email: String
) -> void:

	active_user_email = (
		email.strip_edges().to_lower()
	)


	# --------------------------------------------------------
	# CRITICAL ACCOUNT ISOLATION
	# --------------------------------------------------------
	#
	# Always clear the language state belonging to the previous
	# account before loading the new account.
	#
	# This prevents:
	#
	# Account A
	# learned Mayap a abak
	#
	# ↓ logout/login
	#
	# Account B
	# accidentally still knows Mayap a abak
	#
	# --------------------------------------------------------

	if LanguageProgress:

		LanguageProgress.reset()


	# --------------------------------------------------------
	# SUPABASE EMAIL
	# --------------------------------------------------------

	if SupabaseManager:

		SupabaseManager.current_user_email = (
			active_user_email
		)


	# --------------------------------------------------------
	# CLOUD SAVE FIRST
	# --------------------------------------------------------
	#
	# The cloud save belongs to the authenticated Supabase
	# user ID.
	# --------------------------------------------------------

	if SupabaseManager:

		var cloud_data: Dictionary = (
			await SupabaseManager.fetch_save_from_cloud()
		)


		if not cloud_data.is_empty():

			SaveManager.write_raw_save_data(
				cloud_data
			)

			print(
				"☁️ [GAME MANAGER] Cloud account save "
				+ "restored for: ",
				active_user_email
			)


	# --------------------------------------------------------
	# ACCOUNT SAVE
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
	# LANGUAGE
	# --------------------------------------------------------
	#
	# IMPORTANT:
	# Completely remove the previous account's language state
	# from memory.
	# --------------------------------------------------------

	if LanguageProgress:

		LanguageProgress.reset()


	# --------------------------------------------------------
	# TUTORIAL
	# --------------------------------------------------------

	if TutorialManager:

		TutorialManager.reset_tutorial()


	# --------------------------------------------------------
	# PLAYER
	# --------------------------------------------------------

	if PlayerProgression:

		PlayerProgression.load_save_data(
			{}
		)


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
		QuestManager.dialogue_flags.clear()


	print(
		"🔄 [GAME MANAGER] Account session cleared."
	)
