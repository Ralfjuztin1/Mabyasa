extends CanvasLayer

@onready var welcome_box: Control = $WelcomeBox
@onready var welcome_dimmer: ColorRect = $WelcomeBox/Dimmer
@onready var welcome_panel: PanelContainer = $WelcomeBox/PanelContainer
@onready var start_button: Button = $WelcomeBox/PanelContainer/VBoxContainer/StartButton

@onready var sidebar_box: PanelContainer = $SidebarBox
@onready var task_title: Label = $SidebarBox/MarginContainer/VBoxContainer/TaskTitle
@onready var task_desc: Label = $SidebarBox/MarginContainer/VBoxContainer/TaskDesc
@onready var progress_bar: ProgressBar = $SidebarBox/MarginContainer/VBoxContainer/ProgressBar

@onready var completion_box: Control = $CompletionBox
@onready var completion_dimmer: ColorRect = $CompletionBox/Dimmer
@onready var completion_panel: PanelContainer = $CompletionBox/PanelContainer
@onready var completion_button: Button = $CompletionBox/PanelContainer/VBoxContainer/ContinueButton


var text_database: Dictionary = {
	"movement": {
		"title": "1. Basic Mobility",
		"desc": " Try to walk using WASD keys on your keyboard.",
		"show_bar": true
	},
	"camera": {
		"title": "2. Environment Scan",
		"desc": "Move your mouse to look around.",
		"show_bar": true
	},
	"sprint": {
		"title": "3. Sprint Burst",
		"desc": "While walking in any direction, press and hold [SHIFT] to do a sprint.",
		"show_bar": false
	},
	"alt_mouse": {
		"title": "4. Cursor Toggle",
		"desc": "Press and hold [ALT] to free your mouse cursor.",
		"show_bar": false
	},
	"finished": {
		"title": "ALL SET!",
		"desc": "Complete. Welcome to MABYASA!",
		"show_bar": false
	}
}


var progress_tween: Tween
var sidebar_tween: Tween
var welcome_tween: Tween
var completion_tween: Tween
var button_tween: Tween


func _ready() -> void:
	# Initial visibility
	welcome_box.visible = false
	sidebar_box.visible = false
	completion_box.visible = false
	progress_bar.visible = false

	# Initial animation states
	welcome_box.modulate.a = 0.0
	welcome_panel.scale = Vector2(0.92, 0.92)

	sidebar_box.modulate.a = 0.0
	sidebar_box.scale = Vector2(0.96, 0.96)

	completion_box.modulate.a = 0.0
	completion_panel.scale = Vector2(0.9, 0.9)

	# Connect UI buttons
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

	if not completion_button.pressed.is_connected(_on_completion_continue_pressed):
		completion_button.pressed.connect(_on_completion_continue_pressed)

	# Button hover animations
	if not start_button.mouse_entered.is_connected(_on_start_button_mouse_entered):
		start_button.mouse_entered.connect(_on_start_button_mouse_entered)

	if not start_button.mouse_exited.is_connected(_on_start_button_mouse_exited):
		start_button.mouse_exited.connect(_on_start_button_mouse_exited)

	if not completion_button.mouse_entered.is_connected(_on_completion_button_mouse_entered):
		completion_button.mouse_entered.connect(_on_completion_button_mouse_entered)

	if not completion_button.mouse_exited.is_connected(_on_completion_button_mouse_exited):
		completion_button.mouse_exited.connect(_on_completion_button_mouse_exited)

	# Tutorial manager signals
	TutorialManager.step_changed.connect(_on_step_changed)
	TutorialManager.progress_updated.connect(_on_progress_bar_updated)
	TutorialManager.tutorial_step_completed.connect(_on_step_completed)

	# Brand new tutorial
	if TutorialManager.current_active_step == "intro":
		show_welcome()


func show_welcome() -> void:
	if TutorialManager.current_active_step == "finished":
		return

	welcome_box.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if welcome_tween and welcome_tween.is_valid():
		welcome_tween.kill()

	welcome_box.modulate.a = 0.0
	welcome_panel.scale = Vector2(0.92, 0.92)

	welcome_tween = create_tween()
	welcome_tween.set_parallel(true)

	welcome_tween.tween_property(
		welcome_box,
		"modulate:a",
		1.0,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	welcome_tween.tween_property(
		welcome_panel,
		"scale",
		Vector2.ONE,
		0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	_play_button_press(start_button)

	_hide_welcome()

	# Give the UI animation a tiny moment before starting the tutorial.
	await get_tree().create_timer(0.12).timeout

	sidebar_box.visible = true
	_show_sidebar()

	TutorialManager.start_tutorial()


func _hide_welcome() -> void:
	if welcome_tween and welcome_tween.is_valid():
		welcome_tween.kill()

	welcome_tween = create_tween()
	welcome_tween.set_parallel(true)

	welcome_tween.tween_property(
		welcome_box,
		"modulate:a",
		0.0,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	welcome_tween.tween_property(
		welcome_panel,
		"scale",
		Vector2(0.95, 0.95),
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await welcome_tween.finished

	welcome_box.visible = false


func _show_sidebar() -> void:
	if sidebar_tween and sidebar_tween.is_valid():
		sidebar_tween.kill()

	sidebar_box.modulate.a = 0.0
	sidebar_box.scale = Vector2(0.96, 0.96)

	sidebar_tween = create_tween()
	sidebar_tween.set_parallel(true)

	sidebar_tween.tween_property(
		sidebar_box,
		"modulate:a",
		1.0,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	sidebar_tween.tween_property(
		sidebar_box,
		"scale",
		Vector2.ONE,
		0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_sidebar() -> void:
	if sidebar_tween and sidebar_tween.is_valid():
		sidebar_tween.kill()

	sidebar_tween = create_tween()
	sidebar_tween.set_parallel(true)

	sidebar_tween.tween_property(
		sidebar_box,
		"modulate:a",
		0.0,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	sidebar_tween.tween_property(
		sidebar_box,
		"scale",
		Vector2(0.96, 0.96),
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await sidebar_tween.finished

	sidebar_box.visible = false


func _on_step_changed(step_name: String) -> void:
	if step_name == "finished":
		_handle_tutorial_finished()
		return

	if not text_database.has(step_name):
		return

	var data: Dictionary = text_database[step_name]

	# Make sure sidebar is visible.
	if not sidebar_box.visible:
		sidebar_box.visible = true
		_show_sidebar()

	# Smooth text transition.
	var text_tween := create_tween()

	text_tween.tween_property(
		task_title,
		"modulate:a",
		0.0,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	text_tween.parallel().tween_property(
		task_desc,
		"modulate:a",
		0.0,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await text_tween.finished

	# Update text while hidden.
	task_title.text = data["title"]
	task_desc.text = data["desc"]

	# Reset title to normal tutorial color.
	task_title.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.3)
	)

	# Reset progress.
	if progress_tween and progress_tween.is_valid():
		progress_tween.kill()

	progress_bar.value = 0
	progress_bar.visible = data["show_bar"]

	# Fade text back in.
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)

	fade_tween.tween_property(
		task_title,
		"modulate:a",
		1.0,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	fade_tween.tween_property(
		task_desc,
		"modulate:a",
		1.0,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_step_completed(_step_name: String) -> void:
	# Hide progress bar once this objective is complete.
	progress_bar.visible = false

	# Green success color.
	task_title.add_theme_color_override(
		"font_color",
		Color(0.35, 1.0, 0.45)
	)

	# Add completion mark.
	if not task_title.text.ends_with("  ✔"):
		task_title.text += "  ✔"

	_play_completion_flash()


func _play_completion_flash() -> void:
	if sidebar_tween and sidebar_tween.is_valid():
		sidebar_tween.kill()

	# Start from normal state.
	sidebar_box.modulate = Color.WHITE
	sidebar_box.scale = Vector2.ONE

	# Quick bright pulse.
	var glow_tween := create_tween()
	glow_tween.set_parallel(true)

	glow_tween.tween_property(
		sidebar_box,
		"self_modulate",
		Color(0.7, 1.0, 0.75, 1.0),
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	glow_tween.tween_property(
		sidebar_box,
		"scale",
		Vector2(1.04, 1.04),
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await glow_tween.finished

	var settle_tween := create_tween()
	settle_tween.set_parallel(true)

	settle_tween.tween_property(
		sidebar_box,
		"self_modulate",
		Color.WHITE,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	settle_tween.tween_property(
		sidebar_box,
		"scale",
		Vector2.ONE,
		0.3
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


func _on_progress_bar_updated(current: float, target: float) -> void:
	progress_bar.max_value = target

	if progress_tween and progress_tween.is_valid():
		progress_tween.kill()

	progress_tween = create_tween()

	progress_tween.tween_property(
		progress_bar,
		"value",
		current,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _handle_tutorial_finished() -> void:
	# Hide the tutorial task panel.
	_hide_sidebar()

	# Show completion window.
	_show_completion_popup()


func _show_completion_popup() -> void:
	if completion_tween and completion_tween.is_valid():
		completion_tween.kill()

	# Make sure the mouse is free while the completion popup is shown.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	completion_box.visible = true
	completion_box.modulate.a = 0.0
	completion_panel.scale = Vector2(0.9, 0.9)

	completion_tween = create_tween()
	completion_tween.set_parallel(true)

	completion_tween.tween_property(
		completion_box,
		"modulate:a",
		1.0,
		0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	completion_tween.tween_property(
		completion_panel,
		"scale",
		Vector2.ONE,
		0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_completion_continue_pressed() -> void:
	_play_button_press(completion_button)

	if completion_tween and completion_tween.is_valid():
		completion_tween.kill()

	completion_tween = create_tween()
	completion_tween.set_parallel(true)

	completion_tween.tween_property(
		completion_box,
		"modulate:a",
		0.0,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	completion_tween.tween_property(
		completion_panel,
		"scale",
		Vector2(0.95, 0.95),
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await completion_tween.finished

	completion_box.visible = false

	# Lock the mouse only after the popup is completely closed.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_start_button_mouse_entered() -> void:
	_animate_button_hover(start_button, true)


func _on_start_button_mouse_exited() -> void:
	_animate_button_hover(start_button, false)


func _on_completion_button_mouse_entered() -> void:
	_animate_button_hover(completion_button, true)


func _on_completion_button_mouse_exited() -> void:
	_animate_button_hover(completion_button, false)


func _animate_button_hover(button: Button, hovered: bool) -> void:
	if button_tween and button_tween.is_valid():
		button_tween.kill()

	button_tween = create_tween()

	var target_scale := Vector2(1.04, 1.04) if hovered else Vector2.ONE

	button_tween.tween_property(
		button,
		"scale",
		target_scale,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_button_press(button: Button) -> void:
	if button_tween and button_tween.is_valid():
		button_tween.kill()

	button_tween = create_tween()

	button_tween.tween_property(
		button,
		"scale",
		Vector2(0.96, 0.96),
		0.06
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	button_tween.tween_property(
		button,
		"scale",
		Vector2.ONE,
		0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
