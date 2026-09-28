class_name EnemyData
extends Resource

## Deliberately minimal — no lore, no corruption visuals, no "cured on
## defeat" reveal yet. Just enough to make a fight function. Extend this
## once the enemy identity/story is actually decided.

@export var enemy_id: String = ""
@export var display_name: String = "Enemy"
@export var max_hp: int = 30
@export var max_barrier: int = 15 ## The "language barrier" — a second pool in front of HP. Damage hits this first; only once it's broken does damage reach max_hp.
@export var atk: int = 6
@export var exp_reward: int = 20
@export var gold_reward: int = 10
