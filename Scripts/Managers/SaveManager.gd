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

	var user_key: String = ""


	# --------------------------------------------------------
	# SUPABASE ACCOUNT ID
	# --------------------------------------------------------

	if (
		SupabaseManager
		and not SupabaseManager.current_user_id.is_empty()
	):

		user_key = (
			SupabaseManager.current_user_id
		)


	# --------------------------------------------------------
	# EMAIL FALLBACK
	# --------------------------------------------------------

	elif (
		GameManager
		and not GameManager.active_user_email.is_empty()
	):

		user_key = (
			GameManager.active_user_email
			.replace("@", "_at_")
			.replace(".", "_")
		)


	# --------------------------------------------------------
	# NO ACCOUNT
	# --------------------------------------------------------

	else:

		user_key = "guest"


	return (
		"user://save_account_"
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

	if data.is_empty():
		return


	var cloud_data: Dictionary = (
		_normalize_save_data(
			data
		)
	)


	var file_path: String = (
		_get_save_path()
	)


	# --------------------------------------------------------
	# READ EXISTING LOCAL ACCOUNT SAVE
	# --------------------------------------------------------

	var local_data: Dictionary = (
		_read_save_file(
			file_path
		)
	)


	# --------------------------------------------------------
	# MERGE CLOUD + LOCAL
	# --------------------------------------------------------
	#
	# Cloud remains the main source.
	# But if the cloud save is missing data that already exists
	# locally, preserve the local data instead of destroying it.
	#
	# This is especially important for language progress.
	# --------------------------------------------------------

	var merged_data: Dictionary = (
		cloud_data.duplicate(true)
	)


	var sections: Array[String] = [
		"progression",
		"language",
		"time",
		"quests"
	]


	for section: String in sections:

		var local_section: Variant = (
			local_data.get(
				section,
				null
			)
		)


		var cloud_section: Variant = (
			cloud_data.get(
				section,
				null
			)
		)


		# Section missing from cloud.
		if cloud_section == null:

			if local_section != null:

				merged_data[section] = (
					local_section
				)

			continue


		# Language/progression/etc. exists locally but cloud has
		# an empty dictionary. Preserve local progress.
		if (
			cloud_section is Dictionary
			and local_section is Dictionary
			and (cloud_section as Dictionary).is_empty()
			and not (local_section as Dictionary).is_empty()
		):

			merged_data[section] = (
				local_section
			)


	# --------------------------------------------------------
	# TUTORIAL
	# --------------------------------------------------------

	if (
		local_data.has("tutorial_completed")
		and bool(
			local_data["tutorial_completed"]
		)
		and not bool(
			merged_data.get(
				"tutorial_completed",
				false
			)
		)
	):

		merged_data["tutorial_completed"] = true


	# --------------------------------------------------------
	# WRITE MERGED ACCOUNT SAVE
	# --------------------------------------------------------

	var file: FileAccess = (
		FileAccess.open(
			file_path,
			FileAccess.WRITE
		)
	)


	if file == null:

		push_error(
			"[SAVE MANAGER] Failed to write merged cloud "
			+ "save to local cache."
		)

		return


	file.store_string(
		JSON.stringify(
			merged_data,
			"\t"
		)
	)

	file.close()


	print(
		"☁️ [SAVE MANAGER] Cloud save merged into "
		+ "local account cache."
	)

	print(
		"   └── Preserved local language: ",
		merged_data.has("language")
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
