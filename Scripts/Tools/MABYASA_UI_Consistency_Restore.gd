@tool
extends EditorScript

## Restore original scene and visual-script files from .before_ui_consistency backups.
## Run from Godot Script editor: File > Run (Ctrl+Shift+X).

const RULES_PATH: String = "res://Scripts/Tools/MABYASA_UI_Consistency_Rules.json"
const BACKUP_SUFFIX: String = ".before_ui_consistency"


func _run() -> void:
	if not FileAccess.file_exists(RULES_PATH):
		push_error("[MABYASA UI RESTORE] Missing rules JSON.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not parsed is Dictionary:
		push_error("[MABYASA UI RESTORE] Invalid rules JSON.")
		return
	var rules: Dictionary = parsed as Dictionary
	var targets: Dictionary = {}
	for category: String in ["scenes", "scripts"]:
		var entries: Dictionary = rules.get(category, {})
		for key: Variant in entries.keys():
			targets[str(key)] = true

	var restored: int = 0
	for path_value: Variant in targets.keys():
		var path: String = "res://" + str(path_value)
		var backup_path: String = path + BACKUP_SUFFIX
		if not FileAccess.file_exists(backup_path):
			continue
		var original: String = FileAccess.get_file_as_string(backup_path)
		var target_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if target_file == null:
			push_error("[MABYASA UI RESTORE] Could not restore " + path)
			continue
		target_file.store_string(original)
		target_file.close()
		restored += 1
		print("[MABYASA UI RESTORE] Restored: ", path)
	print("[MABYASA UI RESTORE] Restored ", restored, " files. Reopen scenes in Godot.")
	get_editor_interface().get_resource_filesystem().scan()
