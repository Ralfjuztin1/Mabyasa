extends "res://Scripts/Managers/SaveManager.gd"

## SaveManager extension that preserves paired-assessment data when normal
## gameplay saves and cloud saves are written.

const ASSESSMENT_BOSS_ID: String = "forest_ylang_guardian"

func save_game(player: CharacterBody3D, current_scene_path: String, tutorial_done: bool = false) -> void:
	var assessment_progress := get_assessment_progress()
	super.save_game(player, current_scene_path, tutorial_done)
	if not assessment_progress.is_empty():
		_write_assessment_progress(assessment_progress)


func write_raw_save_data(data: Dictionary) -> void:
	var local_progress := get_assessment_progress()
	var incoming_value: Variant = data.get("assessment_progress", {})
	var incoming_progress: Dictionary = {}
	if incoming_value is Dictionary:
		incoming_progress = (incoming_value as Dictionary).duplicate(true)

	super.write_raw_save_data(data)

	# Keep the local assessment when an older cloud save has no assessment data.
	if incoming_progress.is_empty():
		incoming_progress = local_progress

	if not incoming_progress.is_empty():
		_write_assessment_progress(incoming_progress)


func get_assessment_progress() -> Dictionary:
	var data := _read_save_file(_get_save_path())
	var value: Variant = data.get("assessment_progress", {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func save_assessment_progress(progress: Dictionary) -> bool:
	var merged := get_assessment_progress()
	for key: Variant in progress.keys():
		merged[str(key)] = progress[key]
	merged["last_updated"] = Time.get_datetime_string_from_system(true)

	return _write_assessment_progress(merged)


func _write_assessment_progress(progress: Dictionary) -> bool:
	var path: String = _get_save_path()
	var data := _read_save_file(path)
	data["assessment_progress"] = progress.duplicate(true)

	if not _write_json_file(path, data):
		return false

	if is_instance_valid(SupabaseManager):
		SupabaseManager.sync_save_to_cloud(data)

	print("[ASSESSMENT SAVE] Assessment data saved.")
	return true


func save_pre_assessment_report(report: Dictionary) -> bool:
	var progress := get_assessment_progress()
	progress["pre_assessment"] = report.duplicate(true)
	progress["pre_assessment_completed"] = true
	progress["pre_assessment_date"] = Time.get_datetime_string_from_system(true)
	return save_assessment_progress(progress)


func get_pre_assessment_report() -> Dictionary:
	var progress := get_assessment_progress()
	var value: Variant = progress.get("pre_assessment", {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func has_pre_assessment() -> bool:
	return not get_pre_assessment_report().is_empty()


func record_boss_assessment_attempt(report: Dictionary, victory: bool) -> Dictionary:
	var progress := get_assessment_progress()
	var attempts: Array = []
	var raw_attempts: Variant = progress.get("boss_attempts", [])

	if raw_attempts is Array:
		attempts = (raw_attempts as Array).duplicate(true)

	var attempt_number: int = attempts.size() + 1
	var attempt_data := {
		"attempt_number": attempt_number,
		"victory": victory,
		"date": Time.get_datetime_string_from_system(true),
		"report": report.duplicate(true)
	}

	attempts.append(attempt_data)
	progress["boss_attempts"] = attempts

	# The first completed boss attempt is the official post-assessment.
	if attempt_number == 1:
		progress["official_post_assessment"] = report.duplicate(true)
		progress["official_post_victory"] = victory

	save_assessment_progress(progress)
	return attempt_data


func get_boss_assessment_attempts() -> Array[Dictionary]:
	var progress := get_assessment_progress()
	var raw_attempts: Variant = progress.get("boss_attempts", [])
	var result: Array[Dictionary] = []

	if not raw_attempts is Array:
		return result

	for raw_attempt: Variant in raw_attempts:
		if raw_attempt is Dictionary:
			result.append((raw_attempt as Dictionary).duplicate(true))

	return result
