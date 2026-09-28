extends Area3D

## Drop this into any scene (e.g. FirstTown) to test the battle loop.
## Walk up, press "interact". Not meant to be the real enemy-encounter
## system — it's scaffolding so combat can be tested before any real
## enemy identity or trigger design (wandering mobs, corruption visuals,
## etc.) is decided.

@export var enemy_name: String = "Training Dummy"
@export var enemy_max_hp: int = 30
@export var enemy_max_barrier: int = 15
@export var enemy_atk: int = 6
@export var enemy_exp_reward: int = 20
@export var enemy_gold_reward: int = 10

const BATTLE_SCREEN_SCENE: PackedScene = preload("res://Scenes/Battle/BattleScreen.tscn")

var player_in_range: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if BattleManager.battle_active:
		return

	if event.is_action_pressed("interact"):
		_start_battle()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _start_battle() -> void:
	var enemy_data := EnemyData.new()
	enemy_data.enemy_id = "test_dummy"
	enemy_data.display_name = enemy_name
	enemy_data.max_hp = enemy_max_hp
	enemy_data.max_barrier = enemy_max_barrier
	enemy_data.atk = enemy_atk
	enemy_data.exp_reward = enemy_exp_reward
	enemy_data.gold_reward = enemy_gold_reward

	var battle_screen := BATTLE_SCREEN_SCENE.instantiate()
	get_tree().current_scene.add_child(battle_screen)

	BattleManager.start_battle(enemy_data)
