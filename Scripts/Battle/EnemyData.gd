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

## Animated battle sprite. Preferred for new enemy setups.
@export var battle_sprite_frames: SpriteFrames
@export var battle_sprite_animation: StringName = &"idle_left"
## Plays when the enemy attacks the player. Configure this in the reusable enemy instance.
@export var battle_attack_animation: StringName = &"attack_left"
## Plays when the enemy receives damage. Empty means use flash/shake feedback only.
@export var battle_hit_animation: StringName = &"hit"
## Wind-up duration in seconds before the enemy's damage is applied.
@export_range(0.0, 2.0, 0.05) var battle_attack_duration: float = 0.45

## Compatibility with older BattleTrigger instances that still provide a single texture.
## BattleScreen converts this texture to a one-frame SpriteFrames resource when needed.
@export var battle_sprite: Texture2D

## Enable if the supplied sprite should be flipped horizontally in the battle UI.
@export var battle_sprite_flip_h: bool = false
