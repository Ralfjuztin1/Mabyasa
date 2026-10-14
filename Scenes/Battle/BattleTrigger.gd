extends Area3D

## Touch-triggered fixed encounter. Kept for existing encounter areas in maps.
## Walking into this Area3D starts battle; no E/interact input is required.

@export var enemy_id: String = "training_enemy"
@export var enemy_name: String = "Training Enemy"
@export_range(1, 99999, 1) var enemy_max_hp: int = 30
@export_range(0, 99999, 1) var enemy_max_barrier: int = 15
@export_range(1, 9999, 1) var enemy_atk: int = 6
@export_range(0, 999999, 1) var enemy_exp_reward: int = 20
@export_range(0, 999999, 1) var enemy_gold_reward: int = 10
@export var is_boss: bool = false
@export var enemy_battle_sprite: Texture2D
@export var enemy_battle_flip_h: bool = false

const BATTLE_SCREEN_SCENE: PackedScene = preload("res://Scenes/Battle/BattleScreen.tscn")

var _encounter_started: bool = false
var _active_enemy_data: EnemyData = null
var _defeated: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.connect(_on_battle_ended)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _encounter_started or _defeated or BattleManager.battle_active:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	_start_battle()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _defeated and not BattleManager.battle_active:
		_encounter_started = false
		_active_enemy_data = null


func _start_battle() -> void:
	if _encounter_started or BattleManager.battle_active:
		return
	if get_tree().current_scene == null:
		push_error("[BATTLE TRIGGER] Cannot start battle: current_scene is null.")
		return

	_encounter_started = true
	_active_enemy_data = EnemyData.new()
	_active_enemy_data.enemy_id = enemy_id
	_active_enemy_data.display_name = enemy_name
	_active_enemy_data.max_hp = maxi(enemy_max_hp, 1)
	_active_enemy_data.max_barrier = maxi(enemy_max_barrier, 0)
	_active_enemy_data.atk = maxi(enemy_atk, 1)
	_active_enemy_data.exp_reward = maxi(enemy_exp_reward, 0)
	_active_enemy_data.gold_reward = maxi(enemy_gold_reward, 0)
	_active_enemy_data.is_boss = is_boss
	_active_enemy_data.battle_sprite = enemy_battle_sprite
	_active_enemy_data.battle_sprite_flip_h = enemy_battle_flip_h

	var battle_screen: CanvasLayer = BATTLE_SCREEN_SCENE.instantiate() as CanvasLayer
	if battle_screen == null:
		push_error("[BATTLE TRIGGER] Could not instantiate BattleScreen.tscn.")
		_encounter_started = false
		_active_enemy_data = null
		return

	get_tree().current_scene.add_child(battle_screen)
	BattleManager.start_battle(_active_enemy_data)
	if not BattleManager.battle_active:
		battle_screen.queue_free()
		_encounter_started = false
		_active_enemy_data = null


func _on_battle_ended(victory: bool) -> void:
	if _active_enemy_data == null or BattleManager.current_enemy != _active_enemy_data:
		return
	if victory:
		_defeated = true
		set_deferred("monitoring", false)
		queue_free()
	# On defeat, this trigger is re-armed only when the player leaves its area.
