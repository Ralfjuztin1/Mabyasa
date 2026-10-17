extends "res://Scripts/Battle/QuizUI.gd"

## Animated presentation layer for both normal battle quizzes and boss sentence
## attacks. Quiz evaluation and payloads remain owned by QuizUI/BattleManager.

const FX_BOSS_FLASH_COLOR: Color = Color(0.72, 0.12, 0.055, 0.24)
const FX_NORMAL_POP_SCALE: Vector2 = Vector2(0.92, 0.92)
const FX_BOSS_POP_SCALE: Vector2 = Vector2(0.80, 0.80)

var _fx_generation: int = 0
var _fx_is_boss: bool = false
var _fx_boss_flash: ColorRect
var _fx_dimmer: ColorRect


func _ready() -> void:
	super._ready()
	_fx_dimmer = get_node_or_null("Dimmer") as ColorRect
	_add_boss_flash_layer()


func _add_boss_flash_layer() -> void:
	# Keep this flash between the background dimmer and the quiz card so it
	# tints the backdrop without washing out the question or answer buttons.
	_fx_boss_flash = ColorRect.new()
	_fx_boss_flash.name = "BossQuizFlash"
	_fx_boss_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_boss_flash.color = FX_BOSS_FLASH_COLOR
	_fx_boss_flash.modulate.a = 0.0
	_fx_boss_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_boss_flash.visible = false
	add_child(_fx_boss_flash)
	move_child(_fx_boss_flash, 1)


func start_quiz(question: QuizQuestion) -> void:
	if question == null:
		return

	_fx_generation += 1
	var generation: int = _fx_generation
	_fx_is_boss = _is_boss_battle()

	super.start_quiz(question)

	# Override the base's small fade/scale entrance with a more visible, but
	# still quick, animation. Input and the quiz timer stay locked during entry.
	_resolving = true
	_type_label.text = (
		"BOSS SENTENCE ATTACK"
		if _fx_is_boss
		else question.get_type_label().to_upper()
	)
	_type_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.57, 0.34) if _fx_is_boss else GOLD
	)

	call_deferred("_play_quiz_intro", generation)


func _is_boss_battle() -> bool:
	return (
		is_instance_valid(BattleManager)
		and BattleManager.current_enemy != null
		and BattleManager.current_enemy.is_boss
	)


func _play_quiz_intro(generation: int) -> void:
	await get_tree().process_frame
	if generation != _fx_generation or current_question == null or not visible:
		return

	if _transition_tween != null and _transition_tween.is_running():
		_transition_tween.kill()

	modulate = Color.WHITE
	if is_instance_valid(_fx_dimmer):
		_fx_dimmer.modulate.a = 0.0

	_card.pivot_offset = _card.size * 0.5
	_card.modulate.a = 0.0
	_card.scale = FX_BOSS_POP_SCALE if _fx_is_boss else FX_NORMAL_POP_SCALE
	_card.rotation_degrees = -2.0 if _fx_is_boss else 0.0

	_type_label.pivot_offset = _type_label.size * 0.5
	_type_label.scale = Vector2(0.84, 0.84)
	_type_label.modulate.a = 0.0
	_prompt_label.pivot_offset = _prompt_label.size * 0.5
	_prompt_label.scale = Vector2(0.96, 0.96)
	_prompt_label.modulate.a = 0.0
	_sub_prompt.pivot_offset = _sub_prompt.size * 0.5
	_sub_prompt.modulate.a = 0.0

	if is_instance_valid(_fx_boss_flash):
		_fx_boss_flash.visible = _fx_is_boss
		_fx_boss_flash.modulate.a = 0.0

	var entrance := create_tween()
	_transition_tween = entrance
	entrance.set_parallel(true)
	entrance.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_fx_dimmer):
		entrance.tween_property(_fx_dimmer, "modulate:a", 1.0, 0.24)
	entrance.tween_property(_card, "modulate:a", 1.0, 0.16)
	entrance.tween_property(_card, "scale", Vector2.ONE, 0.34 if _fx_is_boss else 0.25)
	entrance.tween_property(_card, "rotation_degrees", 0.0, 0.30)
	entrance.tween_property(_type_label, "scale", Vector2.ONE, 0.20)
	entrance.tween_property(_type_label, "modulate:a", 1.0, 0.15)
	entrance.tween_property(_prompt_label, "scale", Vector2.ONE, 0.20)
	entrance.tween_property(_prompt_label, "modulate:a", 1.0, 0.20)
	entrance.tween_property(_sub_prompt, "modulate:a", 1.0, 0.24)

	if _fx_is_boss and is_instance_valid(_fx_boss_flash):
		var flash_tween := create_tween()
		flash_tween.tween_property(_fx_boss_flash, "modulate:a", 1.0, 0.06)
		flash_tween.tween_property(_fx_boss_flash, "modulate:a", 0.0, 0.42)
		flash_tween.tween_callback(func() -> void:
			if is_instance_valid(_fx_boss_flash):
				_fx_boss_flash.visible = false
		)

	await entrance.finished
	if generation != _fx_generation or current_question == null or not visible:
		return

	# Stagger answers into view. This works for ordinary options, matching
	# choices, and the word bank/check button in boss sentence-building quizzes.
	var controls: Array[Control] = _get_quiz_controls_for_intro()
	var last_tween: Tween = null
	for control: Control in controls:
		if generation != _fx_generation or not is_instance_valid(control):
			return
		control.pivot_offset = control.size * 0.5
		control.modulate.a = 0.0
		control.scale = Vector2(0.90, 0.90)
		var pop := create_tween()
		last_tween = pop
		pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(control, "modulate:a", 1.0, 0.13)
		pop.parallel().tween_property(control, "scale", Vector2.ONE, 0.16)
		await get_tree().create_timer(0.035).timeout

	if last_tween != null and last_tween.is_running():
		await last_tween.finished

	if generation == _fx_generation and current_question != null and visible:
		_resolving = false


func _get_quiz_controls_for_intro() -> Array[Control]:
	var controls: Array[Control] = []

	for button: Button in _standard_buttons:
		controls.append(button)
	for button: Button in _match_left_buttons:
		controls.append(button)
	for button: Button in _match_right_buttons:
		controls.append(button)

	for value: Variant in _sentence_source_buttons.values():
		if value is Control:
			controls.append(value as Control)

	if _sentence_root.visible:
		controls.append(_sentence_check_button)

	return controls


func _on_standard_answer_pressed(index: int, chosen_button: Button) -> void:
	if _resolving or current_question == null:
		return
	if index < 0 or index >= current_question.choices.size():
		return

	_resolving = true
	var correct_index: int = current_question.correct_index
	for i: int in range(_standard_buttons.size()):
		var button: Button = _standard_buttons[i]
		button.disabled = true
		if i == correct_index:
			button.modulate = GOOD
		elif button == chosen_button:
			button.modulate = BAD
		else:
			button.modulate = DISABLED_TINT

	if index == correct_index:
		_play_control_pop(chosen_button, 1.13)
	else:
		_play_control_shake(chosen_button)
		if correct_index >= 0 and correct_index < _standard_buttons.size():
			_play_control_pop(_standard_buttons[correct_index], 1.09)

	# Keep the answer locked long enough for feedback to be readable before
	# BattleManager receives the payload.
	await get_tree().create_timer(0.30).timeout
	if not is_instance_valid(self) or current_question == null:
		return
	_emit_answer({
		"index": index,
		"elapsed": _elapsed,
		"timed_out": false
	})


func _on_match_left_pressed(index: int) -> void:
	super._on_match_left_pressed(index)
	if index >= 0 and index < _match_left_buttons.size() and _match_left_selected == index:
		_play_control_pop(_match_left_buttons[index], 1.07)


func _on_match_right_pressed(index: int) -> void:
	if (
		_resolving
		or current_question == null
		or _match_left_selected < 0
		or index < 0
		or index >= _match_right_buttons.size()
	):
		return

	var left_button: Button = _match_left_buttons[_match_left_selected]
	var right_button: Button = _match_right_buttons[index]
	var left_id: String = str(left_button.get_meta("match_id"))
	var right_id: String = str(right_button.get_meta("match_id"))
	var pair_is_correct: bool = false

	for i: int in range(current_question.match_left_ids.size()):
		if current_question.match_left_ids[i] == left_id:
			pair_is_correct = (
				i < current_question.match_right_ids.size()
				and current_question.match_right_ids[i] == right_id
			)
			break

	if pair_is_correct:
		_play_control_pop(left_button, 1.10)
		_play_control_pop(right_button, 1.10)
	else:
		_play_control_shake(left_button)
		_play_control_shake(right_button)

	await super._on_match_right_pressed(index)


func _on_sentence_token_pressed(button: Button) -> void:
	var old_count: int = _sentence_bar.get_child_count()
	super._on_sentence_token_pressed(button)
	if _sentence_bar.get_child_count() > old_count:
		var placed: Control = _sentence_bar.get_child(
			_sentence_bar.get_child_count() - 1
		) as Control
		if is_instance_valid(placed):
			placed.pivot_offset = placed.size * 0.5
			placed.scale = Vector2(0.78, 0.78)
			placed.modulate = Color(1.0, 0.87, 0.50, 1.0)
			var pop := create_tween()
			pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_property(placed, "scale", Vector2.ONE, 0.17)
			pop.parallel().tween_property(placed, "modulate", Color.WHITE, 0.22)
			_play_control_pop(_sentence_check_button, 1.035)


func _remove_sentence_token(token_id: String, placed: Button, source: Button) -> void:
	if _resolving:
		return
	if not is_instance_valid(placed):
		super._remove_sentence_token(token_id, placed, source)
		return

	placed.disabled = true
	var shrink := create_tween()
	shrink.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shrink.tween_property(placed, "scale", Vector2(0.75, 0.75), 0.09)
	shrink.parallel().tween_property(placed, "modulate:a", 0.0, 0.09)
	await shrink.finished
	if is_instance_valid(self):
		super._remove_sentence_token(token_id, placed, source)


func _submit_sentence() -> void:
	if _resolving or current_question == null or _sentence_order.is_empty():
		return

	_resolving = true
	# Freeze the quiz timer while the sentence-fusion result plays.
	var payload: Dictionary = {
		"order": _sentence_order.duplicate(),
		"elapsed": _elapsed,
		"timed_out": false
	}

	if _fx_is_boss:
		await _play_sentence_fusion(payload)
	else:
		var check_tween := create_tween()
		check_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		check_tween.tween_property(_sentence_check_button, "scale", Vector2(1.08, 1.08), 0.09)
		check_tween.tween_property(_sentence_check_button, "scale", Vector2.ONE, 0.10)
		for child: Node in _sentence_bar.get_children():
			if child is Control:
				var token: Control = child as Control
				var token_tween := create_tween()
				token_tween.tween_property(token, "scale", Vector2(1.06, 1.06), 0.08)
				token_tween.tween_property(token, "scale", Vector2.ONE, 0.10)
		await check_tween.finished
		if not is_instance_valid(self) or current_question == null:
			return
		_emit_answer(payload)


func _play_sentence_fusion(payload: Dictionary) -> void:
	if not is_instance_valid(self) or current_question == null:
		return

	var selected_words: Array[String] = []
	for child: Node in _sentence_bar.get_children():
		if child is Button:
			selected_words.append((child as Button).text)
	var assembled_phrase: String = " ".join(selected_words)
	var expected_phrase: String = " ".join(current_question.sentence_token_texts)
	var is_correct: bool = _sentence_order == current_question.sentence_token_ids

	_sentence_check_button.disabled = true
	_sentence_check_button.text = "FUSING WORDS..."
	
	# Effects live on the full-screen quiz Control, so positions are converted
	# from each placed token's canvas transform instead of assuming a fixed spot.
	var fusion_layer := Control.new()
	fusion_layer.name = "SentenceFusionLayer"
	fusion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fusion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fusion_layer.z_index = 40
	add_child(fusion_layer)

	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.78, 0.32, 0.0)
	fusion_layer.add_child(flash)

	var source_tokens: Array[Control] = []
	var ghost_tokens: Array[Button] = []
	var widths: Array[float] = []
	var total_width: float = 0.0
	for child: Node in _sentence_bar.get_children():
		if not (child is Button):
			continue
		var source := child as Button
		var ghost := source.duplicate() as Button
		if ghost == null:
			continue
		ghost.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ghost.size = source.size
		ghost.custom_minimum_size = source.size
		ghost.pivot_offset = ghost.size * 0.5
		ghost.disabled = true
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var canvas_origin: Vector2 = source.get_global_transform_with_canvas().origin
		ghost.position = get_global_transform_with_canvas().affine_inverse() * canvas_origin
		fusion_layer.add_child(ghost)
		source_tokens.append(source)
		ghost_tokens.append(ghost)
		widths.append(source.size.x)
		total_width += source.size.x
		source.modulate.a = 0.0
	
	if ghost_tokens.is_empty():
		fusion_layer.queue_free()
		_sentence_check_button.text = "CHECK SENTENCE"
		_emit_answer(payload)
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var gap: float = 6.0
	total_width += gap * float(maxi(ghost_tokens.size() - 1, 0))
	var target_x: float = maxf((viewport_size.x - total_width) * 0.5, 18.0)
	var target_y: float = viewport_size.y * 0.47
	var move_tweens: Array[Tween] = []
	for index: int in range(ghost_tokens.size()):
		var ghost: Button = ghost_tokens[index]
		ghost.z_index = 45
		ghost.modulate = Color(1.0, 0.86, 0.46, 1.0)
		var target_position := Vector2(target_x, target_y - ghost.size.y * 0.5)
		var move := create_tween()
		move.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		move.tween_property(ghost, "position", target_position, 0.36).set_delay(float(index) * 0.035)
		move.parallel().tween_property(ghost, "scale", Vector2(0.92, 0.92), 0.36).set_delay(float(index) * 0.035)
		move_tweens.append(move)
		target_x += ghost.size.x + gap

	# Wait for the final word to fuse before revealing the assembled phrase.
	await get_tree().create_timer(0.36 + float(maxi(ghost_tokens.size() - 1, 0)) * 0.035).timeout
	if not is_instance_valid(self):
		return

	for ghost: Button in ghost_tokens:
		if is_instance_valid(ghost):
			ghost.hide()

	var center_panel := PanelContainer.new()
	center_panel.name = "FusedPhrasePanel"
	center_panel.custom_minimum_size = Vector2(minf(viewport_size.x - 56.0, 760.0), 150.0)
	center_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	center_panel.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.54) - center_panel.custom_minimum_size * 0.5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.04, 0.98)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = GOOD if is_correct else BAD
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	center_panel.add_theme_stylebox_override("panel", panel_style)
	fusion_layer.add_child(center_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	center_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var outcome := Label.new()
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome.add_theme_color_override("font_color", GOOD if is_correct else BAD)
	outcome.add_theme_font_size_override("font_size", 22)
	outcome.text = "PHRASE FORGED!" if is_correct else "PHRASE UNSTABLE"
	stack.add_child(outcome)

	var phrase_label := Label.new()
	phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phrase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phrase_label.add_theme_color_override("font_color", GOLD)
	phrase_label.add_theme_font_size_override("font_size", 30 if assembled_phrase.length() < 24 else 22)
	phrase_label.text = assembled_phrase if not assembled_phrase.is_empty() else "(no phrase assembled)"
	stack.add_child(phrase_label)

	if not is_correct:
		var correct_label := Label.new()
		correct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		correct_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		correct_label.add_theme_color_override("font_color", TEXT)
		correct_label.add_theme_font_size_override("font_size", 16)
		correct_label.text = "Correct phrase: " + expected_phrase
		stack.add_child(correct_label)

	center_panel.scale = Vector2(0.72, 0.72)
	center_panel.modulate.a = 0.0
	center_panel.pivot_offset = center_panel.custom_minimum_size * 0.5
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(center_panel, "scale", Vector2.ONE, 0.22)
	reveal.parallel().tween_property(center_panel, "modulate:a", 1.0, 0.18)
	reveal.parallel().tween_property(flash, "color:a", 0.12 if is_correct else 0.08, 0.08)
	reveal.chain().tween_property(flash, "color:a", 0.0, 0.35)
	await get_tree().create_timer(1.15 if is_correct else 1.45).timeout
	if not is_instance_valid(self) or current_question == null:
		return

	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(center_panel, "modulate:a", 0.0, 0.16)
	out.tween_property(center_panel, "scale", Vector2(0.9, 0.9), 0.16)
	await out.finished
	if is_instance_valid(fusion_layer):
		fusion_layer.queue_free()
	for source: Control in source_tokens:
		if is_instance_valid(source):
			source.modulate.a = 1.0
	_sentence_check_button.text = "CHECK SENTENCE"
	if is_instance_valid(self) and current_question != null:
		_emit_answer(payload)


func _play_control_pop(control: Control, peak_scale: float = 1.08) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE * peak_scale, 0.075)
	tween.tween_property(control, "scale", Vector2.ONE, 0.12)


func _play_control_shake(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var home_rotation: float = control.rotation_degrees
	var tween := create_tween()
	tween.tween_property(control, "rotation_degrees", home_rotation + 3.0, 0.035)
	tween.tween_property(control, "rotation_degrees", home_rotation - 3.0, 0.045)
	tween.tween_property(control, "rotation_degrees", home_rotation + 1.5, 0.035)
	tween.tween_property(control, "rotation_degrees", home_rotation, 0.045)


func _hide_quiz() -> void:
	_fx_generation += 1
	_resolving = true
	if _transition_tween != null and _transition_tween.is_running():
		_transition_tween.kill()

	var out := create_tween()
	_transition_tween = out
	out.set_parallel(true)
	out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(self, "modulate:a", 0.0, 0.13)
	out.tween_property(_card, "scale", Vector2(0.96, 0.96), 0.13)
	out.chain().tween_callback(_finish_hide)


func _finish_hide() -> void:
	super._finish_hide()
	if is_instance_valid(_card):
		_card.scale = Vector2.ONE
		_card.rotation_degrees = 0.0
		_card.modulate = Color.WHITE
	if is_instance_valid(_fx_dimmer):
		_fx_dimmer.modulate = Color.WHITE
	if is_instance_valid(_fx_boss_flash):
		_fx_boss_flash.visible = false
		_fx_boss_flash.modulate.a = 0.0
