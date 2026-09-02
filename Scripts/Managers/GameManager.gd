extends Node

signal game_paused(is_paused: bool)
signal hud_visibility_changed(is_visible: bool)
signal state_changed(new_state: GameState)

enum GameState { EXPLORATION, DIALOGUE, QUIZ, COMBAT, PAUSED }
var should_load_save: bool = false
var current_state: GameState = GameState.EXPLORATION

# Tracks the active gameplay map file path instead of the container scene
var current_level_path: String = "res://Scenes/Main/FirstTown.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_perform_emergency_save_and_quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): 
		toggle_pause()

func toggle_pause() -> void:
	if current_state in [GameState.DIALOGUE, GameState.COMBAT, GameState.QUIZ]:
		return 

	var tree = get_tree()
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

func _perform_emergency_save_and_quit() -> void:
	print("❖ Window close requested. Performing emergency position save...")
	
	var tree = get_tree()
	var player = tree.get_first_node_in_group("player")
	var current_scene = tree.current_scene
	
	if player and SaveManager:
		if current_scene and current_scene.scene_file_path != "res://Scenes/UI/GameMenu.tscn":
			SaveManager.save_game(player, current_level_path)
	
	tree.quit()
