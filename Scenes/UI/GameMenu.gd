extends Control

@onready var panel_container = $CenterContainer/PanelContainer
@onready var play_button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/PlayButton
@onready var settings_button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/SettingsButton
@onready var quit_button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/QuitButton

func _ready():
	# Connect buttons
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Add hover animations
	_setup_button_animations(play_button)
	_setup_button_animations(settings_button)
	_setup_button_animations(quit_button)
	
	# Animate menu pop-in
	_animate_panel_pop_in()

func _animate_panel_pop_in():
	panel_container.pivot_offset = panel_container.size / 2.0
	panel_container.scale = Vector2(0.8, 0.8)
	panel_container.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.25)

func _setup_button_animations(button: Button):
	# Set pivot to center so it scales cleanly from the middle
	button.pivot_offset = button.size / 2.0
	
	button.mouse_entered.connect(func():
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	)

# Inside GameMenu.gd

# Inside GameMenu.gd

func _on_play_pressed() -> void:
	print("Loading game world...")
	
	# Check dynamically using the active user's account file
	if SaveManager.has_save():
		GameManager.should_load_save = true
		print("Found user save file! Loading position...")
	else:
		GameManager.should_load_save = false
		print("No save file found for this user. Starting fresh.")
	
	await TransitionManager.fade_out(0.5)
	get_tree().change_scene_to_file("res://Scenes/SceneManager/Main.tscn")
	TransitionManager.fade_in(0.5)

func _on_settings_pressed():
	print("Opening Settings...")
	# TODO: Open a settings panel here later

func _on_quit_pressed():
	# Safely close the game
	get_tree().quit()
