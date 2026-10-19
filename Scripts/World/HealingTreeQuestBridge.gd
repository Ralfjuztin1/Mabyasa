extends "res://Scripts/World/HealingTree.gd"

## Quest-aware wrapper for the existing Big Tree healing area.
## Attach this script to Bigtree/Area3D in FirstTown.tscn.

@export var object_id: String = "bigtree"


func _heal_player() -> void:
	# Capture story state before healing or emitting quest events.
	var is_current_story_heal_step: bool = (
		is_instance_valid(QuestManager)
		and QuestManager.is_quest_active("return_home_to_ima")
		and QuestManager.get_current_step("return_home_to_ima") == 0
	)
	var is_chief_recovery: bool = (
		is_instance_valid(QuestManager)
		and QuestManager.has_dialogue_flag("chief_training_battle_lost")
	)
	var is_chief_final_recovery: bool = (
		is_instance_valid(QuestManager)
		and QuestManager.has_dialogue_flag("chief_final_training_battle_lost")
	)
	var progression_available: bool = is_instance_valid(PlayerProgression)

	# Preserve the original HP restoration, effects, feedback, and save behavior.
	super._heal_player()

	if not progression_available:
		return

	# Complete any matching Big Tree objective, including when the player is
	# already above the configured healing threshold.
	if is_instance_valid(GameEvents):
		GameEvents.object_interacted.emit(object_id)

	# Recovery for the original Chief training battle.
	if is_chief_recovery and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("training_battle_requested", false)
		QuestManager.set_dialogue_flag("chief_training_battle_started", false)
		QuestManager.set_dialogue_flag("chief_training_battle_completed", false)
		QuestManager.set_dialogue_flag("chief_training_battle_lost", false)
		QuestManager.set_dialogue_flag("chief_training_healed", true)
		print("[HEALING TREE] Chief training recovery registered. Return to Chief.")

	# Final-boss recovery is separate, so it cannot reset the original training flags.
	if is_chief_final_recovery and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("final_training_battle_requested", false)
		QuestManager.set_dialogue_flag("chief_final_training_battle_started", false)
		QuestManager.set_dialogue_flag("chief_final_training_battle_completed", false)
		QuestManager.set_dialogue_flag("chief_final_training_battle_lost", false)
		QuestManager.set_dialogue_flag("chief_final_training_battle_healed", true)
		print("[HEALING TREE] Final training recovery registered. Return to Chief.")

	# After winning the first training battle, the separate story objective
	# sends the player to the tree before going home to Ima.
	if is_current_story_heal_step and is_instance_valid(QuestManager):
		QuestManager.set_dialogue_flag("request_time_night", true)
		if is_instance_valid(TimeManager):
			TimeManager.set_time("night")
