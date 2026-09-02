extends CanvasLayer

@onready var welcome_box = $WelcomeBox
@onready var start_button = $WelcomeBox/PanelContainer/VBoxContainer/StartButton
@onready var sidebar_box = $SidebarBox
@onready var task_title = $SidebarBox/MarginContainer/VBoxContainer/TaskTitle
@onready var task_desc = $SidebarBox/MarginContainer/VBoxContainer/TaskDesc
@onready var progress_bar = $SidebarBox/MarginContainer/VBoxContainer/ProgressBar

var text_database = {
	"movement": {
		"title": "1. Basic Mobility",
		"desc": "Calibrating systems... Walk 25 meters using WASD keys.",
		"show_bar": true
	},
	"camera": {
		"title": "2. Environment Scan",
		"desc": "Mouse locked. Move your mouse horizontally to look around and pan the frame.",
		"show_bar": true
	},
	"sprint": {
		"title": "3. Sprint Burst",
		"desc": "While walking in any direction, press and hold [SHIFT] to test sprinting speed.",
		"show_bar": false
	},
	"alt_mouse": {
		"title": "4. Cursor Toggle",
		"desc": "Press and hold [ALT] to free your mouse cursor while keeping movement active.",
		"show_bar": false
	},
	"finished": {
		"title": "System Ready",
		"desc": "Calibration sequence complete. Welcome to Mabiyasa!",
		"show_bar": false
	}
}

func _ready() -> void:
	welcome_box.visible = false
	sidebar_box.visible = false
	progress_bar.visible = false
	
	if TutorialManager.current_active_step == "finished":
		return
		
	start_button.pressed.connect(_on_start_pressed)
	TutorialManager.step_changed.connect(_on_step_changed)
	TutorialManager.progress_updated.connect(_on_progress_bar_updated)
	TutorialManager.tutorial_step_completed.connect(_on_step_completed)

func show_welcome() -> void:
	if TutorialManager.current_active_step == "finished":
		return
	welcome_box.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start_pressed() -> void:
	welcome_box.visible = false
	sidebar_box.visible = true
	TutorialManager.start_tutorial() 

func _on_step_changed(step_name: String) -> void:
	if step_name == "finished":
		sidebar_box.visible = false
		return

	if text_database.has(step_name):
		var data = text_database[step_name]
		task_title.text = data["title"]
		# Reset text color back to default theme gold
		task_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		task_desc.text = data["desc"]
		
		progress_bar.visible = data["show_bar"]
		progress_bar.value = 0

# Visual feedback handler when a step finishes
func _on_step_completed(_step_name: String) -> void:
	task_title.text += " [✔]"
	task_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4)) # Flash success green
	progress_bar.visible = false

func _on_progress_bar_updated(current: float, target: float) -> void:
	progress_bar.max_value = target
	progress_bar.value = current
