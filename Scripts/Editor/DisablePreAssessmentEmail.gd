@tool
extends EditorScript

# Run once from the Godot Script Editor (File -> Run).
# Modifies ONLY Scripts/Assessment/PreAssessment.gd and makes a .bak backup.
# Questions, saved pre-test data, and both Guardian email flows remain unchanged.

const TARGET: String = "res://Scripts/Assessment/PreAssessment.gd"
const PATCH_MARKER: String = "# MABIYASA_PRE_EMAIL_DISABLED_V1"

func _run() -> void:
	if not FileAccess.file_exists(TARGET):
		push_error("Missing pre-assessment script: " + TARGET)
		return
	var original: String = FileAccess.get_file_as_string(TARGET)
	if original.contains(PATCH_MARKER):
		print("[PRE-ASSESSMENT] Email removal already installed.")
		return
	if not original.contains("const TOTAL_QUESTIONS: int = 20"):
		push_error("This update expects the existing 20-question pre-test. No changes made.")
		return

	var edited: String = original
	# No email request or long wait on initial successful save.
	edited = _replace_block(edited,
		"\tif SaveManager.save_pre_assessment_report(_report):",
		"\n\nfunc _show_save_error()",
		"\tif SaveManager.save_pre_assessment_report(_report):\n" +
		"\t\t_saved_successfully = true\n" +
		"\t\t_show_pre_completion()\n" +
		"\telse:\n" +
		"\t\t_show_save_error()")
	if edited.is_empty(): return

	# The retry button should only retry saving, never send an email.
	edited = _replace_block(edited,
		"func _retry_baseline_save() -> void:",
		"\n\nfunc _show_pre_completion()",
		"func _retry_baseline_save() -> void:\n" +
		"\tif _saved_successfully:\n" +
		"\t\treturn\n" +
		"\tif SaveManager.save_pre_assessment_report(_report):\n" +
		"\t\t_saved_successfully = true\n" +
		"\t\t_show_pre_completion()\n" +
		"\telse:\n" +
		"\t\t_show_save_error()")
	if edited.is_empty(): return

	# Remove the delivery panel and allow the player to continue after save.
	edited = _replace_block(edited,
		"\tvar email_parts: Dictionary = _make_baseline_box()",
		"\tcall_deferred(\"_reset_baseline_scroll\")",
		"\t_pre_continue_button = _make_button(\"CONTINUE TO FIRST TOWN\", close, 240.0)\n" +
		"\t_pre_continue_button.disabled = false\n")
	if edited.is_empty(): return

	# Never invoke the parent's email sender from the pre-assessment scene.
	var close_anchor: String = "\n\nfunc close() -> void:"
	if not edited.contains(close_anchor):
		push_error("Could not find close() anchor. No changes made.")
		return
	edited = edited.replace(close_anchor,
		"\n\n" + PATCH_MARKER + "\n" +
		"func _send_email_report() -> void:\n" +
		"\treturn\n" + close_anchor)

	if edited.contains("await _send_email_report()") or edited.contains("EMAIL DELIVERY") or edited.contains("RETRY EMAIL"):
		push_error("Pre-assessment still contains email UI or calls. No changes made.")
		return
	if not edited.contains("NUMBER_BANK.build_questions()") or not edited.contains("SaveManager.save_pre_assessment_report(_report)"):
		push_error("Baseline question/save integrity check failed. No changes made.")
		return

	var backup_path: String = TARGET + ".before_email_removal.bak"
	if not FileAccess.file_exists(backup_path):
		var backup: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
		if backup == null:
			push_error("Backup failed. No changes made.")
			return
		backup.store_string(original)
		backup.close()

	var file: FileAccess = FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not update pre-assessment script.")
		return
	file.store_string(edited)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	print("[PRE-ASSESSMENT] Email disabled. Results still saved; 20 questions unchanged.")

func _replace_block(source: String, from_token: String, to_token: String, replacement: String) -> String:
	var start_index: int = source.find(from_token)
	var end_index: int = source.find(to_token, start_index)
	if start_index < 0 or end_index < 0:
		push_error("Pre-assessment differs from expected file. No changes made. Missing anchor: " + from_token.left(90))
		return ""
	return source.substr(0, start_index) + replacement + source.substr(end_index)
