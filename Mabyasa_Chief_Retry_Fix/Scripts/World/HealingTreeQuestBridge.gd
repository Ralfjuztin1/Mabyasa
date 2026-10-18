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
	if is_instance_valid(GameEvents):
		GameEvents.object_interacted.emit(object_id)

	# Defeat recovery: reset the retry state before returning to Chief.
	if is_chief_recovery and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("training_battle_requested", false)
		QuestManager.set_dialogue_flag("chief_training_battle_started", false)
		QuestManager.set_dialogue_flag("chief_training_battle_completed", false)
		QuestManager.set_dialogue_flag("chief_training_battle_lost", false)
		QuestManager.set_dialogue_flag("chief_training_healed", true)

	# Preserve the existing post-victory progression behavior.
	if is_current_story_heal_step and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("request_time_evening", true)
