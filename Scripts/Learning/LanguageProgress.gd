extends Node

## ============================================================
## ACCOUNT-BASED LANGUAGE PROGRESS
## ============================================================
##
## Vocabulary data (.tres files) is shared by the whole game.
##
## Player language progress is NOT shared.
##
## Each logged-in account has its own:
## - encountered vocabulary
## - learned vocabulary
## - mastery
## - streak
## - question history
##
## SaveManager stores this data inside the account save.
##
## IMPORTANT:
## Encountered != Learned.
##
## encountered:
## The player has seen/heard the word or phrase.
##
## learned:
## The story explicitly taught the word or phrase.
##
## Only learned vocabulary is allowed in battle.
## ============================================================


signal encountered_changed(vocab_id: String)
signal learned_changed(vocab_id: String)
signal mastery_changed(vocab_id: String, correct: bool)
signal progress_changed


const VOCAB_PATH: String = "res://Data/Vocabulary/"
const MAX_STAGE: int = 3


var _entries: Dictionary = {}
var _encountered: Dictionary = {}
var _learned: Dictionary = {}
var _mastery: Dictionary = {}


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_load_database()


# ============================================================
# VOCABULARY DATABASE
# ============================================================

func _load_database() -> void:
	_entries.clear()

	var files: PackedStringArray = DirAccess.get_files_at(
		VOCAB_PATH
	)

	for file_name: String in files:

		if not file_name.to_lower().ends_with(".tres"):
			continue

		var resource: Resource = ResourceLoader.load(
			VOCAB_PATH + file_name
		)

		if resource == null or not resource is VocabEntry:
			push_warning(
				"[LANGUAGE] Invalid VocabEntry: "
				+ file_name
			)
			continue

		var entry: VocabEntry = resource as VocabEntry

		if entry.id.is_empty():
			push_warning(
				"[LANGUAGE] Missing ID: "
				+ file_name
			)
			continue

		if entry.kapampangan.is_empty():
			push_warning(
				"[LANGUAGE] Missing Kapampangan text: "
				+ file_name
			)
			continue

		if _entries.has(entry.id):
			push_warning(
				"[LANGUAGE] Duplicate vocab ID: "
				+ entry.id
			)
			continue

		_entries[entry.id] = entry

	_validate_database()

	print(
		"[LANGUAGE] Loaded ",
		_entries.size(),
		" vocabulary entries."
	)


func _validate_database() -> void:

	for raw_id: Variant in _entries.keys():

		var id: String = str(raw_id)
		var entry: VocabEntry = _entries[id]

		if entry.english.is_empty():
			push_warning(
				"[LANGUAGE] Missing English meaning: "
				+ id
			)

		for part_id: String in entry.parts:

			if not _entries.has(part_id):
				push_warning(
					"[LANGUAGE] %s references missing part: %s"
					% [id, part_id]
				)

		for variant: Dictionary in entry.fill_blank_variants:

			var raw_answer_id: Variant = (
				variant.get("answer_id", "")
			)

			var answer_id: String = str(
				raw_answer_id
			)

			if (
				not answer_id.is_empty()
				and not _entries.has(answer_id)
			):
				push_warning(
					"[LANGUAGE] %s references missing fill-blank answer: %s"
					% [id, answer_id]
				)


# ============================================================
# ENTRY ACCESS
# ============================================================

func get_entry(
	vocab_id: String
) -> VocabEntry:

	var raw_entry: Variant = _entries.get(
		vocab_id,
		null
	)

	if raw_entry is VocabEntry:
		return raw_entry as VocabEntry

	return null


func get_all_entries() -> Array[VocabEntry]:

	var result: Array[VocabEntry] = []

	for raw_entry: Variant in _entries.values():

		if raw_entry is VocabEntry:
			result.append(
				raw_entry as VocabEntry
			)

	return result


# ============================================================
# ENCOUNTERED
# ============================================================

func is_encountered(
	vocab_id: String
) -> bool:

	return _encountered.has(
		vocab_id
	)


func mark_encountered(
	vocab_ids: String
) -> void:

	var changed: bool = false

	var ids: PackedStringArray = (
		vocab_ids.split("+", false)
	)

	for id: String in ids:

		var clean_id: String = id.strip_edges()

		if clean_id.is_empty():
			continue

		if not _entries.has(clean_id):

			push_warning(
				"[LANGUAGE] Unknown encountered ID: "
				+ clean_id
			)

			continue

		if _encountered.has(clean_id):
			continue

		_encountered[clean_id] = true

		encountered_changed.emit(
			clean_id
		)

		changed = true

	if changed:

		progress_changed.emit()
		_request_save()


# ============================================================
# LEARNED
# ============================================================

func is_learned(
	vocab_id: String
) -> bool:

	return _learned.has(
		vocab_id
	)


func get_learned_entries() -> Array[VocabEntry]:

	var result: Array[VocabEntry] = []

	for raw_id: Variant in _learned.keys():

		var id: String = str(raw_id)

		if not _entries.has(id):
			continue

		var entry: VocabEntry = (
			_entries[id] as VocabEntry
		)

		if entry != null:
			result.append(entry)

	return result


func get_learned_combat_entries() -> Array[VocabEntry]:

	var result: Array[VocabEntry] = []

	for entry: VocabEntry in get_learned_entries():

		if (
			entry.allowed_types.has(
				"multiple_choice"
			)
			or entry.allowed_types.has(
				"translate"
			)
			or entry.allowed_types.has(
				"fill_blank"
			)
			or entry.allowed_types.has(
				"match"
			)
		):
			result.append(entry)

	return result


# ============================================================
# MARK LEARNED
# ============================================================

func mark_learned(
	vocab_ids: String
) -> void:

	var changed: bool = _grant_ids(
		vocab_ids,
		true
	)

	if changed:

		progress_changed.emit()
		_request_save()


func _grant_ids(
	vocab_ids: String,
	include_parts: bool
) -> bool:

	var changed: bool = false

	var ids: PackedStringArray = (
		vocab_ids.split("+", false)
	)

	for id: String in ids:

		var clean_id: String = id.strip_edges()

		if clean_id.is_empty():
			continue

		if _grant_single(
			clean_id,
			include_parts
		):
			changed = true

	return changed


func _grant_single(
	vocab_id: String,
	include_parts: bool
) -> bool:

	if not _entries.has(vocab_id):

		push_warning(
			"[LANGUAGE] Unknown learned ID: "
			+ vocab_id
		)

		return false

	var changed: bool = false


	# --------------------------------------------------------
	# LEARNED ALSO MEANS ENCOUNTERED
	# --------------------------------------------------------

	if not _encountered.has(vocab_id):

		_encountered[vocab_id] = true

		encountered_changed.emit(
			vocab_id
		)

		changed = true


	# --------------------------------------------------------
	# LEARNED
	# --------------------------------------------------------

	if not _learned.has(vocab_id):

		_learned[vocab_id] = true

		_mastery[vocab_id] = _mastery.get(
			vocab_id,
			_new_mastery()
		)

		learned_changed.emit(
			vocab_id
		)

		changed = true


	# --------------------------------------------------------
	# PHRASE PARTS
	# --------------------------------------------------------
	#
	# Example:
	#
	# mayap_a_abak
	#      ↓
	# mayap
	# a
	# abak
	#
	# These parts become learned too.
	#
	# Their own .tres files control whether they are allowed
	# in normal battle.
	# --------------------------------------------------------

	if include_parts:

		var entry: VocabEntry = (
			_entries[vocab_id] as VocabEntry
		)

		if entry != null:

			for part_id: String in entry.parts:

				if _grant_single(
					part_id,
					true
				):
					changed = true

	return changed


# ============================================================
# DEBUG GRANT
# ============================================================

func debug_grant(
	vocab_ids: PackedStringArray
) -> void:

	var changed: bool = false

	for id: String in vocab_ids:

		if _grant_single(
			id,
			true
		):
			changed = true

	if changed:

		progress_changed.emit()
		_request_save()


# ============================================================
# MASTERY
# ============================================================

func get_mastery(
	vocab_id: String
) -> Dictionary:

	var raw_mastery: Variant = _mastery.get(
		vocab_id,
		_new_mastery()
	)

	if raw_mastery is Dictionary:

		return (
			raw_mastery as Dictionary
		).duplicate(true)

	return _new_mastery()


func get_stage(
	vocab_id: String
) -> int:

	var mastery: Dictionary = (
		get_mastery(vocab_id)
	)

	var raw_stage: Variant = (
		mastery.get("stage", 0)
	)

	return clampi(
		int(raw_stage),
		0,
		MAX_STAGE
	)


func record_result(
	vocab_id: String,
	correct: bool
) -> void:

	if vocab_id.is_empty():
		return

	if not _learned.has(vocab_id):
		return

	var raw_existing: Variant = (
		_mastery.get(
			vocab_id,
			_new_mastery()
		)
	)

	var mastery: Dictionary

	if raw_existing is Dictionary:
		mastery = (
			raw_existing as Dictionary
		).duplicate(true)
	else:
		mastery = _new_mastery()


	var seen: int = int(
		mastery.get("seen", 0)
	)

	var correct_count: int = int(
		mastery.get("correct", 0)
	)

	var wrong_count: int = int(
		mastery.get("wrong", 0)
	)

	var streak: int = int(
		mastery.get("streak", 0)
	)

	var stage: int = int(
		mastery.get("stage", 0)
	)


	seen += 1

	if correct:

		correct_count += 1
		streak += 1

	else:

		wrong_count += 1
		streak = 0


	# --------------------------------------------------------
	# STAGE PROGRESSION
	# --------------------------------------------------------

	if (
		correct_count >= 2
		and seen >= 2
	):
		stage = maxi(
			stage,
			1
		)

	if (
		correct_count >= 4
		and wrong_count <= correct_count
	):
		stage = maxi(
			stage,
			2
		)

	if (
		correct_count >= 7
		and wrong_count * 2 <= correct_count
	):
		stage = MAX_STAGE


	mastery["seen"] = seen
	mastery["correct"] = correct_count
	mastery["wrong"] = wrong_count
	mastery["streak"] = streak
	mastery["stage"] = clampi(
		stage,
		0,
		MAX_STAGE
	)

	_mastery[vocab_id] = mastery

	mastery_changed.emit(
		vocab_id,
		correct
	)

	progress_changed.emit()

	_request_save()


# ============================================================
# DEFAULT MASTERY
# ============================================================

func _new_mastery() -> Dictionary:

	return {
		"stage": 0,
		"correct": 0,
		"wrong": 0,
		"streak": 0,
		"seen": 0
	}


# ============================================================
# RESET ACCOUNT STATE
# ============================================================
#
# IMPORTANT:
# This does NOT delete vocabulary files.
#
# It only clears the currently loaded ACCOUNT'S progress.
# ============================================================

func reset() -> void:

	_encountered.clear()
	_learned.clear()
	_mastery.clear()

	progress_changed.emit()


# ============================================================
# SAVE DATA
# ============================================================

func get_save_data() -> Dictionary:

	return {
		"encountered":
			_encountered.keys(),

		"learned":
			_learned.keys(),

		"mastery":
			_mastery.duplicate(true)
	}


# ============================================================
# LOAD ACCOUNT SAVE
# ============================================================

func load_save_data(
	data: Dictionary
) -> void:

	reset()

	if data.is_empty():
		return


	# --------------------------------------------------------
	# ENCOUNTERED
	# --------------------------------------------------------

	var saved_encountered: Variant = (
		data.get(
			"encountered",
			[]
		)
	)

	if saved_encountered is Array:

		for raw_id: Variant in (
			saved_encountered as Array
		):

			var id: String = str(raw_id)

			if _entries.has(id):
				_encountered[id] = true


	# --------------------------------------------------------
	# LEARNED
	# --------------------------------------------------------

	var saved_learned: Variant = (
		data.get(
			"learned",
			[]
		)
	)

	if saved_learned is Array:

		for raw_id: Variant in (
			saved_learned as Array
		):

			var id: String = str(raw_id)

			if _entries.has(id):
				_learned[id] = true


	# --------------------------------------------------------
	# MASTERY
	# --------------------------------------------------------

	var saved_mastery: Variant = (
		data.get(
			"mastery",
			{}
		)
	)

	if saved_mastery is Dictionary:

		var mastery_dictionary: Dictionary = (
			saved_mastery as Dictionary
		)

		for raw_id: Variant in (
			mastery_dictionary.keys()
		):

			var id: String = str(raw_id)

			var raw_entry_mastery: Variant = (
				mastery_dictionary.get(
					id,
					null
				)
			)

			if not raw_entry_mastery is Dictionary:
				continue

			var source_mastery: Dictionary = (
				raw_entry_mastery as Dictionary
			)

			var mastery: Dictionary = (
				_new_mastery()
			)

			for key: String in mastery.keys():

				var raw_value: Variant = (
					source_mastery.get(
						key,
						mastery[key]
					)
				)

				mastery[key] = int(
					raw_value
				)

			_mastery[id] = mastery


	# --------------------------------------------------------
	# BACKWARD COMPATIBILITY
	# --------------------------------------------------------
	#
	# Older saves may have learned phrases but no encountered
	# information.
	#
	# Also make sure phrase parts are available for sentence
	# building.
	# --------------------------------------------------------

	var learned_snapshot: Array = (
		_learned.keys().duplicate()
	)

	for raw_id: Variant in learned_snapshot:

		var id: String = str(raw_id)

		var entry: VocabEntry = get_entry(
			id
		)

		if entry == null:
			continue


		# Learned implies encountered.
		if not _encountered.has(id):
			_encountered[id] = true


		# Expose parts.
		for part_id: String in entry.parts:

			if not _entries.has(part_id):
				continue

			if not _learned.has(part_id):
				_learned[part_id] = true

			if not _encountered.has(part_id):
				_encountered[part_id] = true

			if not _mastery.has(part_id):
				_mastery[part_id] = (
					_new_mastery()
				)

	progress_changed.emit()


# ============================================================
# SAVE REQUEST
# ============================================================

func _request_save() -> void:

	if (
		GameManager
		and GameManager.has_method(
			"request_save"
		)
	):
		GameManager.request_save()
