@tool
extends CharacterBody3D

@export_category("NPC Identity")
@export var npc_name: String = "Townsman":
	set(value):
		npc_name = value
		if is_inside_tree() and has_node("NameLabel"):
			$NameLabel.text = value

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

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var start_position: Vector3
var player_in_range: bool = false

# --- ANIMATION & STATE OPTIMIZATIONS ---
var current_facing: String = "front"
var is_idling: bool = true # Tracks if the NPC is naturally standing still
var active_camera: Camera3D
var last_look_dir: Vector3 = Vector3(0, 0, 1)

@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var name_label: Label3D = $NameLabel
@onready var interaction_prompt: Label3D = $InteractionPrompt

func _ready() -> void:
	if has_node("NameLabel"):
		name_label.text = npc_name
		
	if Engine.is_editor_hint():
		return

	start_position = global_position

	if npc_frames:
		animated_sprite.sprite_frames = npc_frames
		animated_sprite.play("idle_front")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- REALISTIC WANDER CYCLE ---
	if can_wander:
		if wander_timer > 0:
			wander_timer -= delta
		else:
			_switch_wander_state() # Naturally swap between walking and idling

		velocity.x = wander_direction.x * move_speed
		velocity.z = wander_direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

	# --- COLLISION FIX ---
	# If they bump a wall while walking, force a quick pause, then they will recalculate
	if is_on_wall() and can_wander and not is_idling:
		_switch_wander_state(true) 

	_update_animation()

func _switch_wander_state(forced_wall_bump: bool = false) -> void:
	if forced_wall_bump or not is_idling:
		# Switch to IDLE
		is_idling = true
		wander_direction = Vector3.ZERO
		
		if forced_wall_bump:
			wander_timer = randf_range(0.5, 1.2) # Quick pause if they bumped an object
		else:
			wander_timer = randf_range(2.0, 4.0) # Natural pause to look around
	else:
		# Switch to WALK
		is_idling = false
		if global_position.distance_to(start_position) > wander_radius:
			wander_direction = (start_position - global_position).normalized()
		else:
			wander_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		
		wander_timer = randf_range(1.5, 3.5) # Walk for a few seconds

func _update_animation() -> void:
	# length_squared() is a CPU optimization to avoid calculating square roots
	var is_moving = velocity.length_squared() > 0.01
	
	if is_moving:
		last_look_dir = velocity.normalized()

	# Cache the camera so we only search the scene tree once
	if not active_camera:
		active_camera = get_viewport().get_camera_3d()
		
	if active_camera:
		var cam_forward = -active_camera.global_transform.basis.z
		var cam_right = active_camera.global_transform.basis.x

		cam_forward.y = 0
		cam_right.y = 0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()

		# Constant dot-product calculation ensures the sprite updates even if you run around an idle NPC
		var forward_amount = last_look_dir.dot(cam_forward)
		var right_amount = last_look_dir.dot(cam_right)

		if abs(right_amount) > abs(forward_amount):
			current_facing = "right" if right_amount > 0 else "left"
		else:
			current_facing = "back" if forward_amount > 0 else "front"

	if is_moving:
		animated_sprite.play("walk_" + current_facing)
	else:
		animated_sprite.play("idle_" + current_facing)

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("interact"):
		DialogueManager.start_dialogue(self)

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true
	interaction_prompt.visible = true

	print("[NPC] Player entered interaction range: ", npc_name)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false
	interaction_prompt.visible = false

	print("[NPC] Player left interaction range: ", npc_name)
