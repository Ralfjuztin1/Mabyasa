extends "res://Scenes/SceneManager/Main.gd"

## Small extension of the existing Main loader.
## It leaves terrain loading, player spawning, saving, and cutscenes unchanged.
## Main.gd emits loading_completed only AFTER the player has been placed.

const SECOND_TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"
const SECOND_TOWN_LOCATION_ID: String = "second_town"


func _ready() -> void:
	# Subscribe BEFORE the original loader starts, including when loading a save.
	if not loading_completed.is_connected(_on_level_loaded_for_second_town):
		loading_completed.connect(_on_level_loaded_for_second_town)

	super._ready()


func _on_level_loaded_for_second_town() -> void:
	if not is_instance_valid(current_level_node):
		return
	if GameManager.current_level_path != SECOND_TOWN_PATH:
		return

	# Verify the intended spawn marker is still present in the actual town scene.
	var town_spawn: Node3D = current_level_node.find_child(
		"DefaultSpawn", true, false
	) as Node3D
	if not is_instance_valid(town_spawn):
		push_error("[SECOND TOWN] Missing DefaultSpawn marker in SecondTown.tscn.")
		return
	if not is_instance_valid(player):
		push_error("[SECOND TOWN] Main's player node is missing after loading.")
		return

	# The portal already emits forest_second_town_path (objective 1).
	# This event completes objective 2: arrival in Second Town.
	# QuestManager ignores it when the follow-up quest is not active.
	GameEvents.location_reached.emit(SECOND_TOWN_LOCATION_ID)
	print("[SECOND TOWN] Loaded successfully; arrival event emitted: ", SECOND_TOWN_LOCATION_ID)
