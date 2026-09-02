extends Node

# Generates a unique save file path based on the logged-in Supabase user email
func _get_save_path() -> String:
	var user_id = "guest"
	if SupabaseManager and not SupabaseManager.current_user_email.is_empty():
		user_id = SupabaseManager.current_user_email.replace("@", "_at_").replace(".", "_")
	
	return "user://save_" + user_id + ".json"

func save_game(player: CharacterBody3D, current_scene_path: String, tutorial_done: bool = false) -> void:
	if not is_instance_valid(player):
		return

	# Load existing data first so we don't overwrite flags like tutorial_completed
	var existing_data = load_game()
	var final_tutorial_status = tutorial_done
	
	if not existing_data.is_empty():
		# Once tutorial_completed is true, it stays true forever (prevents false overwrites)
		var previous_status = existing_data.get("tutorial_completed", false)
		final_tutorial_status = previous_status or tutorial_done

	var game_data = {
		"tutorial_completed": final_tutorial_status,
		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"current_scene": current_scene_path
	}

	var file_path = _get_save_path()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(game_data)
		file.store_string(json_string)
		
		print("💾 [SAVE MANAGER] Game successfully saved!")
		print("   ├── Target User File:     ", file_path)
		print("   ├── Tutorial Completed?:  ", final_tutorial_status)
		print("   ├── Saved Scene Path:     ", current_scene_path)
		print("   └── Saved Position:       ", player.global_position)
	else:
		push_error("Failed to open save file for writing: " + file_path)

func load_game() -> Dictionary:
	var file_path = _get_save_path()
	
	if not FileAccess.file_exists(file_path):
		print("📂 [SAVE MANAGER] No save file found for user at: ", file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		
		if error == OK:
			var data = json.get_data()
			# --- DEBUG CONSOLE LOG ---
			print("📂 [SAVE MANAGER] Save file loaded successfully!")
			print("   ├── File Path:  ", file_path)
			print("   ├── Map Scene:  ", data.get("current_scene", "Unknown"))
			print("   └── Coordinates:", data.get("player_position", "Unknown"))
			return data
		else:
			push_error("JSON Parse Error on save file: ", json.get_error_message())
			
	return {}

func has_save() -> bool:
	return FileAccess.file_exists(_get_save_path())
