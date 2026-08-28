extends CharacterBody3D

@export var speed: float = 12.0
@export var gravity_multiplier: float = 3.0 # Increase this in the Inspector to fall faster
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

# Track the character's absolute 3D direction instead of 2D inputs
# Vector3(0, 0, 1) means facing toward the camera natively
var last_movement_direction := Vector3(0, 0, 1) 

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spring_arm.spring_length = camera_distance
	camera_yaw = rotation.y

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ALT and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

func _physics_process(delta: float) -> void:
	# 1. Apply Camera Orbit
	head.rotation.y = camera_yaw
	head.rotation.x = camera_pitch

	# 2. Handle Gravity
	if not is_on_floor():
		# Multiplies the default gravity so you drop much faster
		velocity.y -= (gravity * gravity_multiplier) * delta

	# 3. Handle Camera-Relative Movement
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (head.transform.basis * Vector3(input.x, 0, input.y))
	direction.y = 0 
	direction = direction.normalized()

	var is_moving = false

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Lock the true 3D direction the character is moving in the world
		last_movement_direction = direction 
		is_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		is_moving = false

	move_and_slide()
	_update_animation(is_moving)


func _update_animation(is_moving: bool) -> void:
	var state = "walk" if is_moving else "idle"
	
	# MATH MAGIC: Convert the player's world direction into the camera's local space
	var local_dir = head.global_transform.basis.inverse() * last_movement_direction
	
	var dir = ""
	
	# Determine which side of the player the camera is currently looking at
	if abs(local_dir.x) > abs(local_dir.z):
		# Looking mostly at the sides
		dir = "right" if local_dir.x > 0 else "left"
	else:
		# Looking mostly at the front or back
		dir = "front" if local_dir.z > 0 else "back"
		
	var anim_name = state + "_" + dir
	anim.play(anim_name)
