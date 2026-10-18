extends "res://Scripts/World/HealingTree.gd"

## Quest-aware wrapper for the existing Big Tree healing area.
## Attach this script to Bigtree/Area3D in FirstTown.tscn.

@export var object_id: String = "bigtree"


func _heal_player() -> void:
	# Save this before emitting the event, because the quest step changes
	# immediately when QuestManager receives object_interacted.
	var is_current_story_heal_step: bool = (
		is_instance_valid(QuestManager)
		and QuestManager.is_quest_active("return_home_to_ima")
		and QuestManager.get_current_step("return_home_to_ima") == 0
	)
	var progression_available: bool = is_instance_valid(PlayerProgression)

	# Keep all existing healing, effects, prompt feedback, and save behavior.
	super._heal_player()

	if not progression_available:
		return

	# This allows the interact_object quest objective to complete, even if
	# the player is already above the tree's configured healing threshold.
	if is_instance_valid(GameEvents):
		GameEvents.object_interacted.emit(object_id)

	# Only request night after the player has used the tree during this
	# story objective, not whenever they use the tree in ordinary gameplay.
	if is_current_story_heal_step and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("request_time_night", true)
		# This script sets flags directly, so apply the time change here too.
		TimeManager.set_time("night")
