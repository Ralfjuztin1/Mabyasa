@tool
extends EditorScript

## Run ONCE in Godot Editor: File -> Run. Keeps the existing 10 greeting
## questions and appends 10 new blind number-baseline questions.
## Does not overwrite the old first-boss comparison ID list.
const TARGET: String = "res://Scripts/Assessment/PreAssessment.gd"
const PATCH_MARKER: String = "# MABIYASA_NUMBER_BASELINE_V1"


func _run() -> void:
	if not FileAccess.file_exists(TARGET):
		push_error("[NUMBERS BASELINE] Cannot find " + TARGET)
		return
	var original: String = FileAccess.get_file_as_string(TARGET)
	if original.contains(PATCH_MARKER):
		print("[NUMBERS BASELINE] Already installed; no edits made.")
		return

	var edited: String = original
	# Add a separate question bank. NEVER add number IDs to
	# PRE_ASSESSMENT_VOCAB_IDS: the first Guardian expects greetings only.
	edited = _replace_required(edited,
		"const TOTAL_QUESTIONS: int = 10",
		PATCH_MARKER + "\nconst NUMBER_BANK: GDScript = preload(\"res://Scripts/Assessment/NumberPreAssessmentBank.gd\")\nconst TOTAL_QUESTIONS: int = 20"
	)
	if edited.is_empty():
		return

	# Append to the 10 existing story questions before size validation.
	edited = _replace_required(edited,
		"\tif questions.size() != TOTAL_QUESTIONS:\n\t\tpush_error(\"[PRE-ASSESSMENT] Expected six translations and four situations (10 total).\")",
		"\tvar number_questions: Array[Dictionary] = NUMBER_BANK.build_questions()\n\tif number_questions.size() != 10:\n\t\tpush_error(\"[PRE-ASSESSMENT] Number bank incomplete (expected 10).\")\n\t\treturn []\n\tquestions.append_array(number_questions)\n\tif questions.size() != TOTAL_QUESTIONS:\n\t\tpush_error(\"[PRE-ASSESSMENT] Expected ten greeting and ten number questions.\")"
	)
	if edited.is_empty():
		return

	# Preserve assessment_vocab_ids (exactly six greetings) for Boss 1;
	# Boss 2 matches assessment_number_vocab_ids and assessment_items.
	edited = _replace_required(edited,
		"\t_report[\"assessment_version\"] = 3",
		"\t_report[\"assessment_version\"] = 4"
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		"\t_report[\"assessment_format\"] = \"story_translation_then_situational_choices\"",
		"\t_report[\"assessment_format\"] = \"greetings_translation_situations_plus_numbers\""
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		"\t_report[\"assessment_vocab_ids\"] = PRE_ASSESSMENT_VOCAB_IDS.duplicate()",
		"\t_report[\"assessment_vocab_ids\"] = PRE_ASSESSMENT_VOCAB_IDS.duplicate()\n\t_report[\"assessment_number_vocab_ids\"] = NUMBER_BANK.get_number_ids()"
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		"\t_report[\"assessment_items\"] = items",
		"\t_report[\"assessment_items\"] = items\n\t# Send question prompts and submitted answers to the researcher; omit\n\t# the answer key so the blind pre-test stays blind to players.\n\t_report[\"question_results\"] = NUMBER_BANK.blind_email_question_rows(_responses)"
	)
	if edited.is_empty():
		return

	# Refresh UI descriptions only; keep original question counting/flow.
	edited = _replace_required(edited,
		'"This assessment records your familiarity with six Kapampangan "',
		'"This assessment records your starting knowledge of Kapampangan "'
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		'"expressions. Your responses provide a baseline for the Guardian "',
		'"greetings and numbers (1-10). Your responses provide a baseline for the "'
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		'"learning comparison."',
		'"two Guardian assessments."'
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		"\t\t\"Complete all ten questions. Your answers are recorded privately, \"",
		"\t\t\"Complete all twenty questions. Your answers are recorded privately, \""
	)
	if edited.is_empty():
		return

	# Insert a third assessment-stage row next to the existing greeting rows.
	edited = _replace_required(edited,
		'\t\t"Choose the appropriate expression for everyday situations."\n\t))',
		'\t\t"Choose the appropriate expression for everyday situations."\n\t))\n\tstructure_content.add_child(_make_baseline_stage_row(\n\t\t"03", "NUMBERS 1-10", "10 QUESTIONS",\n\t\t"Recognize and translate the ten cardinal numbers."\n\t))'
	)
	if edited.is_empty():
		return

	edited = _replace_required(edited,
		'"All ten responses have been recorded. You can continue to First Town and begin the learning adventure."',
		'"All twenty responses have been recorded. You can continue to First Town and begin the learning adventure."'
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		'"6 unique phrases assessed · 6 translations and 4 situational questions."',
		'"6 greeting targets and 10 numbers · 20 questions total."'
	)
	if edited.is_empty():
		return
	edited = _replace_required(edited,
		'"Your first response for each phrase will be compared with its first construction during the Guardian battle. No answers are revealed here."',
		'"Greeting results support Boss 1 comparison; number results support Boss 2 comparison. No answers are revealed here."'
	)
	if edited.is_empty():
		return
	edited = edited.replace(
		"Continue through the lessons, then try the Guardian's sentence-building challenge.",
		"Continue the greeting and number lessons before facing the Guardians."
	)

	var backup: String = TARGET + ".before_number_baseline.bak"
	if not FileAccess.file_exists(backup):
		var backup_file: FileAccess = FileAccess.open(backup, FileAccess.WRITE)
		if backup_file == null:
			push_error("[NUMBERS BASELINE] Backup failed; original left untouched.")
			return
		backup_file.store_string(original)
		backup_file.close()
	var file: FileAccess = FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("[NUMBERS BASELINE] Could not write " + TARGET)
		return
	file.store_string(edited)
	file.close()
	print("[NUMBERS BASELINE] Installed: 10 greetings + 10 numbers. Backup at " + backup)
	EditorInterface.get_resource_filesystem().scan()


func _replace_required(source: String, existing: String, replacement: String) -> String:
	if not source.contains(existing):
		push_error("[NUMBERS BASELINE] PreAssessment.gd differs from expected source. Missing: " + existing.left(100))
		push_error("[NUMBERS BASELINE] No changes were written. Keep your local file and send it for a merge.")
		return ""
	return source.replace(existing, replacement)
