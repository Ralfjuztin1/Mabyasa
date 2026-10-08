class_name QuizQuestion
extends Resource

## Self-contained language challenge. BattleManager does not inspect question
## internals. It submits a payload and receives AnswerResult.

enum QuizType {
	MULTIPLE_CHOICE,
	FILL_BLANK,
	TRANSLATE,
	MATCH,
	SENTENCE_BUILD
}

@export var quiz_type: QuizType = QuizType.MULTIPLE_CHOICE
@export var prompt: String = ""
@export var time_limit: float = 25.0

@export var choices: Array[String] = []
@export var choice_vocab_ids: Array[String] = []
@export var correct_index: int = 0

@export var match_left_texts: Array[String] = []
@export var match_left_ids: Array[String] = []
@export var match_right_texts: Array[String] = []
@export var match_right_ids: Array[String] = []

@export var sentence_token_texts: Array[String] = []
@export var sentence_token_ids: Array[String] = []
@export var sentence_distractor_texts: Array[String] = []
@export var sentence_distractor_ids: Array[String] = []

@export var vocab_id: String = ""
@export var tested_vocab_ids: Array[String] = []
@export var hint: String = ""
@export var pronunciation: String = ""
@export var answer_line: String = ""

## For contextual fill-in-the-blank, the exact answer component can be
## credited separately from the full phrase.
@export var secondary_vocab_ids: Array[String] = []


func get_kind_name() -> String:
	match quiz_type:
		QuizType.MULTIPLE_CHOICE:
			return "multiple_choice"
		QuizType.FILL_BLANK:
			return "fill_blank"
		QuizType.TRANSLATE:
			return "translate"
		QuizType.MATCH:
			return "match"
		QuizType.SENTENCE_BUILD:
			return "sentence_build"
	return ""


func get_type_label() -> String:
	match quiz_type:
		QuizType.MULTIPLE_CHOICE:
			return "MULTIPLE CHOICE"
		QuizType.FILL_BLANK:
			return "FILL THE BLANK"
		QuizType.TRANSLATE:
			return "TRANSLATE"
		QuizType.MATCH:
			return "MATCH"
		QuizType.SENTENCE_BUILD:
			return "SENTENCE ATTACK"
	return "LANGUAGE ATTACK"


func evaluate_answer(payload: Variant) -> AnswerResult:
	var result := AnswerResult.new()
	result.vocab_id = vocab_id
	result.tested_vocab_ids = tested_vocab_ids.duplicate()
	result.question_kind = get_kind_name()
	result.answer_line = answer_line
	result.hint = hint
	result.pronunciation = pronunciation

	var answer_data: Dictionary = payload if payload is Dictionary else {}
	result.elapsed = clampf(float(answer_data.get("elapsed", time_limit)), 0.0, maxf(time_limit, 0.01))
	result.time_limit = time_limit
	result.timed_out = bool(answer_data.get("timed_out", false))

	match quiz_type:
		QuizType.MULTIPLE_CHOICE, QuizType.FILL_BLANK, QuizType.TRANSLATE:
			_evaluate_choice(result, int(answer_data.get("index", -1)))
		QuizType.MATCH:
			_evaluate_match(result, answer_data.get("pairs", []), int(answer_data.get("mistakes", 0)))
		QuizType.SENTENCE_BUILD:
			_evaluate_sentence(result, answer_data.get("order", []))

	result.speed_bonus = _get_speed_bonus(result.elapsed, time_limit)
	if result.timed_out:
		result.speed_bonus = 0.0

	## The focus entry gets the full result. Secondary entries only exist for
	## contextual blanks, where the missing word itself is also being recalled.
	if quiz_type != QuizType.MATCH:
		result.per_vocab_results[vocab_id] = result.correct
		for secondary_id in secondary_vocab_ids:
			result.per_vocab_results[secondary_id] = result.correct

	return result


func _evaluate_choice(result: AnswerResult, selected_index: int) -> void:
	result.correct = selected_index >= 0 and selected_index == correct_index and not result.timed_out
	result.score = 1.0 if result.correct else 0.0

	if not result.correct:
		result.chosen_note = _describe_choice(selected_index)
		if result.timed_out:
			result.chosen_note = "The timer ran out before you chose an answer."


func _evaluate_match(result: AnswerResult, raw_pairs: Variant, mistakes: int) -> void:
	var pairs: Array = raw_pairs if raw_pairs is Array else []
	var expected: Dictionary = {}
	for i in match_left_ids.size():
		if i < match_right_ids.size():
			expected[match_left_ids[i]] = match_right_ids[i]

	var correct_pairs := 0
	var seen_left: Dictionary = {}
	for pair in pairs:
		if not pair is Dictionary:
			continue
		var left_id := str(pair.get("left_id", ""))
		var right_id := str(pair.get("right_id", ""))
		if left_id.is_empty() or seen_left.has(left_id):
			continue
		seen_left[left_id] = true
		var pair_correct: bool = str(expected.get(left_id, "")) == right_id
		if pair_correct:
			correct_pairs += 1
		result.per_vocab_results[left_id] = pair_correct

	for left_id in match_left_ids:
		if not result.per_vocab_results.has(left_id):
			result.per_vocab_results[left_id] = false

	var total: int = maxi(expected.size(), 1)
	result.score = clampf(float(correct_pairs) / float(total), 0.0, 1.0)
	result.correct = correct_pairs == expected.size() and not result.timed_out
	result.mistake_count = mistakes

	if not result.correct:
		result.chosen_note = "You connected %d of %d pairs correctly." % [correct_pairs, expected.size()]
	if mistakes > 0:
		result.chosen_note += (" " if not result.chosen_note.is_empty() else "") + "%d mismatched connection%s." % [mistakes, "" if mistakes == 1 else "s"]
	if result.timed_out:
		result.chosen_note = "Time ran out. " + result.chosen_note


func _evaluate_sentence(result: AnswerResult, raw_order: Variant) -> void:
	var order: Array = raw_order if raw_order is Array else []
	var expected := sentence_token_ids

	var correct_positions := 0
	var limit: int = mini(order.size(), expected.size())
	for i in limit:
		if str(order[i]) == str(expected[i]):
			correct_positions += 1

	result.score = clampf(float(correct_positions) / float(maxi(expected.size(), 1)), 0.0, 1.0)
	result.correct = order.size() == expected.size() and correct_positions == expected.size() and not result.timed_out

	if not result.correct:
		result.chosen_note = "Correct order: %s" % " → ".join(sentence_token_texts)
		if result.timed_out:
			result.chosen_note = "Time ran out. " + result.chosen_note


func _describe_choice(selected_index: int) -> String:
	if selected_index < 0 or selected_index >= choice_vocab_ids.size():
		return ""

	var entry := LanguageProgress.get_entry(choice_vocab_ids[selected_index])
	if entry == null:
		return ""

	if quiz_type == QuizType.TRANSLATE:
		return '"%s" means "%s".' % [entry.kapampangan, entry.english]
	return '"%s" means "%s" in Kapampangan.' % [entry.english, entry.kapampangan]


static func _get_speed_bonus(elapsed: float, limit: float) -> float:
	if limit <= 0.0:
		return 0.0
	var ratio := clampf(elapsed / limit, 0.0, 1.0)
	if ratio <= 0.30:
		return 0.20
	if ratio <= 0.60:
		return 0.10
	return 0.0
