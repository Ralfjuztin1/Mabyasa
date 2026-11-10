extends "res://Scripts/Battle/BattleManager.gd"

## Only the Ylang-Ylang Guardian uses matched assessment phrases.
## Normal enemies and other bosses retain all their original question mechanics.

const PAIRED_BOSS_ID: String = "forest_ylang_guardian"
const PAIRED_PHRASE_IDS: Array[String] = [
	"mayap_a_abak",
	"mayap_a_gatpanapun",
	"ala_pung_nanu_man",
	"dakal_a_salamat",
	"mayap_a_bengi",
	"mayap_a_aldo",
	"malaus_kayu_pu",
	"makilabas_ku_pu",
	"mangan_ta_na",
	"ume_ta_na"
]

var _paired_boss_phrase_ids: Array[String] = []
var _paired_boss_asked_ids: Array[String] = []


func start_battle(enemy_data: EnemyData) -> void:
	_paired_boss_asked_ids.clear()
	_paired_boss_phrase_ids.clear()
	if enemy_data != null and enemy_data.enemy_id == PAIRED_BOSS_ID:
		var baseline: Dictionary = SaveManager.get_pre_assessment_report()
		var baseline_ids: Variant = baseline.get("assessment_vocab_ids", [])
		if baseline_ids is Array:
			for value: Variant in baseline_ids:
				var id := str(value)
				if not id.is_empty() and not _paired_boss_phrase_ids.has(id):
					_paired_boss_phrase_ids.append(id)
		# Older baseline reports predate assessment_vocab_ids.
		if _paired_boss_phrase_ids.is_empty():
			var raw_items: Variant = baseline.get("assessment_items", [])
			if raw_items is Array:
				for raw: Variant in raw_items:
					if raw is Dictionary:
						var id := str((raw as Dictionary).get("vocab_id", ""))
						if not id.is_empty() and not _paired_boss_phrase_ids.has(id):
							_paired_boss_phrase_ids.append(id)
		if _paired_boss_phrase_ids.is_empty():
			_paired_boss_phrase_ids = PAIRED_PHRASE_IDS.duplicate()
			push_warning("[PAIRED BOSS] No saved baseline; using configured phrases. These cannot be compared to an absent baseline.")
		_paired_boss_phrase_ids.shuffle()
	super.start_battle(enemy_data)


func player_attack() -> void:
	if current_enemy == null or current_enemy.enemy_id != PAIRED_BOSS_ID:
		super.player_attack()
		return

	if (
		not battle_active or awaiting_quiz_response or awaiting_feedback
		or enemy_turn_in_progress or action_in_progress
	):
		return

	if _paired_boss_phrase_ids.is_empty():
		push_error("[PAIRED BOSS] No matched vocabulary IDs are available.")
		return

	var next_id: String = ""
	for id: String in _paired_boss_phrase_ids:
		if not _paired_boss_asked_ids.has(id):
			next_id = id
			break

	# After all unique IDs have been asked, repeat for combat only.
	if next_id.is_empty():
		next_id = _paired_boss_phrase_ids[randi_range(0, _paired_boss_phrase_ids.size() - 1)]

	var question: QuizQuestion = _build_paired_boss_question(next_id)
	if question == null:
		push_error("[PAIRED BOSS] Cannot construct phrase for: " + next_id)
		return

	if not _paired_boss_asked_ids.has(next_id):
		_paired_boss_asked_ids.append(next_id)

	current_question = question
	_set_action_in_progress(true)
	awaiting_quiz_response = true
	quiz_requested.emit(question)


func _build_paired_boss_question(vocab_id: String) -> QuizQuestion:
	var entry: VocabEntry = LanguageProgress.get_entry(vocab_id)
	if entry == null or entry.parts.size() < 2:
		return null

	var question := QuizQuestion.new()
	question.quiz_type = QuizQuestion.QuizType.SENTENCE_BUILD
	question.prompt = "Build the Kapampangan phrase for:\n%s" % entry.english
	question.time_limit = 30.0
	question.vocab_id = entry.id
	question.tested_vocab_ids = [entry.id]
	question.hint = entry.hint
	question.pronunciation = entry.pronunciation
	question.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

	for part_id: String in entry.parts:
		var part: VocabEntry = LanguageProgress.get_entry(part_id)
		if part == null:
			return null
		question.sentence_token_ids.append(part.id)
		question.sentence_token_texts.append(part.kapampangan)

	var used: Dictionary = {}
	for part_id: String in question.sentence_token_ids:
		used[part_id] = true

	if entry.sentence_distractors != null:
		for distractor_id: String in entry.sentence_distractors:
			if used.has(distractor_id):
				continue
			var distractor: VocabEntry = LanguageProgress.get_entry(distractor_id)
			if distractor == null:
				continue
			question.sentence_distractor_ids.append(distractor.id)
			question.sentence_distractor_texts.append(distractor.kapampangan)
			used[distractor.id] = true
			if question.sentence_distractor_ids.size() >= 2:
				break
	return question


func _record_boss_sentence_result(question: QuizQuestion, payload: Variant, result: AnswerResult) -> void:
	super._record_boss_sentence_result(question, payload, result)
	if _boss_assessment_rows.is_empty():
		return

	var row: Dictionary = _boss_assessment_rows.back().duplicate(true)
	var entry: VocabEntry = LanguageProgress.get_entry(question.vocab_id)
	var topic: String = "uncategorized"
	if entry != null:
		topic = entry.lesson_group.strip_edges()
		if topic.is_empty():
			topic = entry.source_section.strip_edges()
		if topic.is_empty():
			topic = entry.category

	row["vocab_id"] = question.vocab_id
	row["score"] = clampf(result.score, 0.0, 1.0)
	row["question_type"] = "sentence_build"
	row["topic_key"] = topic
	row["topic_name"] = topic.replace("_", " ").capitalize()
	row["meaning"] = entry.english if entry != null else ""
	row["official_first_exposure"] = not _has_previous_row_for_vocab(question.vocab_id)
	_boss_assessment_rows[_boss_assessment_rows.size() - 1] = row


func _has_previous_row_for_vocab(vocab_id: String) -> bool:
	for index: int in range(maxi(_boss_assessment_rows.size() - 1, 0)):
		if str(_boss_assessment_rows[index].get("vocab_id", "")) == vocab_id:
			return true
	return false
