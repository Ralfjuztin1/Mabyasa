extends "res://Scenes/Characters/NPC/Enemy/Enemy.gd"

## Remembers the guardian's defeat across map transitions and saves.
const GUARDIAN_DEFEATED_FLAG: String = "forest_ylang_guardian_defeated"


func _ready() -> void:
	super._ready()

	# If the player already defeated this guardian and returned to the Forest,
	# do not respawn it in front of the Mystic Ylang-Ylang.
	if QuestManager.has_dialogue_flag(GUARDIAN_DEFEATED_FLAG):
		_defeated = true
		detection_area.set_deferred("monitoring", false)
		queue_free()


func _on_battle_ended(victory: bool) -> void:
	# Ignore battle_ended signals from any other enemy.
	if _battle_enemy_data == null or BattleManager.current_enemy != _battle_enemy_data:
		return

	if victory:
		QuestManager.set_dialogue_flag(GUARDIAN_DEFEATED_FLAG, true)
		print("[FOREST BOSS] Guardian defeated. Mystic Ylang-Ylang is now accessible.")

	super._on_battle_ended(victory)
