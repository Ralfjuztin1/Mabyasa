@tool
extends CharacterBody3D


@export_category("Animal Identity")
@export var animal_name: String = "Animal":
	set(value):
		animal_name = value

		if is_inside_tree() and has_node("NameLabel"):
			$NameLabel.text = value

@export var animal_id: String = ""


@export_category("Animal Interaction")
@export var can_interact: bool = true


@export_category("Animal Visuals")
@export var animal_frames: SpriteFrames:
	set(value):
		animal_frames = value

		if Engine.is_editor_hint() and has_node("AnimatedSprite3D"):
			$AnimatedSprite3D.sprite_frames = value


@export_category("Animal Behavior")
@export var can_wander: bool = true
@export var move_speed: float = 1.5
@export var wander_radius: float = 5.0

@export_range(0.0, 1.0, 0.05)
var idle_chance: float = 0.5


# ============================================================
# MOVEMENT
# ============================================================

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var start_position: Vector3


# ============================================================
# INTERACTION
# ============================================================

var player_in_range: bool = false


# ============================================================
# ANIMATION
# ============================================================

var current_facing: String = "front"
var is_idling: bool = true

var active_camera: Camera3D
var last_look_dir: Vector3 = Vector3(0, 0, 1)


@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var interaction_prompt: Label3D = $InteractionPrompt


func _ready() -> void:
	# Update animal name.
	if has_node("NameLabel"):
		$NameLabel.text = animal_name

	# Hide interaction prompt.
	if has_node("InteractionPrompt"):
		interaction_prompt.visible = false

	# Don't run gameplay code in the editor.
	if Engine.is_editor_hint():
		return

	start_position = global_position

	# Apply sprite frames.
	if animal_frames:
		animated_sprite.sprite_frames = animal_frames

		if animated_sprite.sprite_frames.has_animation("idle_front"):
			animated_sprite.play("idle_front")

	# Start idle.
	is_idling = true
	wander_direction = Vector3.ZERO
	wander_timer = randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# ========================================================
	# GRAVITY
	# ========================================================

	if not is_on_floor():
		velocity.y -= gravity * delta


	# ========================================================
	# WANDERING
	# ========================================================

	if can_wander:
		if wander_timer > 0.0:
			wander_timer -= delta
		else:
			_switch_wander_state()

		if is_idling:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				move_speed
			)

			velocity.z = move_toward(
				velocity.z,
				0.0,
				move_speed
			)
		else:
			velocity.x = wander_direction.x * move_speed
			velocity.z = wander_direction.z * move_speed

	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			move_speed
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			move_speed
		)


	move_and_slide()


	# ========================================================
	# WALL COLLISION
	# ========================================================

	if is_on_wall() and can_wander and not is_idling:
		_switch_wander_state(true)


	# ========================================================
	# ANIMATION
	# ========================================================

	_update_animation()


# ============================================================
# WANDERING
# ============================================================

func _switch_wander_state(forced_wall_bump: bool = false) -> void:
	if forced_wall_bump:
		is_idling = true
		wander_direction = Vector3.ZERO
		wander_timer = randf_range(0.5, 1.2)
		return


	if is_idling:
		if randf() < idle_chance:
			is_idling = true
			wander_direction = Vector3.ZERO
			wander_timer = randf_range(1.5, 4.0)
			return

		is_idling = false

	else:
		is_idling = true
		wander_direction = Vector3.ZERO
		wander_timer = randf_range(1.5, 4.0)
		return


	if global_position.distance_to(start_position) > wander_radius:
		wander_direction = (
			start_position - global_position
		).normalized()
	else:
		wander_direction = Vector3(
			randf_range(-1.0, 1.0),
			0.0,
			randf_range(-1.0, 1.0)
		).normalized()


	if wander_direction.length_squared() < 0.01:
		wander_direction = Vector3.FORWARD


	wander_timer = randf_range(1.5, 3.5)


# ============================================================
# ANIMATION
# ============================================================

func _update_animation() -> void:
	var is_moving: bool = velocity.length_squared() > 0.01

	if is_moving:
		last_look_dir = velocity.normalized()


	if not is_instance_valid(active_camera):
		active_camera = get_viewport().get_camera_3d()


	if active_camera:
		var cam_forward := -active_camera.global_transform.basis.z
		var cam_right := active_camera.global_transform.basis.x

		cam_forward.y = 0.0
		cam_right.y = 0.0

		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()


		var forward_amount: float = last_look_dir.dot(cam_forward)
		var right_amount: float = last_look_dir.dot(cam_right)


		if abs(right_amount) > abs(forward_amount):
			current_facing = (
				"right"
				if right_amount > 0.0
				else "left"
			)
		else:
			current_facing = (
				"back"
				if forward_amount > 0.0
				else "front"
			)


	var animation_name: String

	if is_moving:
		animation_name = "walk_" + current_facing
	else:
		animation_name = "idle_" + current_facing


	if animated_sprite.animation != animation_name:
		if animated_sprite.sprite_frames.has_animation(animation_name):
			animated_sprite.play(animation_name)


# ============================================================
# PLAYER INTERACTION
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if not can_interact:
		return

	if event.is_action_pressed("interact"):
		_interact_with_animal()


func _interact_with_animal() -> void:
	if animal_id.is_empty():
		push_warning(
			"[ANIMAL] Animal has no animal_id: " + animal_name
		)
		return

	print(
		"🐾 [ANIMAL INTERACT] ",
		animal_name,
		" | ID: ",
		animal_id
	)

	GameEvents.object_interacted.emit(animal_id)


# ============================================================
# INTERACTION AREA
# ============================================================

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true

	if has_node("InteractionPrompt") and can_interact:
		interaction_prompt.visible = true

	print(
		"[ANIMAL] Player entered interaction range: ",
		animal_name
	)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false

	if has_node("InteractionPrompt"):
		interaction_prompt.visible = false

	print(
		"[ANIMAL] Player left interaction range: ",
		animal_name
	)
