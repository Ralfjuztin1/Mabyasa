extends CanvasLayer

@onready var resume_button: Button = $HBoxContainer/SidebarPanel/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_button: Button = $HBoxContainer/SidebarPanel/MarginContainer/VBoxContainer/QuitButton
@onready var h_box_container: HBoxContainer = $HBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if h_box_container:
		h_box_container.mouse_filter = Control.MOUSE_FILTER_PASS

	hide() 
	
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	GameManager.game_paused.connect(_on_game_paused)

func _on_game_paused(is_paused: bool) -> void:
	visible = is_paused
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_quit_pressed() -> void:
	print("Saving game from pause menu...")
	
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Save the actual level map path instead of Main.tscn container
		SaveManager.save_game(player, GameManager.current_level_path)
	
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.EXPLORATION
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	quit_button.disabled = true
	resume_button.disabled = true
	
	await TransitionManager.fade_out(0.5)
	get_tree().change_scene_to_file("res://Scenes/UI/GameMenu.tscn")
	TransitionManager.fade_in(0.5)
