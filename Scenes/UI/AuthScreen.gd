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

	login_email.text_changed.connect(_on_email_text_changed.bind(login_email, login_password))
	reg_email.text_changed.connect(_on_email_text_changed.bind(reg_email, reg_password))

	SupabaseManager.login_completed.connect(_on_login_completed)
	SupabaseManager.registration_completed.connect(_on_registration_completed)

	_animate_panel_pop_in()


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


func _on_email_text_changed(new_text: String, line_edit: LineEdit, password_node: LineEdit) -> void:
	if new_text.ends_with("@") and not "gmail.com" in new_text:
		line_edit.text = new_text + "gmail.com"
		line_edit.caret_column = new_text.length()
		password_node.grab_focus()


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
	header_title.text = "❖ TAVERN LOGIN ❖"
	_animate_box_switch(register_box, login_box)


func _show_register() -> void:
	_set_password_hidden(login_password, login_show_password)
	_set_password_hidden(reg_password, reg_show_password)
	header_title.text = "❖ NEW ADVENTURER ❖"
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
	if login_email.text.strip_edges() == "" or login_password.text.strip_edges() == "":
		_set_status("Please enter email & password.", Color(1, 0.3, 0.3))
		_shake_panel()
		return

	_set_status("Authenticating...", Color(0.9, 0.8, 0.4))
	login_button.disabled = true
	SupabaseManager.login_user(login_email.text, login_password.text)


func _on_register_pressed() -> void:
	if reg_username.text.strip_edges() == "" or reg_email.text.strip_edges() == "" or reg_password.text.strip_edges() == "":
		_set_status("Please fill in all scroll fields.", Color(1, 0.3, 0.3))
		_shake_panel()
		return

	_set_status("Signing scroll...", Color(0.9, 0.8, 0.4))
	register_button.disabled = true
	SupabaseManager.register_user(reg_email.text, reg_password.text, reg_username.text)


func _set_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color


func _on_login_completed(success: bool, message: String) -> void:
	if success:
		# Initialize session data immediately upon successful login.
		if GameManager:
			await GameManager.initialize_session(login_email.text)

		_set_status("Welcome, Adventurer!", Color(0.3, 0.9, 0.4))
		await TransitionManager.fade_out(0.5)
		get_tree().change_scene_to_file("res://Scenes/UI/GameMenu.tscn")
		TransitionManager.fade_in(0.5)
	else:
		login_button.disabled = false
		_set_status(message, Color(1, 0.3, 0.3))
		_shake_panel()


func _on_registration_completed(success: bool, message: String) -> void:
	register_button.disabled = false
	if success:
		_set_status(message + "\nYou may now log in.", Color(0.3, 0.9, 0.4))
		reg_username.text = ""
		reg_email.text = ""
		reg_password.text = ""
		_set_password_hidden(reg_password, reg_show_password)
	else:
		_set_status(message, Color(1, 0.3, 0.3))
		_shake_panel()
