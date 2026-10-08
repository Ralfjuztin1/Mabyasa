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


const MIN_DAMAGE_MULT: float = 0.40
const MAX_DAMAGE_MULT: float = 1.55
const POTION_HEAL_AMOUNT: int = 30

const RECENT_MEMORY: int = 3
const RECENT_KIND_MEMORY: int = 2

const RETRY_DELAY: int = 1

const TIMEOUT_FEEDBACK_DELAY: float = 1.8
const WRONG_FEEDBACK_DELAY: float = 1.2


var battle_active: bool = false
var awaiting_quiz_response: bool = false
var awaiting_feedback: bool = false


var current_enemy: EnemyData = null

var enemy_hp: int = 0
var enemy_barrier: int = 0

var current_question: QuizQuestion = null


var _recent_ids: Array[String] = []
var _recent_kinds: Array[String] = []

var _retry_queue: Array[Dictionary] = []


var _answered_questions: int = 0

var _battle_streak: int = 0
var _best_battle_streak: int = 0


var _enemy_dead_pending: bool = false


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

	enemy_hp = maxi(
		enemy_data.max_hp,
		1
	)

	enemy_barrier = maxi(
		enemy_data.max_barrier,
		0
	)

	battle_active = true
	awaiting_quiz_response = false
	awaiting_feedback = false

	current_question = null

	_enemy_dead_pending = false

	_recent_ids.clear()
	_recent_kinds.clear()
	_retry_queue.clear()

	_answered_questions = 0

	_battle_streak = 0
	_best_battle_streak = 0

	PlayerProgression.ensure_hp_initialized()

	GameManager.set_game_state(
		GameManager.GameState.COMBAT
	)

	battle_started.emit(
		enemy_data
	)

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

	battle_streak_changed.emit(
		0,
		0
	)

	battle_log.emit(
		"A wild %s appears!"
		% enemy_data.display_name
	)


# ============================================================
# PLAYER ATTACK
# ============================================================

func player_attack() -> void:

	if (
		not battle_active
		or awaiting_quiz_response
		or awaiting_feedback
	):
		return


	var forced_id: String = (
		_pop_due_retry()
	)


	var question: QuizQuestion = null


	if (
		current_enemy != null
		and current_enemy.is_boss
	):

		question = (
			QuestionFactoryScript
			.build_boss_sentence_question(
				_recent_ids
			)
		)

	else:

		question = (
			QuestionFactoryScript
			.build_normal_question(
				_recent_ids,
				_recent_kinds,
				forced_id
			)
		)


	# --------------------------------------------------------
	# NO QUESTION
	# --------------------------------------------------------
	#
	# IMPORTANT:
	# Do NOT damage the enemy here.
	#
	# The player must encounter vocabulary before battle can
	# produce an attack.
	# --------------------------------------------------------

	if question == null:

		battle_log.emit(
			"No encountered vocabulary is available yet."
		)

		return


	# --------------------------------------------------------
	# RECENT VOCABULARY
	# --------------------------------------------------------

	for tested_id: String in question.tested_vocab_ids:

		if tested_id.is_empty():
			continue

		if not _recent_ids.has(tested_id):

			_recent_ids.append(
				tested_id
			)


	while _recent_ids.size() > RECENT_MEMORY:

		_recent_ids.pop_front()


	# --------------------------------------------------------
	# RECENT QUESTION TYPES
	# --------------------------------------------------------

	var question_kind: String = (
		question.get_kind_name()
	)

	if not question_kind.is_empty():

		_recent_kinds.append(
			question_kind
		)


	while _recent_kinds.size() > RECENT_KIND_MEMORY:

		_recent_kinds.pop_front()


	# --------------------------------------------------------
	# OPEN QUIZ
	# --------------------------------------------------------

	current_question = question

	awaiting_quiz_response = true

	quiz_requested.emit(
		question
	)


# ============================================================
# SUBMIT QUIZ ANSWER
# ============================================================

func submit_quiz_answer(
	payload: Variant
) -> void:

	if (
		not battle_active
		or not awaiting_quiz_response
		or current_question == null
	):
		return


	awaiting_quiz_response = false


	var result: AnswerResult = (
		current_question.evaluate_answer(
			payload
		)
	)


	if result == null:

		push_error(
			"[BATTLE] Quiz returned no AnswerResult."
		)

		current_question = null

		return


	current_question = null

	_answered_questions += 1


	# --------------------------------------------------------
	# RECORD LANGUAGE RESULTS
	# --------------------------------------------------------

	for vocab_id_variant: Variant in (
		result.per_vocab_results.keys()
	):

		var vocab_id: String = str(
			vocab_id_variant
		)

		var correct: bool = bool(
			result.per_vocab_results[
				vocab_id_variant
			]
		)

		LanguageProgress.record_result(
			vocab_id,
			correct
		)


	# --------------------------------------------------------
	# STREAK
	# --------------------------------------------------------

	if result.correct:

		_battle_streak += 1

		_best_battle_streak = maxi(
			_best_battle_streak,
			_battle_streak
		)

	else:

		_battle_streak = 0

		for failed_id_variant: Variant in (
			result.per_vocab_results.keys()
		):

			var failed_id: String = str(
				failed_id_variant
			)

			var failed: bool = bool(
				result.per_vocab_results[
					failed_id_variant
				]
			)

			if not failed:

				_schedule_retry_if_combat_entry(
					failed_id
				)


	battle_streak_changed.emit(
		_battle_streak,
		_best_battle_streak
	)


	# --------------------------------------------------------
	# DAMAGE
	# --------------------------------------------------------

	var multiplier: float = (
		_calculate_damage_multiplier(
			result
		)
	)

	result.damage_multiplier = multiplier

	_apply_attack(
		multiplier,
		result
	)


# ============================================================
# FEEDBACK
# ============================================================

func acknowledge_feedback() -> void:

	if not awaiting_feedback:
		return

	awaiting_feedback = false

	var enemy_dead: bool = (
		_enemy_dead_pending
	)

	_enemy_dead_pending = false

	if enemy_dead:

		_end_battle(
			true
		)

	else:

		_enemy_turn()


func _auto_acknowledge_timeout_feedback() -> void:

	await get_tree().create_timer(
		TIMEOUT_FEEDBACK_DELAY
	).timeout

	if (
		not battle_active
		or not awaiting_feedback
	):
		return

	acknowledge_feedback()


func _auto_acknowledge_wrong_feedback() -> void:

	await get_tree().create_timer(
		WRONG_FEEDBACK_DELAY
	).timeout

	if (
		not battle_active
		or not awaiting_feedback
	):
		return

	acknowledge_feedback()


# ============================================================
# POTION
# ============================================================

func player_use_potion() -> void:

	if (
		not battle_active
		or awaiting_quiz_response
		or awaiting_feedback
	):
		return


	PlayerProgression.heal(
		POTION_HEAL_AMOUNT
	)

	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)

	battle_log.emit(
		"You recover %d HP."
		% POTION_HEAL_AMOUNT
	)

	_enemy_turn()


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
			MIN_DAMAGE_MULT
			+ result.score * 0.40,
			MIN_DAMAGE_MULT,
			0.80
		)


	var multiplier: float = 1.0


	multiplier += minf(
		float(
			maxi(
				_battle_streak - 1,
				0
			)
		) * 0.05,
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

	var base_atk: int = (
		PlayerProgression.get_total_atk()
	)


	var damage: int = maxi(
		int(
			round(
				float(base_atk)
				* damage_mult
			)
		),
		1
	)


	# --------------------------------------------------------
	# BARRIER
	# --------------------------------------------------------

	var barrier_damage: int = mini(
		damage,
		enemy_barrier
	)

	var hp_damage: int = (
		damage
		- barrier_damage
	)

	enemy_barrier -= barrier_damage

	enemy_hp = maxi(
		enemy_hp - hp_damage,
		0
	)


	enemy_barrier_changed.emit(
		enemy_barrier,
		current_enemy.max_barrier
	)

	enemy_hp_changed.emit(
		enemy_hp,
		current_enemy.max_hp
	)


	# --------------------------------------------------------
	# RESULT
	# --------------------------------------------------------

	if result == null:

		return


	if result.correct:

		var label: String = (
			"Correct!"
		)

		if result.question_kind == "sentence_build":

			label = "Perfect sentence!"

		elif result.speed_bonus > 0.0:

			label = "Quick recall!"


		if _battle_streak >= 2:

			label += (
				" Learning combo x%d!"
				% _battle_streak
			)


		battle_log.emit(
			"%s You deal %d damage."
			% [
				label,
				damage
			]
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


	quiz_resolved.emit(
		result,
		damage
	)


	# --------------------------------------------------------
	# CHECK DEATH
	# --------------------------------------------------------

	var enemy_dead: bool = (
		enemy_hp <= 0
	)


	# --------------------------------------------------------
	# WRONG ANSWER
	# --------------------------------------------------------

	if not result.correct:

		awaiting_feedback = true

		_enemy_dead_pending = enemy_dead

		feedback_requested.emit(
			result
		)


		if result.timed_out:

			_auto_acknowledge_timeout_feedback()

		else:

			_auto_acknowledge_wrong_feedback()

		return


	# --------------------------------------------------------
	# CORRECT ANSWER
	# --------------------------------------------------------

	if enemy_dead:

		_end_battle(
			true
		)

	else:

		_enemy_turn()


# ============================================================
# ENEMY TURN
# ============================================================

func _enemy_turn() -> void:

	if not battle_active:
		return


	await get_tree().create_timer(
		0.28
	).timeout


	if not battle_active:
		return


	var mitigation: int = int(
		PlayerProgression.get_total_def()
		* 0.5
	)

	var damage: int = maxi(
		current_enemy.atk - mitigation,
		1
	)


	PlayerProgression.take_damage(
		damage
	)

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

		_end_battle(
			false
		)


# ============================================================
# END BATTLE
# ============================================================

func _end_battle(
	victory: bool
) -> void:

	if not battle_active:
		return


	battle_active = false
	awaiting_quiz_response = false
	awaiting_feedback = false

	current_question = null

	_enemy_dead_pending = false


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

		battle_log.emit(
			"You were defeated..."
		)


	battle_ended.emit(
		victory
	)

	GameManager.set_game_state(
		GameManager.GameState.EXPLORATION
	)


	if GameManager.has_method(
		"request_save"
	):

		GameManager.request_save()


# ============================================================
# RETRY SYSTEM
# ============================================================

func _schedule_retry_if_combat_entry(
	vocab_id: String
) -> void:

	if vocab_id.is_empty():
		return


	if not LanguageProgress.is_encountered(
		vocab_id
	):
		return


	var entry: VocabEntry = (
		LanguageProgress.get_entry(
			vocab_id
		)
	)


	if entry == null:
		return


	var combat_allowed: bool = (
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
	)


	if not combat_allowed:
		return


	_schedule_retry(
		vocab_id
	)


func _schedule_retry(
	vocab_id: String
) -> void:

	if vocab_id.is_empty():
		return


	for retry_variant: Variant in _retry_queue:

		var retry: Dictionary = (
			retry_variant as Dictionary
		)

		if str(
			retry.get(
				"id",
				""
			)
		) == vocab_id:

			retry["due"] = (
				_answered_questions
				+ RETRY_DELAY
			)

			return


	_retry_queue.append(
		{
			"id": vocab_id,
			"due": (
				_answered_questions
				+ RETRY_DELAY
			)
		}
	)


func _pop_due_retry() -> String:

	if _retry_queue.is_empty():
		return ""


	for i: int in range(
		_retry_queue.size()
	):

		var retry: Dictionary = (
			_retry_queue[i]
			as Dictionary
		)


		if int(
			retry.get(
				"due",
				999999
			)
		) <= _answered_questions:

			_retry_queue.remove_at(
				i
			)

			return str(
				retry.get(
					"id",
					""
				)
			)


	return ""
