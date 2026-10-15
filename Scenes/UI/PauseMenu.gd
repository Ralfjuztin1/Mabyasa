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
@onready var gold_label: Label = $LayoutWrapper/RightPanel/Margin/VBox/ProfileSection/Info/GoldRow/GoldLabel


const QUEST_LOG_SCENE: PackedScene = preload("res://Scenes/UI/QuestLog.tscn")
const PLAYER_STATS_SCENE: PackedScene = preload("res://Scenes/UI/PlayerStats.tscn")
const WORD_BANK_SCENE: PackedScene = preload("res://Scenes/UI/WordBank.tscn")

var quest_log: CanvasLayer = null
var player_stats: CanvasLayer = null
var word_bank: CanvasLayer = null
var _word_bank_opened_from_pause_menu: bool = false

# Track which menu opened an overlay so the HUD can reuse the same
# Quest Log/Stats instances without unexpectedly reopening the pause menu.
var _quest_log_opened_from_pause_menu: bool = false
var _stats_opened_from_pause_menu: bool = false


func _ready() -> void:
	# The menu must still respond while the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(layout_wrapper):
		layout_wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	hide()

	# PRIMARY BUTTONS
	if is_instance_valid(resume_button):
		_connect_if_needed(resume_button.pressed, _on_resume_pressed)
	if is_instance_valid(quit_button):
		_connect_if_needed(quit_button.pressed, _on_quit_pressed)

	# MENU BUTTONS
	if is_instance_valid(menu_grid):
		var inventory_button := menu_grid.get_node_or_null("Inventory") as Button
		var wordbook_button := menu_grid.get_node_or_null("Wordbook") as Button
		var settings_button := menu_grid.get_node_or_null("Settings") as Button

		if is_instance_valid(inventory_button):
			_connect_if_needed(
				inventory_button.pressed,
				_on_unavailable_menu_pressed.bind("Inventory")
			)
		if is_instance_valid(wordbook_button):
			wordbook_button.disabled = false
			wordbook_button.tooltip_text = "Review discovered Kapampangan words."
			_connect_if_needed(wordbook_button.pressed, _on_wordbook_pressed)
		if is_instance_valid(settings_button):
			_connect_if_needed(
				settings_button.pressed,
				_on_unavailable_menu_pressed.bind("Settings")
			)

	if is_instance_valid(missions_button):
		_connect_if_needed(missions_button.pressed, _on_missions_pressed)
	if is_instance_valid(stats_button):
		_connect_if_needed(stats_button.pressed, _on_stats_pressed)

	_create_quest_log()
	_create_player_stats()
	_create_word_bank()
	# Connect progression updates once and clean them up on exit.
	if is_instance_valid(PlayerProgression):
		_connect_if_needed(
			PlayerProgression.stats_changed,
			_update_profile_display
		)
		_connect_if_needed(
			PlayerProgression.leveled_up,
			_update_profile_display
		)

	_update_profile_display()

	if (
		is_instance_valid(GameManager)
		and GameManager.has_signal("game_paused")
	):
		_connect_if_needed(GameManager.game_paused, _on_game_paused)


func _exit_tree() -> void:
	if is_instance_valid(PlayerProgression):
		_disconnect_if_connected(
			PlayerProgression.stats_changed,
			_update_profile_display
		)
		_disconnect_if_connected(
			PlayerProgression.leveled_up,
			_update_profile_display
		)

	if (
		is_instance_valid(GameManager)
		and GameManager.has_signal("game_paused")
	):
		_disconnect_if_connected(
			GameManager.game_paused,
			_on_game_paused
		)


func _connect_if_needed(signal_ref: Signal, callback: Callable) -> void:
	if not signal_ref.is_connected(callback):
		signal_ref.connect(callback)


func _disconnect_if_connected(signal_ref: Signal, callback: Callable) -> void:
	if signal_ref.is_connected(callback):
		signal_ref.disconnect(callback)

func _create_quest_log() -> void:
	if is_instance_valid(quest_log):
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
		_connect_if_needed(quest_log.closed, _on_quest_log_closed)

	quest_log.visible = false


func _on_missions_pressed() -> void:
	if not is_instance_valid(quest_log):
		return

	_quest_log_opened_from_pause_menu = true
	quest_log.layer = 60
	hide()
	quest_log.open()


func _on_quest_log_closed() -> void:
	# If the HUD opened the shared Quest Log, leave overlay handling to the HUD.
	if not _quest_log_opened_from_pause_menu:
		return

	_quest_log_opened_from_pause_menu = false
	if is_instance_valid(quest_log):
		quest_log.layer = 1

	# Closing the log returns to the pause menu, but never resumes gameplay.
	if get_tree().paused:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _create_player_stats() -> void:
	if is_instance_valid(player_stats):
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
		_connect_if_needed(player_stats.closed, _on_player_stats_closed)

	player_stats.visible = false


func _on_stats_pressed() -> void:
	if not is_instance_valid(player_stats):
		return

	_stats_opened_from_pause_menu = true
	player_stats.layer = 60
	hide()
	player_stats.open()


func _on_player_stats_closed() -> void:
	# The HUD may also open this instance. Only return to the pause menu if
	# the pause menu itself started the transition.
	if not _stats_opened_from_pause_menu:
		return

	_stats_opened_from_pause_menu = false
	if is_instance_valid(player_stats):
		player_stats.layer = 1

	if get_tree().paused:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _create_word_bank() -> void:
	if is_instance_valid(word_bank):
		return

	word_bank = WORD_BANK_SCENE.instantiate() as CanvasLayer
	if word_bank == null:
		push_error("[PAUSE MENU] Failed to create WordBank.")
		return

	add_child(word_bank)

	if word_bank.has_signal("closed"):
		_connect_if_needed(word_bank.closed, _on_word_bank_closed)

	word_bank.visible = false


func _on_wordbook_pressed() -> void:
	if not is_instance_valid(word_bank):
		return

	_word_bank_opened_from_pause_menu = true
	word_bank.layer = 60
	hide()
	word_bank.open()


func _on_word_bank_closed() -> void:
	if not _word_bank_opened_from_pause_menu:
		return

	_word_bank_opened_from_pause_menu = false

	if is_instance_valid(word_bank):
		word_bank.layer = 1

	if get_tree().paused:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
func _on_unavailable_menu_pressed(menu_name: String) -> void:
	print("[PAUSE MENU] %s menu is not available yet." % menu_name)


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
		gold_label.text = str(PlayerProgression.gold)


func _on_game_paused(is_paused: bool) -> void:
	visible = is_paused

	if not is_paused:
		_quest_log_opened_from_pause_menu = false
		_stats_opened_from_pause_menu = false
		_word_bank_opened_from_pause_menu = false
		if is_instance_valid(word_bank):
			word_bank.visible = false
			word_bank.layer = 1
		if is_instance_valid(quest_log):
			quest_log.visible = false
			quest_log.layer = 1

		if is_instance_valid(player_stats):
			player_stats.visible = false
			player_stats.layer = 1

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

	# Emit GameManager state/visibility signals instead of mutating its state directly.
	if is_instance_valid(GameManager):
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_instance_valid(quit_button):
		quit_button.disabled = true

	if is_instance_valid(resume_button):
		resume_button.disabled = true

	if TransitionManager:
		await TransitionManager.fade_out(0.5)

	get_tree().change_scene_to_file("res://Scenes/UI/GameMenu.tscn")

	if is_instance_valid(TransitionManager):
		await TransitionManager.fade_in(0.5)
