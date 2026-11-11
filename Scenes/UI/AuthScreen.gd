extends Control

@onready var panel_container: Control = $CenterContainer/PanelContainer
@onready var header_title: Label = $CenterContainer/PanelContainer/MarginContainer/MainVBox/HeaderTitle
@onready var login_box: Control = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox
@onready var register_box: Control = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox
@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/MainVBox/StatusLabel

@onready var login_email: LineEdit = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginEmail
@onready var login_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginPasswordRow/LoginPassword
@onready var login_show_password: Button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginPasswordRow/LoginShowPassword
@onready var login_button: Button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginButton
@onready var switch_to_reg_btn: Button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/SwitchToRegister

@onready var reg_username: LineEdit = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegUsername
@onready var reg_email: LineEdit = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegEmail
@onready var reg_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegPasswordRow/RegPassword
@onready var reg_show_password: Button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegPasswordRow/RegShowPassword
@onready var register_button: Button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegisterButton
@onready var switch_to_login_btn: Button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/SwitchToLogin

# Registration continues into an authenticated session automatically.
# Existing-account logins still return to the Game Menu.
const NEW_ACCOUNT_GAME_SCENE: String = "res://Scenes/SceneManager/Main.tscn"
const EXISTING_ACCOUNT_MENU_SCENE: String = "res://Scenes/UI/GameMenu.tscn"
var _auto_login_from_registration: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	switch_to_reg_btn.pressed.connect(_show_register)
	switch_to_login_btn.pressed.connect(_show_login)
	login_show_password.pressed.connect(_toggle_password_visibility.bind(login_password, login_show_password))
	reg_show_password.pressed.connect(_toggle_password_visibility.bind(reg_password, reg_show_password))

	# Passwords start hidden on both forms.
	_set_password_hidden(login_password, login_show_password)
	_set_password_hidden(reg_password, reg_show_password)
	_style_password_toggle(login_show_password)
	_style_password_toggle(reg_show_password)

	_setup_button_animations(login_button)
	_setup_button_animations(register_button)

	# Email input is unrestricted: do not auto-complete domains or steal keyboard focus.
	# Enter moves through fields and submits the active form.
	login_email.text_submitted.connect(_on_login_email_submitted)
	login_password.text_submitted.connect(_on_login_password_submitted)
	reg_username.text_submitted.connect(_on_registration_username_submitted)
	reg_email.text_submitted.connect(_on_registration_email_submitted)
	reg_password.text_submitted.connect(_on_registration_password_submitted)

	SupabaseManager.login_completed.connect(_on_login_completed)
	SupabaseManager.registration_completed.connect(_on_registration_completed)

	_animate_panel_pop_in()
	login_email.call_deferred("grab_focus")


func _toggle_password_visibility(password_field: LineEdit, toggle_button: Button) -> void:
	password_field.secret = not password_field.secret
	toggle_button.text = "Show" if password_field.secret else "Hide"
	# Return the caret to the password so the player can continue typing immediately.
	password_field.grab_focus()
	password_field.caret_column = password_field.text.length()


func _set_password_hidden(password_field: LineEdit, toggle_button: Button) -> void:
	password_field.secret = true
	toggle_button.text = "Show"


func _style_password_toggle(button: Button) -> void:
	button.custom_minimum_size = Vector2(82, 48)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.91, 0.86, 0.71, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.42, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.42, 1.0))

	var normal := _make_toggle_style(Color(0.03, 0.04, 0.07, 0.7), Color(0.2, 0.25, 0.35, 0.8))
	var hover := _make_toggle_style(Color(0.08, 0.09, 0.12, 0.95), Color(0.85, 0.75, 0.45, 1.0))
	var pressed := _make_toggle_style(Color(0.12, 0.11, 0.08, 1.0), Color(0.85, 0.75, 0.45, 1.0))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func _make_toggle_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _on_login_email_submitted(_text: String) -> void:
	login_password.grab_focus()


func _on_login_password_submitted(_text: String) -> void:
	_on_login_pressed()


func _on_registration_username_submitted(_text: String) -> void:
	reg_email.grab_focus()


func _on_registration_email_submitted(_text: String) -> void:
	reg_password.grab_focus()


func _on_registration_password_submitted(_text: String) -> void:
	_on_register_pressed()


func _email_seems_valid(text_value: String) -> bool:
	var address: String = text_value.strip_edges()
	if address.contains(" ") or not address.contains("@"):
		return false
	var parts: PackedStringArray = address.split("@")
	return parts.size() == 2 and not parts[0].is_empty() and parts[1].contains(".") and not parts[1].begins_with(".") and not parts[1].ends_with(".")


func _animate_panel_pop_in() -> void:
	panel_container.pivot_offset = panel_container.size / 2.0
	panel_container.scale = Vector2(0.8, 0.8)
	panel_container.modulate.a = 0.0

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.25)


func _shake_panel() -> void:
	var orig_x: float = panel_container.position.x
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(4):
		var offset: int = 6 if i % 2 == 0 else -6
		tween.tween_property(panel_container, "position:x", orig_x + offset, 0.04)
	tween.tween_property(panel_container, "position:x", orig_x, 0.04)


func _setup_button_animations(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(func():
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.1)
	)
	button.mouse_exited.connect(func():
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _show_login() -> void:
	_set_password_hidden(login_password, login_show_password)
	_set_password_hidden(reg_password, reg_show_password)
	header_title.text = "LOGIN"
	_animate_box_switch(register_box, login_box)


func _show_register() -> void:
	_set_password_hidden(login_password, login_show_password)
	_set_password_hidden(reg_password, reg_show_password)
	header_title.text = "CREATE ACCOUNT"
	_animate_box_switch(login_box, register_box)


func _animate_box_switch(from_box: Control, to_box: Control) -> void:
	_clear_status()
	if not from_box.visible:
		return

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(from_box, "modulate:a", 0.0, 0.12)
	tween.tween_callback(from_box.hide)
	tween.tween_callback(to_box.show)

	to_box.modulate.a = 0.0
	tween.tween_property(to_box, "modulate:a", 1.0, 0.15)


func _clear_status() -> void:
	status_label.text = ""
	status_label.modulate = Color.WHITE


func _on_login_pressed() -> void:
	if login_button.disabled:
		return
	if login_email.text.strip_edges().is_empty() or login_password.text.is_empty():
		_set_status("Enter your email and password.", Color(1, 0.4, 0.35))
		_shake_panel()
		return
	if not _email_seems_valid(login_email.text):
		_set_status("Enter a valid email address.", Color(1, 0.4, 0.35))
		login_email.grab_focus()
		return

	_set_status("Signing in...", Color(0.9, 0.8, 0.4))
	login_button.disabled = true
	SupabaseManager.login_user(login_email.text, login_password.text)


func _on_register_pressed() -> void:
	if register_button.disabled:
		return
	if reg_username.text.strip_edges().is_empty() or reg_email.text.strip_edges().is_empty() or reg_password.text.is_empty():
		_set_status("Complete all three fields to create an account.", Color(1, 0.4, 0.35))
		_shake_panel()
		return
	if not _email_seems_valid(reg_email.text):
		_set_status("Enter a valid email address.", Color(1, 0.4, 0.35))
		reg_email.grab_focus()
		return
	if reg_password.text.length() < 6:
		_set_status("Password must contain at least 6 characters.", Color(1, 0.4, 0.35))
		reg_password.grab_focus()
		return

	_set_status("Creating your account...", Color(0.9, 0.8, 0.4))
	register_button.disabled = true
	SupabaseManager.register_user(reg_email.text, reg_password.text, reg_username.text)


func _set_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color


func _on_login_completed(success: bool, message: String) -> void:
	var new_account: bool = _auto_login_from_registration
	_auto_login_from_registration = false
	if success:
		# Both normal logins and newly registered accounts must finish
		# account-specific cloud/local save restoration before entering gameplay.
		if is_instance_valid(GameManager):
			await GameManager.initialize_session(login_email.text)
		if not is_inside_tree():
			return

		_set_status("Entering MABYASA...", Color(0.3, 0.9, 0.4))
		if is_instance_valid(TransitionManager):
			await TransitionManager.fade_out(0.5)
		if not is_inside_tree():
			return

		# New accounts go directly into the world (including the tutorial).
		# Returning players keep the original Game Menu flow.
		var destination: String = NEW_ACCOUNT_GAME_SCENE if new_account else EXISTING_ACCOUNT_MENU_SCENE
		var error: Error = get_tree().change_scene_to_file(destination)
		if error != OK:
			login_button.disabled = false
			register_button.disabled = false
			_set_status("Could not open the game. Please try again.", Color(1, 0.3, 0.3))
			push_error("[AUTH] Could not open scene: " + destination)
		# Main.gd fades in once the level is fully loaded. Do not reveal
		# an empty world while its async loading is still in progress.
		if is_instance_valid(TransitionManager) and (error != OK or not new_account):
			TransitionManager.fade_in(0.5)
	else:
		login_button.disabled = false
		register_button.disabled = false
		if new_account:
			# Sign-up succeeded, but Supabase did not authenticate the account.
			# This commonly occurs when email confirmation is required. Never
			# enter the game without a verified authenticated session.
			var normalized_message: String = message.to_lower()
			_show_login()
			if "confirm" in normalized_message or "verif" in normalized_message:
				_set_status("Account created. Confirm your email, then sign in.", Color(0.9, 0.8, 0.4))
			else:
				_set_status("Account created, but auto sign-in failed: " + message, Color(1, 0.65, 0.4))
		else:
			_set_status(message, Color(1, 0.3, 0.3))
			_shake_panel()


func _on_registration_completed(success: bool, message: String) -> void:
	if success:
		# Immediately log in with the credentials just used for registration.
		# Supabase may require email confirmation; that outcome is handled
		# in _on_login_completed rather than bypassing authentication.
		var registered_email: String = reg_email.text.strip_edges()
		var registered_password: String = reg_password.text
		login_email.text = registered_email
		login_password.clear()
		reg_password.clear()
		_set_password_hidden(reg_password, reg_show_password)
		_auto_login_from_registration = true
		register_button.disabled = true
		_set_status("Account created. Signing you in...", Color(0.9, 0.8, 0.4))
		SupabaseManager.login_user(registered_email, registered_password)
	else:
		register_button.disabled = false
		_set_status(message, Color(1, 0.3, 0.3))
		_shake_panel()
