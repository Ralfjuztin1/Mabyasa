extends CanvasLayer

## Pure UI layer — all it does is reflect BattleManager's state and
## forward input back into it. No combat rules live here.
##
## The bottom bar (MessageBox + ActionBox) handles action selection and
## simple log text. The quiz itself — sword, question, draggable answer
## cards — is fully owned by QuizUI; this script just shows/hides it and
## forwards its answer_selected signal into BattleManager.

signal closed

@onready var enemy_name_label: Label = $Root/EnemyInfoBox/Margin/VBox/EnemyNameLabel
@onready var enemy_hp_label: Label = $Root/EnemyInfoBox/Margin/VBox/HPRow/EnemyHPLabel
@onready var enemy_hp_bar: ProgressBar = $Root/EnemyInfoBox/Margin/VBox/EnemyHPBar
@onready var barrier_value_label: Label = $Root/EnemyInfoBox/Margin/VBox/BarrierRow/BarrierValueLabel
@onready var barrier_bar: ProgressBar = $Root/EnemyInfoBox/Margin/VBox/BarrierBar
@onready var enemy_sprite_label: Label = $Root/EnemySpriteBox/EnemySpriteLabel

@onready var player_level_label: Label = $Root/PlayerInfoBox/Margin/VBox/PlayerNameRow/LevelLabel
@onready var player_hp_label: Label = $Root/PlayerInfoBox/Margin/VBox/PlayerHPRow/PlayerHPLabel
@onready var player_hp_bar: ProgressBar = $Root/PlayerInfoBox/Margin/VBox/PlayerHPBar
@onready var player_exp_bar: ProgressBar = $Root/PlayerInfoBox/Margin/VBox/EXPBar

@onready var bottom_bar: HBoxContainer = $Root/BottomBar
@onready var message_label: Label = $Root/BottomBar/MessageBox/MessageMargin/MessageLabel

@onready var attack_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/AttackButton
@onready var potion_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/PotionButton
@onready var continue_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/ContinueButton

@onready var quiz_ui: QuizUI = $Root/QuizUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Show cursor for battle UI.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	attack_button.pressed.connect(_on_attack_pressed)
	potion_button.pressed.connect(_on_potion_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	quiz_ui.answer_selected.connect(_on_quiz_answer_selected)

	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	BattleManager.enemy_barrier_changed.connect(_on_enemy_barrier_changed)
	BattleManager.player_hp_changed.connect(_on_player_hp_changed)
	BattleManager.quiz_requested.connect(_on_quiz_requested)
	BattleManager.battle_log.connect(_on_battle_log)
	BattleManager.battle_ended.connect(_on_battle_ended)

	if PlayerProgression:
		PlayerProgression.stats_changed.connect(_refresh_player_exp)
		PlayerProgression.leveled_up.connect(_refresh_player_exp)

	_show_action_buttons()


func _on_battle_started(enemy: EnemyData) -> void:
	enemy_name_label.text = enemy.display_name
	enemy_sprite_label.text = enemy.display_name + "\n(no sprite yet)"
	message_label.text = "A wild %s appears!" % enemy.display_name
	_refresh_player_exp()
	_show_action_buttons()


func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	enemy_hp_label.text = "%d / %d" % [current, max_hp]

	if max_hp > 0:
		enemy_hp_bar.value = (float(current) / float(max_hp)) * 100.0


func _on_enemy_barrier_changed(current: int, max_barrier: int) -> void:
	barrier_value_label.text = "%d / %d" % [current, max_barrier]

	if max_barrier > 0:
		barrier_bar.value = (float(current) / float(max_barrier)) * 100.0
	else:
		barrier_bar.value = 0.0


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	player_hp_label.text = "%d / %d" % [current, max_hp]

	if max_hp > 0:
		player_hp_bar.value = (float(current) / float(max_hp)) * 100.0


func _refresh_player_exp() -> void:
	if not PlayerProgression:
		return

	var level: int = PlayerProgression.level
	var current_exp: int = PlayerProgression.current_exp
	var max_exp: int = PlayerProgression.get_max_exp(level)

	player_level_label.text = "Lv. %d" % level

	if max_exp > 0:
		player_exp_bar.value = (float(current_exp) / float(max_exp)) * 100.0


func _on_quiz_requested(question: QuizQuestion) -> void:
	# Bottom bar hides while the quiz overlay is up — the sword and
	# cards occupy roughly the same screen region, and having both
	# visible at once would be redundant.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bottom_bar.visible = false
	quiz_ui.start_quiz(question)


func _on_quiz_answer_selected(payload: Variant) -> void:
	bottom_bar.visible = true
	BattleManager.submit_quiz_answer(payload)


func _on_battle_log(message: String) -> void:
	message_label.text = message


func _on_battle_ended(victory: bool) -> void:
	bottom_bar.visible = true
	message_label.text = (
		"You won the fight!" if victory else "You were defeated..."
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	attack_button.visible = false
	potion_button.visible = false
	continue_button.visible = true


func _show_action_buttons() -> void:
	continue_button.visible = false
	attack_button.visible = true
	potion_button.visible = true


func _on_attack_pressed() -> void:
	BattleManager.player_attack()


func _on_potion_pressed() -> void:
	BattleManager.player_use_potion()


func _on_continue_pressed() -> void:
	closed.emit()
	queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
