extends CharacterBody3D

@export var speed: float = 5.0
@export var sprint_multiplier: float = 2
@export var gravity_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var camera_distance: float = 7.1
@export_range(-89.0, 0.0, 1.0) var min_pitch: float = -65.0
@export_range(0.0, 89.0, 1.0) var max_pitch: float = 15.0

@onready var anim: AnimatedSprite3D = $AnimatedSprite3D
@onready var head: Node3D = $Head
@onready var spring_arm: SpringArm3D = $Head/SpringArm3D

const FOOTSTEP_PATHS: Array[String] = [
	"res://Assets/Audio/World/footstep_new.mp3"
]
const FOOTSTEP_VOLUME_DB: float = -12.0
const WALK_STEP_DISTANCE: float = 1.65
const SPRINT_STEP_DISTANCE: float = 2.20
const FALL_THRESHOLD: float = -5.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_yaw: float = 0.0
var camera_pitch: float = deg_to_rad(-12.0)
var last_movement_direction := Vector3(0, 0, 1)
var is_respawning: bool = false

var _footstep_player: AudioStreamPlayer3D
var _footstep_streams: Array[AudioStream] = []
var _footstep_index: int = 0
var _footstep_distance: float = 0.0
var _step_was_active: bool = false


func _ready() -> void:
	add_to_group("player")
	# TutorialManager controls the mouse mode on boot.
	spring_arm.spring_length = camera_distance
	_apply_account_settings()
	camera_yaw = rotation.y
	_setup_footstep_audio()


func _apply_account_settings() -> void:
	# Keep the exported value as the base so sensitivity scales consistently
	# when a player changes settings multiple times.
	set_meta("mabiyasa_base_mouse_sensitivity", mouse_sensitivity)
	var account_settings: Dictionary = {}
	if is_instance_valid(SaveManager):
		account_settings = SaveManager.load_settings_data()

	var sensitivity_percent: float = clampf(
		float(account_settings.get("sensitivity_percent", 100.0)),
		25.0,
		300.0
	)
	mouse_sensitivity = float(get_meta("mabiyasa_base_mouse_sensitivity")) * sensitivity_percent / 100.0

	var gameplay_camera := get_node_or_null("Head/SpringArm3D/Camera3D") as Camera3D
	if is_instance_valid(gameplay_camera):
		gameplay_camera.fov = clampf(float(account_settings.get("fov", 75.0)), 55.0, 100.0)


func _setup_footstep_audio() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "FootstepAudio"
	_footstep_player.volume_db = FOOTSTEP_VOLUME_DB
	_footstep_player.unit_size = 22.0
	_footstep_player.max_distance = 55.0
	_footstep_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_footstep_player.position = Vector3(0.0, 0.08, 0.0)
	_footstep_player.max_polyphony = 1
	add_child(_footstep_player)

	for path: String in FOOTSTEP_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("[WORLD AUDIO] Footstep file not found: " + path)
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			_footstep_streams.append(stream)


func _input(event: InputEvent) -> void:
	# Alt-to-Free Mouse toggle.
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

	# Camera control.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if TutorialManager.camera_allowed:
			camera_yaw -= event.relative.x * mouse_sensitivity
			camera_pitch -= event.relative.y * mouse_sensitivity
			camera_pitch = clamp(camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			TutorialManager.record_camera_turn(event.relative.length() * 0.5)


func sync_after_cutscene() -> void:
	# Preserve the current camera's world yaw.
	var camera := get_viewport().get_camera_3d()
	var world_camera_yaw: float = camera.global_rotation.y if camera else 0.0
	rotation.y = 0.0
	camera_yaw = world_camera_yaw
	head.rotation.y = camera_yaw
	head.rotation.x = camera_pitch
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if global_position.y < FALL_THRESHOLD and not is_respawning:
		_reset_footstep_state()
		_respawn_at_checkpoint()
		return

	head.rotation.y = camera_yaw
	head.rotation.x = camera_pitch

	if not is_on_floor():
		velocity.y -= (gravity * gravity_multiplier) * delta

	if not TutorialManager.movement_allowed:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		var blocked_position: Vector3 = global_position
		move_and_slide()
		_update_animation(false, false)
		_update_footsteps(blocked_position, false, false)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := head.transform.basis * Vector3(input.x, 0, input.y)
	direction.y = 0
	direction = direction.normalized()

	var current_speed: float = speed
	var is_moving: bool = false
	var is_sprinting: bool = false

	if direction:
		if Input.is_action_pressed("sprint") and TutorialManager.sprint_allowed:
			current_speed *= sprint_multiplier
			is_sprinting = true
			TutorialManager.record_sprint()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		last_movement_direction = direction
		is_moving = true
		var distance_traveled: float = Vector2(velocity.x, velocity.z).length() * delta
		TutorialManager.record_walk(distance_traveled)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		is_moving = false
		is_sprinting = false

	var position_before_move: Vector3 = global_position
	move_and_slide()
	_update_animation(is_moving, is_sprinting)
	_update_footsteps(position_before_move, is_moving, is_sprinting)


func _update_footsteps(position_before_move: Vector3, is_moving: bool, is_sprinting: bool) -> void:
	if _footstep_player == null or _footstep_streams.is_empty() or not is_moving or not is_on_floor():
		_reset_footstep_state()
		return

	var displacement: Vector3 = global_position - position_before_move
	displacement.y = 0.0
	var moved_distance: float = displacement.length()
	if moved_distance < 0.005:
		return

	var step_distance: float = SPRINT_STEP_DISTANCE if is_sprinting else WALK_STEP_DISTANCE
	if not _step_was_active:
		_footstep_distance = step_distance * 0.48
		_step_was_active = true
	_footstep_distance += moved_distance
	if _footstep_distance >= step_distance:
		_footstep_distance -= step_distance
		_play_footstep(is_sprinting)


func _play_footstep(is_sprinting: bool = false) -> void:
	if _footstep_streams.is_empty() or not is_instance_valid(_footstep_player):
		return
	_footstep_player.stream = _footstep_streams[0]
	if is_sprinting:
		_footstep_player.pitch_scale = randf_range(1.12, 1.20)
	else:
		_footstep_player.pitch_scale = randf_range(0.98, 1.02)
	_footstep_player.play()


func _reset_footstep_state() -> void:
	_footstep_distance = 0.0
	_step_was_active = false


func _respawn_at_checkpoint() -> void:
	is_respawning = true
	_reset_footstep_state()
	print("Player fell below the world bounds! Respawning...")

	if is_instance_valid(TransitionManager):
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
	if is_instance_valid(TransitionManager):
		await TransitionManager.fade_in(0.4)
	is_respawning = false


func _update_animation(is_moving: bool, is_sprinting: bool) -> void:
	var state: String
	if not is_moving:
		state = "idle"
	elif is_sprinting:
		state = "run"
	else:
		state = "walk"

	var local_dir := head.global_transform.basis.inverse() * last_movement_direction
	var dir: String
	if abs(local_dir.x) > abs(local_dir.z):
		dir = "right" if local_dir.x > 0 else "left"
	else:
		dir = "front" if local_dir.z > 0 else "back"

	var anim_name := state + "_" + dir
	if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
