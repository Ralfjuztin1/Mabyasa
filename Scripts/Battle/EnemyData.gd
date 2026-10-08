class_name EnemyData
extends Resource

@export var enemy_id: String = ""
@export var display_name: String = "Enemy"
@export var max_hp: int = 30
@export var max_barrier: int = 15
@export var atk: int = 6
@export var exp_reward: int = 20
@export var gold_reward: int = 10

## Boss fights switch the language challenge to sentence construction.
@export var is_boss: bool = false
