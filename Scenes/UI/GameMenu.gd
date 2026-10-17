extends Control

const SETTINGS_MENU_SCENE: PackedScene = preload("res://Scenes/UI/SettingsMenu.tscn")
const MAIN_GAME_SCENE_PATH: String = "res://Scenes/SceneManager/Main.tscn"
const AUTH_SCENE_PATH: String = "res://Scenes/UI/AuthScreen.tscn"

@onready var panel_container: Control = get_node_or_null("CenterContainer/PanelContainer") as Control
@onready var play_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/PlayButton") as Button
@onready var settings_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/SettingsButton") as Button
@onready var logout_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/LogoutButton") as Button
@onready var quit_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/QuitButton") as Button

var settings_menu: CanvasLayer = null
var _changing_scene: bool = false


func _ready() -> void:
	# The front-end menu must never become a paused gameplay scene.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_saved_display_audio_settings()

	_connect_button(play_button, _on_play_pressed)
	_connect_button(settings_button, _on_settings_pressed)
	_connect_button(logout_button, _on_logout_pressed)
	_connect_button(quit_button, _on_quit_pressed)

	for button: Button in [play_button, settings_button, logout_button, quit_button]:
		if is_instance_valid(button):
			_setup_button_animations(button)

	_animate_panel_pop_in()


func _input(event: InputEvent) -> void:
	# GameManager globally treats ui_cancel/Escape as gameplay pause.
	# Consume it here so Escape never pauses/freezes the main menu.
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(settings_menu) and settings_menu.visible:
			if settings_menu.has_method("close"):
				settings_menu.call("close")
		get_viewport().set_input_as_handled()


func _connect_button(button: Button, callback: Callable) -> void:
	if not is_instance_valid(button):
		push_warning("[GAME MENU] A menu button could not be found for callback: " + str(callback))
		return
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _animate_panel_pop_in() -> void:
	if not is_instance_valid(panel_container):
		return

	await get_tree().process_frame
	if not is_instance_valid(panel_container):
		return

	panel_container.pivot_offset = panel_container.size / 2.0
	panel_container.scale = Vector2(0.8, 0.8)
	panel_container.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.35)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.25)


func _setup_button_animations(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	if not button.mouse_entered.is_connected(_on_button_mouse_entered.bind(button)):
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	if not button.mouse_exited.is_connected(_on_button_mouse_exited.bind(button)):
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))


func _on_button_mouse_entered(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size / 2.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)


func _on_button_mouse_exited(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)


func _on_play_pressed() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	_set_menu_buttons_disabled(true)
	print("[GAME MENU] Loading game world...")

	if is_instance_valid(SaveManager) and SaveManager.has_save():
		GameManager.should_load_save = true
		print("[GAME MENU] Save found. Loading saved progress.")
	else:
		GameManager.should_load_save = false
		print("[GAME MENU] No save found. Starting a new session.")

	if is_instance_valid(TransitionManager):
		await TransitionManager.fade_out(0.5)

	# SceneTree removes this GameMenu as part of the scene change. Do not
	# await get_tree().process_frame afterward: this node may already be detached.
	# Main.gd handles the fade-in after the gameplay level finishes loading.
	var tree: SceneTree = get_tree()
	var error: Error = tree.change_scene_to_file(MAIN_GAME_SCENE_PATH)
	if error != OK:
		push_error("[GAME MENU] Failed to open game scene. Error code: %s" % error)
		_changing_scene = false
		_set_menu_buttons_disabled(false)
		if is_instance_valid(TransitionManager):
			await TransitionManager.fade_in(0.3)
		return
	return


func _on_settings_pressed() -> void:
	if not is_instance_valid(settings_menu):
		if not ResourceLoader.exists("res://Scenes/UI/SettingsMenu.tscn"):
			push_error("[GAME MENU] Missing res://Scenes/UI/SettingsMenu.tscn. Copy the settings scene and script into the project.")
			return

		settings_menu = SETTINGS_MENU_SCENE.instantiate() as CanvasLayer
		if not is_instance_valid(settings_menu):
			push_error("[GAME MENU] Could not instantiate SettingsMenu.")
			return
		settings_menu.name = "SettingsMenu"
		add_child(settings_menu)

	if settings_menu.has_method("open"):
		settings_menu.call("open", false)
	else:
		settings_menu.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_logout_pressed() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	_set_menu_buttons_disabled(true)
	print("[GAME MENU] Logging out and returning to the authentication screen...")

	if is_instance_valid(GameManager) and GameManager.has_method("clear_session_data"):
		GameManager.clear_session_data()

	if is_instance_valid(TransitionManager):
		await TransitionManager.fade_out(0.3)

	# As with Play, the old GameMenu may be freed immediately after the
	# scene switch. Avoid awaiting a frame on this node after changing scenes.
	var tree: SceneTree = get_tree()
	var error: Error = tree.change_scene_to_file(AUTH_SCENE_PATH)
	if error != OK:
		push_error("[GAME MENU] Failed to open authentication screen. Error code: %s" % error)
		_changing_scene = false
		_set_menu_buttons_disabled(false)
		if is_instance_valid(TransitionManager):
			await TransitionManager.fade_in(0.3)
		return

	# AuthScreen does not perform a transition fade on entry, so ask the
	# persistent autoload to reveal it without awaiting the freed GameMenu.
	if is_instance_valid(TransitionManager):
		TransitionManager.fade_in(0.3)
	return


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_menu_buttons_disabled(disabled: bool) -> void:
	for button: Button in [play_button, settings_button, logout_button, quit_button]:
		if is_instance_valid(button):
			button.disabled = disabled


func _apply_saved_display_audio_settings() -> void:
	# Preferences are loaded from the logged-in account's save, not a shared file.
	if not is_instance_valid(SaveManager):
		return
	var settings: Dictionary = SaveManager.load_settings_data()
	if settings.is_empty():
		return

	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var volume_percent: float = clampf(float(settings.get("volume_percent", 100.0)), 0.0, 100.0)
		AudioServer.set_bus_volume_linear(master_bus, volume_percent / 100.0)

	var current_mode: int = DisplayServer.window_get_mode()
	var saved_mode: int = int(settings.get("window_mode", current_mode))
	if saved_mode in [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]:
		DisplayServer.window_set_mode(saved_mode)

	var vsync_enabled: bool = bool(settings.get("vsync", true))
	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
