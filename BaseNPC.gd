@tool
extends CharacterBody3D

@export_category("NPC Identity")
@export var npc_name: String = "Townsman":
	set(value):
		npc_name = value

		if is_inside_tree() and has_node("NameLabel"):
			$NameLabel.text = value

@export var npc_id: String = ""


@export_category("Dialogue")
@export var dialogue_id: String = ""


@export var npc_frames: SpriteFrames:
	set(value):
		npc_frames = value

		if Engine.is_editor_hint() and has_node("AnimatedSprite3D"):
			$AnimatedSprite3D.sprite_frames = value


@export_category("NPC Behavior")
@export var can_wander: bool = false
@export var move_speed: float = 2.0
@export var wander_radius: float = 3.0


# --- MOVEMENT ---

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var start_position: Vector3

# --- INTERACTION ---

var player_in_range: bool = false

# --- ANIMATION ---

var current_facing: String = "front"
var is_idling: bool = true
var active_camera: Camera3D
var last_look_dir: Vector3 = Vector3(0, 0, 1)


@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var name_label: Label3D = $NameLabel
@onready var interaction_prompt: Label3D = $InteractionPrompt


func _ready() -> void:
	# Update NPC name.
	if has_node("NameLabel"):
		name_label.text = npc_name

	# Hide interaction prompt until player is nearby.
	if has_node("InteractionPrompt"):
		interaction_prompt.visible = false

	# Stop editor-only execution here.
	if Engine.is_editor_hint():
		return

	start_position = global_position

	# Apply NPC sprite frames.
	if npc_frames:
		animated_sprite.sprite_frames = npc_frames

		if animated_sprite.sprite_frames.has_animation("idle_front"):
			animated_sprite.play("idle_front")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# --- GRAVITY ---

	if not is_on_floor():
		velocity.y -= gravity * delta


	# --- WANDERING ---

	if can_wander:
		if wander_timer > 0.0:
			wander_timer -= delta
		else:
			_switch_wander_state()

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


	# --- WALL COLLISION ---

	if is_on_wall() and can_wander and not is_idling:
		_switch_wander_state(true)


	# --- ANIMATION ---

	_update_animation()


func _switch_wander_state(forced_wall_bump: bool = false) -> void:
	if forced_wall_bump or not is_idling:
		# Enter idle state.
		is_idling = true
		wander_direction = Vector3.ZERO

		if forced_wall_bump:
			wander_timer = randf_range(0.5, 1.2)
		else:
			wander_timer = randf_range(2.0, 4.0)

		return


	# Enter walking state.
	is_idling = false

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


	wander_timer = randf_range(1.5, 3.5)


func _update_animation() -> void:
	# Avoid square root when checking movement.
	var is_moving: bool = velocity.length_squared() > 0.01

	if is_moving:
		last_look_dir = velocity.normalized()


	# Cache the current camera.
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
			current_facing = "right" if right_amount > 0.0 else "left"
		else:
			current_facing = "back" if forward_amount > 0.0 else "front"


	# Play the appropriate animation.
	var animation_name: String

	if is_moving:
		animation_name = "walk_" + current_facing
	else:
		animation_name = "idle_" + current_facing


	# Avoid repeatedly restarting the same animation.
	if animated_sprite.animation != animation_name:
		if animated_sprite.sprite_frames.has_animation(animation_name):
			animated_sprite.play(animation_name)


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("interact"):
		QuestManager.handle_npc_interaction(npc_id)
		DialogueManager.start_dialogue(self)

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true

	if has_node("InteractionPrompt"):
		interaction_prompt.visible = true

	print("[NPC] Player entered interaction range: ", npc_name)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false

	if has_node("InteractionPrompt"):
		interaction_prompt.visible = false

	print("[NPC] Player left interaction range: ", npc_name)
