extends Area3D

## Small reusable trigger for testing or placing fixed encounters.
## Set is_boss=true for a sentence-building boss fight.

@export var enemy_id: String = "training_enemy"
@export var enemy_name: String = "Training Enemy"
@export var enemy_max_hp: int = 30
@export var enemy_max_barrier: int = 15
@export var enemy_atk: int = 6
@export var enemy_exp_reward: int = 20
@export var enemy_gold_reward: int = 10
@export var is_boss: bool = false

const BATTLE_SCREEN_SCENE: PackedScene = preload(
	"res://Scenes/Battle/BattleScreen.tscn"
)

var player_in_range: bool = false


func _ready() -> void:
	# FirstTown.tscn already has these signal connections saved
	# in the scene file, so do not connect them again here.
	pass


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
	if BattleManager.battle_active:
		return

	var enemy_data := EnemyData.new()

	enemy_data.enemy_id = enemy_id
	enemy_data.display_name = enemy_name
	enemy_data.max_hp = enemy_max_hp
	enemy_data.max_barrier = enemy_max_barrier
	enemy_data.atk = enemy_atk
	enemy_data.exp_reward = enemy_exp_reward
	enemy_data.gold_reward = enemy_gold_reward
	enemy_data.is_boss = is_boss

	var battle_screen := BATTLE_SCREEN_SCENE.instantiate()

	get_tree().current_scene.add_child(
		battle_screen
	)

	BattleManager.start_battle(
		enemy_data
	)
