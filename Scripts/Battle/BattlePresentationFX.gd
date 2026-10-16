extends Control

## Visual-only combat effects for MABYASA.
## Connects to existing BattleManager signals; does not change combat rules,
## damage, quiz results, or the timing of a turn.

const COLOR_GOLD: Color = Color(1.0, 0.82, 0.40, 1.0)
const COLOR_HIT: Color = Color(1.0, 0.78, 0.55, 1.0)
const COLOR_DAMAGE: Color = Color(1.0, 0.48, 0.39, 1.0)
const COLOR_HEAL: Color = Color(0.62, 0.94, 0.60, 1.0)
const COLOR_BARRIER: Color = Color(0.62, 0.82, 1.0, 1.0)
const COLOR_TEXT: Color = Color(0.98, 0.95, 0.85, 1.0)

var _enemy_slot: Control
var _player_slot: Control
var _encounter_caption: Control
var _screen_flash: ColorRect
var _flash_tween: Tween
var _last_enemy_hp: int = -1
var _last_enemy_barrier: int = -1
var _last_player_hp: int = -1
var _banner_generation: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 80
	_build_screen_flash()

	var root: Node = get_parent()
	_enemy_slot = root.get_node_or_null("EnemySpriteBox") as Control
	_player_slot = root.get_node_or_null("PlayerSpriteBox") as Control
	_encounter_caption = root.get_node_or_null("EncounterCaption") as Control

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


func _exit_tree() -> void:
	if not is_instance_valid(BattleManager):
		return
	_disconnect_if_connected(BattleManager.battle_started, _on_battle_started)
	_disconnect_if_connected(BattleManager.enemy_hp_changed, _on_enemy_hp_changed)
	_disconnect_if_connected(BattleManager.enemy_barrier_changed, _on_enemy_barrier_changed)
	_disconnect_if_connected(BattleManager.player_hp_changed, _on_player_hp_changed)
	_disconnect_if_connected(BattleManager.quiz_resolved, _on_quiz_resolved)
	_disconnect_if_connected(BattleManager.battle_streak_changed, _on_battle_streak_changed)
	_disconnect_if_connected(BattleManager.battle_ended, _on_battle_ended)


func _connect_if_needed(signal_ref: Signal, callback: Callable) -> void:
	if not signal_ref.is_connected(callback):
		signal_ref.connect(callback)


func _disconnect_if_connected(signal_ref: Signal, callback: Callable) -> void:
	if signal_ref.is_connected(callback):
		signal_ref.disconnect(callback)


func _build_screen_flash() -> void:
	_screen_flash = ColorRect.new()
	_screen_flash.name = "CombatFlash"
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_flash.z_index = 0
	_screen_flash.visible = false
	add_child(_screen_flash)


func _on_battle_started(enemy: EnemyData) -> void:
	if enemy == null:
		return
	_last_enemy_hp = enemy.max_hp
	_last_enemy_barrier = enemy.max_barrier
	_last_player_hp = (
		PlayerProgression.current_hp
		if is_instance_valid(PlayerProgression)
		else -1
	)
	_flash(Color(0.80, 0.76, 0.48, 1.0), 0.045)


func _on_enemy_hp_changed(current: int, _max_hp: int) -> void:
	if _last_enemy_hp >= 0 and current < _last_enemy_hp:
		damage_number(_enemy_slot, _last_enemy_hp - current)
	_last_enemy_hp = current


func _on_enemy_barrier_changed(current: int, _max_barrier: int) -> void:
	if _last_enemy_barrier >= 0 and current < _last_enemy_barrier:
		barrier_number(_enemy_slot, _last_enemy_barrier - current)
	_last_enemy_barrier = current


func _on_player_hp_changed(current: int, _max_hp: int) -> void:
	if _last_player_hp >= 0 and current < _last_player_hp:
		damage_number(_player_slot, _last_player_hp - current)
		_flash(COLOR_DAMAGE, 0.09)
	elif _last_player_hp >= 0 and current > _last_player_hp:
		heal_number(_player_slot, current - _last_player_hp)
	_last_player_hp = current


func _on_quiz_resolved(result: AnswerResult, _damage_dealt: int) -> void:
	if result == null:
		return

	if result.correct:
		var strong_hit: bool = (
			result.damage_multiplier >= 1.25
			or result.speed_bonus > 0.0
		)
		impact(_enemy_slot, strong_hit)

		var callout_text: String = "MAYAP!"
		if result.question_kind == "sentence_build":
			callout_text = "SENTENCE STRIKE!"
		elif result.speed_bonus > 0.0:
			callout_text = "QUICK RECALL!"
		elif result.damage_multiplier >= 1.25:
			callout_text = "STRONG HIT!"

		callout(_enemy_slot, callout_text, COLOR_GOLD, 20)
		if strong_hit:
			_flash(COLOR_GOLD, 0.055)
	else:
		var miss_text: String = "TRY AGAIN"
		if result.timed_out:
			miss_text = "TIME'S UP"
		callout(_enemy_slot, miss_text, Color(1.0, 0.62, 0.50, 1.0), 18)


func _on_battle_streak_changed(streak: int, _best_streak: int) -> void:
	if streak >= 2:
		combo(streak, _encounter_caption)


func _on_battle_ended(victory: bool) -> void:
	# Bosses immediately open their existing assessment overlay. Keep that
	# screen unobstructed and let the assessment present the boss result.
	if is_instance_valid(BattleManager) and BattleManager.current_enemy != null:
		if BattleManager.current_enemy.is_boss:
			return
	result_banner(victory)


func damage_number(target: CanvasItem, amount: int) -> void:
	if amount > 0:
		pop_text(target, "-%d" % amount, COLOR_DAMAGE, 26, true)


func heal_number(target: CanvasItem, amount: int) -> void:
	if amount <= 0:
		return
	pop_text(target, "+%d HP" % amount, COLOR_HEAL, 22, true)
	burst(target, COLOR_HEAL, 6, 30.0)


func barrier_number(target: CanvasItem, amount: int) -> void:
	if amount <= 0:
		return
	pop_text(target, "BLOCKED %d" % amount, COLOR_BARRIER, 18, false)
	burst(target, COLOR_BARRIER, 5, 24.0)


func pop_text(
	target: CanvasItem,
	text_value: String,
	text_color: Color = COLOR_TEXT,
	font_size: int = 22,
	emphasized: bool = false
) -> void:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(260.0, 46.0)
	label.position = _target_point(target) - Vector2(130.0, 42.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 12
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color(0.035, 0.045, 0.03, 0.98))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)

	if emphasized:
		label.scale = Vector2(0.78, 0.78)
		label.pivot_offset = label.size * 0.5
		var pop := create_tween()
		pop.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.72).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)


func impact(target: CanvasItem, strong: bool = false) -> void:
	if not is_instance_valid(target):
		return
	var point: Vector2 = _target_point(target)
	var slash := ColorRect.new()
	slash.name = "ImpactSlash"
	slash.size = Vector2(112.0 if strong else 84.0, 4.0 if strong else 3.0)
	slash.position = point - slash.size * 0.5
	slash.pivot_offset = slash.size * 0.5
	slash.rotation = deg_to_rad(-24.0)
	slash.color = Color(1.0, 0.95, 0.70, 0.96) if strong else COLOR_HIT
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.z_index = 5
	slash.scale = Vector2(0.10, 1.0)
	add_child(slash)

	var slash_tween := create_tween()
	slash_tween.set_parallel(true)
	slash_tween.tween_property(slash, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slash_tween.tween_property(slash, "modulate:a", 0.0, 0.20).set_delay(0.05)
	slash_tween.chain().tween_callback(slash.queue_free)

	burst(target, COLOR_GOLD if strong else COLOR_HIT, 12 if strong else 8, 42.0 if strong else 30.0)


func burst(
	target: CanvasItem,
	burst_color: Color,
	count: int = 8,
	radius: float = 32.0
) -> void:
	if not is_instance_valid(target):
		return
	burst_at(_target_point(target), burst_color, count, radius)


func burst_at(point: Vector2, burst_color: Color, count: int, radius: float) -> void:
	var variants: Array[Color] = [burst_color, COLOR_TEXT, Color(1.0, 0.94, 0.70, 1.0)]
	for i: int in range(count):
		var spark := ColorRect.new()
		var spark_size: float = randf_range(3.0, 6.0)
		spark.size = Vector2(spark_size, spark_size)
		spark.position = point + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		spark.pivot_offset = spark.size * 0.5
		spark.color = variants[i % variants.size()]
		spark.rotation = randf_range(-0.8, 0.8)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 6
		add_child(spark)

		var angle: float = TAU * float(i) / float(maxi(count, 1)) + randf_range(-0.25, 0.25)
		var travel: Vector2 = Vector2.from_angle(angle) * randf_range(radius * 0.50, radius)
		var duration: float = randf_range(0.20, 0.34)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + travel, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
		tween.tween_property(spark, "scale", Vector2(0.30, 0.30), duration)
		tween.chain().tween_callback(spark.queue_free)


func _flash(color: Color, strength: float = 0.10) -> void:
	if not is_instance_valid(_screen_flash):
		return
	if is_instance_valid(_flash_tween) and _flash_tween.is_running():
		_flash_tween.kill()

	_screen_flash.visible = true
	_screen_flash.color = Color(color.r, color.g, color.b, 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_screen_flash, "color",
		Color(color.r, color.g, color.b, strength), 0.05
	)
	_flash_tween.tween_property(
		_screen_flash, "color",
		Color(color.r, color.g, color.b, 0.0), 0.18
	)
	_flash_tween.tween_callback(func() -> void:
		if is_instance_valid(_screen_flash):
			_screen_flash.visible = false
	)


func callout(
	target: CanvasItem,
	text_value: String,
	text_color: Color = COLOR_GOLD,
	font_size: int = 20
) -> void:
	pop_text(target, text_value, text_color, font_size, true)


func combo(streak: int, target: CanvasItem) -> void:
	if streak < 2:
		return
	var text_value: String = "LEARNING COMBO  x%d" % streak
	var color: Color = COLOR_GOLD if streak < 4 else Color(1.0, 0.67, 0.34, 1.0)
	callout(target, text_value, color, 18 if streak < 4 else 21)
	if streak >= 4:
		burst(target, COLOR_GOLD, 8, 34.0)


func result_banner(victory: bool) -> void:
	_banner_generation += 1
	var generation: int = _banner_generation
	var banner := Label.new()
	banner.name = "BattleResultBanner"
	banner.text = "VICTORY!" if victory else "DEFEATED"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.size = Vector2(440.0, 76.0)
	banner.position = Vector2((size.x - banner.size.x) * 0.5, size.y * 0.34)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.72, 0.72)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.z_index = 20
	banner.add_theme_color_override("font_color", COLOR_GOLD if victory else COLOR_DAMAGE)
	banner.add_theme_color_override("font_outline_color", Color(0.035, 0.045, 0.03, 0.98))
	banner.add_theme_constant_override("outline_size", 6)
	banner.add_theme_font_size_override("font_size", 42)
	add_child(banner)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.16)
	tween.chain().tween_interval(1.05)
	tween.tween_property(banner, "position:y", banner.position.y - 20.0, 0.28)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.28)
	tween.tween_callback(func() -> void:
		if is_instance_valid(banner) and generation <= _banner_generation:
			banner.queue_free()
	)

	if victory:
		_flash(COLOR_GOLD, 0.11)
		burst_at(Vector2(size.x * 0.5, size.y * 0.42), COLOR_GOLD, 18, 90.0)
	else:
		_flash(COLOR_DAMAGE, 0.13)
		burst_at(Vector2(size.x * 0.5, size.y * 0.42), COLOR_DAMAGE, 8, 52.0)


func _target_point(target: CanvasItem) -> Vector2:
	if not is_instance_valid(target):
		return size * 0.5

	var target_transform: Transform2D = target.get_global_transform_with_canvas()
	var canvas_point: Vector2 = target_transform.origin
	if target is Control:
		canvas_point = target_transform * ((target as Control).size * 0.5)
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return inverse * canvas_point
