extends CharacterBody3D

@export var speed: float = 12.0
@export var sprint_multiplier: float = 1.7
@export var gravity_multiplier: float = 3.0 
@export var mouse_sensitivity: float = 0.003
@export var camera_distance: float = 4.0
@export_range(-89.0, 0.0, 1.0) var min_pitch: float = -65.0  
@export_range(0.0, 89.0, 1.0) var max_pitch: float = 15.0     

@onready var anim = $AnimatedSprite3D
@onready var head = $Head
@onready var spring_arm = $Head/SpringArm3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_yaw: float = 0.0
var camera_pitch: float = 0.0

var last_movement_direction := Vector3(0, 0, 1) 

const FALL_THRESHOLD: float = -15.0
var is_respawning: bool = false

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spring_arm.spring_length = camera_distance
	camera_yaw = rotation.y

func _input(event: InputEvent) -> void:
	# Alt-to-Free Mouse toggle
	if event is InputEventKey and event.keycode == KEY_ALT:
		if TutorialManager.current_active_step == "alt_mouse":
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				TutorialManager.complete_step("alt_mouse")
				TutorialManager.current_active_step = "finished"
				TutorialManager.save_tutorial_to_json()
				TutorialManager.step_changed.emit("finished")
		elif TutorialManager.current_active_step == "finished":
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if TutorialManager.camera_allowed:
				camera_yaw -= event.relative.x * mouse_sensitivity
				camera_pitch -= event.relative.y * mouse_sensitivity
				camera_pitch = clamp(camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
				
				# --- SLOWER ENVIRONMENT SCAN PROGRESS TRACKER ---
				var look_amount = event.relative.length() * 0.5 # Scaled down for a natural panning feel
				TutorialManager.record_camera_turn(look_amount)

func _physics_process(delta: float) -> void:
	if global_position.y < FALL_THRESHOLD and not is_respawning:
		_respawn_at_checkpoint()
		return

	head.rotation.y = camera_yaw
	head.rotation.x = camera_pitch

	if not is_on_floor():
		velocity.y -= (gravity * gravity_multiplier) * delta

	if not TutorialManager.movement_allowed:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		move_and_slide()
		_update_animation(false)
		return

	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (head.transform.basis * Vector3(input.x, 0, input.y))
	direction.y = 0 
	direction = direction.normalized()

	var current_speed = speed
	var is_moving = false

	if direction:
		if Input.is_action_pressed("sprint") and TutorialManager.sprint_allowed:
			current_speed *= sprint_multiplier
			TutorialManager.record_sprint() 

		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		last_movement_direction = direction 
		is_moving = true
		
		var distance_traveled = Vector2(velocity.x, velocity.z).length() * delta
		TutorialManager.record_walk(distance_traveled)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		is_moving = false

	move_and_slide()
	_update_animation(is_moving)

func _respawn_at_checkpoint() -> void:
	is_respawning = true
	print("❖ Player fell below the world bounds! Respawning...")

	if TransitionManager:
		await TransitionManager.fade_out(0.3)

	velocity = Vector3.ZERO
	set_physics_process(false)

	var current_level = get_tree().current_scene.find_child("LevelContainer", true, false)
	var spawn_point = null
	
	if current_level and current_level.get_child_count() > 0:
		spawn_point = current_level.get_child(0).find_child("DefaultSpawn", true, false)

	if spawn_point and spawn_point is Node3D:
		global_position = spawn_point.global_position
	else:
		global_position = Vector3(0, 5, 0)

	await get_tree().process_frame
	set_physics_process(true)

	if TransitionManager:
		await TransitionManager.fade_in(0.4)
		
	is_respawning = false

func _update_animation(is_moving: bool) -> void:
	var state = "walk" if is_moving else "idle"
	
	var local_dir = head.global_transform.basis.inverse() * last_movement_direction
	var dir = ""
	
	if abs(local_dir.x) > abs(local_dir.z):
		dir = "right" if local_dir.x > 0 else "left"
	else:
		dir = "front" if local_dir.z > 0 else "back"
		
	var anim_name = state + "_" + dir
	anim.play(anim_name)
