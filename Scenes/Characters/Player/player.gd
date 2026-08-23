extends CharacterBody3D

const SPEED = 20.0

@onready var anim = $AnimatedSprite3D
@onready var head = $Head
@onready var spring_arm = $Head/SpringArm3D
@onready var camera = $Head/SpringArm3D/Camera3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var mouse_sensitivity := 0.003
@export var camera_distance: float = 4.0

# Pitch limits: -65 degrees looking down, +15 degrees looking up
@export_range(-89.0, 0.0, 1.0) var min_look_down_angle: float = -65.0  
@export_range(0.0, 89.0, 1.0) var max_look_up_angle: float = 15.0    

var current_facing_direction := Vector2.DOWN  # Track which direction player is facing
var camera_yaw := 0.0  # X axis (unlimited rotation)
var camera_pitch := 0.0  # Y axis (limited rotation)


func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	head.position.y = 1.33
	
	# Apply the starting camera distance
	spring_arm.spring_length = camera_distance
	
	# Initialize camera rotation
	camera_yaw = rotation.y
	camera_pitch = 0.0


func _physics_process(delta):
	# Movement input
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		current_facing_direction = input.normalized()
	else:
		velocity.x = 0
		velocity.z = 0

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	# Apply camera rotation
	rotation.y = camera_yaw
	head.rotation.x = camera_pitch

	# Keep camera centered on player
	camera.global_position = global_position + Vector3(0, head.position.y, 0)

	# Animation
	play_idle()


func _input(event):
	# ALT toggle mouse to free cursor
	if event is InputEventKey:
		if event.keycode == KEY_ALT:
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE if event.pressed else Input.MOUSE_MODE_CAPTURED
			)

	# Camera movement - X axis (yaw) flat/unlimited, Y axis (pitch) limited by export variables
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			camera_yaw -= event.relative.x * mouse_sensitivity
			camera_pitch -= event.relative.y * mouse_sensitivity
			
			# Convert export angles from degrees to radians and clamp
			var min_rad = deg_to_rad(min_look_down_angle)
			var max_rad = deg_to_rad(max_look_up_angle)
			camera_pitch = clamp(camera_pitch, min_rad, max_rad)


func play_idle():
	if abs(current_facing_direction.x) > abs(current_facing_direction.y):
		anim.play("idle right" if current_facing_direction.x > 0 else "idle left")
	else:
		anim.play("idle back" if current_facing_direction.y < 0 else "idle front")
