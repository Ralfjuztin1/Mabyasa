extends "res://Scripts/World/HealingTree.gd"

## Quest/story-aware wrapper for the existing Big Tree healing area.
## Attach this to Bigtree/Area3D in FirstTown.tscn.

@export var object_id: String = "bigtree"


func _heal_player() -> void:
	# Capture the story states before healing or sending an objective event.
	var is_current_story_heal_step: bool = (
		is_instance_valid(QuestManager)
		and QuestManager.is_quest_active("return_home_to_ima")
		and QuestManager.get_current_step("return_home_to_ima") == 0
	)
	var is_chief_recovery: bool = (
		is_instance_valid(QuestManager)
		and QuestManager.has_dialogue_flag("chief_training_battle_lost")
	)
	var progression_available: bool = is_instance_valid(PlayerProgression)

	# Keep the original healing, visual effects, feedback, and save behavior.
	super._heal_player()

	if not progression_available:
		return

	# Complete the Big Tree objective in the post-victory quest, when active.
	# Emitting this is safe during ordinary gameplay: no matching active
	# objective means QuestManager simply ignores the event.
	if is_instance_valid(GameEvents):
		GameEvents.object_interacted.emit(object_id)

	# Defeat recovery: the player must interact with the tree before the
	# retry dialogue becomes available. These flags are cleared/set only when
	# the loss-recovery branch is active, not during ordinary tree use.
	if is_chief_recovery and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("chief_training_battle_lost", false)
		QuestManager.set_dialogue_flag("chief_training_healed", true)

	# The successful-training path advances to evening after the first
	# objective of return_home_to_ima has been completed.
	if is_current_story_heal_step and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("request_time_evening", true)
