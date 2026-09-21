extends CanvasLayer


@onready var resume_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/BottomBar/ResumeButton
@onready var quit_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/BottomBar/QuitButton
@onready var layout_wrapper: HBoxContainer = $LayoutWrapper
@onready var menu_grid: GridContainer = $LayoutWrapper/RightPanel/Margin/VBox/MenuGrid
@onready var missions_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/MenuGrid/Missions


const QUEST_LOG_SCENE: PackedScene = preload(
	"res://Scenes/UI/QuestLog.tscn"
)


var quest_log: CanvasLayer = null


func _ready() -> void:
	# Keep processing even when the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if layout_wrapper:
		layout_wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	hide()

	# ------------------------------------------------------------
	# PRIMARY BUTTONS
	# ------------------------------------------------------------

	if is_instance_valid(resume_button):
		resume_button.pressed.connect(_on_resume_pressed)

	if is_instance_valid(quit_button):
		quit_button.pressed.connect(_on_quit_pressed)

	# ------------------------------------------------------------
	# MENU BUTTONS
	# ------------------------------------------------------------

	if is_instance_valid(menu_grid):
		var btn_inventory = menu_grid.get_node_or_null("Inventory")
		var btn_settings = menu_grid.get_node_or_null("Settings")

		if btn_inventory:
			btn_inventory.pressed.connect(
				func():
					print("❖ Inventory menu clicked (Currently Unavailable)")
			)

		if btn_settings:
			btn_settings.pressed.connect(
				func():
					print("❖ Settings menu clicked (Currently Unavailable)")
			)

	# Quests button.
	if is_instance_valid(missions_button):
		missions_button.pressed.connect(_on_missions_pressed)

	# ------------------------------------------------------------
	# QUEST LOG
	# ------------------------------------------------------------

	_create_quest_log()

	# ------------------------------------------------------------
	# GAME MANAGER
	# ------------------------------------------------------------

	if GameManager.has_signal("game_paused"):
		GameManager.game_paused.connect(_on_game_paused)


func _create_quest_log() -> void:
	if quest_log != null:
		return

	if QUEST_LOG_SCENE == null:
		push_error("[PAUSE MENU] QuestLog scene could not be loaded.")
		return

	quest_log = QUEST_LOG_SCENE.instantiate() as CanvasLayer

	if quest_log == null:
		push_error("[PAUSE MENU] Failed to instantiate QuestLog.")
		return

	add_child(quest_log)

	if quest_log.has_signal("closed"):
		quest_log.closed.connect(_on_quest_log_closed)

	quest_log.visible = false


func _on_missions_pressed() -> void:
	if quest_log == null:
		return

	hide()

	quest_log.open()


func _on_quest_log_closed() -> void:
	# Do not resume the game.
	# The player is still paused, so we only return
	# to the Pause Menu.
	show()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_game_paused(is_paused: bool) -> void:
	visible = is_paused

	if not is_paused:
		if quest_log != null:
			quest_log.visible = false

		if TutorialManager and TutorialManager.current_active_step in [
			"intro",
			"movement"
		]:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		return

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()


func _on_quit_pressed() -> void:
	print("Saving game from pause menu...")

	var player = get_tree().get_first_node_in_group("player")

	if player:
		var current_scene_path = ""
		var current_scene = get_tree().current_scene

		if current_scene:
			if current_scene.scene_file_path == "res://Scenes/SceneManager/Main.tscn":
				var level_container = current_scene.find_child(
					"LevelContainer",
					true,
					false
				)

				if level_container and level_container.get_child_count() > 0:
					var actual_level = level_container.get_child(0)

					if actual_level and not actual_level.scene_file_path.is_empty():
						current_scene_path = actual_level.scene_file_path

			if current_scene_path.is_empty():
				current_scene_path = current_scene.scene_file_path

		if (
			current_scene_path.is_empty()
			or current_scene_path == "res://Scenes/SceneManager/Main.tscn"
		):
			current_scene_path = (
				GameManager.current_level_path
				if "current_level_path" in GameManager
				else "res://Scenes/Main/FirstTown.tscn"
			)

		SaveManager.save_game(
			player,
			current_scene_path
		)

	get_tree().paused = false

	if "GameState" in GameManager and "EXPLORATION" in GameManager.GameState:
		GameManager.current_state = GameManager.GameState.EXPLORATION

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_instance_valid(quit_button):
		quit_button.disabled = true

	if is_instance_valid(resume_button):
		resume_button.disabled = true

	if TransitionManager:
		await TransitionManager.fade_out(0.5)

	get_tree().change_scene_to_file(
		"res://Scenes/UI/GameMenu.tscn"
	)

	if TransitionManager:
		TransitionManager.fade_in(0.5)
