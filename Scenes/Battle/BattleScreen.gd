extends CanvasLayer

const BossAssessmentOverlayScene: PackedScene = preload(
    "res://Scenes/Battle/BossAssessmentOverlay.tscn"
)

signal closed

@export_range(2.0, 5.0, 0.5) var battle_sprite_scale: float = 4.0

@onready var enemy_name_label: Label = $Root/EnemyInfoBox/Margin/VBox/EnemyNameLabel
@onready var enemy_hp_label: Label = $Root/EnemyInfoBox/Margin/VBox/HPRow/EnemyHPLabel
@onready var enemy_hp_bar: ProgressBar = $Root/EnemyInfoBox/Margin/VBox/EnemyHPBar
@onready var barrier_value_label: Label = $Root/EnemyInfoBox/Margin/VBox/BarrierRow/BarrierValueLabel
@onready var barrier_bar: ProgressBar = $Root/EnemyInfoBox/Margin/VBox/BarrierBar
@onready var enemy_sprite: AnimatedSprite2D = $Root/EnemySpriteBox/EnemySprite
@onready var enemy_sprite_slot: Control = $Root/EnemySpriteBox
@onready var enemy_sprite_label: Label = $Root/EnemySpriteBox/EnemySpriteLabel

@onready var player_sprite_slot: Control = $Root/PlayerSpriteBox
@onready var player_battle_sprite: AnimatedSprite2D = $Root/PlayerSpriteBox/PlayerSprite
@onready var player_sprite_label: Label = $Root/PlayerSpriteBox/PlayerSpriteLabel
@onready var player_level_label: Label = $Root/PlayerInfoBox/Margin/VBox/PlayerNameRow/LevelLabel
@onready var player_name_label: Label = $Root/PlayerInfoBox/Margin/VBox/PlayerNameRow/PlayerNameLabel
@onready var player_hp_label: Label = $Root/PlayerInfoBox/Margin/VBox/PlayerHPRow/PlayerHPLabel
@onready var player_hp_bar: ProgressBar = $Root/PlayerInfoBox/Margin/VBox/PlayerHPBar
@onready var player_exp_bar: ProgressBar = $Root/PlayerInfoBox/Margin/VBox/EXPBar

@onready var bottom_bar: HBoxContainer = $Root/BottomBar
@onready var message_label: Label = $Root/BottomBar/MessageBox/MessageMargin/MessageLabel
@onready var attack_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/AttackButton

# Keep the existing scene node path to avoid breaking BattleScreen.tscn.
@onready var food_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/PotionButton

@onready var flee_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/FleeButton
@onready var continue_button: Button = $Root/BottomBar/ActionBox/ActionMargin/ActionVBox/ContinueButton
@onready var quiz_ui: QuizUI = $Root/QuizUI

var _last_enemy_hp: int = -1
var _last_player_hp: int = -1
var _last_battle_victory: bool = true
var _entry_animation_played: bool = false
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _current_enemy_idle_animation: StringName = &""
var _current_enemy_attack_animation: StringName = &""
var _current_enemy_hit_animation: StringName = &""
var _current_enemy_action_animation: StringName = &""
var _current_enemy_action_kind: StringName = &""
var _enemy_hp_tween: Tween = null
var _player_hp_tween: Tween = null
var _player_hit_tween: Tween = null
var _enemy_hp_visual_generation: int = 0
var _player_hp_visual_generation: int = 0
var _player_hp_visual_parts_remaining: int = 0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_previous_mouse_mode = Input.mouse_mode

	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	attack_button.pressed.connect(_on_attack_pressed)
	food_button.pressed.connect(_on_food_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	quiz_ui.answer_selected.connect(_on_quiz_answer_selected)

	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	BattleManager.enemy_barrier_changed.connect(_on_enemy_barrier_changed)
	BattleManager.player_hp_changed.connect(_on_player_hp_changed)
	BattleManager.quiz_requested.connect(_on_quiz_requested)
	BattleManager.battle_log.connect(_on_battle_log)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.battle_fled.connect(_on_battle_fled)
	BattleManager.enemy_attack_animation_requested.connect(_on_enemy_attack_animation_requested)
	BattleManager.enemy_hit_animation_requested.connect(_on_enemy_hit_animation_requested)
	BattleManager.turn_busy_changed.connect(_on_turn_busy_changed)

	InventoryManager.battle_food_selected.connect(
		_on_battle_food_selected
	)
	InventoryManager.inventory_changed.connect(
		_refresh_food_button
	)

	if not enemy_sprite.animation_finished.is_connected(
		_on_enemy_animation_finished
	):
		enemy_sprite.animation_finished.connect(
			_on_enemy_animation_finished
		)

	if PlayerProgression:
		PlayerProgression.stats_changed.connect(_refresh_player_exp)
		PlayerProgression.leveled_up.connect(_refresh_player_exp)

	_refresh_food_button()
	_show_action_buttons()
	_on_turn_busy_changed(BattleManager.action_in_progress)

	call_deferred("_setup_player_battle_sprite")


# ============================================================
# MOUSE VISIBILITY
# ============================================================

func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = _previous_mouse_mode


# ============================================================
# PLAYER SPRITE SETUP
# ============================================================

func _setup_player_battle_sprite() -> void:
	var source_node := get_tree().get_first_node_in_group(
        "battle_player_sprite"
	)

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

	var animation := _find_combat_idle(animation_names)

	if animation.is_empty():
		_show_player_sprite_fallback("No idle animation found")
		return

	player_battle_sprite.visible = true
	player_battle_sprite.play(animation)

	if is_instance_valid(player_sprite_label):
		player_sprite_label.visible = false

	if not player_sprite_slot.resized.is_connected(
		_center_player_battle_sprite
	):
		player_sprite_slot.resized.connect(
			_center_player_battle_sprite
		)

	_center_player_battle_sprite()
	_fit_player_sprite()

	if BattleManager.battle_active:
		call_deferred("_play_battle_entry")


func _find_combat_idle(
	animation_names: PackedStringArray
) -> String:
	for preferred in [
		"idle_left",
		"idle_right",
		"idle_back",
        "idle_front"
	]:
		if animation_names.has(preferred):
			return preferred

	for animation_name in animation_names:
		if animation_name.to_lower().contains("idle"):
			return animation_name

	return ""


func _center_player_battle_sprite() -> void:
	if not is_instance_valid(player_battle_sprite):
		return

	if not is_instance_valid(player_sprite_slot):
		return

	player_battle_sprite.position = player_sprite_slot.size * 0.5
	_fit_player_sprite()


func _fit_player_sprite() -> void:
	if not is_instance_valid(player_battle_sprite):
		return

	if player_battle_sprite.sprite_frames == null:
		return

	var animation := str(player_battle_sprite.animation)

	if animation.is_empty():
		return

	if player_battle_sprite.sprite_frames.get_frame_count(animation) == 0:
		return

	var frame_texture := (
		player_battle_sprite.sprite_frames.get_frame_texture(
			animation,
			0
		)
	)

	if frame_texture == null:
		return

	var frame_size := frame_texture.get_size()

	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	var fit_scale := minf(
		player_sprite_slot.size.x * 0.84 / frame_size.x,
		player_sprite_slot.size.y * 0.88 / frame_size.y
	)

	var integer_scale := floorf(
		minf(battle_sprite_scale, fit_scale)
	)

	player_battle_sprite.scale = (
		Vector2.ONE * maxf(1.0, integer_scale)
	)


func _show_player_sprite_fallback(message: String) -> void:
	if is_instance_valid(player_sprite_label):
		player_sprite_label.visible = true
		player_sprite_label.text = message

	if is_instance_valid(player_battle_sprite):
		player_battle_sprite.visible = false


# ============================================================
# ENEMY SPRITE
# ============================================================

func _fit_enemy_sprite() -> void:
	if not is_instance_valid(enemy_sprite):
		return
	if enemy_sprite.sprite_frames == null or enemy_sprite.animation.is_empty():
		return
	if not enemy_sprite.sprite_frames.has_animation(enemy_sprite.animation):
		return
	if enemy_sprite.sprite_frames.get_frame_count(enemy_sprite.animation) <= 0:
		return

	var texture: Texture2D = enemy_sprite.sprite_frames.get_frame_texture(
		enemy_sprite.animation,
		0
	)

	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale: float = minf(
		enemy_sprite_slot.size.x * 0.90 / texture_size.x,
		enemy_sprite_slot.size.y * 0.90 / texture_size.y
	)

	var integer_scale: float = floorf(
		minf(battle_sprite_scale, fit_scale)
	)

	enemy_sprite.scale = Vector2.ONE * maxf(1.0, integer_scale)
	enemy_sprite.position = enemy_sprite_slot.size * 0.5


func _choose_enemy_battle_animation(
	frames: SpriteFrames,
	preferred: StringName,
	flip_h: bool
) -> StringName:
	if frames == null:
		return &""

	var side_animation: StringName = &"idle_left" if not flip_h else &"idle_right"
	var other_side_animation: StringName = &"idle_right" if not flip_h else &"idle_left"

	var candidates: Array[StringName] = [
		preferred,
		&"battle_idle",
		side_animation,
		&"idle_front",
		&"idle",
		&"default",
		other_side_animation,
		&"idle_back"
	]

	for animation_name: StringName in candidates:
		if (
			frames.has_animation(animation_name)
			and frames.get_frame_count(animation_name) > 0
		):
			return animation_name

	for animation_text: String in frames.get_animation_names():
		var animation_name: StringName = StringName(animation_text)

		if frames.get_frame_count(animation_name) > 0:
			return animation_name

	return &""


func _find_enemy_animation(
	frames: SpriteFrames,
	preferred: StringName,
	fallback_names: Array[StringName]
) -> StringName:
	if frames == null:
		return &""

	var candidates: Array[StringName] = []

	if not preferred.is_empty():
		candidates.append(preferred)

	for candidate: StringName in fallback_names:
		if not candidates.has(candidate):
			candidates.append(candidate)

	for candidate: StringName in candidates:
		if frames.has_animation(candidate) and frames.get_frame_count(candidate) > 0:
			return candidate

		for actual_text: String in frames.get_animation_names():
			if actual_text.to_lower() == str(candidate).to_lower():
				var actual: StringName = StringName(actual_text)

				if frames.get_frame_count(actual) > 0:
					return actual

	return &""


func _show_enemy_sprite(enemy: EnemyData) -> void:
	var frames: SpriteFrames = enemy.battle_sprite_frames

	# Support older BattleTrigger instances.
	if frames == null and enemy.battle_sprite != null:
		frames = SpriteFrames.new()

		if not frames.has_animation(&"idle"):
			frames.add_animation(&"idle")

		frames.set_animation_loop(&"idle", true)
		frames.add_frame(&"idle", enemy.battle_sprite)

	enemy_sprite.stop()
	enemy_sprite.sprite_frames = frames
	enemy_sprite.flip_h = enemy.battle_sprite_flip_h

	var preferred_idle: StringName = enemy.battle_sprite_animation

	if preferred_idle.is_empty():
		preferred_idle = (
			&"idle_left"
			if not enemy.battle_sprite_flip_h
			else &"idle_right"
		)

	var chosen_animation: StringName = _find_enemy_animation(
		frames,
		preferred_idle,
		[
			&"battle_idle",
			&"idle_left",
			&"idle_right",
			&"idle_front",
			&"idle_back",
			&"idle",
			&"default"
		]
	)

	_current_enemy_idle_animation = chosen_animation

	_current_enemy_attack_animation = _find_enemy_animation(
		frames,
		enemy.battle_attack_animation,
		[
			&"attack_left",
			&"attack",
			&"atk_left",
			&"atk",
			&"attack_right",
			&"attack_front",
			&"attack_back"
		]
	)

	_current_enemy_hit_animation = _find_enemy_animation(
		frames,
		enemy.battle_hit_animation,
		[
			&"hit",
			&"hurt",
			&"hit_left",
			&"hurt_left",
			&"damage",
			&"hit_right",
			&"hurt_right"
		]
	)

	_current_enemy_action_animation = &""

	if frames != null and not chosen_animation.is_empty():
		enemy_sprite.visible = true
		enemy_sprite_label.visible = false
		enemy_sprite.play(chosen_animation)
		enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fit_enemy_sprite()
	else:
		enemy_sprite.visible = false
		enemy_sprite_label.visible = true
		enemy_sprite_label.text = enemy.display_name

		push_warning(
            "[BATTLE UI] No usable SpriteFrames assigned for '"
			+ enemy.display_name
			+ "'. Assign battle_sprite_frames or world_sprite_frames."
		)

	if not enemy_sprite_slot.resized.is_connected(_fit_enemy_sprite):
		enemy_sprite_slot.resized.connect(_fit_enemy_sprite)


# ============================================================
# BATTLE ENTRY ANIMATION
# ============================================================

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

		tween.tween_property(
			enemy_sprite,
			"position",
			enemy_home,
			0.24
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		tween.tween_property(
			enemy_sprite,
			"modulate:a",
			1.0,
			0.22
		)

	if (
		is_instance_valid(player_battle_sprite)
		and player_battle_sprite.visible
	):
		var player_home := player_battle_sprite.position

		player_battle_sprite.position = player_home + Vector2(52.0, 0.0)
		player_battle_sprite.modulate.a = 0.0

		tween.tween_property(
			player_battle_sprite,
			"position",
			player_home,
			0.26
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		tween.tween_property(
			player_battle_sprite,
			"modulate:a",
			1.0,
			0.24
		)


# ============================================================
# BATTLE EVENTS
# ============================================================

func _on_battle_started(enemy: EnemyData) -> void:
	_entry_animation_played = false
	_last_enemy_hp = enemy.max_hp
	_last_player_hp = PlayerProgression.current_hp

	enemy_name_label.text = enemy.display_name
	enemy_hp_label.text = "%d / %d" % [enemy.max_hp, enemy.max_hp]
	enemy_hp_bar.value = 100.0
	var player_max_hp: int = PlayerProgression.get_total_max_hp()
	player_hp_label.text = "%d / %d" % [PlayerProgression.current_hp, player_max_hp]
	if player_max_hp > 0:
		player_hp_bar.value = (
			float(PlayerProgression.current_hp)
			/ float(player_max_hp) * 100.0
		)
	else:
		player_hp_bar.value = 0.0
	_show_enemy_sprite(enemy)

	message_label.text = "A wild %s appears!" % enemy.display_name

	_refresh_player_exp()
	_refresh_food_button()
	_show_action_buttons()

	call_deferred("_play_battle_entry")


func _play_enemy_action_animation(
	animation_name: StringName,
	action_kind: StringName
) -> bool:
	if (
		not is_instance_valid(enemy_sprite)
		or not enemy_sprite.visible
		or enemy_sprite.sprite_frames == null
		or animation_name.is_empty()
		or not enemy_sprite.sprite_frames.has_animation(animation_name)
		or enemy_sprite.sprite_frames.get_frame_count(animation_name) <= 0
	):
		return false

	enemy_sprite.sprite_frames.set_animation_loop(
		animation_name,
		false
	)

	_current_enemy_action_animation = animation_name
	_current_enemy_action_kind = action_kind
	enemy_sprite.play(animation_name)

	return true


func _on_enemy_attack_animation_requested() -> void:
	if _play_enemy_action_animation(
		_current_enemy_attack_animation,
		&"attack"
	):
		return

	# Some enemies have no battle attack clip. Preserve the configured pause
	# for those enemies, then acknowledge the turn so combat cannot deadlock.
	var fallback_delay: float = 0.0
	if BattleManager.current_enemy != null:
		fallback_delay = maxf(
			BattleManager.current_enemy.battle_attack_duration,
			0.0
		)
	if fallback_delay > 0.0:
		await _finish_enemy_attack_after_delay(fallback_delay)
	else:
		call_deferred("_emit_enemy_attack_animation_finished")


func _finish_enemy_attack_after_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self):
		call_deferred("_emit_enemy_attack_animation_finished")


func _emit_enemy_attack_animation_finished() -> void:
	if is_instance_valid(BattleManager):
		BattleManager.enemy_attack_animation_finished.emit()


func _on_enemy_hit_animation_requested() -> void:
	if _play_enemy_action_animation(
		_current_enemy_hit_animation,
		&"hit"
	):
		return

	# If this enemy has no hit clip, wait for the fallback hit reaction instead.
	var feedback_tween: Tween = _play_hit_feedback(enemy_sprite)
	if feedback_tween != null:
		feedback_tween.finished.connect(
			_emit_enemy_hit_animation_finished,
			CONNECT_ONE_SHOT
		)
	else:
		call_deferred("_emit_enemy_hit_animation_finished")


func _emit_enemy_hit_animation_finished() -> void:
	if is_instance_valid(BattleManager):
		BattleManager.enemy_hit_animation_finished.emit()


func _on_enemy_animation_finished() -> void:
	if _current_enemy_action_animation.is_empty():
		return

	if StringName(enemy_sprite.animation) != _current_enemy_action_animation:
		return

	var finished_action_kind: StringName = _current_enemy_action_kind
	_current_enemy_action_animation = &""
	_current_enemy_action_kind = &""

	if (
		not _current_enemy_idle_animation.is_empty()
		and enemy_sprite.sprite_frames != null
		and enemy_sprite.sprite_frames.has_animation(
			_current_enemy_idle_animation
		)
		and enemy_sprite.sprite_frames.get_frame_count(
			_current_enemy_idle_animation
		) > 0
	):
		enemy_sprite.play(_current_enemy_idle_animation)

	if finished_action_kind == &"attack":
		BattleManager.enemy_attack_animation_finished.emit()
	elif finished_action_kind == &"hit":
		BattleManager.enemy_hit_animation_finished.emit()


func _on_enemy_hp_changed(
	current: int,
	max_hp: int
) -> void:
	enemy_hp_label.text = "%d / %d" % [current, max_hp]
	var target_value: float = (
		float(current) / float(max_hp) * 100.0
		if max_hp > 0 else 0.0
	)

	_enemy_hp_tween = _animate_hp_bar(
		enemy_hp_bar,
		target_value,
		_enemy_hp_tween
	)
	_track_enemy_hp_visuals(_enemy_hp_tween)
	_last_enemy_hp = current


func _track_enemy_hp_visuals(tween: Tween) -> void:
	_enemy_hp_visual_generation += 1
	var generation: int = _enemy_hp_visual_generation
	if tween == null:
		call_deferred(
			"_emit_enemy_hp_visuals_finished_if_current",
			generation
		)
		return
	tween.finished.connect(
		_on_enemy_hp_tween_finished.bind(generation),
		CONNECT_ONE_SHOT
	)


func _on_enemy_hp_tween_finished(generation: int) -> void:
	_emit_enemy_hp_visuals_finished_if_current(generation)


func _emit_enemy_hp_visuals_finished_if_current(generation: int) -> void:
	if generation != _enemy_hp_visual_generation:
		return
	if is_instance_valid(BattleManager):
		BattleManager.enemy_hp_visuals_finished.emit()


func _on_enemy_barrier_changed(
	current: int,
	max_barrier: int
) -> void:
	barrier_value_label.text = "%d / %d" % [
		current,
		max_barrier
	]

	if max_barrier > 0:
		barrier_bar.value = (
			float(current) / float(max_barrier) * 100.0
		)
	else:
		barrier_bar.value = 0.0


func _on_player_hp_changed(
	current: int,
	max_hp: int
) -> void:
	player_hp_label.text = "%d / %d" % [current, max_hp]
	var target_value: float = (
		float(current) / float(max_hp) * 100.0
		if max_hp > 0 else 0.0
	)

	_player_hp_tween = _animate_hp_bar(
		player_hp_bar,
		target_value,
		_player_hp_tween
	)

	var hit_tween: Tween = null
	if _last_player_hp >= 0 and current < _last_player_hp:
		if (
			is_instance_valid(_player_hit_tween)
			and _player_hit_tween.is_running()
		):
			_player_hit_tween.kill()
		hit_tween = _play_hit_feedback(player_battle_sprite)
	_player_hit_tween = hit_tween
	_last_player_hp = current
	_track_player_hp_visuals(_player_hp_tween, hit_tween)


func _track_player_hp_visuals(
	bar_tween: Tween,
	hit_tween: Tween
) -> void:
	_player_hp_visual_generation += 1
	var generation: int = _player_hp_visual_generation
	_player_hp_visual_parts_remaining = 0

	if bar_tween != null:
		_player_hp_visual_parts_remaining += 1
		bar_tween.finished.connect(
			_on_player_hp_visual_part_finished.bind(generation),
			CONNECT_ONE_SHOT
		)
	if hit_tween != null:
		_player_hp_visual_parts_remaining += 1
		hit_tween.finished.connect(
			_on_player_hp_visual_part_finished.bind(generation),
			CONNECT_ONE_SHOT
		)

	if _player_hp_visual_parts_remaining == 0:
		call_deferred(
			"_emit_player_hp_visuals_finished_if_current",
			generation
		)


func _on_player_hp_visual_part_finished(generation: int) -> void:
	if generation != _player_hp_visual_generation:
		return
	_player_hp_visual_parts_remaining -= 1
	if _player_hp_visual_parts_remaining <= 0:
		_emit_player_hp_visuals_finished_if_current(generation)


func _emit_player_hp_visuals_finished_if_current(generation: int) -> void:
	if generation != _player_hp_visual_generation:
		return
	if is_instance_valid(BattleManager):
		BattleManager.player_hp_visuals_finished.emit()


func _animate_hp_bar(
	bar: ProgressBar,
	target_value: float,
	previous_tween: Tween
) -> Tween:
	if is_instance_valid(previous_tween) and previous_tween.is_running():
		previous_tween.kill()

	var distance: float = absf(target_value - bar.value)
	if distance < 0.05:
		bar.value = target_value
		return null

	# Larger HP changes get a slightly longer animation, capped to stay responsive.
	var duration: float = clampf(
		0.20 + distance * 0.012,
		0.25,
		0.72
	)
	var tween: Tween = create_tween()
	tween.tween_property(
		bar,
		"value",
		target_value,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


func _refresh_player_exp() -> void:
	if is_instance_valid(player_name_label):
		var display_name := "Adventurer"

		if is_instance_valid(GameManager):
			var saved_name := GameManager.adventurer_name.strip_edges()

			if not saved_name.is_empty():
				display_name = saved_name

		player_name_label.text = display_name

	if not PlayerProgression:
		return

	player_level_label.text = "Lv. %d" % PlayerProgression.level

	var max_exp: int = PlayerProgression.get_max_exp(
		PlayerProgression.level
	)

	if max_exp > 0:
		player_exp_bar.value = (
			float(PlayerProgression.current_exp)
			/ float(max_exp)
			* 100.0
		)


# ============================================================
# QUIZ
# ============================================================

func _on_quiz_requested(question: QuizQuestion) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bottom_bar.visible = false

	quiz_ui.start_quiz(question)


func _on_quiz_answer_selected(payload: Variant) -> void:
	bottom_bar.visible = true

	await BattleManager.submit_quiz_answer(payload)


# ============================================================
# HIT FEEDBACK
# ============================================================

func _play_hit_feedback(actor: Node2D) -> Tween:
	if not is_instance_valid(actor) or not actor.visible:
		return null

	var home_position: Vector2 = actor.position
	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)

	tween.tween_property(
		actor,
		"modulate",
		Color(1.0, 0.58, 0.48, 1.0),
		0.07
	)

	tween.parallel().tween_property(
		actor,
		"position:x",
		home_position.x + 5.0,
		0.035
	)

	tween.tween_property(
		actor,
		"position:x",
		home_position.x - 5.0,
		0.045
	)

	tween.tween_property(
		actor,
		"position:x",
		home_position.x,
		0.06
	)

	tween.tween_property(
		actor,
		"modulate",
		Color.WHITE,
		0.10
	)
	return tween


# ============================================================
# BATTLE MESSAGES AND ENDING
# ============================================================

func _on_battle_log(message: String) -> void:
	message_label.text = message


func _on_battle_ended(victory: bool) -> void:
	# Boss battles use the assessment overlay.
	if (
		BattleManager.current_enemy != null
		and BattleManager.current_enemy.is_boss
	):
		bottom_bar.visible = false
		attack_button.visible = false
		food_button.visible = false
		flee_button.visible = false
		continue_button.visible = false

		var assessment: Control = (
			BossAssessmentOverlayScene.instantiate() as Control
		)

		if assessment == null:
			push_error(
                "[BOSS ASSESSMENT] Could not instantiate BossAssessmentOverlay.tscn."
			)
			return

		assessment.name = "BossAssessmentOverlay"
		assessment.process_mode = Node.PROCESS_MODE_ALWAYS

		add_child(assessment)

		assessment.connect(
			"finished",
			Callable(self, "_on_boss_assessment_finished")
		)

		var boss_name: String = (
			BattleManager.current_enemy.display_name
		)

		var report: Dictionary = (
			BattleManager.get_boss_assessment_report()
		)

		assessment.call(
			"present",
			victory,
			report,
			boss_name
		)

		return

	_last_battle_victory = victory
	bottom_bar.visible = true

	if victory:
		message_label.text = "Victory! The path is clear."
	else:
		message_label.text = "You were defeated..."

	attack_button.visible = false
	food_button.visible = false
	flee_button.visible = false
	continue_button.visible = true
	continue_button.text = "Continue" if victory else "Return to Checkpoint"


func _on_boss_assessment_finished(victory: bool) -> void:
	if victory:
		GameManager.set_game_state(
			GameManager.GameState.EXPLORATION
		)

		if GameManager.has_method("request_save"):
			GameManager.request_save()

		closed.emit()
		queue_free()
		return

	var restored: bool = await CheckpointManager.restore_checkpoint()

	if not restored:
		GameManager.set_game_state(
			GameManager.GameState.EXPLORATION
		)

		if GameManager.has_method("request_save"):
			GameManager.request_save()

	if is_instance_valid(self):
		closed.emit()
		queue_free()


# ============================================================
# ACTION BUTTONS
# ============================================================

func _show_action_buttons() -> void:
	continue_button.visible = false
	attack_button.visible = true
	food_button.visible = true
	_on_turn_busy_changed(BattleManager.action_in_progress)

	# Fleeing is only offered in normal battles.
	flee_button.visible = (
		BattleManager.current_enemy != null
		and not BattleManager.current_enemy.is_boss
	)


func _on_turn_busy_changed(is_busy: bool) -> void:
	# Prevent extra clicks while an attack, heal, HP tween, or enemy animation
	# is still resolving.
	attack_button.disabled = is_busy
	food_button.disabled = is_busy
	flee_button.disabled = is_busy


func _on_attack_pressed() -> void:
	BattleManager.player_attack()


func _on_food_pressed() -> void:
	InventoryManager.open_battle_food_picker()


func _on_battle_food_selected(item_id: String) -> void:
	await BattleManager.player_use_food(item_id)


func _refresh_food_button() -> void:
	if is_instance_valid(food_button):
		food_button.text = "Food Bag (%d)" % (
			InventoryManager.get_total_food_count()
		)


func _on_flee_pressed() -> void:
	BattleManager.flee_battle()


func _on_battle_fled() -> void:
	closed.emit()
	queue_free()


func _on_continue_pressed() -> void:
	# Normal battle defeat should use the same checkpoint restore as boss defeat.
	# Victory continues normally and does not teleport the player.
	if not _last_battle_victory:
		continue_button.disabled = true
		bottom_bar.visible = false

		var restored: bool = await CheckpointManager.restore_checkpoint()
		if not restored:
			GameManager.set_game_state(
				GameManager.GameState.EXPLORATION
			)
			if GameManager.has_method("request_save"):
				GameManager.request_save()

		if is_instance_valid(self):
			closed.emit()
			queue_free()
		return

	closed.emit()
	queue_free()
