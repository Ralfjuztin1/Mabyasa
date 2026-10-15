extends Node

const QuestionFactoryScript: GDScript = preload(
    "res://Scripts/Battle/QuestionFactory.gd"
)

signal battle_started(enemy: EnemyData)
signal enemy_hp_changed(current: int, max: int)
signal enemy_barrier_changed(current: int, max: int)
signal player_hp_changed(current: int, max: int)
signal quiz_requested(question: QuizQuestion)
signal quiz_resolved(result: AnswerResult, damage_dealt: int)
signal feedback_requested(result: AnswerResult)
signal battle_log(message: String)
signal battle_streak_changed(streak: int, best_streak: int)
signal battle_ended(victory: bool)
signal battle_fled
signal enemy_attack_animation_requested
signal enemy_hit_animation_requested

const MIN_DAMAGE_MULT: float = 0.40
const MAX_DAMAGE_MULT: float = 1.55

const RECENT_MEMORY: int = 3
const RECENT_KIND_MEMORY: int = 2

const RETRY_DELAY: int = 1

const TIMEOUT_FEEDBACK_DELAY: float = 1.8
const WRONG_FEEDBACK_DELAY: float = 1.2

var battle_active: bool = false
var awaiting_quiz_response: bool = false
var awaiting_feedback: bool = false
var enemy_turn_in_progress: bool = false

var current_enemy: EnemyData = null

var enemy_hp: int = 0
var enemy_barrier: int = 0

var current_question: QuizQuestion = null

var _recent_ids: Array[String] = []
var _recent_kinds: Array[String] = []
var _retry_queue: Array[Dictionary] = []

# Healing effects currently active in this battle.
var _active_food_effects: Array[Dictionary] = []

var _answered_questions: int = 0

var _battle_streak: int = 0
var _best_battle_streak: int = 0

var _enemy_dead_pending: bool = false

# Boss-only assessment data. Normal battles do not use these fields.
var is_boss_battle: bool = false
var _boss_assessment_rows: Array[Dictionary] = []
var _boss_words_correct: int = 0
var _boss_words_total: int = 0
var _boss_correct_sentences: int = 0
var _boss_sentence_attempts: int = 0
var _boss_mistake_count: int = 0


# ============================================================
# START BATTLE
# ============================================================

func start_battle(enemy_data: EnemyData) -> void:
	if battle_active:
		return

	if enemy_data == null:
		push_error("[BATTLE] Missing EnemyData.")
		return

	current_enemy = enemy_data

	is_boss_battle = enemy_data.is_boss
	_boss_assessment_rows.clear()
	_boss_words_correct = 0
	_boss_words_total = 0
	_boss_correct_sentences = 0
	_boss_sentence_attempts = 0
	_boss_mistake_count = 0

	if is_boss_battle:
		CheckpointManager.ensure_checkpoint_at_player()

	enemy_hp = maxi(enemy_data.max_hp, 1)
	enemy_barrier = maxi(enemy_data.max_barrier, 0)

	battle_active = true
	awaiting_quiz_response = false
	awaiting_feedback = false
	enemy_turn_in_progress = false

	current_question = null
	_enemy_dead_pending = false

	_recent_ids.clear()
	_recent_kinds.clear()
	_retry_queue.clear()
	_active_food_effects.clear()

	_answered_questions = 0

	_battle_streak = 0
	_best_battle_streak = 0

	PlayerProgression.ensure_hp_initialized()

	GameManager.set_game_state(
		GameManager.GameState.COMBAT
	)

	battle_started.emit(enemy_data)

	enemy_hp_changed.emit(
		enemy_hp,
		enemy_data.max_hp
	)

	enemy_barrier_changed.emit(
		enemy_barrier,
		enemy_data.max_barrier
	)

	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)

	battle_streak_changed.emit(0, 0)

	battle_log.emit(
		"A wild %s appears!" % enemy_data.display_name
	)


# ============================================================
# PLAYER ATTACK
# ============================================================

func player_attack() -> void:
	if (
		not battle_active
		or awaiting_quiz_response
		or awaiting_feedback
		or enemy_turn_in_progress
	):
		return

	var forced_id: String = _pop_due_retry()
	var question: QuizQuestion = null

	if current_enemy != null and current_enemy.is_boss:
		question = QuestionFactoryScript.build_boss_sentence_question(
			_recent_ids
		)
	else:
		question = QuestionFactoryScript.build_normal_question(
			_recent_ids,
			_recent_kinds,
			forced_id
		)

	# Do not damage the enemy if no question is available.
	if question == null:
		battle_log.emit(
            "No encountered vocabulary is available yet."
		)
		return

	for tested_id: String in question.tested_vocab_ids:
		if tested_id.is_empty():
			continue

		if not _recent_ids.has(tested_id):
			_recent_ids.append(tested_id)

	while _recent_ids.size() > RECENT_MEMORY:
		_recent_ids.pop_front()

	var question_kind: String = question.get_kind_name()

	if not question_kind.is_empty():
		_recent_kinds.append(question_kind)

	while _recent_kinds.size() > RECENT_KIND_MEMORY:
		_recent_kinds.pop_front()

	current_question = question
	awaiting_quiz_response = true

	quiz_requested.emit(question)


# ============================================================
# SUBMIT QUIZ ANSWER
# ============================================================

func submit_quiz_answer(payload: Variant) -> void:
	if (
		not battle_active
		or not awaiting_quiz_response
		or current_question == null
	):
		return

	awaiting_quiz_response = false

	var result: AnswerResult = current_question.evaluate_answer(
		payload
	)

	if result == null:
		push_error(
            "[BATTLE] Quiz returned no AnswerResult."
		)
		current_question = null
		return

	if (
		is_boss_battle
		and current_question.quiz_type
		== QuizQuestion.QuizType.SENTENCE_BUILD
	):
		_record_boss_sentence_result(
			current_question,
			payload,
			result
		)

	current_question = null
	_answered_questions += 1

	# Record language results.
	for vocab_id_variant: Variant in result.per_vocab_results.keys():
		var vocab_id: String = str(vocab_id_variant)
		var correct: bool = bool(
			result.per_vocab_results[vocab_id_variant]
		)

		LanguageProgress.record_result(
			vocab_id,
			correct
		)

	# Streak.
	if result.correct:
		_battle_streak += 1

		_best_battle_streak = maxi(
			_best_battle_streak,
			_battle_streak
		)
	else:
		_battle_streak = 0

		for failed_id_variant: Variant in result.per_vocab_results.keys():
			var failed_id: String = str(failed_id_variant)
			var failed: bool = bool(
				result.per_vocab_results[failed_id_variant]
			)

			if not failed:
				_schedule_retry_if_combat_entry(failed_id)

	battle_streak_changed.emit(
		_battle_streak,
		_best_battle_streak
	)

	# Damage.
	var multiplier: float = _calculate_damage_multiplier(result)
	result.damage_multiplier = multiplier

	_apply_attack(multiplier, result)


# ============================================================
# BOSS ASSESSMENT REPORT
# ============================================================

func get_boss_assessment_report() -> Dictionary:
	var accuracy_percent: int = 0

	if _boss_words_total > 0:
		accuracy_percent = int(
			round(
				float(_boss_words_correct)
				/ float(_boss_words_total)
				* 100.0
			)
		)

	return {
		"rows": _boss_assessment_rows.duplicate(true),
		"accuracy_percent": accuracy_percent,
		"words_correct": _boss_words_correct,
		"words_total": _boss_words_total,
		"correct_sentences": _boss_correct_sentences,
		"total_sentences": _boss_sentence_attempts,
		"mistake_count": _boss_mistake_count
	}


func _record_boss_sentence_result(
	question: QuizQuestion,
	payload: Variant,
	result: AnswerResult
) -> void:
	var answer_data: Dictionary = (
		payload if payload is Dictionary else {}
	)

	var raw_order: Variant = answer_data.get("order", [])
	var order: Array = raw_order if raw_order is Array else []

	var text_by_id: Dictionary = {}

	for i in range(question.sentence_token_ids.size()):
		if i < question.sentence_token_texts.size():
			text_by_id[str(question.sentence_token_ids[i])] = (
				str(question.sentence_token_texts[i])
			)

	for i in range(question.sentence_distractor_ids.size()):
		if i < question.sentence_distractor_texts.size():
			text_by_id[str(question.sentence_distractor_ids[i])] = (
				str(question.sentence_distractor_texts[i])
			)

	var submitted_words: PackedStringArray = []

	for raw_id: Variant in order:
		var token_id: String = str(raw_id)
		submitted_words.append(
			str(text_by_id.get(token_id, token_id))
		)

	var correct_words: PackedStringArray = []

	for word: String in question.sentence_token_texts:
		correct_words.append(word)

	var mistakes: Array[String] = []
	var correct_positions: int = 0

	for i in range(question.sentence_token_ids.size()):
		var expected_id: String = str(
			question.sentence_token_ids[i]
		)

		var expected_text: String = str(
			text_by_id.get(expected_id, expected_id)
		)

		var chosen_id: String = (
			str(order[i]) if i < order.size() else ""
		)

		if chosen_id == expected_id:
			correct_positions += 1
		elif chosen_id.is_empty():
			mistakes.append(
                "Position %d: expected '%s', but no word was placed."
				% [i + 1, expected_text]
			)
		else:
			mistakes.append(
                "Position %d: expected '%s', got '%s'."
				% [
					i + 1,
					expected_text,
					str(text_by_id.get(chosen_id, chosen_id))
				]
			)

	for i in range(
		question.sentence_token_ids.size(),
		order.size()
	):
		var extra_id: String = str(order[i])

		mistakes.append(
            "Extra word at position %d: '%s'."
			% [
				i + 1,
				str(text_by_id.get(extra_id, extra_id))
			]
		)

	var expected_count: int = maxi(
		question.sentence_token_ids.size(),
		1
	)

	var score_percent: int = int(
		round(
			float(correct_positions)
			/ float(expected_count)
			* 100.0
		)
	)

	var english_meaning: String = ""
	var phrase_entry: VocabEntry = LanguageProgress.get_entry(
		question.vocab_id
	)

	if phrase_entry != null:
		english_meaning = phrase_entry.english

	if english_meaning.is_empty():
		english_meaning = question.prompt.get_slice("\n", 1)

	_boss_sentence_attempts += 1
	_boss_words_correct += correct_positions
	_boss_words_total += question.sentence_token_ids.size()
	_boss_mistake_count += mistakes.size()

	if result.correct:
		_boss_correct_sentences += 1

	_boss_assessment_rows.append({
		"submitted_sentence": (
			" ".join(submitted_words)
			if not submitted_words.is_empty()
			else "(no words submitted)"
		),
		"correct_sentence": " ".join(correct_words),
		"english_meaning": english_meaning,
		"score_percent": score_percent,
		"correct": result.correct,
		"timed_out": result.timed_out,
		"mistakes": mistakes.duplicate()
	})


# ============================================================
# FEEDBACK
# ============================================================

func acknowledge_feedback() -> void:
	if not awaiting_feedback:
		return

	awaiting_feedback = false

	var enemy_dead: bool = _enemy_dead_pending
	_enemy_dead_pending = false

	if enemy_dead:
		_end_battle(true)
	else:
		_enemy_turn()


func _auto_acknowledge_timeout_feedback() -> void:
	await get_tree().create_timer(
		TIMEOUT_FEEDBACK_DELAY
	).timeout

	if not battle_active or not awaiting_feedback:
		return

	acknowledge_feedback()


func _auto_acknowledge_wrong_feedback() -> void:
	await get_tree().create_timer(
		WRONG_FEEDBACK_DELAY
	).timeout

	if not battle_active or not awaiting_feedback:
		return

	acknowledge_feedback()


# ============================================================
# FOOD HEALING
# ============================================================

func player_use_food(item_id: String) -> bool:
	# Prevent multiple food uses during an enemy turn or quiz.
	if (
		not battle_active
		or awaiting_quiz_response
		or awaiting_feedback
		or enemy_turn_in_progress
	):
		return false

	if InventoryManager == null or PlayerProgression == null:
		return false

	if InventoryManager.get_quantity(item_id) <= 0:
		battle_log.emit("You do not have that food.")
		return false

	var food: Dictionary = InventoryManager.get_food(item_id)

	if food.is_empty():
		return false

	PlayerProgression.ensure_hp_initialized()

	if (
		PlayerProgression.current_hp
		>= PlayerProgression.get_total_max_hp()
	):
		battle_log.emit(
            "Your HP is already full. Save that food for later."
		)
		return false

	var instant_healing: int = maxi(
		int(food.get("heal_amount", 0)),
		0
	)

	var healing_per_turn: int = maxi(
		int(food.get("heal_per_turn", 0)),
		0
	)

	var duration: int = maxi(
		int(food.get("duration", 0)),
		0
	)

	if not InventoryManager.consume_food(item_id):
		return false

	if instant_healing > 0:
		var previous_hp: int = PlayerProgression.current_hp

		PlayerProgression.heal(instant_healing)

		var actual_healing: int = (
			PlayerProgression.current_hp - previous_hp
		)

		battle_log.emit(
            "You ate %s and restored %d HP."
			% [
				str(food.get("name", item_id)),
				actual_healing
			]
		)

	if healing_per_turn > 0 and duration > 0:
		_active_food_effects.append({
			"item_id": item_id,
			"heal_per_turn": healing_per_turn,
			"turns_remaining": duration
		})

		battle_log.emit(
            "%s will restore up to %d HP for %d turns."
			% [
				str(food.get("name", item_id)),
				healing_per_turn,
				duration
			]
		)

	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)

	# Eating uses the player's action. The enemy still gets a turn.
	_enemy_turn()

	return true


func _tick_food_effects() -> void:
	if _active_food_effects.is_empty():
		return

	for index: int in range(
		_active_food_effects.size() - 1,
		-1,
		-1
	):
		var effect: Dictionary = _active_food_effects[index]

		var amount: int = maxi(
			int(effect.get("heal_per_turn", 0)),
			0
		)

		var turns_left: int = maxi(
			int(effect.get("turns_remaining", 0)) - 1,
			0
		)

		if amount > 0:
			var previous_hp: int = PlayerProgression.current_hp

			PlayerProgression.heal(amount)

			var actual_healing: int = (
				PlayerProgression.current_hp - previous_hp
			)

			var food: Dictionary = InventoryManager.get_food(
				str(effect.get("item_id", ""))
			)

			battle_log.emit(
                "%s restores %d HP."
				% [
					str(food.get("name", "Food")),
					actual_healing
				]
			)

		if turns_left <= 0:
			_active_food_effects.remove_at(index)
		else:
			effect["turns_remaining"] = turns_left
			_active_food_effects[index] = effect

	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)


# ============================================================
# BEST STREAK
# ============================================================

func get_best_battle_streak() -> int:
	return _best_battle_streak


# ============================================================
# DAMAGE MULTIPLIER
# ============================================================

func _calculate_damage_multiplier(
	result: AnswerResult
) -> float:
	if result == null:
		return 0.0

	if not result.correct:
		return clampf(
			MIN_DAMAGE_MULT + result.score * 0.40,
			MIN_DAMAGE_MULT,
			0.80
		)

	var multiplier: float = 1.0

	multiplier += minf(
		float(maxi(_battle_streak - 1, 0)) * 0.05,
		0.20
	)

	multiplier += result.speed_bonus

	if result.question_kind == "sentence_build":
		multiplier += 0.20

	return clampf(
		multiplier,
		1.0,
		MAX_DAMAGE_MULT
	)


# ============================================================
# APPLY ATTACK
# ============================================================

func _apply_attack(
	damage_mult: float,
	result: AnswerResult
) -> void:
	var base_atk: int = PlayerProgression.get_total_atk()

	var damage: int = maxi(
		int(round(float(base_atk) * damage_mult)),
		1
	)

	enemy_hit_animation_requested.emit()

	# Barrier absorbs damage before HP.
	var barrier_damage: int = mini(
		damage,
		enemy_barrier
	)

	var hp_damage: int = damage - barrier_damage

	enemy_barrier -= barrier_damage
	enemy_hp = maxi(enemy_hp - hp_damage, 0)

	enemy_barrier_changed.emit(
		enemy_barrier,
		current_enemy.max_barrier
	)

	enemy_hp_changed.emit(
		enemy_hp,
		current_enemy.max_hp
	)

	if result == null:
		return

	if result.correct:
		var label: String = "Correct!"

		if result.question_kind == "sentence_build":
			label = "Perfect sentence!"
		elif result.speed_bonus > 0.0:
			label = "Quick recall!"

		if _battle_streak >= 2:
			label += " Learning combo x%d!" % _battle_streak

		battle_log.emit(
            "%s You deal %d damage."
			% [label, damage]
		)
	else:
		if result.timed_out:
			battle_log.emit(
				"Time's up. The blade weakly strikes for %d."
				% damage
			)
		else:
			battle_log.emit(
				"Not quite. The blade weakly strikes for %d."
				% damage
			)

	quiz_resolved.emit(result, damage)

	var enemy_dead: bool = enemy_hp <= 0

	if not result.correct:
		awaiting_feedback = true
		_enemy_dead_pending = enemy_dead

		feedback_requested.emit(result)

		if result.timed_out:
			_auto_acknowledge_timeout_feedback()
		else:
			_auto_acknowledge_wrong_feedback()

		return

	if enemy_dead:
		_end_battle(true)
	else:
		_enemy_turn()


# ============================================================
# ENEMY TURN
# ============================================================

func _enemy_turn() -> void:
	if not battle_active:
		return

	enemy_turn_in_progress = true

	await get_tree().create_timer(0.28).timeout

	if not battle_active:
		enemy_turn_in_progress = false
		return

	# Play attack animation before applying damage.
	if (
		current_enemy != null
		and not current_enemy.battle_attack_animation.is_empty()
		and current_enemy.battle_attack_duration > 0.0
	):
		enemy_attack_animation_requested.emit()

		await get_tree().create_timer(
			current_enemy.battle_attack_duration
		).timeout

		if not battle_active:
			enemy_turn_in_progress = false
			return

	var mitigation: int = int(
		PlayerProgression.get_total_def() * 0.5
	)

	var damage: int = maxi(
		current_enemy.atk - mitigation,
		1
	)

	PlayerProgression.take_damage(damage)

	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)

	battle_log.emit(
		"%s strikes for %d damage."
		% [
			current_enemy.display_name,
			damage
		]
	)

	if PlayerProgression.current_hp <= 0:
		enemy_turn_in_progress = false

		_end_battle(false)
		return

	# Damage happens first. Food healing then restores HP, capped at max HP.
	_tick_food_effects()

	enemy_turn_in_progress = false


# ============================================================
# FLEE BATTLE
# ============================================================

func flee_battle() -> void:
	if not battle_active:
		return

	# Boss battles must use their existing assessment flow.
	if is_boss_battle:
		battle_log.emit("You cannot flee from a boss battle.")
		return

	# Do not cancel a quiz, feedback result, or enemy turn.
	if (
		awaiting_quiz_response
		or awaiting_feedback
		or enemy_turn_in_progress
	):
		battle_log.emit(
			"Wait until the current action finishes before fleeing."
		)
		return

	battle_active = false
	awaiting_quiz_response = false
	awaiting_feedback = false
	enemy_turn_in_progress = false

	current_question = null
	_enemy_dead_pending = false
	_active_food_effects.clear()

	var fled_from: String = (
		current_enemy.display_name
		if current_enemy != null
		else "the encounter"
	)

	battle_log.emit("You fled from %s." % fled_from)
	battle_fled.emit()

	GameManager.set_game_state(
		GameManager.GameState.EXPLORATION
	)

	if GameManager.has_method("request_save"):
		GameManager.request_save()


# ============================================================
# END BATTLE
# ============================================================

func _end_battle(victory: bool) -> void:
	if not battle_active:
		return

	battle_active = false
	awaiting_quiz_response = false
	awaiting_feedback = false
	enemy_turn_in_progress = false

	current_question = null

	_enemy_dead_pending = false
	_active_food_effects.clear()

	if victory:
		PlayerProgression.add_exp(
			current_enemy.exp_reward
		)

		PlayerProgression.gold += (
			current_enemy.gold_reward
		)

		PlayerProgression.stats_changed.emit()

		if (
			not current_enemy.enemy_id.is_empty()
			and GameEvents
		):
			GameEvents.enemy_killed.emit(
				current_enemy.enemy_id
			)

		battle_log.emit(
			"You defeated %s! +%d EXP, +%d Gold. Best learning combo: x%d"
			% [
				current_enemy.display_name,
				current_enemy.exp_reward,
				current_enemy.gold_reward,
				_best_battle_streak
			]
		)
	else:
		battle_log.emit("You were defeated...")

	battle_ended.emit(victory)

	# Boss battles stay in COMBAT behind the assessment overlay.
	if not is_boss_battle:
		GameManager.set_game_state(
			GameManager.GameState.EXPLORATION
		)

		if GameManager.has_method("request_save"):
			GameManager.request_save()


# ============================================================
# RETRY SYSTEM
# ============================================================

func _schedule_retry_if_combat_entry(
	vocab_id: String
) -> void:
	if vocab_id.is_empty():
		return

	if not LanguageProgress.is_encountered(vocab_id):
		return

	var entry: VocabEntry = LanguageProgress.get_entry(
		vocab_id
	)

	if entry == null:
		return

	var combat_allowed: bool = (
		entry.allowed_types.has("multiple_choice")
		or entry.allowed_types.has("translate")
		or entry.allowed_types.has("fill_blank")
		or entry.allowed_types.has("match")
	)

	if not combat_allowed:
		return

	_schedule_retry(vocab_id)


func _schedule_retry(vocab_id: String) -> void:
	if vocab_id.is_empty():
		return

	for retry_variant: Variant in _retry_queue:
		var retry: Dictionary = retry_variant as Dictionary

		if str(retry.get("id", "")) == vocab_id:
			retry["due"] = (
				_answered_questions + RETRY_DELAY
			)
			return

	_retry_queue.append({
		"id": vocab_id,
		"due": _answered_questions + RETRY_DELAY
	})


func _pop_due_retry() -> String:
	if _retry_queue.is_empty():
		return ""

	for i: int in range(_retry_queue.size()):
		var retry: Dictionary = (
			_retry_queue[i] as Dictionary
		)

		if int(retry.get("due", 999999)) <= _answered_questions:
			_retry_queue.remove_at(i)
			return str(retry.get("id", ""))

	return ""
