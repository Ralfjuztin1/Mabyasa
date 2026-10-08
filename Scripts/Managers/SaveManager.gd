extends Node


# ============================================================
# SCENE PATHS
# ============================================================

const BOOT_SCENE_PATH: String = (
	"res://Scenes/SceneManager/Main.tscn"
)

const FIRST_TOWN_PATH: String = (
	"res://Scenes/Main/FirstTown.tscn"
)


# ============================================================
# SAVE PATH
# ============================================================

func _get_save_path() -> String:

	var user_key: String = "guest"

	if (
		GameManager
		and not GameManager.active_user_email.is_empty()
	):

		user_key = (
			GameManager.active_user_email
			.replace("@", "_at_")
			.replace(".", "_")
		)

	return (
		"user://save_"
		+ user_key
		+ ".json"
	)


# ============================================================
# NORMALIZE SCENE PATH
# ============================================================

func _normalize_scene_path(
	scene_path: String
) -> String:

	if scene_path == BOOT_SCENE_PATH:

		print(
			"⚠️ [SAVE MANAGER] Converting Main.tscn "
			+ "save path to FirstTown.tscn."
		)

		return FIRST_TOWN_PATH

	return scene_path


# ============================================================
# NORMALIZE SAVE DATA
# ============================================================

func _normalize_save_data(
	data: Dictionary
) -> Dictionary:

	var normalized_data: Dictionary = (
		data.duplicate(true)
	)


	if (
		normalized_data.has(
			"current_scene"
		)
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
			"[SAVE MANAGER] Cannot save: player invalid."
		)

		return


	var file_path: String = (
		_get_save_path()
	)


	# --------------------------------------------------------
	# EXISTING SAVE
	# --------------------------------------------------------

	var existing_data: Dictionary = (
		_read_save_file(
			file_path
		)
	)


	# --------------------------------------------------------
	# TUTORIAL
	# --------------------------------------------------------

	var previous_tutorial_status: bool = (
		bool(
			existing_data.get(
				"tutorial_completed",
				false
			)
		)
	)

	var final_tutorial_status: bool = (
		previous_tutorial_status
		or tutorial_done
	)


	# --------------------------------------------------------
	# SCENE
	# --------------------------------------------------------

	var normalized_scene_path: String = (
		_normalize_scene_path(
			current_scene_path
		)
	)


	# --------------------------------------------------------
	# LANGUAGE
	# --------------------------------------------------------
	#
	# THIS is the important addition.
	#
	# LanguageProgress data is stored inside the same account
	# save as player progression, quests, etc.
	# --------------------------------------------------------

	var language_data: Dictionary = {}

	if LanguageProgress:

		language_data = (
			LanguageProgress.get_save_data()
		)


	# --------------------------------------------------------
	# BUILD ACCOUNT SAVE
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

		"language":
			language_data,

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
	# LOCAL SAVE
	# --------------------------------------------------------

	var file: FileAccess = (
		FileAccess.open(
			file_path,
			FileAccess.WRITE
		)
	)


	if file == null:

		push_error(
			"[SAVE MANAGER] Failed to open: "
			+ file_path
		)

		return


	file.store_string(
		JSON.stringify(
			game_data,
			"\t"
		)
	)

	file.close()


	# --------------------------------------------------------
	# CLOUD SAVE
	# --------------------------------------------------------
	#
	# SupabaseManager handles the cloud account using the
	# authenticated Supabase user_id.
	# --------------------------------------------------------

	if SupabaseManager:

		SupabaseManager.sync_save_to_cloud(
			game_data
		)


	# --------------------------------------------------------
	# DEBUG
	# --------------------------------------------------------

	print(
		"💾 [SAVE MANAGER] Account save completed."
	)

	print(
		"   ├── Local account file: ",
		file_path
	)

	print(
		"   ├── Tutorial: ",
		final_tutorial_status
	)

	print(
		"   ├── Scene: ",
		normalized_scene_path
	)

	print(
		"   └── Language entries: ",
		language_data.get(
			"learned",
			[]
		).size()
	)


# ============================================================
# READ SAVE FILE
# ============================================================

func _read_save_file(
	file_path: String
) -> Dictionary:

	if not FileAccess.file_exists(
		file_path
	):
		return {}


	var file: FileAccess = (
		FileAccess.open(
			file_path,
			FileAccess.READ
		)
	)


	if file == null:
		return {}


	var json_text: String = (
		file.get_as_text()
	)

	file.close()


	if json_text.is_empty():
		return {}


	var json: JSON = JSON.new()

	var error: Error = (
		json.parse(
			json_text
		)
	)


	if error != OK:

		push_error(
			"[SAVE MANAGER] Invalid JSON: "
			+ json.get_error_message()
		)

		return {}


	var raw_data: Variant = (
		json.get_data()
	)


	if raw_data is Dictionary:

		return (
			raw_data as Dictionary
		)


	return {}


# ============================================================
# CLOUD DATA -> LOCAL ACCOUNT CACHE
# ============================================================

func write_raw_save_data(
	data: Dictionary
) -> void:

	var normalized_data: Dictionary = (
		_normalize_save_data(
			data
		)
	)


	var file_path: String = (
		_get_save_path()
	)


	var file: FileAccess = (
		FileAccess.open(
			file_path,
			FileAccess.WRITE
		)
	)


	if file == null:

		push_error(
			"[SAVE MANAGER] Failed to write cloud "
			+ "data to local cache."
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
		"☁️ [SAVE MANAGER] Cloud save restored "
		+ "to local account cache."
	)


# ============================================================
# LOAD GAME
# ============================================================

func load_game() -> Dictionary:

	var file_path: String = (
		_get_save_path()
	)


	if not FileAccess.file_exists(
		file_path
	):

		print(
			"📂 [SAVE MANAGER] No save found for account: ",
			file_path
		)

		return {}


	var raw_data: Dictionary = (
		_read_save_file(
			file_path
		)
	)


	if raw_data.is_empty():
		return {}


	var data: Dictionary = (
		_normalize_save_data(
			raw_data
		)
	)


	# --------------------------------------------------------
	# PLAYER
	# --------------------------------------------------------

	if (
		data.has("progression")
		and PlayerProgression
	):

		var progression_data: Variant = (
			data["progression"]
		)

		if progression_data is Dictionary:

			PlayerProgression.load_save_data(
				progression_data as Dictionary
			)


	# --------------------------------------------------------
	# LANGUAGE
	# --------------------------------------------------------
	#
	# This restores THIS ACCOUNT'S language progress.
	# --------------------------------------------------------

	if (
		data.has("language")
		and LanguageProgress
	):

		var language_data: Variant = (
			data["language"]
		)

		if language_data is Dictionary:

			LanguageProgress.load_save_data(
				language_data as Dictionary
			)

	else:

		# Old save without language data.
		# This account simply starts with no learned vocabulary.
		if LanguageProgress:

			LanguageProgress.load_save_data(
				{}
			)


	# --------------------------------------------------------
	# TIME
	# --------------------------------------------------------

	if (
		data.has("time")
		and TimeManager
	):

		var time_data: Variant = (
			data["time"]
		)

		if time_data is Dictionary:

			TimeManager.load_save_data(
				time_data as Dictionary
			)


	# --------------------------------------------------------
	# QUESTS
	# --------------------------------------------------------

	if (
		data.has("quests")
		and QuestManager
	):

		var quest_data: Variant = (
			data["quests"]
		)

		if quest_data is Dictionary:

			QuestManager.load_save_data(
				quest_data as Dictionary
			)


	# --------------------------------------------------------
	# DEBUG
	# --------------------------------------------------------

	print(
		"📂 [SAVE MANAGER] Account save loaded."
	)

	print(
		"   ├── Account file: ",
		file_path
	)

	print(
		"   ├── Scene: ",
		data.get(
			"current_scene",
			"Unknown"
		)
	)

	if LanguageProgress:

		print(
			"   └── Learned vocabulary: ",
			LanguageProgress.get_learned_entries().size()
		)


	return data


# ============================================================
# CHECK SAVE
# ============================================================

func has_save() -> bool:

	return FileAccess.file_exists(
		_get_save_path()
	)
