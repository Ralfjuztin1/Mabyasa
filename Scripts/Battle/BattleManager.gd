extends Node

## One-battle controller. It owns combat state and delegates language work
## to QuestionFactory/QuizQuestion.

signal battle_started(enemy: EnemyData)
signal enemy_hp_changed(current: int, max_hp: int)
signal enemy_barrier_changed(current: int, max_barrier: int)
signal player_hp_changed(current: int, max_hp: int)
signal quiz_requested(question: QuizQuestion)
signal quiz_resolved(result: AnswerResult, damage_dealt: int)
signal feedback_requested(result: AnswerResult)
signal battle_log(message: String)
signal battle_streak_changed(streak: int, best_streak: int)
signal battle_ended(victory: bool)

const MIN_DAMAGE_MULT := 0.40
const MAX_DAMAGE_MULT := 1.55
const POTION_HEAL_AMOUNT := 30
const RECENT_MEMORY := 3
const RECENT_KIND_MEMORY := 2
const RETRY_DELAY := 1
const TIMEOUT_FEEDBACK_DELAY := 1.8

var battle_active := false
var awaiting_quiz_response := false
var awaiting_feedback := false

var current_enemy: EnemyData = null
var enemy_hp := 0
var enemy_barrier := 0
var current_question: QuizQuestion = null

var _recent_ids: Array[String] = []
var _recent_kinds: Array[String] = []
var _retry_queue: Array[Dictionary] = []
var _answered_questions := 0
var _battle_streak := 0
var _best_battle_streak := 0
var _enemy_dead_pending := false


func start_battle(enemy_data: EnemyData) -> void:
	if battle_active:
		return
	if enemy_data == null:
		push_error("[BATTLE] Missing EnemyData.")
		return

	current_enemy = enemy_data
	enemy_hp = maxi(enemy_data.max_hp, 1)
	enemy_barrier = maxi(enemy_data.max_barrier, 0)
	battle_active = true
	awaiting_quiz_response = false
	awaiting_feedback = false
	_enemy_dead_pending = false
	_recent_ids.clear()
	_recent_kinds.clear()
	_retry_queue.clear()
	_answered_questions = 0
	_battle_streak = 0
	_best_battle_streak = 0

	PlayerProgression.ensure_hp_initialized()
	GameManager.set_game_state(GameManager.GameState.COMBAT)

	battle_started.emit(enemy_data)
	enemy_hp_changed.emit(enemy_hp, enemy_data.max_hp)
	enemy_barrier_changed.emit(enemy_barrier, enemy_data.max_barrier)
	player_hp_changed.emit(PlayerProgression.current_hp, PlayerProgression.get_total_max_hp())
	battle_streak_changed.emit(0, 0)
	battle_log.emit("A wild %s appears!" % enemy_data.display_name)


func player_attack() -> void:
	if not battle_active or awaiting_quiz_response or awaiting_feedback:
		return

	var forced_id := _pop_due_retry()
	var question: QuizQuestion
	if current_enemy.is_boss:
		question = QuestionFactory.build_boss_sentence_question(_recent_ids)
	else:
		question = QuestionFactory.build_normal_question(_recent_ids, _recent_kinds, forced_id)

	if question == null:
		## No vocabulary available for a real question yet. Never invent one.
		battle_log.emit("You need to learn more words before this attack becomes strong.")
		_apply_attack(0.25, null)
		return

	_recent_ids.append(question.vocab_id)
	while _recent_ids.size() > RECENT_MEMORY:
		_recent_ids.pop_front()

	_recent_kinds.append(question.get_kind_name())
	while _recent_kinds.size() > RECENT_KIND_MEMORY:
		_recent_kinds.pop_front()

	current_question = question
	awaiting_quiz_response = true
	quiz_requested.emit(question)


func submit_quiz_answer(payload: Variant) -> void:
	if not battle_active or not awaiting_quiz_response or current_question == null:
		return

	awaiting_quiz_response = false
	var result := current_question.evaluate_answer(payload)
	_answered_questions += 1

	for vocab_id in result.per_vocab_results.keys():
		LanguageProgress.record_result(str(vocab_id), bool(result.per_vocab_results[vocab_id]))

	if result.correct:
		_battle_streak += 1
		_best_battle_streak = maxi(_best_battle_streak, _battle_streak)
	else:
		_battle_streak = 0
		for failed_id in result.per_vocab_results.keys():
			if not bool(result.per_vocab_results[failed_id]):
				_schedule_retry_if_combat_entry(str(failed_id))

	battle_streak_changed.emit(_battle_streak, _best_battle_streak)

	var multiplier := _calculate_damage_multiplier(result)
	result.damage_multiplier = multiplier
	_apply_attack(multiplier, result)


func acknowledge_feedback() -> void:
	if not awaiting_feedback:
		return

	awaiting_feedback = false
	var enemy_dead := _enemy_dead_pending
	_enemy_dead_pending = false
	_continue_after_attack(enemy_dead)


func _auto_acknowledge_timeout_feedback() -> void:
	# Timeout is still a learning moment, but it must never soft-lock combat.
	# The UI may also call acknowledge_feedback(), and the state guard above
	# makes that safe.
	await get_tree().create_timer(TIMEOUT_FEEDBACK_DELAY).timeout

	if not battle_active or not awaiting_feedback:
		return

	acknowledge_feedback()


func player_use_potion() -> void:
	if not battle_active or awaiting_quiz_response or awaiting_feedback:
		return

	PlayerProgression.heal(POTION_HEAL_AMOUNT)
	player_hp_changed.emit(PlayerProgression.current_hp, PlayerProgression.get_total_max_hp())
	battle_log.emit("You recover %d HP." % POTION_HEAL_AMOUNT)
	_enemy_turn()


func get_best_battle_streak() -> int:
	return _best_battle_streak


func _calculate_damage_multiplier(result: AnswerResult) -> float:
	if result == null:
		return 0.25

	if not result.correct:
		## Partial matching/sentence attempts are rewarded without making a
		## mistake stronger than a correct attack.
		return clampf(MIN_DAMAGE_MULT + result.score * 0.40, MIN_DAMAGE_MULT, 0.80)

	var multiplier := 1.0
	multiplier += minf(float(maxi(_battle_streak - 1, 0)) * 0.05, 0.20)
	multiplier += result.speed_bonus
	if result.question_kind == "sentence_build":
		multiplier += 0.20
	return clampf(multiplier, 1.0, MAX_DAMAGE_MULT)


func _apply_attack(damage_mult: float, result: AnswerResult) -> void:
	var base_atk := PlayerProgression.get_total_atk()
	var damage := maxi(int(round(float(base_atk) * damage_mult)), 1)

	var barrier_damage := mini(damage, enemy_barrier)
	var hp_damage := damage - barrier_damage
	enemy_barrier -= barrier_damage
	enemy_hp = maxi(enemy_hp - hp_damage, 0)

	enemy_barrier_changed.emit(enemy_barrier, current_enemy.max_barrier)
	enemy_hp_changed.emit(enemy_hp, current_enemy.max_hp)

	if result == null:
		battle_log.emit("A weak strike deals %d damage." % damage)
	else:
		if result.correct:
			var label := "Correct!"
			if result.question_kind == "sentence_build":
				label = "Perfect sentence!"
			elif result.speed_bonus > 0.0:
				label = "Quick recall!"
			if _battle_streak >= 2:
				label += " Learning combo x%d!" % _battle_streak
			battle_log.emit("%s You deal %d damage." % [label, damage])
		else:
			if result.timed_out:
				battle_log.emit("Time's up. The blade weakly strikes for %d." % damage)
			else:
				battle_log.emit("Not quite. The blade weakly strikes for %d." % damage)

		quiz_resolved.emit(result, damage)

	var enemy_dead := enemy_hp <= 0
	if result != null and not result.correct:
		awaiting_feedback = true
		_enemy_dead_pending = enemy_dead
		feedback_requested.emit(result)

		if result.timed_out:
			_auto_acknowledge_timeout_feedback()

		return

	_continue_after_attack(enemy_dead)


func _continue_after_attack(enemy_dead: bool) -> void:
	if enemy_dead:
		_end_battle(true)
	else:
		_enemy_turn()


func _enemy_turn() -> void:
	if not battle_active:
		return

	await get_tree().create_timer(0.28).timeout
	if not battle_active:
		return

	var mitigation := int(PlayerProgression.get_total_def() * 0.5)
	var damage := maxi(current_enemy.atk - mitigation, 1)
	PlayerProgression.take_damage(damage)
	player_hp_changed.emit(PlayerProgression.current_hp, PlayerProgression.get_total_max_hp())
	battle_log.emit("%s strikes for %d damage." % [current_enemy.display_name, damage])

	if PlayerProgression.current_hp <= 0:
		_end_battle(false)


func _end_battle(victory: bool) -> void:
	if not battle_active:
		return

	battle_active = false
	awaiting_quiz_response = false
	awaiting_feedback = false

	if victory:
		PlayerProgression.add_exp(current_enemy.exp_reward)
		PlayerProgression.gold += current_enemy.gold_reward
		PlayerProgression.stats_changed.emit()
		if not current_enemy.enemy_id.is_empty() and GameEvents:
			GameEvents.enemy_killed.emit(current_enemy.enemy_id)
		battle_log.emit(
			"You defeated %s! +%d EXP, +%d Gold. Best learning combo: x%d"
			% [current_enemy.display_name, current_enemy.exp_reward, current_enemy.gold_reward, _best_battle_streak]
		)
	else:
		battle_log.emit("You were defeated... Keep practicing what you learned.")

	battle_ended.emit(victory)
	GameManager.set_game_state(GameManager.GameState.EXPLORATION)
	if GameManager.has_method("request_save"):
		GameManager.request_save()


func _schedule_retry_if_combat_entry(vocab_id: String) -> void:
	if vocab_id.is_empty():
		return
	var entry := LanguageProgress.get_entry(vocab_id)
	if entry == null:
		return
	if not (entry.allowed_types.has("multiple_choice") or entry.allowed_types.has("translate") or entry.allowed_types.has("fill_blank") or entry.allowed_types.has("match")):
		return
	_schedule_retry(vocab_id)


func _schedule_retry(vocab_id: String) -> void:
	if vocab_id.is_empty():
		return
	for retry in _retry_queue:
		if str(retry.get("id", "")) == vocab_id:
			retry["due"] = _answered_questions + RETRY_DELAY
			return
	_retry_queue.append({"id": vocab_id, "due": _answered_questions + RETRY_DELAY})


func _pop_due_retry() -> String:
	if _retry_queue.is_empty():
		return ""
	for i in _retry_queue.size():
		var retry: Dictionary = _retry_queue[i]
		if int(retry.get("due", 999999)) <= _answered_questions:
			_retry_queue.remove_at(i)
			return str(retry.get("id", ""))
	return ""
