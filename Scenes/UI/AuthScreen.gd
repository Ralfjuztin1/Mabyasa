extends Control

# --- Main UI Nodes ---
@onready var panel_container = $CenterContainer/PanelContainer
@onready var header_title = $CenterContainer/PanelContainer/MarginContainer/MainVBox/HeaderTitle
@onready var login_box = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox
@onready var register_box = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox
@onready var status_label = $CenterContainer/PanelContainer/MarginContainer/MainVBox/StatusLabel

# --- Login Nodes ---
@onready var login_email = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginEmail
@onready var login_password = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginPassword
@onready var login_button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/LoginButton
@onready var switch_to_reg_btn = $CenterContainer/PanelContainer/MarginContainer/MainVBox/LoginBox/SwitchToRegister

# --- Register Nodes ---
@onready var reg_username = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegUsername
@onready var reg_email = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegEmail
@onready var reg_password = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegPassword
@onready var register_button = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/RegisterButton
@onready var switch_to_login_btn = $CenterContainer/PanelContainer/MarginContainer/MainVBox/RegisterBox/SwitchToLogin

func _ready():
	# Connect Button Presses
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	switch_to_reg_btn.pressed.connect(_show_register)
	switch_to_login_btn.pressed.connect(_show_login)
	
	# Connect Button Animations (Hover & Click scale)
	_setup_button_animations(login_button)
	_setup_button_animations(register_button)
	
	# Connect Supabase Signals
	SupabaseManager.login_completed.connect(_on_login_completed)
	SupabaseManager.registration_completed.connect(_on_registration_completed)
	
	# Play initial panel pop-in animation
	_animate_panel_pop_in()

# --- Animated Transitions ---
func _animate_panel_pop_in():
	panel_container.pivot_offset = panel_container.size / 2.0
	panel_container.scale = Vector2(0.8, 0.8)
	panel_container.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.25)

func _shake_panel():
	var orig_x = panel_container.position.x
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(4):
		var offset = 6 if i % 2 == 0 else -6
		tween.tween_property(panel_container, "position:x", orig_x + offset, 0.04)
	tween.tween_property(panel_container, "position:x", orig_x, 0.04)

func _setup_button_animations(button: Button):
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(func():
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.1)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	)

func _show_login():
	header_title.text = "❖ TAVERN LOGIN ❖"
	_animate_box_switch(register_box, login_box)

func _show_register():
	header_title.text = "❖ NEW ADVENTURER ❖"
	_animate_box_switch(login_box, register_box)

func _animate_box_switch(from_box: Control, to_box: Control):
	_clear_status()
	if not from_box.visible:
		return
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(from_box, "modulate:a", 0.0, 0.12)
	tween.tween_callback(from_box.hide)
	tween.tween_callback(to_box.show)
	
	to_box.modulate.a = 0.0
	tween.tween_property(to_box, "modulate:a", 1.0, 0.15)

func _clear_status():
	status_label.text = ""
	status_label.modulate = Color.WHITE

# --- Button Actions & Auth ---
func _on_login_pressed():
	if login_email.text.strip_edges() == "" or login_password.text.strip_edges() == "":
		_set_status("Please enter email & password.", Color(1, 0.3, 0.3))
		_shake_panel()
		return
		
	_set_status("Authenticating...", Color(0.9, 0.8, 0.4))
	login_button.disabled = true
	SupabaseManager.login_user(login_email.text, login_password.text)

func _on_register_pressed():
	if reg_username.text.strip_edges() == "" or reg_email.text.strip_edges() == "" or reg_password.text.strip_edges() == "":
		_set_status("Please fill in all scroll fields.", Color(1, 0.3, 0.3))
		_shake_panel()
		return
		
	_set_status("Signing scroll...", Color(0.9, 0.8, 0.4))
	register_button.disabled = true
	SupabaseManager.register_user(reg_email.text, reg_password.text, reg_username.text)

# --- Supabase Responses ---
func _set_status(message: String, color: Color):
	status_label.text = message
	status_label.modulate = color

func _on_login_completed(success: bool, message: String):
	login_button.disabled = false
	if success:
		_set_status("Welcome, Adventurer!", Color(0.3, 0.9, 0.4))
		# Add this line to load the new menu!
		get_tree().change_scene_to_file("res://Scenes/UI/GameMenu.tscn")
	else:
		_set_status(message, Color(1, 0.3, 0.3))
		_shake_panel()

func _on_registration_completed(success: bool, message: String):
	register_button.disabled = false
	if success:
		_set_status(message + "\nYou may now log in.", Color(0.3, 0.9, 0.4))
		reg_username.text = ""
		reg_email.text = ""
		reg_password.text = ""
	else:
		_set_status(message, Color(1, 0.3, 0.3))
		_shake_panel()
