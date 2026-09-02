extends Node

signal tutorial_step_completed(step_name: String)
signal step_changed(step_name: String)
signal progress_updated(current: float, target: float)
signal tutorial_visibility_changed(is_visible: bool)

var progress : Dictionary = {
	"movement": false,
	"camera": false,
	"sprint": false,
	"alt_mouse": false
}

var current_active_step: String = "intro"

var movement_allowed: bool = false
var camera_allowed: bool = false
var sprint_allowed: bool = false

var walk_distance: float = 0.0
const TARGET_WALK_DISTANCE: float = 25.0 

var camera_turned_amount: float = 0.0
const TARGET_CAMERA_TURN: float = 250.0

func _ready() -> void:
	update_permissions()
	load_tutorial_from_save()

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		reset_tutorial()
		get_tree().reload_current_scene()
		return

	if event is InputEventKey and event.keycode == KEY_ALT:
		if current_active_step == "alt_mouse":
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				complete_step("alt_mouse")
				current_active_step = "finished"
				
				# --- FINALIZE AND SAVE TO UNIFIED JSON ---
				save_tutorial_to_json()
				
				tutorial_step_completed.emit("alt_mouse")
				await get_tree().create_timer(1.0).timeout
				step_changed.emit("finished")
		elif current_active_step == "finished":
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func is_completed(step_name: String) -> bool:
	return progress.get(step_name, false)

func start_step(step_name: String) -> void:
	if is_completed(step_name):
		return
	current_active_step = step_name
	update_permissions()
	step_changed.emit(step_name)

func start_tutorial() -> void:
	start_step("movement")

func complete_step(step_name: String) -> void:
	if progress.has(step_name) and not progress[step_name]:
		progress[step_name] = true
		tutorial_step_completed.emit(step_name)

func update_permissions() -> void:
	var is_tutorial_active = not (current_active_step in ["intro", "", "finished"])
	tutorial_visibility_changed.emit(is_tutorial_active)
	
	match current_active_step:
		"intro", "":
			movement_allowed = false; camera_allowed = false; sprint_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		"movement":
			movement_allowed = true; camera_allowed = false; sprint_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		"camera":
			movement_allowed = true; camera_allowed = true; sprint_allowed = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		"sprint", "alt_mouse", "finished":
			movement_allowed = true; camera_allowed = true; sprint_allowed = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- PROGRESS RECORDERS WITH DELAYED TRANSITIONS ---

func record_walk(amount: float) -> void:
	if current_active_step != "movement": return
	walk_distance += amount
	progress_updated.emit(walk_distance, TARGET_WALK_DISTANCE)
	if walk_distance >= TARGET_WALK_DISTANCE:
		complete_step("movement")
		current_active_step = "transitioning" # Lock inputs during checkmark feedback
		await get_tree().create_timer(0.9).timeout
		start_step("camera")

func record_camera_turn(amount: float) -> void:
	if current_active_step != "camera": return
	camera_turned_amount += amount
	progress_updated.emit(camera_turned_amount, TARGET_CAMERA_TURN)
	if camera_turned_amount >= TARGET_CAMERA_TURN:
		complete_step("camera")
		current_active_step = "transitioning"
		await get_tree().create_timer(0.9).timeout
		start_step("sprint")

func record_sprint() -> void:
	if current_active_step != "sprint": return
	complete_step("sprint")
	current_active_step = "transitioning"
	await get_tree().create_timer(0.9).timeout
	start_step("alt_mouse")

# --- SAVE / LOAD INTEGRATION ---

func save_tutorial_to_json() -> void:
	var player = Engine.get_main_loop().get_root().get_node_or_null("Main/Player")
	var current_scene = Engine.get_main_loop().current_scene
	if player and SaveManager:
		# Explicitly saves tutorial_completed as true into the user's unified JSON file
		SaveManager.save_game(player, current_scene.scene_file_path if current_scene else "res://Scenes/Main/FirstTown.tscn", true)
		print("💾 [TUTORIAL MANAGER] Tutorial successfully marked completed and saved to JSON.")

func load_tutorial_from_save() -> void:
	if SaveManager and SaveManager.has_save():
		var data = SaveManager.load_game()
		if data.get("tutorial_completed", false):
			current_active_step = "finished"
			for key in progress.keys():
				progress[key] = true
		else:
			current_active_step = "intro"
	else:
		current_active_step = "intro"
	update_permissions()

func reset_tutorial() -> void:
	current_active_step = "intro"
	walk_distance = 0.0
	camera_turned_amount = 0.0
	for key in progress.keys():
		progress[key] = false
	update_permissions()
