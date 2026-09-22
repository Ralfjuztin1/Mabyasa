extends CanvasLayer


@onready var resume_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/BottomBar/ResumeButton
@onready var quit_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/BottomBar/QuitButton
@onready var layout_wrapper: HBoxContainer = $LayoutWrapper
@onready var menu_grid: GridContainer = $LayoutWrapper/RightPanel/Margin/VBox/MenuGrid
@onready var missions_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/MenuGrid/Missions
@onready var stats_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/ProfileSection/Info/StatsButton

@onready var level_label: Label = $LayoutWrapper/RightPanel/Margin/VBox/ProfileSection/Info/LevelUID
@onready var xp_bar: ProgressBar = $LayoutWrapper/RightPanel/Margin/VBox/ProfileSection/Info/XPBar
@onready var xp_label: Label = $LayoutWrapper/RightPanel/Margin/VBox/ProfileSection/Info/XPLabel
@onready var gold_label: Label = $LayoutWrapper/RightPanel/Margin/VBox/ProfileSection/Info/GoldLabel


const QUEST_LOG_SCENE: PackedScene = preload("res://Scenes/UI/QuestLog.tscn")
const PLAYER_STATS_SCENE: PackedScene = preload("res://Scenes/UI/PlayerStats.tscn")


var quest_log: CanvasLayer = null
var player_stats: CanvasLayer = null


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
				func(): print("❖ Inventory menu clicked (Currently Unavailable)")
			)

		if btn_settings:
			btn_settings.pressed.connect(
				func(): print("❖ Settings menu clicked (Currently Unavailable)")
			)

	# Quests button.
	if is_instance_valid(missions_button):
		missions_button.pressed.connect(_on_missions_pressed)

	# Stats button.
	if is_instance_valid(stats_button):
		stats_button.pressed.connect(_on_stats_pressed)

	# ------------------------------------------------------------
	# QUEST LOG
	# ------------------------------------------------------------

	_create_quest_log()

	# ------------------------------------------------------------
	# PLAYER STATS
	# ------------------------------------------------------------

	_create_player_stats()

	# ------------------------------------------------------------
	# PLAYER PROGRESSION (level / XP / gold)
	# ------------------------------------------------------------

	if PlayerProgression:
		PlayerProgression.stats_changed.connect(_update_profile_display)
		PlayerProgression.leveled_up.connect(_update_profile_display)

	_update_profile_display()

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
	# Do not resume the game — the player is still paused, we just
	# return to the Pause Menu itself.
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _create_player_stats() -> void:
	if player_stats != null:
		return

	if PLAYER_STATS_SCENE == null:
		push_error("[PAUSE MENU] PlayerStats scene could not be loaded.")
		return

	player_stats = PLAYER_STATS_SCENE.instantiate() as CanvasLayer

	if player_stats == null:
		push_error("[PAUSE MENU] Failed to instantiate PlayerStats.")
		return

	add_child(player_stats)

	if player_stats.has_signal("closed"):
		player_stats.closed.connect(_on_player_stats_closed)

	player_stats.visible = false


func _on_stats_pressed() -> void:
	if player_stats == null:
		return

	hide()
	player_stats.open()


func _on_player_stats_closed() -> void:
	# Same as the quest log — stay paused, just return to the Pause Menu.
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_profile_display() -> void:
	if not PlayerProgression:
		return

	var level: int = PlayerProgression.level
	var current_exp: int = PlayerProgression.current_exp
	var max_exp: int = PlayerProgression.get_max_exp(level)

	if is_instance_valid(level_label):
		level_label.text = "Lv. %d" % level

	if is_instance_valid(xp_bar) and max_exp > 0:
		xp_bar.value = (float(current_exp) / float(max_exp)) * 100.0

	if is_instance_valid(xp_label):
		xp_label.text = "EXP  %d / %d" % [current_exp, max_exp]

	if is_instance_valid(gold_label):
		gold_label.text = "🪙 %d" % PlayerProgression.gold


func _on_game_paused(is_paused: bool) -> void:
	visible = is_paused

	if not is_paused:
		if quest_log != null:
			quest_log.visible = false

		if player_stats != null:
			player_stats.visible = false

		if TutorialManager and TutorialManager.current_active_step in ["intro", "movement"]:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		return

	_update_profile_display()
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
				var level_container = current_scene.find_child("LevelContainer", true, false)

				if level_container and level_container.get_child_count() > 0:
					var actual_level = level_container.get_child(0)

					if actual_level and not actual_level.scene_file_path.is_empty():
						current_scene_path = actual_level.scene_file_path

			if current_scene_path.is_empty():
				current_scene_path = current_scene.scene_file_path

		if current_scene_path.is_empty() or current_scene_path == "res://Scenes/SceneManager/Main.tscn":
			current_scene_path = GameManager.current_level_path if "current_level_path" in GameManager else "res://Scenes/Main/FirstTown.tscn"

		SaveManager.save_game(player, current_scene_path)

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

	get_tree().change_scene_to_file("res://Scenes/UI/GameMenu.tscn")

	if TransitionManager:
		TransitionManager.fade_in(0.5)
