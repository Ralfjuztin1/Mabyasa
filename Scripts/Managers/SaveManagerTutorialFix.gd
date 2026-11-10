extends "res://Scripts/Managers/SaveManager.gd"

## Account-save bridge for UITutorialManager and paired assessments.
## Assign this script to the autoload named SaveManager.

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
	var final_tutorial_status: bool = bool(existing_data.get("tutorial_completed", false)) or tutorial_done
	var normalized_scene_path: String = _normalize_scene_path(current_scene_path)

	var language_data: Dictionary = {}
	if is_instance_valid(LanguageProgress):
		language_data = LanguageProgress.get_save_data()

	var ui_tutorial_data: Dictionary = {}
	if is_instance_valid(UITutorialManager) and UITutorialManager.has_method("get_save_data"):
		ui_tutorial_data = UITutorialManager.get_save_data()
	elif existing_data.get("ui_tutorials", {}) is Dictionary:
		ui_tutorial_data = (existing_data.get("ui_tutorials", {}) as Dictionary).duplicate(true)

	var saved_settings: Dictionary = {}
	if existing_data.get("settings", {}) is Dictionary:
		saved_settings = (existing_data.get("settings", {}) as Dictionary).duplicate(true)

	var saved_assessment_progress: Dictionary = {}
	if existing_data.get("assessment_progress", {}) is Dictionary:
		saved_assessment_progress = (existing_data.get("assessment_progress", {}) as Dictionary).duplicate(true)

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
		"inventory": InventoryManager.get_save_data() if is_instance_valid(InventoryManager) else {},
		"settings": saved_settings,
		"assessment_progress": saved_assessment_progress
	}

	if not _write_json_file(file_path, game_data):
		return

	if is_instance_valid(SupabaseManager):
		SupabaseManager.sync_save_to_cloud(game_data)

	print("[SAVE MANAGER] Account save completed, including tutorial flags and assessments: ", file_path)


func load_game() -> Dictionary:
	var data: Dictionary = super.load_game()
	var ui_tutorial_data: Variant = data.get("ui_tutorials", {})
	if not (ui_tutorial_data is Dictionary):
		ui_tutorial_data = {}

	if is_instance_valid(UITutorialManager) and UITutorialManager.has_method("load_save_data"):
		UITutorialManager.load_save_data(ui_tutorial_data)
	return data


func write_raw_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Merge locally first. The parent knows how to preserve old settings/progression.
	var incoming: Dictionary = data.duplicate(true)
	var local_data: Dictionary = _read_save_file(_get_save_path())

	var incoming_flags: Dictionary = {}
	if incoming.get("ui_tutorials", {}) is Dictionary:
		incoming_flags = (incoming.get("ui_tutorials", {}) as Dictionary).duplicate(true)
	var local_flags: Dictionary = {}
	if local_data.get("ui_tutorials", {}) is Dictionary:
		local_flags = (local_data.get("ui_tutorials", {}) as Dictionary).duplicate(true)

	for tutorial_id: Variant in local_flags.keys():
		if bool(local_flags.get(tutorial_id, false)):
			incoming_flags[str(tutorial_id)] = true
	incoming["ui_tutorials"] = incoming_flags

	var incoming_assessment: Variant = incoming.get("assessment_progress", null)
	var local_assessment: Variant = local_data.get("assessment_progress", {})
	if local_assessment is Dictionary:
		if not (incoming_assessment is Dictionary):
			incoming["assessment_progress"] = (local_assessment as Dictionary).duplicate(true)
		elif (incoming_assessment as Dictionary).is_empty():
			incoming["assessment_progress"] = (local_assessment as Dictionary).duplicate(true)
		else:
			var merged_assessment: Dictionary = (local_assessment as Dictionary).duplicate(true)
			merged_assessment.merge(incoming_assessment as Dictionary, true)
			incoming["assessment_progress"] = merged_assessment

	# Parent cloud merge can preserve settings and progression; the sections above
	# are present in incoming so they survive even for old cloud saves.
	super.write_raw_save_data(incoming)


func get_assessment_progress() -> Dictionary:
	var save_data: Dictionary = _read_save_file(_get_save_path())
	var progress: Variant = save_data.get("assessment_progress", {})
	if progress is Dictionary:
		return (progress as Dictionary).duplicate(true)
	return {}


func save_assessment_progress(progress: Dictionary) -> bool:
	if not _has_authenticated_account():
		push_error("[ASSESSMENT] No authenticated account; baseline not saved.")
		return false

	var account_id: String = str(SupabaseManager.current_user_id)
	var file_path: String = _get_save_path()
	var save_data: Dictionary = _read_save_file(file_path)
	save_data["assessment_progress"] = progress.duplicate(true)

	if not _write_json_file(file_path, save_data):
		return false

	if is_instance_valid(SupabaseManager) and str(SupabaseManager.current_user_id) == account_id:
		SupabaseManager.sync_save_to_cloud(save_data)
	print("[ASSESSMENT] Progress saved for authenticated account.")
	return true


func save_pre_assessment_report(report: Dictionary) -> bool:
	var progress: Dictionary = get_assessment_progress()
	# Preserve the original baseline rather than silently replacing it.
	if bool(progress.get("pre_assessment_completed", false)) or has_pre_assessment():
		push_warning("[ASSESSMENT] Baseline already exists; keeping original result.")
		return true
	progress["pre_assessment_report"] = report.duplicate(true)
	progress["pre_assessment"] = report.duplicate(true) # Compatibility with earlier paired scripts.
	progress["pre_assessment_completed"] = true
	progress["pre_assessment_date"] = Time.get_datetime_string_from_system()
	return save_assessment_progress(progress)


func get_pre_assessment_report() -> Dictionary:
	var progress: Dictionary = get_assessment_progress()
	var report: Variant = progress.get("pre_assessment_report", progress.get("pre_assessment", {}))
	if report is Dictionary:
		return (report as Dictionary).duplicate(true)
	return {}


func has_pre_assessment() -> bool:
	return not get_pre_assessment_report().is_empty()


func record_boss_assessment_attempt(report: Dictionary, victory: bool) -> Dictionary:
	var progress: Dictionary = get_assessment_progress()
	var attempts: Array = []
	if progress.get("boss_attempts", []) is Array:
		attempts = (progress.get("boss_attempts", []) as Array).duplicate(true)

	var attempt: Dictionary = {
		"attempt_number": attempts.size() + 1,
		"victory": victory,
		"date": Time.get_datetime_string_from_system(),
		"report": report.duplicate(true)
	}
	attempts.append(attempt)
	progress["boss_attempts"] = attempts
	if attempts.size() == 1:
		progress["official_post_assessment"] = report.duplicate(true)
		progress["official_post_victory"] = victory

	if not save_assessment_progress(progress):
		return {}
	return attempt


func get_boss_assessment_attempts() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var progress: Dictionary = get_assessment_progress()
	var attempts: Variant = progress.get("boss_attempts", [])
	if attempts is Array:
		for item: Variant in attempts:
			if item is Dictionary:
				output.append((item as Dictionary).duplicate(true))
	return output


func mark_official_post_email_sent() -> bool:
	var progress: Dictionary = get_assessment_progress()
	if not progress.has("official_post_assessment"):
		push_warning("[ASSESSMENT] No official boss report to mark as emailed.")
		return false
	progress["official_post_email_sent"] = true
	progress["official_post_email_sent_at"] = Time.get_datetime_string_from_system()
	return save_assessment_progress(progress)


func is_official_post_email_sent() -> bool:
	return bool(get_assessment_progress().get("official_post_email_sent", false))
