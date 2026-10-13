extends CanvasLayer

signal tutorial_finished

const COLOR_GOLD := Color(0.91, 0.75, 0.38, 1.0)
const COLOR_CREAM := Color(0.97, 0.95, 0.89, 1.0)
const COLOR_SUCCESS := Color(0.72, 0.88, 0.64, 1.0)

@onready var welcome_box: Control = $WelcomeBox
@onready var welcome_panel: PanelContainer = $WelcomeBox/PanelContainer
@onready var start_button: Button = $WelcomeBox/PanelContainer/VBoxContainer/StartButton

@onready var sidebar_box: PanelContainer = $SidebarBox
@onready var task_title: Label = $SidebarBox/MarginContainer/VBoxContainer/TaskTitle
@onready var task_desc: Label = $SidebarBox/MarginContainer/VBoxContainer/TaskDesc
@onready var progress_bar: ProgressBar = $SidebarBox/MarginContainer/VBoxContainer/ProgressBar

@onready var completion_box: Control = $CompletionBox
@onready var completion_panel: PanelContainer = $CompletionBox/PanelContainer
@onready var completion_button: Button = $CompletionBox/PanelContainer/VBoxContainer/ContinueButton

var text_database: Dictionary = {
	"movement": {
		"title": "1. Basic Mobility",
		"desc": "Walk using the WASD keys.",
		"show_bar": true
	},
	"camera": {
		"title": "2. Environment Scan",
		"desc": "Move your mouse to look around.",
		"show_bar": true
	},
	"sprint": {
		"title": "3. Sprint Burst",
		"desc": "Move in any direction while holding SHIFT to sprint.",
		"show_bar": false
	},
	"alt_mouse": {
		"title": "4. Cursor Toggle",
		"desc": "Hold ALT to free your mouse cursor.",
		"show_bar": false
	},
	"finished": {
		"title": "ALL SET!",
		"desc": "Tutorial complete. Welcome to MABIYASA!",
		"show_bar": false
	}
}

var progress_tween: Tween
var sidebar_tween: Tween
var welcome_tween: Tween
var completion_tween: Tween
var step_text_tween: Tween
var sidebar_flash_tween: Tween
var settle_flash_tween: Tween
var button_tweens: Dictionary = {}

var _step_change_version: int = 0
var _finishing_tutorial: bool = false


func _ready() -> void:
	add_to_group("tutorial_ui")

	welcome_box.visible = false
	sidebar_box.visible = false
	completion_box.visible = false
	progress_bar.visible = false

	welcome_box.modulate.a = 0.0
	welcome_panel.scale = Vector2(0.96, 0.96)
	sidebar_box.modulate.a = 0.0
	sidebar_box.scale = Vector2(0.98, 0.98)
	completion_box.modulate.a = 0.0
	completion_panel.scale = Vector2(0.96, 0.96)

	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not completion_button.pressed.is_connected(_on_completion_continue_pressed):
		completion_button.pressed.connect(_on_completion_continue_pressed)

	if not start_button.mouse_entered.is_connected(_on_start_button_mouse_entered):
		start_button.mouse_entered.connect(_on_start_button_mouse_entered)
	if not start_button.mouse_exited.is_connected(_on_start_button_mouse_exited):
		start_button.mouse_exited.connect(_on_start_button_mouse_exited)
	if not completion_button.mouse_entered.is_connected(_on_completion_button_mouse_entered):
		completion_button.mouse_entered.connect(_on_completion_button_mouse_entered)
	if not completion_button.mouse_exited.is_connected(_on_completion_button_mouse_exited):
		completion_button.mouse_exited.connect(_on_completion_button_mouse_exited)

	if not TutorialManager.step_changed.is_connected(_on_step_changed):
		TutorialManager.step_changed.connect(_on_step_changed)
	if not TutorialManager.progress_updated.is_connected(_on_progress_bar_updated):
		TutorialManager.progress_updated.connect(_on_progress_bar_updated)
	if not TutorialManager.tutorial_step_completed.is_connected(_on_step_completed):
		TutorialManager.tutorial_step_completed.connect(_on_step_completed)

	if TutorialManager.current_active_step == "intro":
		show_welcome()


func _exit_tree() -> void:
	# Disconnect autoload signals so a replaced scene cannot leave stale callbacks.
	if is_instance_valid(TutorialManager):
		if TutorialManager.step_changed.is_connected(_on_step_changed):
			TutorialManager.step_changed.disconnect(_on_step_changed)
		if TutorialManager.progress_updated.is_connected(_on_progress_bar_updated):
			TutorialManager.progress_updated.disconnect(_on_progress_bar_updated)
		if TutorialManager.tutorial_step_completed.is_connected(_on_step_completed):
			TutorialManager.tutorial_step_completed.disconnect(_on_step_completed)

	_kill_tween(progress_tween)
	_kill_tween(sidebar_tween)
	_kill_tween(welcome_tween)
	_kill_tween(completion_tween)
	_kill_tween(step_text_tween)
	_kill_tween(sidebar_flash_tween)
	_kill_tween(settle_flash_tween)
	for tween_variant in button_tweens.values():
		if tween_variant is Tween:
			_kill_tween(tween_variant)
	button_tweens.clear()


func show_welcome() -> void:
	if TutorialManager.current_active_step == "finished":
		return

	welcome_box.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_kill_tween(welcome_tween)

	welcome_box.modulate.a = 0.0
	welcome_panel.scale = Vector2(0.96, 0.96)
	welcome_tween = create_tween()
	welcome_tween.set_parallel(true)
	welcome_tween.tween_property(welcome_box, "modulate:a", 1.0, 0.24)
	welcome_tween.tween_property(welcome_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	_animate_button_scale(start_button, Vector2(0.97, 0.97), 0.06, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await _hide_welcome()
	if not is_inside_tree():
		return

	sidebar_box.visible = true
	_show_sidebar()
	TutorialManager.start_tutorial()


func _hide_welcome() -> void:
	_kill_tween(welcome_tween)
	welcome_tween = create_tween()
	welcome_tween.set_parallel(true)
	welcome_tween.tween_property(welcome_box, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	welcome_tween.tween_property(welcome_panel, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await welcome_tween.finished
	if is_inside_tree():
		welcome_box.visible = false


func _show_sidebar() -> void:
	_kill_tween(sidebar_tween)
	_kill_tween(sidebar_flash_tween)
	_kill_tween(settle_flash_tween)

	sidebar_box.modulate = Color.WHITE
	sidebar_box.modulate.a = 0.0
	sidebar_box.scale = Vector2(0.98, 0.98)
	sidebar_tween = create_tween()
	sidebar_tween.set_parallel(true)
	sidebar_tween.tween_property(sidebar_box, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sidebar_tween.tween_property(sidebar_box, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_sidebar() -> void:
	_kill_tween(sidebar_tween)
	_kill_tween(sidebar_flash_tween)
	_kill_tween(settle_flash_tween)
	sidebar_tween = create_tween()
	sidebar_tween.set_parallel(true)
	sidebar_tween.tween_property(sidebar_box, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sidebar_tween.tween_property(sidebar_box, "scale", Vector2(0.98, 0.98), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sidebar_tween.finished
	if is_inside_tree():
		sidebar_box.visible = false


func _on_step_changed(step_name: String) -> void:
	_step_change_version += 1
	var this_version := _step_change_version

	if step_name == "finished":
		_handle_tutorial_finished()
		return
	if not text_database.has(step_name):
		return

	var data: Dictionary = text_database[step_name]
	if not sidebar_box.visible:
		sidebar_box.visible = true
		_show_sidebar()

	_kill_tween(step_text_tween)
	step_text_tween = create_tween()
	step_text_tween.set_parallel(true)
	step_text_tween.tween_property(task_title, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	step_text_tween.tween_property(task_desc, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await step_text_tween.finished

	# A newer tutorial step may have arrived while the fade was running.
	if not is_inside_tree() or this_version != _step_change_version:
		return

	task_title.text = str(data.get("title", "Tutorial"))
	task_desc.text = str(data.get("desc", ""))
	task_title.add_theme_color_override("font_color", COLOR_GOLD)
	_kill_tween(progress_tween)
	progress_bar.value = 0.0
	progress_bar.visible = bool(data.get("show_bar", false))

	step_text_tween = create_tween()
	step_text_tween.set_parallel(true)
	step_text_tween.tween_property(task_title, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	step_text_tween.tween_property(task_desc, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_step_completed(_step_name: String) -> void:
	progress_bar.visible = false
	task_title.add_theme_color_override("font_color", COLOR_SUCCESS)
	if not task_title.text.ends_with("  ✔"):
		task_title.text += "  ✔"
	_play_completion_flash()


func _play_completion_flash() -> void:
	_kill_tween(sidebar_flash_tween)
	_kill_tween(settle_flash_tween)
	sidebar_box.self_modulate = Color.WHITE
	sidebar_flash_tween = create_tween()
	sidebar_flash_tween.set_parallel(true)
	sidebar_flash_tween.tween_property(sidebar_box, "self_modulate", Color(0.78, 0.91, 0.69, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sidebar_flash_tween.tween_property(sidebar_box, "scale", Vector2(1.025, 1.025), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await sidebar_flash_tween.finished
	if not is_inside_tree():
		return

	settle_flash_tween = create_tween()
	settle_flash_tween.set_parallel(true)
	settle_flash_tween.tween_property(sidebar_box, "self_modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	settle_flash_tween.tween_property(sidebar_box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


func _on_progress_bar_updated(current: float, target: float) -> void:
	progress_bar.max_value = maxf(target, 1.0)
	_kill_tween(progress_tween)
	progress_tween = create_tween()
	progress_tween.tween_property(progress_bar, "value", clampf(current, 0.0, progress_bar.max_value), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _handle_tutorial_finished() -> void:
	if _finishing_tutorial:
		return
	_finishing_tutorial = true
	await _hide_sidebar()
	if not is_inside_tree():
		return
	_show_completion_popup()


func _show_completion_popup() -> void:
	_kill_tween(completion_tween)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	completion_box.visible = true
	completion_box.modulate.a = 0.0
	completion_panel.scale = Vector2(0.96, 0.96)

	completion_tween = create_tween()
	completion_tween.set_parallel(true)
	completion_tween.tween_property(completion_box, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	completion_tween.tween_property(completion_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_completion_continue_pressed() -> void:
	_animate_button_scale(completion_button, Vector2(0.97, 0.97), 0.06, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_kill_tween(completion_tween)
	completion_tween = create_tween()
	completion_tween.set_parallel(true)
	completion_tween.tween_property(completion_box, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	completion_tween.tween_property(completion_panel, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await completion_tween.finished
	if not is_inside_tree():
		return

	completion_box.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	tutorial_finished.emit()


func _on_start_button_mouse_entered() -> void:
	_animate_button_scale(start_button, Vector2(1.025, 1.025), 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_start_button_mouse_exited() -> void:
	_animate_button_scale(start_button, Vector2.ONE, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_completion_button_mouse_entered() -> void:
	_animate_button_scale(completion_button, Vector2(1.025, 1.025), 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_completion_button_mouse_exited() -> void:
	_animate_button_scale(completion_button, Vector2.ONE, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _animate_button_scale(button: Control, target_scale: Vector2, duration: float, transition: Tween.TransitionType, ease: Tween.EaseType) -> void:
	if not is_instance_valid(button):
		return
	if button_tweens.has(button):
		var old_tween: Tween = button_tweens[button]
		_kill_tween(old_tween)

	var tween := create_tween()
	button_tweens[button] = tween
	tween.tween_property(button, "scale", target_scale, duration).set_trans(transition).set_ease(ease)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
