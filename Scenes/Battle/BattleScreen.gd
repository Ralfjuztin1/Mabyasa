extends CanvasLayer

## Battle UI.
## BattleManager handles combat logic.
## QuizUI handles the language quiz.
## This script handles UI updates and player sprite display.

signal closed

@export_range(1.0, 8.0, 0.5) var battle_sprite_scale: float = 4.0


# ============================================================
# ENEMY UI
# ============================================================

@onready var enemy_name_label: Label = \
	$Root/EnemyInfoBox/Margin/VBox/EnemyNameLabel

@onready var enemy_hp_label: Label = \
	$Root/EnemyInfoBox/Margin/VBox/HPRow/EnemyHPLabel

@onready var enemy_hp_bar: ProgressBar = \
	$Root/EnemyInfoBox/Margin/VBox/EnemyHPBar

@onready var barrier_value_label: Label = \
	$Root/EnemyInfoBox/Margin/VBox/BarrierRow/BarrierValueLabel

@onready var barrier_bar: ProgressBar = \
	$Root/EnemyInfoBox/Margin/VBox/BarrierBar

@onready var enemy_sprite_label: Label = \
	$Root/EnemySpriteBox/EnemySpriteLabel


# ============================================================
# PLAYER UI
# ============================================================

@onready var player_level_label: Label = \
	$Root/PlayerInfoBox/Margin/VBox/PlayerNameRow/LevelLabel

@onready var player_hp_label: Label = \
	$Root/PlayerInfoBox/Margin/VBox/PlayerHPRow/PlayerHPLabel

@onready var player_hp_bar: ProgressBar = \
	$Root/PlayerInfoBox/Margin/VBox/PlayerHPBar

@onready var player_exp_bar: ProgressBar = \
	$Root/PlayerInfoBox/Margin/VBox/EXPBar


# ============================================================
# PLAYER BATTLE SPRITE
# ============================================================

@onready var player_sprite_slot: Control = \
	$Root/PlayerSpriteBox

@onready var player_battle_sprite: AnimatedSprite2D = \
	get_node_or_null(
		"Root/PlayerSpriteBox/PlayerSprite"
	) as AnimatedSprite2D

@onready var player_sprite_label: Label = \
	get_node_or_null(
		"Root/PlayerSpriteBox/PlayerSpriteLabel"
	) as Label


# ============================================================
# BOTTOM BAR
# ============================================================

@onready var bottom_bar: HBoxContainer = \
	$Root/BottomBar

@onready var message_label: Label = \
	$Root/BottomBar/MessageBox/MessageMargin/MessageLabel

@onready var attack_button: Button = \
	$Root/BottomBar/ActionBox/ActionMargin/ActionVBox/AttackButton

@onready var potion_button: Button = \
	$Root/BottomBar/ActionBox/ActionMargin/ActionVBox/PotionButton

@onready var continue_button: Button = \
	$Root/BottomBar/ActionBox/ActionMargin/ActionVBox/ContinueButton


# ============================================================
# QUIZ UI
# ============================================================

@onready var quiz_ui: QuizUI = $Root/QuizUI


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# The mouse should be visible while fighting and answering quizzes.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Connect action buttons.
	attack_button.pressed.connect(_on_attack_pressed)
	potion_button.pressed.connect(_on_potion_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	# Connect quiz results.
	quiz_ui.answer_selected.connect(_on_quiz_answer_selected)

	# Connect battle events.
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	BattleManager.enemy_barrier_changed.connect(_on_enemy_barrier_changed)
	BattleManager.player_hp_changed.connect(_on_player_hp_changed)
	BattleManager.quiz_requested.connect(_on_quiz_requested)
	BattleManager.battle_log.connect(_on_battle_log)
	BattleManager.battle_ended.connect(_on_battle_ended)

	# Connect player progression updates.
	if PlayerProgression:
		PlayerProgression.stats_changed.connect(_refresh_player_exp)
		PlayerProgression.leveled_up.connect(_refresh_player_exp)

	_show_action_buttons()

	# Wait until the scene has finished initializing its layout.
	call_deferred("_setup_player_battle_sprite")


# ============================================================
# PLAYER SPRITE SETUP
# ============================================================

func _setup_player_battle_sprite() -> void:
	if not is_instance_valid(player_battle_sprite):
		push_warning(
			"[BATTLE UI] Missing AnimatedSprite2D named PlayerSprite "
			+ "under Root/PlayerSpriteBox."
		)
		_show_player_sprite_fallback()
		return

	var source_node: Node = get_tree().get_first_node_in_group(
		"battle_player_sprite"
	)

	if not (source_node is AnimatedSprite3D):
		push_warning(
			"[BATTLE UI] Could not find the player's AnimatedSprite3D. "
			+ "Add it to the battle_player_sprite group."
		)
		_show_player_sprite_fallback()
		return

	var source: AnimatedSprite3D = source_node as AnimatedSprite3D

	if source.sprite_frames == null:
		push_warning(
			"[BATTLE UI] The player's AnimatedSprite3D has no SpriteFrames."
		)
		_show_player_sprite_fallback()
		return

	var animation_names: PackedStringArray = (
		source.sprite_frames.get_animation_names()
	)

	if animation_names.is_empty():
		push_warning("[BATTLE UI] The player has no animations.")
		_show_player_sprite_fallback()
		return

	# Reuse the original animation resource.
	player_battle_sprite.sprite_frames = source.sprite_frames
	player_battle_sprite.centered = true

	# Preserve sharp pixel-art edges.
	player_battle_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	player_battle_sprite.scale = (
		Vector2.ONE * battle_sprite_scale
	)
	player_battle_sprite.flip_h = source.flip_h
	player_battle_sprite.flip_v = source.flip_v
	player_battle_sprite.speed_scale = source.speed_scale

	var chosen_animation: String = _find_idle_animation(
		source,
		animation_names
	)

	if chosen_animation.is_empty():
		chosen_animation = animation_names[0]

	player_battle_sprite.visible = true
	player_battle_sprite.play(chosen_animation)

	# Hide the old text placeholder when the sprite loads.
	if is_instance_valid(player_sprite_label):
		player_sprite_label.visible = false

	if not player_sprite_slot.resized.is_connected(
		_center_player_battle_sprite
	):
		player_sprite_slot.resized.connect(
			_center_player_battle_sprite
		)

	_center_player_battle_sprite()

	print(
		"[BATTLE UI] Player sprite loaded: ",
		chosen_animation
	)


func _find_idle_animation(
	source: AnimatedSprite3D,
	animation_names: PackedStringArray
) -> String:
	var source_animation: String = str(source.animation)
	var lowered_source: String = source_animation.to_lower()

	# If the world character is already using an idle animation,
	# reuse that exact animation first.
	if (
		animation_names.has(source_animation)
		and lowered_source.contains("idle")
	):
		return source_animation

	# Try to preserve the character's current facing direction.
	var direction: String = ""

	for direction_name in [
		"down",
		"up",
		"left",
		"right",
		"north",
		"south",
		"east",
		"west"
	]:
		if lowered_source.contains(direction_name):
			direction = direction_name
			break

	# Prefer an idle animation matching that direction.
	if not direction.is_empty():
		for animation_name in animation_names:
			var lowered_name: String = animation_name.to_lower()

			if (
				lowered_name.contains("idle")
				and lowered_name.contains(direction)
			):
				return animation_name

	# Fall back to any available idle animation.
	for animation_name in animation_names:
		if animation_name.to_lower().contains("idle"):
			return animation_name

	return ""


func _center_player_battle_sprite() -> void:
	if not is_instance_valid(player_battle_sprite):
		return

	if not is_instance_valid(player_sprite_slot):
		return

	player_battle_sprite.position = (
		player_sprite_slot.size * 0.5
	)


func _show_player_sprite_fallback() -> void:
	if is_instance_valid(player_sprite_label):
		player_sprite_label.visible = true
		player_sprite_label.text = "Player sprite unavailable"

	if is_instance_valid(player_battle_sprite):
		player_battle_sprite.visible = false


# ============================================================
# BATTLE START
# ============================================================

func _on_battle_started(enemy: EnemyData) -> void:
	enemy_name_label.text = enemy.display_name
	enemy_sprite_label.text = (
		enemy.display_name + "\n(no sprite yet)"
	)

	message_label.text = "A wild %s appears!" % enemy.display_name

	_refresh_player_exp()
	_show_action_buttons()


# ============================================================
# ENEMY HP AND BARRIER
# ============================================================

func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	enemy_hp_label.text = "%d / %d" % [current, max_hp]

	if max_hp > 0:
		enemy_hp_bar.value = (
			float(current) / float(max_hp)
		) * 100.0
	else:
		enemy_hp_bar.value = 0.0


func _on_enemy_barrier_changed(
	current: int,
	max_barrier: int
) -> void:
	barrier_value_label.text = (
		"%d / %d" % [current, max_barrier]
	)

	if max_barrier > 0:
		barrier_bar.value = (
			float(current) / float(max_barrier)
		) * 100.0
	else:
		barrier_bar.value = 0.0


# ============================================================
# PLAYER HP AND EXPERIENCE
# ============================================================

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	player_hp_label.text = "%d / %d" % [current, max_hp]

	if max_hp > 0:
		player_hp_bar.value = (
			float(current) / float(max_hp)
		) * 100.0
	else:
		player_hp_bar.value = 0.0


func _refresh_player_exp() -> void:
	if not PlayerProgression:
		return

	var level: int = PlayerProgression.level
	var current_exp: int = PlayerProgression.current_exp
	var max_exp: int = PlayerProgression.get_max_exp(level)

	player_level_label.text = "Lv. %d" % level

	if max_exp > 0:
		player_exp_bar.value = (
			float(current_exp) / float(max_exp)
		) * 100.0
	else:
		player_exp_bar.value = 0.0


# ============================================================
# QUIZ
# ============================================================

func _on_quiz_requested(question: QuizQuestion) -> void:
	# Keep the cursor visible for quiz interactions.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Hide the action bar while the quiz is active.
	bottom_bar.visible = false

	quiz_ui.start_quiz(question)


func _on_quiz_answer_selected(payload: Variant) -> void:
	bottom_bar.visible = true

	BattleManager.submit_quiz_answer(payload)


# ============================================================
# BATTLE MESSAGE
# ============================================================

func _on_battle_log(message: String) -> void:
	message_label.text = message


# ============================================================
# BATTLE END
# ============================================================

func _on_battle_ended(victory: bool) -> void:
	bottom_bar.visible = true

	message_label.text = (
		"You won the fight!"
		if victory
		else "You were defeated..."
	)

	attack_button.visible = false
	potion_button.visible = false
	continue_button.visible = true


# ============================================================
# ACTION BUTTONS
# ============================================================

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
