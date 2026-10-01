class_name CutsceneController
extends Node

## Reusable cutscene controller for MABIYASA.
##
## Handles:
## - Locking player control
## - Forced player movement
## - Cinematic camera shots
## - Fade-to-black camera switching
## - Returning to the player camera
## - Restoring player control
## - Dialogic timeline playback
##
## Intended to live persistently in Main.tscn.

const DEFAULT_MOVE_SPEED: float = 2.5
const MIN_TIMEOUT: float = 2.0
const TIMEOUT_MULTIPLIER: float = 3.0

const DEFAULT_FADE_DURATION: float = 0.18
const FADE_LAYER: int = 100


@export var move_speed: float = DEFAULT_MOVE_SPEED


# ============================================================
# STATE
# ============================================================

var is_cutscene_active: bool = false
var _movement_running: bool = false

# Player
var _player: CharacterBody3D = null
var _player_was_physics: bool = true
var _player_was_input: bool = true

# Cameras
var _cutscene_camera: Camera3D = null
var _player_camera: Camera3D = null
var _camera_active: bool = false

# Fade
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("cutscene_controller")


# ============================================================
# BEGIN / END CUTSCENE
# ============================================================

## Begins a cutscene and disables player control.
##
## This is useful when you want to perform several actions:
##
##     controller.begin_cutscene()
##     await controller.move_player_to(point1)
##     await controller.camera_shot(camera_point)
##     await controller.play_dialogue(timeline)
##     await controller.return_to_player_camera()
##     controller.end_cutscene()
##
func begin_cutscene() -> bool:
	if is_cutscene_active:
		return true

	var player := _find_player()

	if not is_instance_valid(player):
		push_warning(
			"[CUTSCENE] begin_cutscene: player not found."
		)
		return false

	_take_control(player)

	print("[CUTSCENE] Cutscene started")

	return true


## Ends the cutscene and restores the player's normal camera/control.
func end_cutscene() -> void:
	if not is_inside_tree():
		return

	if _camera_active:
		await return_to_player_camera()

	_release_control()

	print("[CUTSCENE] Cutscene ended")


# ============================================================
# PLAYER MOVEMENT
# ============================================================

## Moves the player toward a world position.
##
## Can be called:
##
##     await controller.move_player_to(point.global_position)
##
## If begin_cutscene() was NOT called first, this function will
## temporarily take control of the player itself.
func move_player_to(
	target_position: Vector3,
	stopping_distance: float = 0.05
) -> void:
	if _movement_running:
		push_warning(
			"[CUTSCENE] Another movement is already running."
		)
		return

	if not is_inside_tree():
		return

	var player := _find_player()

	if not is_instance_valid(player):
		push_warning(
			"[CUTSCENE] move_player_to: player not found."
		)
		return

	var offset := target_position - player.global_position
	offset.y = 0.0

	var starting_distance := offset.length()

	if starting_distance <= stopping_distance:
		return

	var temporary_control := false

	if not is_cutscene_active:
		_take_control(player)
		temporary_control = true

	_movement_running = true

	var sprite := player.get_node_or_null(
		"AnimatedSprite3D"
	) as AnimatedSprite3D

	var head := player.get_node_or_null(
		"Head"
	) as Node3D

	var gravity := _get_player_gravity(player)

	var timeout := maxf(
		MIN_TIMEOUT,
		(starting_distance / maxf(move_speed, 0.01))
		* TIMEOUT_MULTIPLIER
	)

	var last_direction := Vector3(0.0, 0.0, 1.0)

	var saved_direction = player.get(
		"last_movement_direction"
	)

	if saved_direction is Vector3:
		if saved_direction != Vector3.ZERO:
			last_direction = saved_direction

	var elapsed := 0.0

	while is_cutscene_active:
		await get_tree().physics_frame

		if not is_instance_valid(player):
			break

		if not player.is_inside_tree():
			break

		if get_tree().paused:
			continue

		var delta := get_physics_process_delta_time()

		elapsed += delta

		if elapsed > timeout:
			push_warning(
				"[CUTSCENE] Movement timed out."
			)
			break

		var current_offset := (
			target_position
			- player.global_position
		)

		current_offset.y = 0.0

		var distance := current_offset.length()

		if distance <= stopping_distance:
			break

		var direction := current_offset / distance

		last_direction = direction

		var step_speed := minf(
			move_speed,
			distance / maxf(delta, 0.001)
		)

		player.velocity.x = direction.x * step_speed
		player.velocity.z = direction.z * step_speed

		if not player.is_on_floor():
			player.velocity.y -= gravity * delta

		player.move_and_slide()

		_update_cutscene_animation(
			sprite,
			head,
			direction,
			true
		)

	if is_instance_valid(player):
		player.velocity = Vector3.ZERO

		_update_cutscene_animation(
			sprite,
			head,
			last_direction,
			false
		)

		player.set(
			"last_movement_direction",
			last_direction
		)

	_movement_running = false

	if temporary_control:
		_release_control()


# ============================================================
# PLAYER CONTROL
# ============================================================

func _take_control(player: CharacterBody3D) -> void:
	if not is_instance_valid(player):
		return

	_player = player

	_player_was_physics = player.is_physics_processing()
	_player_was_input = player.is_processing_input()

	is_cutscene_active = true

	player.set_process_input(false)
	player.set_physics_process(false)

	player.velocity = Vector3.ZERO

	print("[CUTSCENE] Player control locked")


func _release_control() -> void:
	if is_instance_valid(_player):
		_player.velocity = Vector3.ZERO

		_player.set_physics_process(
			_player_was_physics
		)

		_player.set_process_input(
			_player_was_input
		)

		print("[CUTSCENE] Player control restored")

	_player = null

	is_cutscene_active = false
	_movement_running = false


# ============================================================
# CAMERA
# ============================================================

## Returns true when the cinematic camera is active.
func has_camera_override() -> bool:
	return _camera_active


## Fades to black, instantly switches to the cinematic camera,
## then fades back in.
##
## There is NO camera panning or tweening.
func camera_shot(
	marker: Node3D,
	fade_duration: float = DEFAULT_FADE_DURATION
) -> void:
	if not is_inside_tree():
		return

	if not is_instance_valid(marker):
		push_warning(
			"[CUTSCENE] camera_shot: marker is invalid."
		)
		return

	await _ensure_fade_overlay()
	await _ensure_camera()

	# Fade out.
	await _fade_screen(
		1.0,
		fade_duration
	)

	_find_player_camera()

	if not is_instance_valid(_cutscene_camera):
		push_warning(
			"[CUTSCENE] Cutscene camera could not be created."
		)

		await _fade_screen(
			0.0,
			fade_duration
		)

		return

	# Instant camera placement.
	_cutscene_camera.global_transform = (
		marker.global_transform
	)

	# Match player's camera settings.
	if is_instance_valid(_player_camera):
		_cutscene_camera.fov = _player_camera.fov
		_cutscene_camera.near = _player_camera.near
		_cutscene_camera.far = _player_camera.far
		_cutscene_camera.keep_aspect = _player_camera.keep_aspect

	# Switch immediately.
	_cutscene_camera.make_current()

	_camera_active = true

	await get_tree().process_frame

	# Fade back in.
	await _fade_screen(
		0.0,
		fade_duration
	)

	print("[CUTSCENE] Cinematic camera active")


## Fades to black, instantly switches back to the player camera,
## then fades in.
func return_to_player_camera(
	fade_duration: float = DEFAULT_FADE_DURATION
) -> void:
	if not is_inside_tree():
		return

	await _ensure_fade_overlay()

	# Fade out.
	await _fade_screen(
		1.0,
		fade_duration
	)

	_find_player_camera()

	if is_instance_valid(_player_camera):
		_player_camera.make_current()

	if is_instance_valid(_cutscene_camera):
		_cutscene_camera.current = false

	_camera_active = false

	await get_tree().process_frame

	# Fade back in.
	await _fade_screen(
		0.0,
		fade_duration
	)

	print("[CUTSCENE] Player camera restored")


# ============================================================
# DIALOGUE
# ============================================================

## Starts a Dialogic timeline and waits for it to finish.
##
## Example:
##
##     await controller.play_dialogue(
##         "res://Scenes/Characters/NPC/Dialogic/meeting_apu.dtl"
##     )
func play_dialogue(timeline_path: String) -> void:
	if timeline_path.is_empty():
		push_warning(
			"[CUTSCENE] Empty dialogue path."
		)
		return

	if not ResourceLoader.exists(timeline_path):
		push_warning(
			"[CUTSCENE] Dialogue not found: "
			+ timeline_path
		)
		return

	Dialogic.start(timeline_path)

	await Dialogic.timeline_ended


# ============================================================
# FADE SYSTEM
# ============================================================

func _ensure_fade_overlay() -> void:
	if (
		is_instance_valid(_fade_layer)
		and is_instance_valid(_fade_rect)
	):
		return

	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "CutsceneFadeLayer"
	_fade_layer.layer = FADE_LAYER

	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"

	_fade_rect.color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)

	_fade_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_fade_layer.add_child(_fade_rect)


func _fade_screen(
	target_alpha: float,
	duration: float
) -> void:
	if not is_instance_valid(_fade_rect):
		return

	target_alpha = clampf(
		target_alpha,
		0.0,
		1.0
	)

	duration = maxf(
		duration,
		0.0
	)

	if is_instance_valid(_fade_tween):
		_fade_tween.kill()

	if duration <= 0.0:
		_fade_rect.color.a = target_alpha
		return

	_fade_tween = create_tween()

	_fade_tween.set_trans(
		Tween.TRANS_SINE
	)

	_fade_tween.set_ease(
		Tween.EASE_IN_OUT
	)

	_fade_tween.tween_property(
		_fade_rect,
		"color:a",
		target_alpha,
		duration
	)

	await _fade_tween.finished


# ============================================================
# CAMERA SETUP
# ============================================================

func _ensure_camera() -> void:
	_find_player_camera()

	if is_instance_valid(_cutscene_camera):
		return

	_cutscene_camera = Camera3D.new()
	_cutscene_camera.name = "CutsceneCamera"
	_cutscene_camera.current = false

	add_child(_cutscene_camera)


func _find_player_camera() -> void:
	if is_instance_valid(_player_camera):
		if _player_camera.is_inside_tree():
			return

	_player_camera = null

	var player := _find_player()

	if not is_instance_valid(player):
		return

	# Current hierarchy:
	#
	# Player
	# └── Head
	#     └── SpringArm3D
	#         └── Camera3D

	_player_camera = player.get_node_or_null(
		"Head/SpringArm3D/Camera3D"
	) as Camera3D

	if not is_instance_valid(_player_camera):
		_player_camera = _find_camera_recursive(
			player
		)


func _find_camera_recursive(
	node: Node
) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child as Camera3D

		var found := _find_camera_recursive(child)

		if is_instance_valid(found):
			return found

	return null


# ============================================================
# PLAYER LOOK / ANIMATION
# ============================================================

func _update_cutscene_animation(
	sprite: AnimatedSprite3D,
	head: Node3D,
	direction: Vector3,
	moving: bool
) -> void:
	if not is_instance_valid(sprite):
		return

	if sprite.sprite_frames == null:
		return

	var local_direction := direction

	if is_instance_valid(head):
		local_direction = (
			head.global_transform.basis.inverse()
			* direction
		)

	var facing := "front"

	if absf(local_direction.x) > absf(
		local_direction.z
	):
		if local_direction.x > 0.0:
			facing = "right"
		else:
			facing = "left"
	else:
		if local_direction.z > 0.0:
			facing = "front"
		else:
			facing = "back"

	var animation_name := (
		"walk_" if moving else "idle_"
	) + facing

	if not sprite.sprite_frames.has_animation(
		animation_name
	):
		return

	if (
		sprite.animation != animation_name
		or not sprite.is_playing()
	):
		sprite.play(animation_name)


# ============================================================
# PLAYER / GRAVITY
# ============================================================

func _find_player() -> CharacterBody3D:
	if is_instance_valid(_player):
		if _player.is_inside_tree():
			return _player

	var found := get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody3D

	return found


func _get_player_gravity(
	player: Node
) -> float:
	var gravity := float(
		ProjectSettings.get_setting(
			"physics/3d/default_gravity",
			9.8
		)
	)

	var player_gravity = player.get(
		"gravity"
	)

	if player_gravity is float:
		gravity = player_gravity

	var multiplier := 1.0

	var player_multiplier = player.get(
		"gravity_multiplier"
	)

	if player_multiplier is float:
		multiplier = player_multiplier

	return gravity * multiplier

# ============================================================
# WAIT
# ============================================================

## Pauses the cutscene for the given number of seconds.
## Can be used with:
##
##     await controller.wait(1.0)
##
func wait(seconds: float) -> void:
	if seconds <= 0.0:
		return

	await get_tree().create_timer(seconds).timeout
# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()

	if is_cutscene_active:
		_release_control()

	# Always give control back to player camera.
	if _camera_active:
		_find_player_camera()

		if is_instance_valid(_player_camera):
			_player_camera.make_current()

	_camera_active = false
