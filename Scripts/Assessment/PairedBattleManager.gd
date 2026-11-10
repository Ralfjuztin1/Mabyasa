extends "res://Scripts/Battle/BattleManager.gd"

## Uses the same four baseline phrases in the Forest Ylang-Ylang Guardian fight.
## Other bosses and all normal battles retain the original QuestionFactory flow.

const PAIRED_BOSS_ID: String = "forest_ylang_guardian"
const PAIRED_PHRASE_IDS: Array[String] = [
	"mayap_a_abak",
	"mayap_a_gatpanapun",
	"ala_pung_nanu_man",
	"dakal_a_salamat"
]

var _paired_boss_asked_ids: Array[String] = []


func start_battle(enemy_data: EnemyData) -> void:
	if enemy_data != null and enemy_data.enemy_id == PAIRED_BOSS_ID:
		_paired_boss_asked_ids.clear()
	super.start_battle(enemy_data)


func player_attack() -> void:
	if current_enemy == null or current_enemy.enemy_id != PAIRED_BOSS_ID:
		super.player_attack()
		return

	if (
		not battle_active
		or awaiting_quiz_response
		or awaiting_feedback
		or enemy_turn_in_progress
		or action_in_progress
	):
		return

	var next_id := ""
	for vocab_id: String in PAIRED_PHRASE_IDS:
		if not _paired_boss_asked_ids.has(vocab_id):
			next_id = vocab_id
			break

	# After each baseline phrase has appeared once, repeat from the same set
	# so the boss can continue using its existing combat loop.
	if next_id.is_empty():
		next_id = PAIRED_PHRASE_IDS[randi_range(0, PAIRED_PHRASE_IDS.size() - 1)]

	var question := _build_paired_boss_question(next_id)
	if question == null:
		push_error("[PAIRED BOSS] Could not build question for " + next_id)
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
			if question.sentence_distractor_ids.size() >= 3:
				break

	return question


func _record_boss_sentence_result(
	question: QuizQuestion,
	payload: Variant,
	result: AnswerResult
) -> void:
	super._record_boss_sentence_result(question, payload, result)

	if _boss_assessment_rows.is_empty():
		return

	var row: Dictionary = _boss_assessment_rows.back().duplicate(true)
	var entry: VocabEntry = LanguageProgress.get_entry(question.vocab_id)

	row["vocab_id"] = question.vocab_id
	row["score"] = clampf(result.score, 0.0, 1.0)
	row["question_type"] = "sentence_build"
	row["topic_key"] = _paired_topic_key(entry)
	row["topic_name"] = _paired_topic_name(_paired_topic_key(entry))
	row["meaning"] = entry.english if entry != null else ""

	_boss_assessment_rows[_boss_assessment_rows.size() - 1] = row


func _paired_topic_key(entry: VocabEntry) -> String:
	if entry == null:
		return "uncategorized"
	if not entry.lesson_group.strip_edges().is_empty():
		return entry.lesson_group.strip_edges()
	if not entry.source_section.strip_edges().is_empty():
		return entry.source_section.strip_edges()
	return entry.category


func _paired_topic_name(key: String) -> String:
	var parts: PackedStringArray = key.replace("-", "_").split("_", false)
	var words: PackedStringArray = []
	for part: String in parts:
		if not part.is_empty():
			words.append(part.capitalize())
	return " ".join(words) if not words.is_empty() else "Other Vocabulary"
