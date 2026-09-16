extends Node


func _get_save_path() -> String:
	var user_id: String = "guest"

	if GameManager and not GameManager.active_user_email.is_empty():
		user_id = GameManager.active_user_email \
			.replace("@", "_at_") \
			.replace(".", "_")

	return "user://save_" + user_id + ".json"


# ============================================================
# SAVE GAME
# ============================================================

func save_game(
	player: CharacterBody3D,
	current_scene_path: String,
	tutorial_done: bool = false
) -> void:

	if not is_instance_valid(player):
		push_warning(
			"[SAVE MANAGER] Cannot save: player is invalid."
		)
		return


	var file_path := _get_save_path()

	# Read the existing JSON WITHOUT calling load_game().
	# load_game() restores manager state, which must NOT happen
	# during a save.
	var existing_data: Dictionary = _read_save_file(file_path)


	# Preserve previously completed tutorial state.
	var previous_tutorial_status: bool = existing_data.get(
		"tutorial_completed",
		false
	)

	var final_tutorial_status: bool = (
		previous_tutorial_status
		or tutorial_done
	)


	# Build the new save data from CURRENT runtime state.
	var game_data: Dictionary = {
		"tutorial_completed": final_tutorial_status,

		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},

		"current_scene": current_scene_path,

		"progression":
			PlayerProgression.get_save_data()
			if PlayerProgression
			else {},

		"time":
			TimeManager.get_save_data()
			if TimeManager
			else {},

		"quests":
			QuestManager.get_save_data()
			if QuestManager
			else {}
	}


	var file := FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"[SAVE MANAGER] Failed to open save file for writing: "
			+ file_path
		)
		return


	var json_string := JSON.stringify(
		game_data,
		"\t"
	)

	file.store_string(json_string)
	file.close()


	print("💾 [SAVE MANAGER] Game successfully saved!")
	print("   ├── Target User File:     ", file_path)
	print("   ├── Tutorial Completed?:  ", final_tutorial_status)
	print("   ├── Saved Scene Path:     ", current_scene_path)
	print("   └── Saved Position:       ", player.global_position)


	# Useful quest debug information.
	if QuestManager:
		var quest_save_data: Dictionary = (
			QuestManager.get_save_data()
		)

		print(
			"   ├── Active Quests:        ",
			quest_save_data.get("active_quests", {})
		)

		print(
			"   └── Completed Quests:     ",
			quest_save_data.get("completed_quests", [])
		)


# ============================================================
# READ SAVE FILE ONLY
# ============================================================

func _read_save_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}


	var file := FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		return {}


	var json_text := file.get_as_text()
	file.close()


	if json_text.is_empty():
		return {}


	var json := JSON.new()
	var error := json.parse(json_text)

	if error != OK:
		push_error(
			"[SAVE MANAGER] Existing save JSON is invalid: "
			+ json.get_error_message()
		)

		return {}


	var data = json.get_data()

	if data is Dictionary:
		return data

	return {}


# ============================================================
# LOAD GAME
# ============================================================

func load_game() -> Dictionary:
	var file_path := _get_save_path()

	if not FileAccess.file_exists(file_path):
		print(
			"📂 [SAVE MANAGER] No save file found for user at: ",
			file_path
		)

		return {}


	var data := _read_save_file(file_path)

	if data.is_empty():
		return {}


	# Restore manager states ONLY when explicitly loading.
	if (
		data.has("progression")
		and PlayerProgression
	):
		PlayerProgression.load_save_data(
			data["progression"]
		)


	if (
		data.has("time")
		and TimeManager
	):
		TimeManager.load_save_data(
			data["time"]
		)


	if (
		data.has("quests")
		and QuestManager
	):
		QuestManager.load_save_data(
			data["quests"]
		)


	print("📂 [SAVE MANAGER] Save file loaded successfully!")
	print("   ├── File Path:  ", file_path)
	print(
		"   ├── Map Scene:  ",
		data.get("current_scene", "Unknown")
	)
	print(
		"   └── Coordinates:",
		data.get("player_position", "Unknown")
	)


	if data.has("quests"):
		var quest_data = data["quests"]

		print(
			"   ├── Active Quests:    ",
			quest_data.get("active_quests", {})
		)

		print(
			"   └── Completed Quests: ",
			quest_data.get("completed_quests", [])
		)


	return data


# ============================================================
# CHECK SAVE
# ============================================================

func has_save() -> bool:
	return FileAccess.file_exists(
		_get_save_path()
	)
