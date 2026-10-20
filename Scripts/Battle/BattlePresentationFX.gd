extends Control

## Dramatic, visual-only combat presentation for MABYASA.
## Reads existing BattleManager signals. Does not touch damage, random rolls,
## quiz scoring, HP, rewards, saves, or the sequential turn pipeline.

const COLOR_GOLD: Color = Color(1.0, 0.80, 0.34, 1.0)
const COLOR_GOLD_PALE: Color = Color(1.0, 0.94, 0.68, 1.0)
const COLOR_HIT: Color = Color(1.0, 0.84, 0.55, 1.0)
const COLOR_DAMAGE: Color = Color(1.0, 0.36, 0.30, 1.0)
const COLOR_HEAL: Color = Color(0.48, 1.0, 0.56, 1.0)
const COLOR_BARRIER: Color = Color(0.38, 0.78, 1.0, 1.0)
const COLOR_TEXT: Color = Color(0.98, 0.95, 0.85, 1.0)
const COLOR_DARK: Color = Color(0.035, 0.045, 0.03, 0.98)
const PIXEL_STEP: float = 4.0
const CORRECT_SFX_PATH: String = "res://Assets/Audio/Battle/answer_correct.wav"
const WRONG_SFX_PATH: String = "res://Assets/Audio/Battle/answer_wrong.wav"
const VICTORY_SFX_PATH: String = "res://Assets/Audio/Battle/battle_victory.wav"
const DEFEAT_SFX_PATH: String = "res://Assets/Audio/Battle/battle_defeat.wav"
const ENEMY_ATTACK_SFX_PATH: String = "res://Assets/Audio/Battle/enemy_attack.wav"
const ENCOUNTER_SFX_PATH: String = "res://Assets/Audio/Battle/enemy_encounter.wav"

@export_range(0.0, 1.0, 0.05) var screen_shake_intensity: float = 0.75
@export_range(0.05, 0.5, 0.05) var flash_duration: float = 0.18
@export_range(12, 64, 4) var heavy_hit_particle_count: int = 36

var _root_control: Control
var _enemy_slot: Control
var _player_slot: Control
var _enemy_actor: Node2D
var _player_actor: Node2D
var _encounter_caption: Control
var _screen_flash: ColorRect
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _flash_tween: Tween
var _screen_shake_tween: Tween
var _last_enemy_hp: int = -1
var _last_enemy_barrier: int = -1
var _last_player_hp: int = -1
var _banner_generation: int = 0
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _slashes: Array[Dictionary] = []
var _actor_tweens: Dictionary = {}
var _actor_home_positions: Dictionary = {}
var _actor_home_scales: Dictionary = {}
var _screen_home_position: Vector2 = Vector2.ZERO
var _answer_correct_player: AudioStreamPlayer
var _answer_wrong_player: AudioStreamPlayer
var _victory_player: AudioStreamPlayer
var _defeat_player: AudioStreamPlayer
var _enemy_attack_player: AudioStreamPlayer
var _encounter_player: AudioStreamPlayer
var _encounter_popup: PanelContainer
var _encounter_tween: Tween
var _result_banner_label: Label
var _result_subtitle_label: Label
var _result_tween: Tween
var _result_active: bool = false
var _result_is_victory: bool = false
var _result_backdrop: ColorRect
var _result_input_lock: Control
var _cinematic_tween: Tween
var _screen_effect_busy: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 80
	_root_control = get_parent() as Control
	if is_instance_valid(_root_control):
		_screen_home_position = _root_control.position

	_build_overlay_nodes()
	_setup_sound_effects()
	_refresh_actor_references()
	var quiz_overlay: Control = _root_control.get_node_or_null("QuizUI") as Control if is_instance_valid(_root_control) else null
	if is_instance_valid(quiz_overlay):
		# The quiz must always draw above battle particles and callouts.
		quiz_overlay.z_index = 120
	set_process(true)

	if not is_instance_valid(BattleManager):
		push_warning("[BATTLE FX] BattleManager is unavailable; effects are disabled.")
		return

	_connect_if_needed(BattleManager.battle_started, _on_battle_started)
	_connect_if_needed(BattleManager.enemy_hp_changed, _on_enemy_hp_changed)
	_connect_if_needed(BattleManager.enemy_barrier_changed, _on_enemy_barrier_changed)
	_connect_if_needed(BattleManager.player_hp_changed, _on_player_hp_changed)
	_connect_if_needed(BattleManager.quiz_resolved, _on_quiz_resolved)
	_connect_if_needed(BattleManager.battle_streak_changed, _on_battle_streak_changed)
	_connect_if_needed(BattleManager.battle_ended, _on_battle_ended)
	_connect_if_needed(BattleManager.enemy_attack_animation_requested, _on_enemy_attack_requested)


func _input(event: InputEvent) -> void:
	# Clicking anywhere skips the result presentation without passing that
	# same click through to the underlying Continue button.
	if not _result_active:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_skip_result_banner()
			get_viewport().set_input_as_handled()


func _on_enemy_attack_requested() -> void:
	# Called when the enemy turn begins, before damage is applied.
	if is_instance_valid(_enemy_attack_player):
		_enemy_attack_player.pitch_scale = randf_range(0.94, 1.04)
	_play_sfx(_enemy_attack_player)


func _setup_sound_effects() -> void:
	_answer_correct_player = _create_sfx_player("AnswerCorrectSFX", CORRECT_SFX_PATH, -7.5)
	_answer_wrong_player = _create_sfx_player("AnswerWrongSFX", WRONG_SFX_PATH, -8.5)
	_victory_player = _create_sfx_player("BattleVictorySFX", VICTORY_SFX_PATH, -6.0)
	_defeat_player = _create_sfx_player("BattleDefeatSFX", DEFEAT_SFX_PATH, -7.5)
	_enemy_attack_player = _create_sfx_player("EnemyAttackSFX", ENEMY_ATTACK_SFX_PATH, -11.0)
	_encounter_player = _create_sfx_player("EnemyEncounterSFX", ENCOUNTER_SFX_PATH, -10.0)


func _create_sfx_player(player_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = volume_db
	if ResourceLoader.exists(path):
		player.stream = load(path) as AudioStream
	else:
		player.stream = null
	if player.stream == null:
		push_warning("[BATTLE FX] Optional sound not found: " + path)
	add_child(player)
	return player


func _play_sfx(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player) or player.stream == null:
		return
	player.stop()
	player.play()


func _exit_tree() -> void:
	if is_instance_valid(_root_control):
		_root_control.position = _screen_home_position
	if not is_instance_valid(BattleManager):
		return
	_disconnect_if_connected(BattleManager.battle_started, _on_battle_started)
	_disconnect_if_connected(BattleManager.enemy_hp_changed, _on_enemy_hp_changed)
	_disconnect_if_connected(BattleManager.enemy_barrier_changed, _on_enemy_barrier_changed)
	_disconnect_if_connected(BattleManager.player_hp_changed, _on_player_hp_changed)
	_disconnect_if_connected(BattleManager.quiz_resolved, _on_quiz_resolved)
	_disconnect_if_connected(BattleManager.battle_streak_changed, _on_battle_streak_changed)
	_disconnect_if_connected(BattleManager.battle_ended, _on_battle_ended)
	_disconnect_if_connected(BattleManager.enemy_attack_animation_requested, _on_enemy_attack_requested)


func _connect_if_needed(signal_ref: Signal, callback: Callable) -> void:
	if not signal_ref.is_connected(callback):
		signal_ref.connect(callback)


func _disconnect_if_connected(signal_ref: Signal, callback: Callable) -> void:
	if signal_ref.is_connected(callback):
		signal_ref.disconnect(callback)


func _build_overlay_nodes() -> void:
	_screen_flash = ColorRect.new()
	_screen_flash.name = "CombatFlash"
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_flash.z_index = 1
	_screen_flash.visible = false
	add_child(_screen_flash)

	_top_bar = ColorRect.new()
	_top_bar.name = "CinematicTopBar"
	_top_bar.color = Color(0.015, 0.02, 0.015, 0.96)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(size.x, 0.0)
	_top_bar.z_index = 2
	add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.name = "CinematicBottomBar"
	_bottom_bar.color = Color(0.015, 0.02, 0.015, 0.96)
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.position = Vector2(0.0, size.y)
	_bottom_bar.size = Vector2(size.x, 0.0)
	_bottom_bar.z_index = 2
	add_child(_bottom_bar)

	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _on_resized() -> void:
	if is_instance_valid(_top_bar):
		_top_bar.size.x = size.x
	if is_instance_valid(_bottom_bar):
		_bottom_bar.size.x = size.x
		if _bottom_bar.size.y <= 0.1:
			_bottom_bar.position.y = size.y


func _refresh_actor_references() -> void:
	if not is_instance_valid(_root_control):
		return
	_enemy_slot = _root_control.get_node_or_null("EnemySpriteBox") as Control
	_player_slot = _root_control.get_node_or_null("PlayerSpriteBox") as Control
	_encounter_caption = _root_control.get_node_or_null("EncounterCaption") as Control
	_enemy_actor = _root_control.get_node_or_null("EnemySpriteBox/EnemySprite") as Node2D
	_player_actor = _root_control.get_node_or_null("PlayerSpriteBox/PlayerSprite") as Node2D


func _enemy_target() -> CanvasItem:
	if is_instance_valid(_enemy_actor) and _enemy_actor.visible:
		return _enemy_actor
	return _enemy_slot


func _player_target() -> CanvasItem:
	if is_instance_valid(_player_actor) and _player_actor.visible:
		return _player_actor
	return _player_slot


func _process(delta: float) -> void:
	# The lower cinematic bar grows upward from the viewport's bottom edge.
	if is_instance_valid(_bottom_bar):
		_bottom_bar.position.y = size.y - _bottom_bar.size.y

	var changed: bool = false

	for i: int in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		var life: float = float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			_particles.remove_at(i)
			changed = true
			continue
		particle["life"] = life
		particle["pos"] = Vector2(particle.get("pos", Vector2.ZERO)) + Vector2(particle.get("vel", Vector2.ZERO)) * delta
		particle["vel"] = Vector2(particle.get("vel", Vector2.ZERO)) * pow(0.06, delta)
		_particles[i] = particle
		changed = true

	for i: int in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		var life: float = float(ring.get("life", 0.0)) - delta
		if life <= 0.0:
			_rings.remove_at(i)
			changed = true
			continue
		ring["life"] = life
		_rings[i] = ring
		changed = true

	for i: int in range(_slashes.size() - 1, -1, -1):
		var slash: Dictionary = _slashes[i]
		var life: float = float(slash.get("life", 0.0)) - delta
		if life <= 0.0:
			_slashes.remove_at(i)
			changed = true
			continue
		slash["life"] = life
		_slashes[i] = slash
		changed = true

	if changed:
		queue_redraw()


func _draw() -> void:
	# Rings and slashes are drawn as chunky 4px blocks to fit the game's pixel art.
	for ring: Dictionary in _rings:
		var life: float = float(ring.get("life", 0.0))
		var duration: float = maxf(float(ring.get("duration", 0.25)), 0.01)
		var progress: float = 1.0 - life / duration
		var tint: Color = ring.get("color", COLOR_GOLD)
		tint.a *= clampf(life / duration, 0.0, 1.0)
		var radius: float = lerpf(8.0, float(ring.get("radius", 60.0)), progress)
		var pixel_count: int = clampi(roundi(TAU * radius / 11.0), 18, 60)
		var thickness_blocks: int = maxi(1, roundi(float(ring.get("width", 3.0)) / PIXEL_STEP))
		var center: Vector2 = _snap_point(ring.get("pos", Vector2.ZERO))
		for i: int in range(pixel_count):
			var angle: float = TAU * float(i) / float(pixel_count)
			for block: int in range(thickness_blocks):
				var block_radius: float = maxf(radius - float(block) * PIXEL_STEP, 0.0)
				var sample: Vector2 = center + Vector2(cos(angle), sin(angle)) * block_radius
				sample = _snap_point(sample)
				draw_rect(Rect2(sample - Vector2.ONE * (PIXEL_STEP * 0.5), Vector2.ONE * PIXEL_STEP), tint, true)

	for slash: Dictionary in _slashes:
		var life: float = float(slash.get("life", 0.0))
		var duration: float = maxf(float(slash.get("duration", 0.2)), 0.01)
		var progress: float = 1.0 - life / duration
		var center: Vector2 = _snap_point(slash.get("pos", Vector2.ZERO))
		var direction: Vector2 = Vector2.RIGHT.rotated(float(slash.get("angle", 0.0)))
		var length: float = float(slash.get("length", 80.0)) * (0.45 + progress * 0.65)
		var tint: Color = slash.get("color", COLOR_HIT)
		tint.a *= clampf(life / duration, 0.0, 1.0)
		var pixel_count: int = maxi(8, roundi(length / 7.0))
		for i: int in range(pixel_count):
			var along: float = float(i) / float(maxi(pixel_count - 1, 1)) - 0.5
			var sample: Vector2 = _snap_point(center + direction * length * along)
			var block_size: float = 8.0 if float(slash.get("width", 4.0)) >= 6.0 else 4.0
			draw_rect(Rect2(sample - Vector2.ONE * block_size * 0.5, Vector2.ONE * block_size), tint, true)

	for particle: Dictionary in _particles:
		var life: float = float(particle.get("life", 0.0))
		var duration: float = maxf(float(particle.get("duration", 0.35)), 0.01)
		var tint: Color = particle.get("color", COLOR_GOLD)
		tint.a *= clampf(life / duration, 0.0, 1.0)
		var raw_size: float = float(particle.get("size", 4.0))
		var particle_size: float = maxf(PIXEL_STEP, roundf(raw_size / PIXEL_STEP) * PIXEL_STEP)
		var position: Vector2 = _snap_point(particle.get("pos", Vector2.ZERO))
		draw_rect(Rect2(position - Vector2.ONE * particle_size * 0.5, Vector2.ONE * particle_size), tint, true)


func _snap_point(point: Vector2) -> Vector2:
	return Vector2(
		roundf(point.x / PIXEL_STEP) * PIXEL_STEP,
		roundf(point.y / PIXEL_STEP) * PIXEL_STEP
	)


func _on_battle_started(enemy: EnemyData) -> void:
	if enemy == null:
		return
	_refresh_actor_references()
	_last_enemy_hp = enemy.max_hp
	_last_enemy_barrier = enemy.max_barrier
	_last_player_hp = PlayerProgression.current_hp if is_instance_valid(PlayerProgression) else -1
	_flash(Color(0.90, 0.78, 0.38, 1.0), 0.13)
	_add_ring(size * Vector2(0.5, 0.48), Color(0.90, 0.78, 0.38, 0.8), 220.0, 5.0, 0.50)
	_show_encounter_popup(enemy.display_name, enemy.is_boss)
	_cinematic_punch(0.32)


func _show_encounter_popup(enemy_name: String, is_boss: bool) -> void:
	if is_instance_valid(_encounter_tween) and _encounter_tween.is_running():
		_encounter_tween.kill()
	if is_instance_valid(_encounter_popup):
		_encounter_popup.queue_free()

	_play_sfx(_encounter_player)

	var panel := PanelContainer.new()
	panel.name = "EnemyEncounterPopup"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 14
	panel.custom_minimum_size = Vector2(minf(size.x - 72.0, 650.0), 112.0)
	panel.size = panel.custom_minimum_size
	panel.position = Vector2(
		(size.x - panel.size.x) * 0.5,
		size.y * 0.27 - panel.size.y * 0.5 - 42.0
	)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.82, 0.82)
	panel.pivot_offset = panel.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.028, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.83, 0.68, 0.34, 0.95)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_encounter_popup = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var heading := Label.new()
	heading.text = "BOSS ENCOUNTERED" if is_boss else "ENEMY ENCOUNTERED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(1.0, 0.77, 0.32, 1.0) if is_boss else COLOR_GOLD_PALE)
	heading.add_theme_color_override("font_outline_color", COLOR_DARK)
	heading.add_theme_constant_override("outline_size", 5)
	heading.add_theme_font_size_override("font_size", 26 if is_boss else 23)
	stack.add_child(heading)

	var enemy_label := Label.new()
	enemy_label.text = enemy_name.to_upper()
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_color_override("font_color", COLOR_TEXT)
	enemy_label.add_theme_color_override("font_outline_color", COLOR_DARK)
	enemy_label.add_theme_constant_override("outline_size", 4)
	enemy_label.add_theme_font_size_override("font_size", 19)
	stack.add_child(enemy_label)

	# Thin pixel-style divider beneath the heading.
	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(140.0, 3.0)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color(0.90, 0.72, 0.36, 0.95)
	stack.add_child(accent)

	var target_y: float = size.y * 0.27 - panel.size.y * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:y", target_y, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.20)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.2)
	tween.chain().tween_property(panel, "modulate:a", 0.0, 0.32)
	tween.chain().tween_callback(_remove_encounter_popup)
	_encounter_tween = tween


func _remove_encounter_popup() -> void:
	if is_instance_valid(_encounter_popup):
		_encounter_popup.queue_free()
	_encounter_popup = null
	_encounter_tween = null


func _on_enemy_hp_changed(current: int, _max_hp: int) -> void:
	if _last_enemy_hp >= 0 and current < _last_enemy_hp:
		var lost: int = _last_enemy_hp - current
		damage_number(_enemy_target(), lost)
		# Quiz resolution triggers the main impact once the turn reaches its
		# damage phase. Keep this HP event to the number and a small ring so
		# high-damage hits do not accidentally play the impact twice.
		_add_ring(_target_point(_enemy_target()), COLOR_HIT, 72.0, 3.0, 0.22)
	_last_enemy_hp = current


func _on_enemy_barrier_changed(current: int, _max_barrier: int) -> void:
	if _last_enemy_barrier >= 0 and current < _last_enemy_barrier:
		var lost: int = _last_enemy_barrier - current
		barrier_number(_enemy_target(), lost)
		var point: Vector2 = _target_point(_enemy_target())
		_add_ring(point, COLOR_BARRIER, 92.0, 5.0, 0.28)
		_burst_at(point, COLOR_BARRIER, 18, 58.0)
		_flash(COLOR_BARRIER, 0.07)
	_last_enemy_barrier = current


func _on_player_hp_changed(current: int, _max_hp: int) -> void:
	if _last_player_hp >= 0 and current < _last_player_hp:
		var lost: int = _last_player_hp - current
		damage_number(_player_target(), lost)
		_flash(COLOR_DAMAGE, 0.17)
		_heavy_impact(_player_target(), false)
		_shake_screen(7.0 + minf(float(lost) * 0.2, 8.0))
	elif _last_player_hp >= 0 and current > _last_player_hp:
		var gained: int = current - _last_player_hp
		heal_number(_player_target(), gained)
		_flash(COLOR_HEAL, 0.06)
	_last_player_hp = current


func _on_quiz_resolved(result: AnswerResult, damage_dealt: int) -> void:
	if result == null:
		return
	var point: Vector2 = _target_point(_enemy_target())

	# A short audible response for every resolved answer type.
	_play_sfx(_answer_correct_player if result.correct else _answer_wrong_player)

	if result.correct:
		var sentence_hit: bool = result.question_kind == "sentence_build"
		var strong_hit: bool = result.damage_multiplier >= 1.25 or result.speed_bonus > 0.0 or sentence_hit
		_heavy_impact(_enemy_target(), strong_hit)
		_shake_screen(4.5 if strong_hit else 2.5)

		var title: String = "MAYAP!"
		if sentence_hit:
			title = "SENTENCE STRIKE!"
		elif result.speed_bonus > 0.0:
			title = "QUICK RECALL!"
		elif result.damage_multiplier >= 1.25:
			title = "POWER HIT!"

		_callout_at(point + Vector2(0, -82), title, COLOR_GOLD_PALE, 30 if strong_hit else 24, true)
		if strong_hit:
			_callout_at(point + Vector2(0, -40), "%d DAMAGE" % damage_dealt, COLOR_TEXT, 19, false)
			_flash(COLOR_GOLD, 0.12)
			_cinematic_punch(0.33 if sentence_hit else 0.24)
	else:
		var miss_text: String = "WEAK STRIKE"
		if result.timed_out:
			miss_text = "TIME'S UP!"
		_callout_at(point + Vector2(0, -62), miss_text, Color(1.0, 0.57, 0.45, 1.0), 24, true)
		_add_ring(point, Color(1.0, 0.42, 0.35, 0.9), 66.0, 3.0, 0.24)


func _on_battle_streak_changed(streak: int, best_streak: int) -> void:
	if streak < 2:
		return
	var point: Vector2 = size * Vector2(0.5, 0.16)
	var combo_color: Color = COLOR_GOLD if streak < 4 else Color(1.0, 0.56, 0.27, 1.0)
	var text_value: String = "LEARNING COMBO  x%d" % streak
	var text_size: int = 23
	if streak >= 5:
		text_value = "KAPAMPANGAN MASTERY  x%d" % streak
		text_size = 27
	elif streak >= 3:
		text_value = "ON A ROLL!  x%d" % streak
		text_size = 25
	_callout_at(point, text_value, combo_color, text_size, true)
	if streak >= 3:
		_burst_at(point, combo_color, mini(10 + streak * 2, 28), 40.0 + float(streak * 3))
	if streak >= 5:
		_flash(COLOR_GOLD, 0.08)
		_cinematic_punch(0.22)


func _on_battle_ended(victory: bool) -> void:
	# Preserve the dedicated assessment flow for boss encounters.
	if is_instance_valid(BattleManager) and BattleManager.current_enemy != null and BattleManager.current_enemy.is_boss:
		return
	_result_banner(victory)


func damage_number(target: CanvasItem, amount: int) -> void:
	if amount <= 0:
		return
	pop_text(target, "-%d" % amount, COLOR_DAMAGE, 38 if amount >= 12 else 30, true)


func heal_number(target: CanvasItem, amount: int) -> void:
	if amount <= 0:
		return
	pop_text(target, "+%d HP" % amount, COLOR_HEAL, 28, true)
	var point: Vector2 = _target_point(target)
	_burst_at(point, COLOR_HEAL, 18, 52.0)
	_add_ring(point, COLOR_HEAL, 95.0, 4.0, 0.32)


func barrier_number(target: CanvasItem, amount: int) -> void:
	if amount <= 0:
		return
	pop_text(target, "BLOCKED %d" % amount, COLOR_BARRIER, 25, true)


func pop_text(target: CanvasItem, text_value: String, text_color: Color = COLOR_TEXT, font_size: int = 26, emphasized: bool = false) -> void:
	_callout_at(_target_point(target) + Vector2(0, -24), text_value, text_color, font_size, emphasized)


func _heavy_impact(target: CanvasItem, strong: bool) -> void:
	var point: Vector2 = _target_point(target)
	var ring_color: Color = COLOR_GOLD_PALE if strong else COLOR_HIT
	_add_ring(point, ring_color, 115.0 if strong else 82.0, 6.0 if strong else 4.0, 0.30 if strong else 0.22)
	_add_ring(point, Color(ring_color.r, ring_color.g, ring_color.b, 0.75), 68.0 if strong else 45.0, 3.0, 0.18)
	_add_slash(point, -0.60, 150.0 if strong else 110.0, 8.0 if strong else 5.0, ring_color, 0.22)
	_add_slash(point, 0.42, 120.0 if strong else 84.0, 5.0 if strong else 3.0, COLOR_TEXT, 0.18)
	_burst_at(point, ring_color, heavy_hit_particle_count if strong else 18, 82.0 if strong else 52.0)
	_shake_actor(_actor_for_target(target), 12.0 if strong else 7.0)
	if strong:
		_flash(COLOR_GOLD, 0.10)


func _actor_for_target(target: CanvasItem) -> Node2D:
	if target == _enemy_slot and is_instance_valid(_enemy_actor) and _enemy_actor.visible:
		return _enemy_actor
	if target == _player_slot and is_instance_valid(_player_actor) and _player_actor.visible:
		return _player_actor
	return target as Node2D


func _shake_actor(actor: Node2D, magnitude: float) -> void:
	if not is_instance_valid(actor):
		return
	var key: int = actor.get_instance_id()
	if not _actor_home_positions.has(key):
		_actor_home_positions[key] = actor.position
		_actor_home_scales[key] = actor.scale
	var home_position: Vector2 = _actor_home_positions[key]
	var home_scale: Vector2 = _actor_home_scales[key]
	if _actor_tweens.has(key):
		var old_tween: Tween = _actor_tweens[key]
		if is_instance_valid(old_tween) and old_tween.is_running():
			old_tween.kill()
	actor.position = home_position
	actor.scale = home_scale

	var amount: float = magnitude * screen_shake_intensity
	var tween := create_tween()
	tween.tween_property(actor, "position", home_position + Vector2(amount, -amount * 0.25), 0.035)
	tween.tween_property(actor, "position", home_position + Vector2(-amount * 0.75, amount * 0.15), 0.045)
	tween.tween_property(actor, "position", home_position + Vector2(amount * 0.35, amount * 0.12), 0.04)
	tween.tween_property(actor, "position", home_position, 0.06)
	tween.parallel().tween_property(actor, "scale", home_scale * 1.12, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "scale", home_scale, 0.10)
	_actor_tweens[key] = tween


func _shake_screen(magnitude: float) -> void:
	if not is_instance_valid(_root_control) or screen_shake_intensity <= 0.0:
		return
	if is_instance_valid(_screen_shake_tween) and _screen_shake_tween.is_running():
		_screen_shake_tween.kill()
	_root_control.position = _screen_home_position
	var strength: float = magnitude * screen_shake_intensity
	_screen_shake_tween = create_tween()
	for _i: int in range(4):
		_screen_shake_tween.tween_property(
			_root_control,
			"position",
			_screen_home_position + Vector2(randf_range(-strength, strength), randf_range(-strength * 0.55, strength * 0.55)),
			0.025
		)
	_screen_shake_tween.tween_property(_root_control, "position", _screen_home_position, 0.055)


func _add_ring(point: Vector2, tint: Color, radius: float, width: float, duration: float) -> void:
	_rings.append({"pos": point, "color": tint, "radius": radius, "width": width, "duration": duration, "life": duration})
	queue_redraw()


func _add_slash(point: Vector2, angle: float, length: float, width: float, tint: Color, duration: float) -> void:
	_slashes.append({"pos": point, "angle": angle, "length": length, "width": width, "color": tint, "duration": duration, "life": duration})
	queue_redraw()


func _burst_at(point: Vector2, tint: Color, count: int, radius: float) -> void:
	var colors: Array[Color] = [tint, COLOR_TEXT, COLOR_GOLD_PALE]
	for i: int in range(count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(radius * 1.1, radius * 2.2)
		var life: float = randf_range(0.18, 0.42)
		_particles.append({
			"pos": _snap_point(point + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))),
			"vel": _snap_point(Vector2.from_angle(angle) * speed),
			"size": [4.0, 4.0, 8.0][randi_range(0, 2)],
			"color": colors[i % colors.size()],
			"life": life,
			"duration": life
		})
	queue_redraw()


func _flash(tint: Color, strength: float = 0.12) -> void:
	if not is_instance_valid(_screen_flash):
		return
	if is_instance_valid(_flash_tween) and _flash_tween.is_running():
		_flash_tween.kill()
	_screen_flash.visible = true
	_screen_flash.color = Color(tint.r, tint.g, tint.b, 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_screen_flash, "color", Color(tint.r, tint.g, tint.b, strength), 0.035)
	_flash_tween.tween_property(_screen_flash, "color", Color(tint.r, tint.g, tint.b, 0.0), flash_duration)
	_flash_tween.tween_callback(func() -> void:
		if is_instance_valid(_screen_flash):
			_screen_flash.visible = false
	)


func _callout_at(point: Vector2, text_value: String, tint: Color, font_size: int, emphasized: bool) -> void:
	var label := Label.new()
	label.name = "CombatCallout"
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(maxf(300.0, float(text_value.length()) * float(font_size) * 0.72), float(font_size) * 2.0 + 18.0)
	label.position = point - label.size * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 24
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", COLOR_DARK)
	label.add_theme_constant_override("outline_size", 7 if emphasized else 5)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)

	if emphasized:
		label.scale = Vector2(0.55, 0.55)
		label.pivot_offset = label.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - (60.0 if emphasized else 38.0), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.18)
	if emphasized:
		tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(label.queue_free)


func _cinematic_punch(duration: float = 0.25) -> void:
	if not is_instance_valid(_top_bar) or not is_instance_valid(_bottom_bar):
		return
	if is_instance_valid(_cinematic_tween) and _cinematic_tween.is_running():
		_cinematic_tween.kill()
	_top_bar.size.y = 0.0
	_bottom_bar.size.y = 0.0
	_bottom_bar.position.y = size.y
	var bar_height: float = 24.0 if duration < 0.30 else 34.0
	_cinematic_tween = create_tween()
	_cinematic_tween.set_parallel(true)
	_cinematic_tween.tween_property(_top_bar, "size:y", bar_height, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_property(_bottom_bar, "size:y", bar_height, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cinematic_tween.chain().tween_interval(duration)
	_cinematic_tween.set_parallel(true)
	_cinematic_tween.tween_property(_top_bar, "size:y", 0.0, 0.10)
	_cinematic_tween.tween_property(_bottom_bar, "size:y", 0.0, 0.10)
	_cinematic_tween.tween_callback(func() -> void:
		if is_instance_valid(_bottom_bar):
			_bottom_bar.position.y = size.y
	)


func _result_banner(victory: bool) -> void:
	_banner_generation += 1
	var generation: int = _banner_generation
	_result_active = true
	_result_is_victory = victory

	var title_text: String = "VICTORY!" if victory else "DEFEATED"
	var subtitle_text: String = "THE PATH IS CLEAR  ·  LEFT CLICK TO CONTINUE" if victory else "REGROUP AND TRY AGAIN  ·  LEFT CLICK TO DISMISS"
	var tint: Color = COLOR_GOLD_PALE if victory else COLOR_DAMAGE
	var center: Vector2 = _snap_point(size * Vector2(0.5, 0.43))

	_play_sfx(_victory_player if victory else _defeat_player)
	_flash(COLOR_GOLD if victory else COLOR_DAMAGE, 0.24)
	_cinematic_punch(3.5)
	_shake_screen(11.0 if victory else 14.0)
	_burst_at(center, tint, 72 if victory else 38, 135.0)
	_add_ring(center, tint, 300.0, 8.0, 1.0)
	_add_ring(center, tint, 210.0, 4.0, 0.8)

	# Full-screen click catcher. _input() handles the first left click and
	# marks it handled so it cannot accidentally click Continue underneath.
	_result_backdrop = ColorRect.new()
	_result_backdrop.name = "BattleResultBackdrop"
	_result_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_backdrop.color = Color(COLOR_DARK.r, COLOR_DARK.g, COLOR_DARK.b, 0.0)
	_result_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_backdrop.z_index = 10
	add_child(_result_backdrop)

	var banner := Label.new()
	banner.name = "BattleResultBanner"
	banner.text = title_text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.size = Vector2(minf(size.x - 40.0, 820.0), 112.0)
	banner.position = center - Vector2(banner.size.x * 0.5, banner.size.y * 0.5)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.30, 0.30)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.z_index = 30
	banner.add_theme_color_override("font_color", tint)
	banner.add_theme_color_override("font_outline_color", COLOR_DARK)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_font_size_override("font_size", 64)
	add_child(banner)
	_result_banner_label = banner

	var subtitle := Label.new()
	subtitle.name = "BattleResultSubtitle"
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(minf(size.x - 60.0, 760.0), 48.0)
	subtitle.position = Vector2((size.x - subtitle.size.x) * 0.5, banner.position.y + banner.size.y - 2.0)
	subtitle.modulate.a = 0.0
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.z_index = 30
	subtitle.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle.add_theme_color_override("font_outline_color", COLOR_DARK)
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.add_theme_font_size_override("font_size", 18)
	add_child(subtitle)
	_result_subtitle_label = subtitle

	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(_result_backdrop, "color:a", 0.70, 0.28)
	reveal.tween_property(banner, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(banner, "modulate:a", 1.0, 0.30)
	reveal.tween_property(subtitle, "modulate:a", 1.0, 0.38).set_delay(0.18)
	reveal.finished.connect(_on_result_reveal_finished.bind(generation), CONNECT_ONE_SHOT)
	_result_tween = reveal


func _on_result_reveal_finished(generation: int) -> void:
	if generation != _banner_generation or not _result_active:
		return
	# Keep victory visible for a readable period. Defeat also gets a pause,
	# but both results can be dismissed by clicking anywhere.
	var hold := create_tween()
	hold.tween_interval(4.2 if _result_is_victory else 3.0)
	hold.tween_callback(_start_result_fade.bind(generation))
	_result_tween = hold


func _start_result_fade(generation: int) -> void:
	if generation != _banner_generation or not _result_active:
		return
	var fade := create_tween()
	fade.set_parallel(true)
	if is_instance_valid(_result_banner_label):
		fade.tween_property(_result_banner_label, "position:y", _result_banner_label.position.y - 24.0, 0.38)
		fade.tween_property(_result_banner_label, "modulate:a", 0.0, 0.38)
	if is_instance_valid(_result_subtitle_label):
		fade.tween_property(_result_subtitle_label, "modulate:a", 0.0, 0.30)
	if is_instance_valid(_result_backdrop):
		fade.tween_property(_result_backdrop, "color:a", 0.0, 0.38)
	fade.finished.connect(_cleanup_result_banner.bind(generation), CONNECT_ONE_SHOT)
	_result_tween = fade


func _skip_result_banner() -> void:
	if not _result_active:
		return
	_banner_generation += 1
	_result_active = false
	if is_instance_valid(_result_tween) and _result_tween.is_running():
		_result_tween.kill()
	_result_tween = null
	_cleanup_result_nodes()

	# End the cinematic bars immediately too; otherwise they could linger
	# after a player skips the banner.
	if is_instance_valid(_cinematic_tween) and _cinematic_tween.is_running():
		_cinematic_tween.kill()
	if is_instance_valid(_top_bar):
		_top_bar.size.y = 0.0
	if is_instance_valid(_bottom_bar):
		_bottom_bar.size.y = 0.0
		_bottom_bar.position.y = size.y


func _cleanup_result_banner(generation: int) -> void:
	if generation != _banner_generation:
		return
	_result_active = false
	_cleanup_result_nodes()


func _cleanup_result_nodes() -> void:
	for node: Node in [_result_banner_label, _result_subtitle_label, _result_backdrop]:
		if is_instance_valid(node):
			node.queue_free()
	_result_banner_label = null
	_result_subtitle_label = null
	_result_backdrop = null
	_result_tween = null


func _target_point(target: CanvasItem) -> Vector2:
	if not is_instance_valid(target):
		return _snap_point(size * 0.5)

	# AnimatedSprite2D's origin is its actual center because centered=true.
	# Controls use their geometric center. Convert from canvas space into the
	# FX control's local space so particles line up under scaling and anchoring.
	var canvas_point: Vector2
	if target is Control:
		var target_control: Control = target as Control
		canvas_point = target_control.get_global_transform_with_canvas() * (target_control.size * 0.5)
	else:
		canvas_point = target.get_global_transform_with_canvas().origin

	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return _snap_point(inverse * canvas_point)
