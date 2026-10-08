extends Node

## Account-owned language progress.
## The vocabulary database is shared by the game; learned/mastery state is
## stored inside the account save, so different accounts remain separate.

signal learned_changed(vocab_id: String)
signal mastery_changed(vocab_id: String, correct: bool)
signal progress_changed

const VOCAB_PATH := "res://Data/Vocabulary/"
const MAX_STAGE := 3

var _entries: Dictionary = {}
var _learned: Dictionary = {}
var _mastery: Dictionary = {}


func _ready() -> void:
	_load_database()


func _load_database() -> void:
	_entries.clear()

	var files := DirAccess.get_files_at(VOCAB_PATH)
	for file_name in files:
		if not file_name.to_lower().ends_with(".tres"):
			continue

		var resource := ResourceLoader.load(VOCAB_PATH + file_name)
		if resource == null or not resource is VocabEntry:
			push_warning("[LANGUAGE] Invalid VocabEntry: " + file_name)
			continue

		var entry: VocabEntry = resource as VocabEntry
		if entry.id.is_empty() or entry.kapampangan.is_empty():
			push_warning("[LANGUAGE] Missing id/Kapampangan: " + file_name)
			continue
		if _entries.has(entry.id):
			push_warning("[LANGUAGE] Duplicate vocab id: " + entry.id)
			continue

		_entries[entry.id] = entry

	_validate_database()
	print("[LANGUAGE] Loaded %d vocabulary entries." % _entries.size())


func _validate_database() -> void:
	for id in _entries.keys():
		var entry: VocabEntry = _entries[id]
		if entry.english.is_empty():
			push_warning("[LANGUAGE] '%s' has no English meaning." % id)

		for part_id in entry.parts:
			if not _entries.has(part_id):
				push_warning("[LANGUAGE] '%s' references missing part '%s'." % [id, part_id])

		for variant in entry.fill_blank_variants:
			var answer_id := str(variant.get("answer_id", ""))
			if not answer_id.is_empty() and not _entries.has(answer_id):
				push_warning("[LANGUAGE] '%s' fill blank references missing answer '%s'." % [id, answer_id])


func get_entry(vocab_id: String) -> VocabEntry:
	return _entries.get(vocab_id, null)


func get_all_entries() -> Array[VocabEntry]:
	var result: Array[VocabEntry] = []
	for entry in _entries.values():
		if entry is VocabEntry:
			result.append(entry)
	return result


func is_learned(vocab_id: String) -> bool:
	return _learned.has(vocab_id)


func get_learned_entries() -> Array[VocabEntry]:
	var result: Array[VocabEntry] = []
	for id in _learned.keys():
		if _entries.has(id):
			result.append(_entries[id])
	return result


func get_learned_combat_entries() -> Array[VocabEntry]:
	var result: Array[VocabEntry] = []
	for entry in get_learned_entries():
		if entry.allowed_types.has("multiple_choice") \
			or entry.allowed_types.has("translate") \
			or entry.allowed_types.has("fill_blank") \
			or entry.allowed_types.has("match"):
			result.append(entry)
	return result


func get_mastery(vocab_id: String) -> Dictionary:
	return _mastery.get(vocab_id, _new_mastery()).duplicate(true)


func get_stage(vocab_id: String) -> int:
	return clampi(int(get_mastery(vocab_id).get("stage", 0)), 0, MAX_STAGE)


func mark_learned(vocab_ids: String) -> void:
	var changed := _grant_ids(vocab_ids, true)
	if changed:
		progress_changed.emit()
		_request_save()


func debug_grant(vocab_ids: PackedStringArray) -> void:
	var changed := false
	for id in vocab_ids:
		if _grant_single(id, true):
			changed = true
	if changed:
		progress_changed.emit()


func _grant_ids(vocab_ids: String, include_parts: bool) -> bool:
	var changed := false
	for raw_id in vocab_ids.split("+", false):
		var id := raw_id.strip_edges()
		if id.is_empty():
			continue
		if _grant_single(id, include_parts):
			changed = true
	return changed


func _grant_single(vocab_id: String, include_parts: bool) -> bool:
	if not _entries.has(vocab_id):
		push_warning("[LANGUAGE] Unknown learned id: " + vocab_id)
		return false

	var changed := false
	if not _learned.has(vocab_id):
		_learned[vocab_id] = true
		_mastery[vocab_id] = _mastery.get(vocab_id, _new_mastery())
		learned_changed.emit(vocab_id)
		changed = true

	if include_parts:
		var entry: VocabEntry = _entries[vocab_id]
		for part_id in entry.parts:
			if _grant_single(part_id, true):
				changed = true

	return changed


func record_result(vocab_id: String, correct: bool) -> void:
	if vocab_id.is_empty() or not _learned.has(vocab_id):
		return

	var mastery: Dictionary = _mastery.get(vocab_id, _new_mastery()).duplicate(true)
	mastery["seen"] = int(mastery.get("seen", 0)) + 1
	if correct:
		mastery["correct"] = int(mastery.get("correct", 0)) + 1
		mastery["streak"] = int(mastery.get("streak", 0)) + 1
	else:
		mastery["wrong"] = int(mastery.get("wrong", 0)) + 1
		mastery["streak"] = 0

	var seen := int(mastery.get("seen", 0))
	var total_correct := int(mastery.get("correct", 0))
	var total_wrong := int(mastery.get("wrong", 0))
	var stage := int(mastery.get("stage", 0))

	## The system advances slowly. Speed should reward a learner, not promote
	## a word after one lucky click.
	if total_correct >= 2 and seen >= 2:
		stage = max(stage, 1)
	if total_correct >= 4 and total_wrong <= total_correct:
		stage = max(stage, 2)
	if total_correct >= 7 and total_wrong * 2 <= total_correct:
		stage = MAX_STAGE

	mastery["stage"] = clampi(stage, 0, MAX_STAGE)
	_mastery[vocab_id] = mastery
	mastery_changed.emit(vocab_id, correct)
	progress_changed.emit()


func _new_mastery() -> Dictionary:
	return {
		"stage": 0,
		"correct": 0,
		"wrong": 0,
		"streak": 0,
		"seen": 0
	}


func reset() -> void:
	_learned.clear()
	_mastery.clear()
	progress_changed.emit()


func get_save_data() -> Dictionary:
	return {
		"learned": _learned.keys(),
		"mastery": _mastery.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return

	var saved_learned = data.get("learned", [])
	if saved_learned is Array:
		for id in saved_learned:
			var key := str(id)
			if _entries.has(key):
				_learned[key] = true

	var saved_mastery = data.get("mastery", {})
	if saved_mastery is Dictionary:
		for id in saved_mastery.keys():
			if not saved_mastery[id] is Dictionary:
				continue
			var mastery := _new_mastery()
			for key in mastery.keys():
				mastery[key] = int(saved_mastery[id].get(key, mastery[key]))
			_mastery[str(id)] = mastery

	## Backward-compatible upgrade: a learned phrase exposes its parts for
	## future sentence building without making those parts appear in normal
	## combat unless their own data explicitly allows it.
	var learned_snapshot := _learned.keys().duplicate()
	for id in learned_snapshot:
		var entry: VocabEntry = _entries.get(str(id), null)
		if entry == null:
			continue
		for part_id in entry.parts:
			if _entries.has(part_id):
				_learned[part_id] = true
				if not _mastery.has(part_id):
					_mastery[part_id] = _new_mastery()

	progress_changed.emit()


func _request_save() -> void:
	if GameManager and GameManager.has_method("request_save"):
		GameManager.request_save()
