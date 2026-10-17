extends "res://Scripts/Managers/SaveManager.gd"

## Account-save bridge for UITutorialManager.
## Keep this script assigned to the autoload named SaveManager.


func save_game(
	player: CharacterBody3D,
	current_scene_path: String,
	tutorial_done: bool = false
) -> void:
	if not is_instance_valid(player):
		push_warning("[SAVE MANAGER] Cannot save: player invalid.")
		return

	var file_path: String = _get_save_path()
	var existing_data: Dictionary = _read_save_file(file_path)
	var previous_tutorial_status: bool = bool(existing_data.get("tutorial_completed", false))
	var final_tutorial_status: bool = previous_tutorial_status or tutorial_done
	var normalized_scene_path: String = _normalize_scene_path(current_scene_path)

	var language_data: Dictionary = {}
	if is_instance_valid(LanguageProgress):
		language_data = LanguageProgress.get_save_data()

	var ui_tutorial_data: Dictionary = {}
	if is_instance_valid(UITutorialManager) and UITutorialManager.has_method("get_save_data"):
		ui_tutorial_data = UITutorialManager.get_save_data()
	elif existing_data.get("ui_tutorials", {}) is Dictionary:
		ui_tutorial_data = existing_data.get("ui_tutorials", {}).duplicate(true)

	var game_data: Dictionary = {
		"tutorial_completed": final_tutorial_status,
		"ui_tutorials": ui_tutorial_data,
		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"current_scene": normalized_scene_path,
		"progression": PlayerProgression.get_save_data() if is_instance_valid(PlayerProgression) else {},
		"language": language_data,
		"time": TimeManager.get_save_data() if is_instance_valid(TimeManager) else {},
		"quests": QuestManager.get_save_data() if is_instance_valid(QuestManager) else {},
		"inventory": InventoryManager.get_save_data() if is_instance_valid(InventoryManager) else {}
	}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SAVE MANAGER] Failed to open: " + file_path)
		return

	file.store_string(JSON.stringify(game_data, "\t"))
	file.close()

	if is_instance_valid(SupabaseManager):
		SupabaseManager.sync_save_to_cloud(game_data)

	print("[SAVE MANAGER] Account save completed, including UI tutorial flags.")
	print("   ├── Account file: ", file_path)
	print("   ├── Scene: ", normalized_scene_path)
	print("   └── Saved UI tutorials: ", ui_tutorial_data)


func load_game() -> Dictionary:
	var data: Dictionary = super.load_game()
	var ui_tutorial_data: Variant = data.get("ui_tutorials", {})
	if not (ui_tutorial_data is Dictionary):
		ui_tutorial_data = {}

	if is_instance_valid(UITutorialManager) and UITutorialManager.has_method("load_save_data"):
		UITutorialManager.load_save_data(ui_tutorial_data)
	return data


func write_raw_save_data(data: Dictionary) -> void:
	# When older cloud rows omit tutorial flags, preserve this account's existing
	# local flags instead of replacing them with an empty section.
	var incoming: Dictionary = data.duplicate(true)
	var local_data: Dictionary = _read_save_file(_get_save_path())
	var incoming_flags: Variant = incoming.get("ui_tutorials", {})
	var local_flags: Variant = local_data.get("ui_tutorials", {})

	if not (incoming_flags is Dictionary):
		incoming_flags = {}
	if not (local_flags is Dictionary):
		local_flags = {}

	var merged_flags: Dictionary = (incoming_flags as Dictionary).duplicate(true)
	for tutorial_id: Variant in (local_flags as Dictionary).keys():
		# Once this account has seen a tutorial, keep it marked seen when an old
		# cloud save has no value for that tutorial.
		if bool((local_flags as Dictionary).get(tutorial_id, false)):
			merged_flags[str(tutorial_id)] = true
	incoming["ui_tutorials"] = merged_flags
	super.write_raw_save_data(incoming)
