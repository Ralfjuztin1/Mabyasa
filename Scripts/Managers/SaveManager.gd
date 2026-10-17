extends Node

const BOOT_SCENE_PATH: String = "res://Scenes/SceneManager/Main.tscn"
const FIRST_TOWN_PATH: String = "res://Scenes/Main/FirstTown.tscn"


func _get_save_path() -> String:
	var user_key: String = ""

	if is_instance_valid(SupabaseManager) and not str(SupabaseManager.current_user_id).is_empty():
		user_key = str(SupabaseManager.current_user_id)
	elif is_instance_valid(GameManager) and not GameManager.active_user_email.is_empty():
		user_key = GameManager.active_user_email.replace("@", "_at_").replace(".", "_")
	else:
		user_key = "guest"

	return "user://save_account_" + user_key + ".json"


func _has_authenticated_account() -> bool:
	return is_instance_valid(SupabaseManager) and not str(SupabaseManager.current_user_id).is_empty()


func _normalize_scene_path(scene_path: String) -> String:
	if scene_path == BOOT_SCENE_PATH:
		print("[SAVE MANAGER] Converting Main.tscn save path to FirstTown.tscn.")
		return FIRST_TOWN_PATH
	return scene_path


func _normalize_save_data(data: Dictionary) -> Dictionary:
	var normalized_data: Dictionary = data.duplicate(true)
	if normalized_data.has("current_scene") and normalized_data["current_scene"] is String:
		normalized_data["current_scene"] = _normalize_scene_path(str(normalized_data["current_scene"]))
	return normalized_data


func save_game(player: CharacterBody3D, current_scene_path: String, tutorial_done: bool = false) -> void:
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

	var saved_settings: Dictionary = {}
	var saved_settings_value: Variant = existing_data.get("settings", {})
	if saved_settings_value is Dictionary:
		saved_settings = (saved_settings_value as Dictionary).duplicate(true)

	var game_data: Dictionary = {
		"tutorial_completed": final_tutorial_status,
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
		"inventory": InventoryManager.get_save_data() if is_instance_valid(InventoryManager) else {},
		# Preserve preferences when ordinary gameplay progress is saved.
		"settings": saved_settings
	}

	if not _write_json_file(file_path, game_data):
		return

	if is_instance_valid(SupabaseManager):
		SupabaseManager.sync_save_to_cloud(game_data)

	print("[SAVE MANAGER] Account save completed: ", file_path)
	print("[SAVE MANAGER] Tutorial: ", final_tutorial_status)
	print("[SAVE MANAGER] Scene: ", normalized_scene_path)
	print("[SAVE MANAGER] Language entries: ", language_data.get("learned", []).size())


func _read_save_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json_text: String = file.get_as_text()
	file.close()
	if json_text.is_empty():
		return {}

	var json := JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		push_error("[SAVE MANAGER] Invalid JSON: " + json.get_error_message())
		return {}

	var raw_data: Variant = json.get_data()
	if raw_data is Dictionary:
		return (raw_data as Dictionary)
	return {}


func _write_json_file(file_path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SAVE MANAGER] Failed to open: " + file_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


# These settings are part of the authenticated account's regular save JSON.
# The game does not read or write a shared ConfigFile for settings.
func load_settings_data() -> Dictionary:
	if not _has_authenticated_account():
		return {}

	var account_data: Dictionary = _read_save_file(_get_save_path())
	var settings_value: Variant = account_data.get("settings", {})
	if settings_value is Dictionary:
		return (settings_value as Dictionary).duplicate(true)
	return {}


func save_settings_data(settings_data: Dictionary, sync_cloud: bool = true) -> void:
	if not _has_authenticated_account():
		push_warning("[SAVE MANAGER] Settings were not saved because no authenticated account is active.")
		return

	var account_id: String = str(SupabaseManager.current_user_id)
	var file_path: String = _get_save_path()
	var account_data: Dictionary = _read_save_file(file_path)
	account_data["settings"] = settings_data.duplicate(true)

	if not _write_json_file(file_path, account_data):
		return

	# The full save row is sent so this does not overwrite the player's progress
	# with a settings-only object. SupabaseManager checks account ID before upload.
	if sync_cloud and is_instance_valid(SupabaseManager) and str(SupabaseManager.current_user_id) == account_id:
		SupabaseManager.sync_save_to_cloud(account_data)


func write_raw_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	var cloud_data: Dictionary = _normalize_save_data(data)
	var file_path: String = _get_save_path()
	var local_data: Dictionary = _read_save_file(file_path)
	var merged_data: Dictionary = cloud_data.duplicate(true)

	# Preserve local sections when a cloud save predates that section or has
	# an empty dictionary where this device already has account data.
	var sections: Array[String] = ["progression", "language", "time", "quests", "inventory", "settings"]
	for section: String in sections:
		var local_section: Variant = local_data.get(section, null)
		var cloud_section: Variant = cloud_data.get(section, null)

		if cloud_section == null:
			if local_section != null:
				merged_data[section] = local_section
			continue

		if cloud_section is Dictionary and local_section is Dictionary:
			if (cloud_section as Dictionary).is_empty() and not (local_section as Dictionary).is_empty():
				merged_data[section] = local_section

	if bool(local_data.get("tutorial_completed", false)) and not bool(merged_data.get("tutorial_completed", false)):
		merged_data["tutorial_completed"] = true

	if _write_json_file(file_path, merged_data):
		print("[SAVE MANAGER] Cloud save merged into account cache: ", file_path)


func load_game() -> Dictionary:
	var file_path: String = _get_save_path()
	if not FileAccess.file_exists(file_path):
		print("[SAVE MANAGER] No save found for account: ", file_path)
		return {}

	var raw_data: Dictionary = _read_save_file(file_path)
	if raw_data.is_empty():
		return {}
	var data: Dictionary = _normalize_save_data(raw_data)

	if data.has("progression") and is_instance_valid(PlayerProgression):
		var progression_data: Variant = data["progression"]
		if progression_data is Dictionary:
			PlayerProgression.load_save_data(progression_data as Dictionary)

	if data.has("language") and is_instance_valid(LanguageProgress):
		var language_data: Variant = data["language"]
		if language_data is Dictionary:
			LanguageProgress.load_save_data(language_data as Dictionary)
	elif is_instance_valid(LanguageProgress):
		LanguageProgress.load_save_data({})

	if data.has("time") and is_instance_valid(TimeManager):
		var time_data: Variant = data["time"]
		if time_data is Dictionary:
			TimeManager.load_save_data(time_data as Dictionary)

	if data.has("quests") and is_instance_valid(QuestManager):
		var quest_data: Variant = data["quests"]
		if quest_data is Dictionary:
			QuestManager.load_save_data(quest_data as Dictionary)

	if is_instance_valid(InventoryManager):
		var inventory_data: Variant = data.get("inventory", {})
		if inventory_data is Dictionary:
			InventoryManager.load_save_data(inventory_data as Dictionary)

	print("[SAVE MANAGER] Account save loaded: ", file_path)
	print("[SAVE MANAGER] Scene: ", data.get("current_scene", "Unknown"))
	if is_instance_valid(LanguageProgress):
		print("[SAVE MANAGER] Learned vocabulary: ", LanguageProgress.get_learned_entries().size())
	return data


func has_save() -> bool:
	# A preferences-only JSON is not a completed gameplay save. This prevents
	# changing settings on a new account from bypassing its first-time flow.
	var data: Dictionary = _read_save_file(_get_save_path())
	return data.has("current_scene") and data.has("player_position")
