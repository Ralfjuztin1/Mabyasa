extends Node

## Handles one battle at a time: turn order, the quiz-gates-damage rule,
## HP, win/lose. Deliberately has zero knowledge of story, corruption
## visuals, or real vocabulary — see QuizQuestion.gd and the placeholder
## pool below. Swap _build_placeholder_questions() for a real vocab/quiz
## database later; nothing else in here should need to change.

signal battle_started(enemy: EnemyData)
signal enemy_hp_changed(current: int, max_hp: int)
signal enemy_barrier_changed(current: int, max_barrier: int)
signal player_hp_changed(current: int, max_hp: int)
signal quiz_requested(question: QuizQuestion)
signal quiz_resolved(correct: bool, damage_dealt: int)
signal battle_log(message: String)
signal battle_ended(victory: bool)

const WRONG_ANSWER_DAMAGE_MULT: float = 0.4
const POTION_HEAL_AMOUNT: int = 30

var battle_active: bool = false
var awaiting_quiz_response: bool = false

var current_enemy: EnemyData = null
var enemy_hp: int = 0
var enemy_barrier: int = 0
var current_question: QuizQuestion = null


func start_battle(enemy_data: EnemyData) -> void:
	if battle_active:
		return

	if enemy_data == null:
		push_error("[BATTLE] start_battle called with no EnemyData.")
		return

	current_enemy = enemy_data
	enemy_hp = enemy_data.max_hp
	enemy_barrier = enemy_data.max_barrier
	battle_active = true
	awaiting_quiz_response = false

	PlayerProgression.ensure_hp_initialized()

	if GameManager:
		GameManager.set_game_state(GameManager.GameState.COMBAT)

	battle_started.emit(enemy_data)
	enemy_hp_changed.emit(enemy_hp, enemy_data.max_hp)
	enemy_barrier_changed.emit(enemy_barrier, enemy_data.max_barrier)
	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)
	battle_log.emit("A wild %s appears!" % enemy_data.display_name)


func player_attack() -> void:
	if not battle_active or awaiting_quiz_response:
		return

	awaiting_quiz_response = true
	current_question = _pick_random_question()
	quiz_requested.emit(current_question)


func submit_quiz_answer(selected_index: int) -> void:
	if not battle_active or not awaiting_quiz_response:
		return

	awaiting_quiz_response = false

	var correct: bool = selected_index == current_question.correct_index
	var base_atk: int = PlayerProgression.get_total_atk()
	var damage: int = base_atk if correct else int(base_atk * WRONG_ANSWER_DAMAGE_MULT)
	damage = max(damage, 1)

	# The barrier is a genuine second health pool in front of HP, not a
	# flat percentage reduction. All damage — correct or wrong — hits
	# the barrier first; only once it's fully broken does the remainder
	# spill over into actual HP.
	var barrier_damage: int = min(damage, enemy_barrier)
	var overflow_damage: int = damage - barrier_damage

	enemy_barrier -= barrier_damage
	enemy_hp = max(enemy_hp - overflow_damage, 0)

	enemy_barrier_changed.emit(enemy_barrier, current_enemy.max_barrier)
	enemy_hp_changed.emit(enemy_hp, current_enemy.max_hp)

	if overflow_damage > 0 and barrier_damage > 0:
		battle_log.emit(
			"You broke through the language barrier! %d damage gets through."
			% overflow_damage
		)
	elif overflow_damage > 0:
		battle_log.emit("%d damage!" % overflow_damage)
	elif correct:
		battle_log.emit("Correct! You chip away at the language barrier. (%d)" % barrier_damage)
	else:
		battle_log.emit(
			"Not quite — you barely dent the language barrier. (%d)" % barrier_damage
		)

	quiz_resolved.emit(correct, damage)

	if enemy_hp <= 0:
		_end_battle(true)
		return

	_enemy_turn()


func player_use_potion() -> void:
	if not battle_active or awaiting_quiz_response:
		return

	# No quiz gate on purpose — potion is the safe fallback action.
	PlayerProgression.heal(POTION_HEAL_AMOUNT)
	battle_log.emit("You drink a potion and recover %d HP." % POTION_HEAL_AMOUNT)

	_enemy_turn()


func _enemy_turn() -> void:
	if not battle_active:
		return

	var mitigation: int = int(PlayerProgression.get_total_def() * 0.5)
	var dmg: int = max(current_enemy.atk - mitigation, 1)

	PlayerProgression.take_damage(dmg)
	player_hp_changed.emit(
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	)
	battle_log.emit("%s strikes back for %d damage!" % [current_enemy.display_name, dmg])

	if PlayerProgression.current_hp <= 0:
		_end_battle(false)


func _end_battle(victory: bool) -> void:
	battle_active = false

	if victory:
		PlayerProgression.add_exp(current_enemy.exp_reward)
		PlayerProgression.gold += current_enemy.gold_reward
		PlayerProgression.stats_changed.emit()

		if not current_enemy.enemy_id.is_empty() and GameEvents:
			GameEvents.enemy_killed.emit(current_enemy.enemy_id)

		battle_log.emit(
			"You defeated %s! +%d EXP, +%d Gold."
			% [current_enemy.display_name, current_enemy.exp_reward, current_enemy.gold_reward]
		)
	else:
		battle_log.emit("You were defeated...")

	battle_ended.emit(victory)

	if GameManager:
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)


# ============================================================
# PLACEHOLDER QUIZ POOL
# ============================================================
# Not Kapampangan vocab — intentionally generic so the battle loop
# itself can be built and tested before any real content or story
# is attached. Replace this with a real question source later.

func _pick_random_question() -> QuizQuestion:
	var pool := _build_placeholder_questions()
	return pool[randi() % pool.size()]


func _build_placeholder_questions() -> Array[QuizQuestion]:
	var questions: Array[QuizQuestion] = []

	var q1 := QuizQuestion.new()
	q1.quiz_type = QuizQuestion.QuizType.MULTIPLE_CHOICE
	q1.prompt = "What is 2 + 2?"
	q1.choices = ["3", "4", "5"]
	q1.correct_index = 1
	questions.append(q1)

	var q2 := QuizQuestion.new()
	q2.quiz_type = QuizQuestion.QuizType.FILL_BLANK
	q2.prompt = "The sky is ____"
	q2.choices = ["blue", "loud", "square"]
	q2.correct_index = 0
	questions.append(q2)

	var q3 := QuizQuestion.new()
	q3.quiz_type = QuizQuestion.QuizType.TRANSLATE
	q3.prompt = "What comes after Monday?"
	q3.choices = ["Wednesday", "Sunday", "Tuesday"]
	q3.correct_index = 2
	questions.append(q3)

	return questions
