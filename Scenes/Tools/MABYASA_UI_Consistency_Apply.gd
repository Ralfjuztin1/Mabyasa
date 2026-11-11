@tool
extends EditorScript

## One-time, reversible layout-only patch for MABYASA's EXISTING UI.
## Does not replace scene trees, artwork, text, signals, scripts or gameplay logic.
## Run from the Godot Script editor: File > Run (Ctrl+Shift+X).

const RULES_PATH: String = "res://Scripts/Tools/MABYASA_UI_Consistency_Rules.json"
const BACKUP_SUFFIX: String = ".before_ui_consistency"


func _run() -> void:
	if not FileAccess.file_exists(RULES_PATH):
		push_error("[MABYASA UI] Missing rules: " + RULES_PATH)
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not parsed is Dictionary:
		push_error("[MABYASA UI] Invalid layout rule JSON.")
		return
	var rules: Dictionary = parsed as Dictionary
	var scenes: Dictionary = rules.get("scenes", {})
	var scripts: Dictionary = rules.get("scripts", {})
	var changed_files: int = 0
	var total_changes: int = 0
	var warnings: int = 0

	for key: Variant in scenes.keys():
		var path: String = "res://" + str(key)
		if not FileAccess.file_exists(path):
			push_warning("[MABYASA UI] Missing scene, skipped: " + path)
			warnings += 1
			continue

		var original: String = FileAccess.get_file_as_string(path)
		var result: Dictionary = _patch_scene(original, scenes[key] as Array)
		warnings += int(result.get("warnings", 0))
		var patched: String = str(result.get("text", original))
		if patched == original:
			continue
		if original.count("[node name=") != patched.count("[node name="):
			push_error("[MABYASA UI] Node count changed unexpectedly. Skipped: " + path)
			continue
		if not _save_with_backup(path, original, patched):
			continue
		changed_files += 1
		total_changes += int(result.get("changes", 0))
		print("[MABYASA UI] Scene updated: ", path, " (", result.get("changes", 0), " properties)")

	for key: Variant in scripts.keys():
		var path: String = "res://" + str(key)
		if not FileAccess.file_exists(path):
			push_warning("[MABYASA UI] Missing script, skipped: " + path)
			warnings += 1
			continue
		var original: String = FileAccess.get_file_as_string(path)
		var result: Dictionary = _patch_script(original, scripts[key] as Array)
		warnings += int(result.get("warnings", 0))
		var patched: String = str(result.get("text", original))
		if patched == original:
			continue
		if not _save_with_backup(path, original, patched):
			continue
		changed_files += 1
		total_changes += int(result.get("changes", 0))
		print("[MABYASA UI] Script visual constants updated: ", path)

	print("[MABYASA UI] Completed: ", changed_files, " files; ", total_changes, " layout edits; ", warnings, " skipped rules/files.")
	print("[MABYASA UI] Backups are alongside originals with suffix: ", BACKUP_SUFFIX)
	print("[MABYASA UI] Close/reopen affected scenes before saving them in Godot.")
	get_editor_interface().get_resource_filesystem().scan()


func _patch_scene(source: String, targets: Array) -> Dictionary:
	var current: String = source
	var changed: int = 0
	var warnings: int = 0
	for raw_target: Variant in targets:
		if not raw_target is Dictionary:
			warnings += 1
			continue
		var target: Dictionary = raw_target as Dictionary
		var name: String = str(target.get("name", ""))
		var parent_path: String = str(target.get("parent", ""))
		var node_start: int = _find_node_start(current, name, parent_path)
		if node_start < 0:
			push_warning("[MABYASA UI] Missing node: " + name + " (" + parent_path + ")")
			warnings += 1
			continue
		var header_end: int = current.find("\n", node_start)
		if header_end < 0:
			warnings += 1
			continue
		var body_start: int = header_end + 1
		var body_end: int = current.find("\n[node ", body_start)
		if body_end < 0:
			body_end = current.length()
		else:
			body_end += 1 # retain the blank line before the next node header
		var body: String = current.substr(body_start, body_end - body_start)
		var lines: PackedStringArray = body.split("\n", true)
		var props: Dictionary = target.get("props", {})
		for raw_property: Variant in props.keys():
			var property_name: String = str(raw_property)
			var desired: String = property_name + " = " + str(props[raw_property])
			var found: bool = false
			for i: int in range(lines.size()):
				if lines[i].begins_with(property_name + " = "):
					if lines[i] != desired:
						lines[i] = desired
						changed += 1
					found = true
					break
			if not found:
				lines.insert(0, desired)
				changed += 1
		var replacement: String = "\n".join(lines)
		current = current.substr(0, body_start) + replacement + current.substr(body_end)
	return {"text": current, "changes": changed, "warnings": warnings}


func _find_node_start(source: String, node_name: String, parent_path: String) -> int:
	var needle: String = "[node name=\"" + node_name + "\""
	var at: int = source.find(needle)
	while at >= 0:
		var end: int = source.find("\n", at)
		if end < 0:
			return -1
		var header: String = source.substr(at, end - at)
		if parent_path.is_empty() or header.contains("parent=\"" + parent_path + "\""):
			return at
		at = source.find(needle, end + 1)
	return -1


func _patch_script(source: String, edits: Array) -> Dictionary:
	var current: String = source
	var changed: int = 0
	var warnings: int = 0
	for raw_edit: Variant in edits:
		if not raw_edit is Dictionary:
			warnings += 1
			continue
		var edit: Dictionary = raw_edit as Dictionary
		var before: String = str(edit.get("before", ""))
		var after: String = str(edit.get("after", ""))
		if before.is_empty() or before == after:
			continue
		var matches: int = current.count(before)
		if matches == 0 and current.contains(after):
			continue # already installed; safe to run more than once
		if matches != 1:
			push_warning("[MABYASA UI] Visual script edit skipped: expected one match, found " + str(matches))
			warnings += 1
			continue
		current = current.replace(before, after)
		changed += 1
	return {"text": current, "changes": changed, "warnings": warnings}


func _save_with_backup(path: String, original: String, replacement: String) -> bool:
	var backup_path: String = path + BACKUP_SUFFIX
	if not FileAccess.file_exists(backup_path):
		if not _write_text(backup_path, original):
			push_error("[MABYASA UI] Could not back up " + path + "; original left unchanged.")
			return false
	if not _write_text(path, replacement):
		push_error("[MABYASA UI] Could not write " + path)
		return false
	return true


func _write_text(path: String, content: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(content)
	f.close()
	return true
