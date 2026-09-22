extends Node


# ============================================================
# SCENE PATHS
# ============================================================

const BOOT_SCENE_PATH := "res://Scenes/SceneManager/Main.tscn"
const FIRST_TOWN_PATH := "res://Scenes/Main/FirstTown.tscn"


# ============================================================
# SAVE PATH
# ============================================================

func _get_save_path() -> String:

	var user_id: String = "guest"

	if GameManager and not GameManager.active_user_email.is_empty():

		user_id = GameManager.active_user_email \
			.replace("@", "_at_") \
			.replace(".", "_")

	return "user://save_" + user_id + ".json"


# ============================================================
# NORMALIZE SCENE PATH
# ============================================================

func _normalize_scene_path(
	scene_path: String
) -> String:

	if scene_path == BOOT_SCENE_PATH:

		print(
			"⚠️ [SAVE MANAGER] Converting Main.tscn save path "
			+ "to FirstTown.tscn."
		)

		return FIRST_TOWN_PATH

	return scene_path


# ============================================================
# NORMALIZE SAVE DATA
# ============================================================

func _normalize_save_data(
	data: Dictionary
) -> Dictionary:

	var normalized_data: Dictionary = data.duplicate(
		true
	)

	if (
		normalized_data.has("current_scene")
		and normalized_data["current_scene"] is String
	):

		normalized_data["current_scene"] = (
			_normalize_scene_path(
				normalized_data["current_scene"]
			)
		)

	return normalized_data


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

	# --------------------------------------------------------
	# READ EXISTING DATA
	# --------------------------------------------------------

	var existing_data: Dictionary = _read_save_file(
		file_path
	)

	# --------------------------------------------------------
	# TUTORIAL STATE
	# --------------------------------------------------------

	var previous_tutorial_status: bool = (
		existing_data.get(
			"tutorial_completed",
			false
		)
	)

	var final_tutorial_status: bool = (
		previous_tutorial_status
		or tutorial_done
	)

	# --------------------------------------------------------
	# NORMALIZE SCENE PATH
	# --------------------------------------------------------

	var normalized_scene_path := (
		_normalize_scene_path(
			current_scene_path
		)
	)

	# --------------------------------------------------------
	# BUILD SAVE DATA
	# --------------------------------------------------------

	var game_data: Dictionary = {

		"tutorial_completed":
			final_tutorial_status,

		"player_position": {

			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},

		"current_scene":
			normalized_scene_path,

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

	# --------------------------------------------------------
	# WRITE LOCAL SAVE
	# --------------------------------------------------------

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

	file.store_string(
		json_string
	)

	file.close()

	# --------------------------------------------------------
	# CLOUD SAVE
	# --------------------------------------------------------

	if SupabaseManager:

		SupabaseManager.sync_save_to_cloud(
			game_data
		)

	# --------------------------------------------------------
	# DEBUG
	# --------------------------------------------------------

	print(
		"💾 [SAVE MANAGER] Game successfully saved!"
	)

	print(
		"   ├── Target User File:     ",
		file_path
	)

	print(
		"   ├── Tutorial Completed?:  ",
		final_tutorial_status
	)

	print(
		"   ├── Saved Scene Path:     ",
		normalized_scene_path
	)

	print(
		"   └── Saved Position:       ",
		player.global_position
	)

	# --------------------------------------------------------
	# QUEST DEBUG
	# --------------------------------------------------------

	if QuestManager:

		var quest_save_data: Dictionary = (
			QuestManager.get_save_data()
		)

		print(
			"   ├── Active Quests:        ",
			quest_save_data.get(
				"active_quests",
				{}
			)
		)

		print(
			"   └── Completed Quests:     ",
			quest_save_data.get(
				"completed_quests",
				[]
			)
		)


# ============================================================
# READ SAVE FILE ONLY
# ============================================================

func _read_save_file(
	file_path: String
) -> Dictionary:

	if not FileAccess.file_exists(
		file_path
	):

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

	var error := json.parse(
		json_text
	)

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
# WRITE RAW SAVE DATA
# ============================================================

func write_raw_save_data(
	data: Dictionary
) -> void:

	var normalized_data := _normalize_save_data(
		data
	)

	var file_path := _get_save_path()

	var file := FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if file == null:

		push_error(
			"[SAVE MANAGER] Failed to open save file for cloud write: "
			+ file_path
		)

		return

	file.store_string(
		JSON.stringify(
			normalized_data,
			"\t"
		)
	)

	file.close()

	print(
		"☁️ [SAVE MANAGER] Cloud save written to local cache: ",
		file_path
	)


# ============================================================
# LOAD GAME
# ============================================================

func load_game() -> Dictionary:

	var file_path := _get_save_path()

	if not FileAccess.file_exists(
		file_path
	):

		print(
			"📂 [SAVE MANAGER] No save file found for user at: ",
			file_path
		)

		return {}

	var raw_data := _read_save_file(
		file_path
	)

	if raw_data.is_empty():
		return {}

	# --------------------------------------------------------
	# NORMALIZE OLD SAVE
	# --------------------------------------------------------

	var data := _normalize_save_data(
		raw_data
	)

	# --------------------------------------------------------
	# RESTORE PROGRESSION
	# --------------------------------------------------------

	if (
		data.has("progression")
		and PlayerProgression
	):

		PlayerProgression.load_save_data(
			data["progression"]
		)

	# --------------------------------------------------------
	# RESTORE TIME
	# --------------------------------------------------------

	if (
		data.has("time")
		and TimeManager
	):

		TimeManager.load_save_data(
			data["time"]
		)

	# --------------------------------------------------------
	# RESTORE QUESTS
	# --------------------------------------------------------

	if (
		data.has("quests")
		and QuestManager
	):

		QuestManager.load_save_data(
			data["quests"]
		)

	# --------------------------------------------------------
	# DEBUG
	# --------------------------------------------------------

	print(
		"📂 [SAVE MANAGER] Save file loaded successfully!"
	)

	print(
		"   ├── File Path:  ",
		file_path
	)

	print(
		"   ├── Map Scene:  ",
		data.get(
			"current_scene",
			"Unknown"
		)
	)

	print(
		"   └── Coordinates:",
		data.get(
			"player_position",
			"Unknown"
		)
	)

	# --------------------------------------------------------
	# QUEST DEBUG
	# --------------------------------------------------------

	if data.has("quests"):

		var quest_data = data["quests"]

		print(
			"   ├── Active Quests:    ",
			quest_data.get(
				"active_quests",
				{}
			)
		)

		print(
			"   └── Completed Quests: ",
			quest_data.get(
				"completed_quests",
				[]
			)
		)

	return data


# ============================================================
# CHECK SAVE
# ============================================================

func has_save() -> bool:

	return FileAccess.file_exists(
		_get_save_path()
	)
