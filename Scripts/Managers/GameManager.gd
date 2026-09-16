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

# Prevent multiple quest events in the same frame
# from causing multiple save operations.
var quest_save_queued: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)

	# Quest progress should automatically trigger a save.
	if QuestManager:
		QuestManager.quest_started.connect(_on_quest_state_changed)
		QuestManager.quest_objective_updated.connect(_on_quest_state_changed)
		QuestManager.quest_completed.connect(_on_quest_state_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_perform_emergency_save_and_quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	if current_state in [
		GameState.DIALOGUE,
		GameState.COMBAT,
		GameState.QUIZ
	]:
		return

	# Prevent pausing while the tutorial welcome intro box is open.
	if TutorialManager and TutorialManager.current_active_step == "intro":
		return

	var tree := get_tree()

	tree.paused = not tree.paused

	if tree.paused:
		_apply_state(GameState.PAUSED)
	else:
		_apply_state(GameState.EXPLORATION)


func set_game_state(new_state: GameState) -> void:
	if get_tree().paused and new_state != GameState.PAUSED:
		return

	_apply_state(new_state)


func _apply_state(new_state: GameState) -> void:
	current_state = new_state

	state_changed.emit(current_state)

	match current_state:
		GameState.EXPLORATION:
			hud_visibility_changed.emit(true)
			game_paused.emit(false)

		GameState.PAUSED:
			hud_visibility_changed.emit(false)
			game_paused.emit(true)

		GameState.DIALOGUE, GameState.QUIZ, GameState.COMBAT:
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

func _queue_quest_save() -> void:
	if quest_save_queued:
		return

	quest_save_queued = true

	# Wait until the current event finishes.
	call_deferred("_save_quest_progress")


func _save_quest_progress() -> void:
	quest_save_queued = false

	if active_user_email.is_empty():
		print("⚠️ [GAME MANAGER] Quest changed but no user is logged in.")
		return

	var player := get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		print("⚠️ [GAME MANAGER] Quest changed but player is not available yet.")
		return

	if not SaveManager:
		push_warning(
			"[GAME MANAGER] SaveManager is unavailable."
		)
		return

	SaveManager.save_game(
		player,
		current_level_path
	)

	print("💾 [GAME MANAGER] Quest progress automatically saved.")


# ============================================================
# EMERGENCY SAVE
# ============================================================

func _perform_emergency_save_and_quit() -> void:
	print(
		"❖ Window close requested. Performing emergency position save..."
	)

	var tree := get_tree()

	var player := tree.get_first_node_in_group("player")
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
# CENTRALIZED SESSION INITIALIZATION
# ============================================================

func initialize_session(email: String) -> void:
	active_user_email = email.strip_edges().to_lower()

	if SupabaseManager:
		SupabaseManager.current_user_email = active_user_email

	# Pre-load save data and tutorial state immediately upon login.
	if SaveManager and SaveManager.has_save():
		should_load_save = true

		var data := SaveManager.load_game()

		if TutorialManager:
			if data.get("tutorial_completed", false):
				TutorialManager.current_active_step = "finished"

				for key in TutorialManager.progress.keys():
					TutorialManager.progress[key] = true
			else:
				TutorialManager.current_active_step = "intro"

			TutorialManager.update_permissions()

		print(
			"📂 [GAME MANAGER] Loaded existing session for: ",
			active_user_email
		)

	else:
		should_load_save = false

		if TutorialManager:
			TutorialManager.reset_tutorial()

		print(
			"✨ [GAME MANAGER] Initialized fresh session for new user: ",
			active_user_email
		)


# ============================================================
# MASTER SESSION RESET
# ============================================================

func clear_session_data() -> void:
	should_load_save = false

	current_level_path = "res://Scenes/Main/FirstTown.tscn"

	active_user_email = ""

	quest_save_queued = false

	if SupabaseManager:
		SupabaseManager.current_user_email = ""

	if TutorialManager:
		TutorialManager.reset_tutorial()

	if PlayerProgression:
		PlayerProgression.load_save_data({})

	if TimeManager:
		TimeManager.current_index = 0

	if QuestManager:
		QuestManager.active_quests.clear()
		QuestManager.completed_quests.clear()
