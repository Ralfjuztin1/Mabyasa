extends "res://Scripts/Assessment/PairedBattleManager.gd"

## Keeps the First Forest Guardian's paired pre/post assessment unchanged.
const NUMBER_BOSS_ID: String = "second_town_number_guardian"
const NUMBER_QUESTIONS: GDScript = preload("res://Scripts/Battle/SecondTownNumberQuestions.gd")

var _number_question_index: int = 0
var _number_results: Array[Dictionary] = []

func _is_number_boss() -> bool:
	return current_enemy != null and current_enemy.enemy_id == NUMBER_BOSS_ID

func start_battle(enemy_data: EnemyData) -> void:
	_number_question_index = 0
	_number_results.clear()
	if enemy_data != null and enemy_data.enemy_id == NUMBER_BOSS_ID:
		enemy_data.is_boss = true
		# Prevent an overlevelled player from finishing before the ten unique
		# numbers can be tested. The existing battle still determines victory,
		# damage and defeat; no question-count UI is added.
		var peak_damage: int = maxi(
			int(ceil(float(PlayerProgression.get_total_atk()) * MAX_DAMAGE_MULT)), 1
		)
		enemy_data.max_hp = maxi(
			enemy_data.max_hp,
			peak_damage * (NUMBER_QUESTIONS.CORE_COVERAGE_COUNT - 1) + 1
		)
	super.start_battle(enemy_data)

func player_attack() -> void:
	if not _is_number_boss():
		super.player_attack()
		return
	if not battle_active or awaiting_quiz_response or awaiting_feedback or enemy_turn_in_progress or action_in_progress:
		return

	var question: QuizQuestion = NUMBER_QUESTIONS.make_question(_number_question_index)
	_number_question_index += 1
	current_question = question
	_set_action_in_progress(true)
	awaiting_quiz_response = true
	quiz_requested.emit(question)

func submit_quiz_answer(payload: Variant) -> void:
	if _is_number_boss() and battle_active and awaiting_quiz_response and current_question != null:
		var question: QuizQuestion = current_question
		var result: AnswerResult = question.evaluate_answer(payload)
		var index: int = -1
		if payload is Dictionary:
			index = int((payload as Dictionary).get("index", -1))
		var selected: String = "(no answer)"
		if index >= 0 and index < question.choices.size():
			selected = question.choices[index]
		var trial: Dictionary = NUMBER_QUESTIONS.get_trial(_number_results.size())
		var correct_answer: String = str(trial["answer"])
		_number_results.append({
			"question_id": str(trial["id"]),
			"phase": str(trial["phase"]),
			"lesson": str(trial["lesson"]),
			"target_number": int(trial["target_number"]),
			"prompt": str(trial["prompt"]),
			"vocab_id": str(trial["vocab"]),
			"topic_name": "Numbers 1-10",
			"question_type": "multiple_choice",
			"submitted_sentence": selected,
			"correct_sentence": correct_answer,
			"english_meaning": str(trial["prompt"]),
			"score": 1.0 if result.correct else 0.0,
			"score_percent": 100 if result.correct else 0,
			"correct": result.correct,
			"timed_out": result.timed_out,
			"time_seconds": result.elapsed,
			"learning_tip": str(trial["tip"]),
			"mistakes": [] if result.correct else ["Expected %s; selected %s." % [correct_answer, selected]]
		})
	super.submit_quiz_answer(payload)

func get_boss_assessment_report() -> Dictionary:
	if not _is_number_boss():
		return super.get_boss_assessment_report()
	var correct_count: int = 0
	for row: Dictionary in _number_results:
		if bool(row.get("correct", false)):
			correct_count += 1
	var total: int = _number_results.size()
	return {
		"boss_id": NUMBER_BOSS_ID,
		"lesson": "numbers_1_to_10",
		"rows": _number_results.duplicate(true),
		"accuracy_percent": int(round(float(correct_count) / float(maxi(total, 1)) * 100.0)),
		"words_correct": correct_count,
		"words_total": total,
		"correct_sentences": 0,
		"total_sentences": 0,
		"questions_correct": correct_count,
		"questions_total": total,
		"mistake_count": total - correct_count
	}
