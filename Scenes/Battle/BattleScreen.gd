extends CanvasLayer

## Presentation-only battle layer.
## BattleManager retains all combat, quiz, damage, reward and turn logic.
## This view uses a side-facing player sprite so 4-direction sprites are enough.

signal closed

@export_range(2.0, 5.0, 0.5) var battle_sprite_scale: float = 4.0

@onready var enemy_name_label: Label = $Root/EnemyInfoBox/Margin/VBox/EnemyNameLabel
@onready var enemy_hp_label: Label = $Root/EnemyInfoBox/Margin/VBox/HPRow/EnemyHPLabel
@onready var enemy_hp_bar: ProgressBar = $Root/EnemyInfoBox/Margin/VBox/EnemyHPBar
@onready var barrier_value_label: Label = $Root/EnemyInfoBox/Margin/VBox/BarrierRow/BarrierValueLabel
@onready var barrier_bar: ProgressBar = $Root/EnemyInfoBox/Margin/VBox/BarrierBar
@onready var enemy_sprite: Sprite2D = $Root/EnemySpriteBox/EnemySprite
@onready var enemy_sprite_slot: Control = $Root/EnemySpriteBox
@onready var enemy_sprite_label: Label = $Root/EnemySpriteBox/EnemySpriteLabel

@onready var player_sprite_slot: Control = $Root/PlayerSpriteBox
@onready var player_battle_sprite: AnimatedSprite2D = $Root/PlayerSpriteBox/PlayerSprite
@onready var player_sprite_label: Label = $Root/PlayerSpriteBox/PlayerSpriteLabel
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

var _last_enemy_hp: int = -1
var _last_player_hp: int = -1
var _entry_animation_played: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	call_deferred("_setup_player_battle_sprite")


# -----------------------------------------------------------------------------
# SPRITE SETUP
# -----------------------------------------------------------------------------

func _setup_player_battle_sprite() -> void:
	var source_node := get_tree().get_first_node_in_group("battle_player_sprite")
	if not (source_node is AnimatedSprite3D):
		_show_player_sprite_fallback("Player sprite unavailable")
		return

	var source := source_node as AnimatedSprite3D
	if source.sprite_frames == null:
		_show_player_sprite_fallback("Player SpriteFrames missing")
		return

	var animation_names := source.sprite_frames.get_animation_names()
	if animation_names.is_empty():
		_show_player_sprite_fallback("Player animations missing")
		return

	player_battle_sprite.sprite_frames = source.sprite_frames
	player_battle_sprite.centered = true
	player_battle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_battle_sprite.speed_scale = 0.75
	player_battle_sprite.flip_h = false

	# The actor stands on the right, so idle_left faces the enemy.
	# This uses a supplied cardinal animation, never a diagonal one.
	var animation := _find_combat_idle(animation_names)
	if animation.is_empty():
		_show_player_sprite_fallback("No idle animation found")
		return

	player_battle_sprite.visible = true
	player_battle_sprite.play(animation)
	if is_instance_valid(player_sprite_label):
		player_sprite_label.visible = false

	if not player_sprite_slot.resized.is_connected(_center_player_battle_sprite):
		player_sprite_slot.resized.connect(_center_player_battle_sprite)
	_center_player_battle_sprite()
	_fit_player_sprite()

	# A battle may have started before the deferred sprite copy finished.
	if BattleManager.battle_active:
		call_deferred("_play_battle_entry")


func _find_combat_idle(animation_names: PackedStringArray) -> String:
	for preferred in ["idle_left", "idle_right", "idle_back", "idle_front"]:
		if animation_names.has(preferred):
			return preferred

	for animation_name in animation_names:
		if animation_name.to_lower().contains("idle"):
			return animation_name
	return ""


func _center_player_battle_sprite() -> void:
	if not is_instance_valid(player_battle_sprite) or not is_instance_valid(player_sprite_slot):
		return
	player_battle_sprite.position = player_sprite_slot.size * 0.5
	_fit_player_sprite()


func _fit_player_sprite() -> void:
	if not is_instance_valid(player_battle_sprite) or player_battle_sprite.sprite_frames == null:
		return
	var animation := str(player_battle_sprite.animation)
	if animation.is_empty() or player_battle_sprite.sprite_frames.get_frame_count(animation) == 0:
		return
	var frame_texture := player_battle_sprite.sprite_frames.get_frame_texture(animation, 0)
	if frame_texture == null:
		return
	var frame_size := frame_texture.get_size()
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	var fit_scale := minf(
		player_sprite_slot.size.x * 0.84 / frame_size.x,
		player_sprite_slot.size.y * 0.88 / frame_size.y
	)
	# Keep pixel-art scaling integer where possible, so edges stay crisp.
	var integer_scale := floorf(minf(battle_sprite_scale, fit_scale))
	player_battle_sprite.scale = Vector2.ONE * maxf(1.0, integer_scale)


func _show_player_sprite_fallback(message: String) -> void:
	if is_instance_valid(player_sprite_label):
		player_sprite_label.visible = true
		player_sprite_label.text = message
	if is_instance_valid(player_battle_sprite):
		player_battle_sprite.visible = false


func _fit_enemy_sprite() -> void:
	if not is_instance_valid(enemy_sprite) or enemy_sprite.texture == null:
		return
	var size := enemy_sprite.texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit_scale := minf(
		enemy_sprite_slot.size.x * 0.90 / size.x,
		enemy_sprite_slot.size.y * 0.90 / size.y
	)
	var integer_scale := floorf(minf(battle_sprite_scale, fit_scale))
	enemy_sprite.scale = Vector2.ONE * maxf(1.0, integer_scale)
	enemy_sprite.position = enemy_sprite_slot.size * 0.5


func _show_enemy_sprite(enemy: EnemyData) -> void:
	enemy_sprite.texture = enemy.battle_sprite
	enemy_sprite.visible = enemy.battle_sprite != null
	enemy_sprite.flip_h = enemy.battle_sprite_flip_h
	if enemy.battle_sprite != null:
		enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		enemy_sprite_label.visible = false
		_fit_enemy_sprite()
	else:
		enemy_sprite_label.visible = true
		enemy_sprite_label.text = enemy.display_name
		push_warning(
			"[BATTLE UI] No battle sprite assigned for '"
			+ enemy.display_name
			+ "'. Set enemy_battle_sprite on the BattleTrigger."
		)

	if not enemy_sprite_slot.resized.is_connected(_fit_enemy_sprite):
		enemy_sprite_slot.resized.connect(_fit_enemy_sprite)


func _play_battle_entry() -> void:
	if _entry_animation_played:
		return
	_entry_animation_played = true

	var tween := create_tween()
	tween.set_parallel(true)
	if is_instance_valid(enemy_sprite) and enemy_sprite.visible:
		var enemy_home := enemy_sprite.position
		enemy_sprite.position = enemy_home + Vector2(-52.0, 0.0)
		enemy_sprite.modulate.a = 0.0
		tween.tween_property(enemy_sprite, "position", enemy_home, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(enemy_sprite, "modulate:a", 1.0, 0.22)

	if is_instance_valid(player_battle_sprite) and player_battle_sprite.visible:
		var player_home := player_battle_sprite.position
		player_battle_sprite.position = player_home + Vector2(52.0, 0.0)
		player_battle_sprite.modulate.a = 0.0
		tween.tween_property(player_battle_sprite, "position", player_home, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(player_battle_sprite, "modulate:a", 1.0, 0.24)


# -----------------------------------------------------------------------------
# BATTLE EVENTS: VISUALS ONLY
# -----------------------------------------------------------------------------

func _on_battle_started(enemy: EnemyData) -> void:
	_entry_animation_played = false
	_last_enemy_hp = enemy.max_hp
	_last_player_hp = -1
	enemy_name_label.text = enemy.display_name
	_show_enemy_sprite(enemy)
	message_label.text = "A wild %s appears!" % enemy.display_name
	_refresh_player_exp()
	_show_action_buttons()
	call_deferred("_play_battle_entry")


func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	enemy_hp_label.text = "%d / %d" % [current, max_hp]
	enemy_hp_bar.value = float(current) / float(max_hp) * 100.0 if max_hp > 0 else 0.0
	if _last_enemy_hp >= 0 and current < _last_enemy_hp:
		_play_hit_feedback(enemy_sprite)
	_last_enemy_hp = current


func _on_enemy_barrier_changed(current: int, max_barrier: int) -> void:
	barrier_value_label.text = "%d / %d" % [current, max_barrier]
	barrier_bar.value = float(current) / float(max_barrier) * 100.0 if max_barrier > 0 else 0.0


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	player_hp_label.text = "%d / %d" % [current, max_hp]
	player_hp_bar.value = float(current) / float(max_hp) * 100.0 if max_hp > 0 else 0.0
	if _last_player_hp >= 0 and current < _last_player_hp:
		_play_hit_feedback(player_battle_sprite)
	_last_player_hp = current


func _refresh_player_exp() -> void:
	if not PlayerProgression:
		return
	player_level_label.text = "Lv. %d" % PlayerProgression.level
	var max_exp: int = PlayerProgression.get_max_exp(PlayerProgression.level)
	player_exp_bar.value = float(PlayerProgression.current_exp) / float(max_exp) * 100.0 if max_exp > 0 else 0.0


func _on_quiz_requested(question: QuizQuestion) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bottom_bar.visible = false
	quiz_ui.start_quiz(question)


func _on_quiz_answer_selected(payload: Variant) -> void:
	bottom_bar.visible = true
	BattleManager.submit_quiz_answer(payload)


func _play_hit_feedback(actor: Node2D) -> void:
	if not is_instance_valid(actor) or not actor.visible:
		return
	var home_position: Vector2 = actor.position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(actor, "modulate", Color(1.0, 0.58, 0.48, 1.0), 0.07)
	tween.parallel().tween_property(actor, "position:x", home_position.x + 5.0, 0.035)
	tween.tween_property(actor, "position:x", home_position.x - 5.0, 0.045)
	tween.tween_property(actor, "position:x", home_position.x, 0.06)
	tween.tween_property(actor, "modulate", Color.WHITE, 0.10)


func _on_battle_log(message: String) -> void:
	message_label.text = message


func _on_battle_ended(victory: bool) -> void:
	bottom_bar.visible = true
	message_label.text = "Victory! The path is clear." if victory else "You were defeated..."
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
