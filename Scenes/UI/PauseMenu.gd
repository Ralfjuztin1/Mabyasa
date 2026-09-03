extends CanvasLayer

# --- Updated Node Paths Matching the New UI Layout ---
@onready var resume_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/BottomBar/ResumeButton
@onready var quit_button: Button = $LayoutWrapper/RightPanel/Margin/VBox/BottomBar/QuitButton
@onready var layout_wrapper: HBoxContainer = $LayoutWrapper
@onready var menu_grid: GridContainer = $LayoutWrapper/RightPanel/Margin/VBox/MenuGrid

func _ready() -> void:
	# Keep processing even when the game tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if layout_wrapper:
		layout_wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	hide() 
	
	# Connect primary buttons safely
	if is_instance_valid(resume_button):
		resume_button.pressed.connect(_on_resume_pressed)
	if is_instance_valid(quit_button):
		quit_button.pressed.connect(_on_quit_pressed)
		
	# Connect Grid Buttons with Console Placeholders safely
	if is_instance_valid(menu_grid):
		var btn_store = menu_grid.get_node_or_null("GridBtn1")
		var btn_party = menu_grid.get_node_or_null("GridBtn2")
		var btn_wish = menu_grid.get_node_or_null("GridBtn3")
		var btn_missions = menu_grid.get_node_or_null("GridBtn4")
		var btn_inventory = menu_grid.get_node_or_null("GridBtn5")
		var btn_settings = menu_grid.get_node_or_null("GridBtn6")
		
		if btn_store: btn_store.pressed.connect(func(): print("❖ Store menu clicked (Currently Unavailable)"))
		if btn_party: btn_party.pressed.connect(func(): print("❖ Party menu clicked (Currently Unavailable)"))
		if btn_wish: btn_wish.pressed.connect(func(): print("❖ Wish menu clicked (Currently Unavailable)"))
		if btn_missions: btn_missions.pressed.connect(func(): print("❖ Missions menu clicked (Currently Unavailable)"))
		if btn_inventory: btn_inventory.pressed.connect(func(): print("❖ Inventory menu clicked (Currently Unavailable)"))
		if btn_settings: btn_settings.pressed.connect(func(): print("❖ Settings menu clicked (Currently Unavailable)"))
	
	# Connect via GameManager signal (the goat method that handles ESC cleanly)
	if GameManager.has_signal("game_paused"):
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
		# Dynamically resolve current map path safely (ignoring Main.tscn wrapper)
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
	
	if is_instance_valid(quit_button): quit_button.disabled = true
	if is_instance_valid(resume_button): resume_button.disabled = true
	
	if TransitionManager:
		await TransitionManager.fade_out(0.5)
	get_tree().change_scene_to_file("res://Scenes/UI/GameMenu.tscn")
	if TransitionManager:
		TransitionManager.fade_in(0.5)
