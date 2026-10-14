extends CharacterBody3D

## Reusable touch-triggered enemy for both normal and boss battles.
## Configure the encounter, stats, and art from this scene instance's Inspector.

@export_group("Encounter")
@export var enemy_id: String = "wild_boar"
@export var enemy_name: String = "Wild Boar"
@export var is_boss: bool = false

@export_group("Combat Stats")
@export_range(1, 99999, 1) var enemy_max_hp: int = 35
@export_range(0, 99999, 1) var enemy_max_barrier: int = 0
@export_range(1, 9999, 1) var enemy_atk: int = 6
@export_range(0, 999999, 1) var enemy_exp_reward: int = 20
@export_range(0, 999999, 1) var enemy_gold_reward: int = 10

@export_group("Visuals")
## Assign a SpriteFrames resource for this enemy. You can create one from any compatible sprite sheet.
@export var world_sprite_frames: SpriteFrames
## Optional animated battle sprite. If empty, uses world_sprite_frames.
@export var battle_sprite_frames: SpriteFrames
## Animation to play in the battle UI. Falls back to another non-empty idle animation if missing.
@export var battle_sprite_animation: StringName = &"idle_left"
## One-shot animation played when this enemy attacks the player. Leave empty to disable.
@export var battle_attack_animation: StringName = &"attack_left"
## One-shot reaction played when the player damages this enemy. Leave empty for flash-only feedback.
@export var battle_hit_animation: StringName = &"hit"
## How long the battle pauses for the enemy attack animation before damage is applied.
@export_range(0.0, 2.0, 0.05) var battle_attack_duration: float = 0.45
@export var battle_sprite_flip_h: bool = false

@export_group("Physics")
## Must include the physics layer used by the ground/terrain collision.
@export_flags_3d_physics var floor_collision_mask: int = 1
@export_range(1.0, 60.0, 0.5) var gravity: float = 24.0

@export_group("Detection")
@export_flags_3d_physics var detection_collision_mask: int = 1
@export_range(0.25, 8.0, 0.25) var detection_radius: float = 1.0

const BATTLE_SCREEN_SCENE: PackedScene = preload(
    "res://Scenes/Battle/BattleScreen.tscn"
)

@onready var detection_area: Area3D = $DetectionArea
@onready var detection_shape: CollisionShape3D = $DetectionArea/CollisionShape3D
@onready var enemy_sprite: AnimatedSprite3D = $AnimatedSprite3D

var _encounter_started: bool = false
var _defeated: bool = false
var _battle_enemy_data: EnemyData = null


func _ready() -> void:
	# Apply per-instance sprite frames without changing the shared scene resource.
	if world_sprite_frames != null:
		enemy_sprite.sprite_frames = world_sprite_frames
	elif enemy_sprite.sprite_frames != null:
		world_sprite_frames = enemy_sprite.sprite_frames

	# Apply per-instance detection radius without changing other enemies using this scene.
	if detection_shape.shape is SphereShape3D:
		var detection_sphere: SphereShape3D = detection_shape.shape.duplicate() as SphereShape3D
		detection_sphere.radius = detection_radius
		detection_shape.shape = detection_sphere

	# The body does not block the player, but it must detect the ground so gravity works.
	collision_layer = 0
	collision_mask = floor_collision_mask
	add_to_group("enemies")

	detection_area.collision_layer = 0
	detection_area.collision_mask = detection_collision_mask
	detection_area.monitoring = true
	detection_area.monitorable = false

	if not detection_area.body_entered.is_connected(_on_detection_body_entered):
		detection_area.body_entered.connect(_on_detection_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_body_exited):
		detection_area.body_exited.connect(_on_detection_body_exited)

	if not BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.connect(_on_battle_ended)

	if enemy_sprite.sprite_frames != null:
		if _has_frames("idle_front"):
			enemy_sprite.play("idle_front")
		else:
			push_warning("[ENEMY] Assign an idle_front animation with at least one frame, or update Enemy.gd's default idle animation.")



func _physics_process(delta: float) -> void:
	# CharacterBody3D does not apply gravity automatically.
	# move_and_slide() also checks the floor using floor_collision_mask.
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()


func _process(_delta: float) -> void:
	# Face the player using the directional idle animations that exist in SpriteFrames.
	if _encounter_started or _defeated or enemy_sprite.sprite_frames == null:
		return

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var relative: Vector3 = to_local(player.global_position)
	var wanted_animation: String
	if absf(relative.x) > absf(relative.z):
		wanted_animation = "idle_right" if relative.x > 0.0 else "idle_left"
	else:
		wanted_animation = "idle_front" if relative.z < 0.0 else "idle_back"

	if _has_frames(wanted_animation) and enemy_sprite.animation != wanted_animation:
		enemy_sprite.play(wanted_animation)


func _has_frames(animation_name: String) -> bool:
	return (
		enemy_sprite.sprite_frames != null
		and enemy_sprite.sprite_frames.has_animation(animation_name)
		and enemy_sprite.sprite_frames.get_frame_count(animation_name) > 0
	)


func _on_detection_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _encounter_started or _defeated or BattleManager.battle_active:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	_start_battle()


func _on_detection_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	# Require the player to leave the area before allowing a retry after defeat.
	if not _defeated and not BattleManager.battle_active:
		_encounter_started = false
		_battle_enemy_data = null


func _start_battle() -> void:
	if _encounter_started or BattleManager.battle_active:
		return
	if get_tree().current_scene == null:
		push_error("[ENEMY] Cannot start battle: current_scene is null.")
		return

	_encounter_started = true
	_battle_enemy_data = EnemyData.new()
	_battle_enemy_data.enemy_id = enemy_id
	_battle_enemy_data.display_name = enemy_name
	_battle_enemy_data.max_hp = maxi(enemy_max_hp, 1)
	_battle_enemy_data.max_barrier = maxi(enemy_max_barrier, 0)
	_battle_enemy_data.atk = maxi(enemy_atk, 1)
	_battle_enemy_data.exp_reward = maxi(enemy_exp_reward, 0)
	_battle_enemy_data.gold_reward = maxi(enemy_gold_reward, 0)
	_battle_enemy_data.is_boss = is_boss
	_battle_enemy_data.battle_sprite_frames = (
		battle_sprite_frames
		if battle_sprite_frames != null
		else world_sprite_frames
	)
	_battle_enemy_data.battle_sprite_animation = battle_sprite_animation
	_battle_enemy_data.battle_attack_animation = battle_attack_animation
	_battle_enemy_data.battle_hit_animation = battle_hit_animation
	_battle_enemy_data.battle_attack_duration = battle_attack_duration
	_battle_enemy_data.battle_sprite_flip_h = battle_sprite_flip_h

	var battle_screen: CanvasLayer = BATTLE_SCREEN_SCENE.instantiate() as CanvasLayer
	if battle_screen == null:
		push_error("[ENEMY] Could not instantiate BattleScreen.tscn.")
		_encounter_started = false
		_battle_enemy_data = null
		return

	get_tree().current_scene.add_child(battle_screen)
	BattleManager.start_battle(_battle_enemy_data)

	if not BattleManager.battle_active:
		battle_screen.queue_free()
		_encounter_started = false
		_battle_enemy_data = null


func _on_battle_ended(victory: bool) -> void:
	# BattleManager is shared, so only handle the battle started by this instance.
	if _battle_enemy_data == null or BattleManager.current_enemy != _battle_enemy_data:
		return

	if victory:
		_defeated = true
		detection_area.set_deferred("monitoring", false)
		queue_free()
	# On defeat the enemy remains. The player must leave its detection area to retry.
