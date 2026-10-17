extends Area3D

## Attach to Bigtree/Area3D in FirstTown.tscn.
## Interact with the tree to restore HP up to a configurable percentage.

@export_category("Healing Tree")
@export_range(1.0, 100.0, 1.0, "suffix:%") var heal_to_percent: float = 70.0
@export var interaction_action: StringName = &"interact"
@export_range(0.5, 5.0, 0.25, "suffix:s") var feedback_duration: float = 2.0
@export var prompt_text: String = "Rest & restore your health"

const SPARKLE_COUNT: int = 12
const PROMPT_LAYER: int = 40

var _player_in_range: bool = false
var _prompt_layer: CanvasLayer
var _prompt_panel: PanelContainer
var _prompt_key_panel: PanelContainer
var _prompt_key_label: Label
var _prompt_title: Label
var _prompt_label: Label
var _prompt_pulse_tween: Tween
var _feedback_generation: int = 0
var _prompt_generation: int = 0


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_create_prompt()
	# Catch the edge case where the player is already inside the Area3D as the
	# scene starts or is streamed in.
	call_deferred("_sync_initial_overlap")


func _exit_tree() -> void:
	if is_instance_valid(_prompt_pulse_tween) and _prompt_pulse_tween.is_running():
		_prompt_pulse_tween.kill()
	if is_instance_valid(_prompt_layer):
		_prompt_layer.queue_free()
	_prompt_layer = null
	_prompt_panel = null
	_prompt_label = null


func _process(_delta: float) -> void:
	# Poll overlap as a fallback in case body_entered was missed during loading.
	if not monitoring:
		return
	var found_player := false
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group("player"):
			found_player = true
			break
	if found_player != _player_in_range:
		_set_player_in_range(found_player)


func _input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if not event.is_action_pressed(interaction_action, false):
		return
	if not is_instance_valid(GameManager):
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	get_viewport().set_input_as_handled()
	_heal_player()


func _sync_initial_overlap() -> void:
	if not is_inside_tree():
		return
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group("player"):
			_set_player_in_range(true)
			return


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_set_player_in_range(true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_set_player_in_range(false)


func _create_prompt() -> void:
	# Mabiyasa palette: deep forest green, warm antique gold, cream, and muted sage.
	const FOREST_DARK := Color(0.035, 0.055, 0.043, 0.97)
	const FOREST_PANEL := Color(0.075, 0.105, 0.078, 1.0)
	const ANTIQUE_GOLD := Color(0.88, 0.70, 0.36, 1.0)
	const CREAM := Color(0.96, 0.93, 0.84, 1.0)
	const MUTED_SAGE := Color(0.69, 0.72, 0.65, 1.0)

	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "HealingTreePromptLayer"
	_prompt_layer.layer = PROMPT_LAYER
	_prompt_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var host: Node = get_tree().current_scene
	if not is_instance_valid(host):
		host = get_tree().root
	host.add_child(_prompt_layer)

	var screen_root := Control.new()
	screen_root.name = "ScreenRoot"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_layer.add_child(screen_root)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "PromptPanel"
	_prompt_panel.custom_minimum_size = Vector2(510.0, 82.0)
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_left = -255.0
	_prompt_panel.offset_right = 255.0
	_prompt_panel.offset_top = -146.0
	_prompt_panel.offset_bottom = -64.0
	_prompt_panel.pivot_offset = Vector2(255.0, 41.0)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = FOREST_DARK
	panel_style.border_color = ANTIQUE_GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 15.0
	panel_style.content_margin_right = 15.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	panel_style.shadow_color = Color(0.008, 0.014, 0.01, 0.72)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	_prompt_panel.add_theme_stylebox_override("panel", panel_style)
	screen_root.add_child(_prompt_panel)

	var row := HBoxContainer.new()
	row.name = "PromptRow"
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(row)

	# The E key is a proper keycap, using the same brass/gold accent as the game's review UI.
	_prompt_key_panel = PanelContainer.new()
	_prompt_key_panel.name = "InteractKeycap"
	_prompt_key_panel.custom_minimum_size = Vector2(52.0, 48.0)
	_prompt_key_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = ANTIQUE_GOLD
	key_style.border_color = Color(0.98, 0.86, 0.59, 1.0)
	key_style.set_border_width_all(1)
	key_style.set_corner_radius_all(5)
	key_style.content_margin_left = 8.0
	key_style.content_margin_right = 8.0
	key_style.content_margin_top = 5.0
	key_style.content_margin_bottom = 5.0
	_prompt_key_panel.add_theme_stylebox_override("panel", key_style)
	row.add_child(_prompt_key_panel)

	_prompt_key_label = Label.new()
	_prompt_key_label.name = "InteractKeyLabel"
	_prompt_key_label.text = "E"
	_prompt_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_key_label.add_theme_color_override("font_color", FOREST_PANEL)
	_prompt_key_label.add_theme_font_size_override("font_size", 24)
	_prompt_key_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
	_prompt_key_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_key_panel.add_child(_prompt_key_label)

	var text_column := VBoxContainer.new()
	text_column.name = "PromptTextColumn"
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 3)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	_prompt_title = Label.new()
	_prompt_title.name = "PromptTitle"
	_prompt_title.text = "ANCIENT TREE"
	_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_prompt_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_title.add_theme_color_override("font_color", ANTIQUE_GOLD)
	_prompt_title.add_theme_font_size_override("font_size", 12)
	_prompt_title.add_theme_constant_override("outline_size", 2)
	_prompt_title.add_theme_color_override("font_outline_color", FOREST_DARK)
	_prompt_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(_prompt_title)

	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = prompt_text
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", CREAM)
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(_prompt_label)

func _set_player_in_range(is_in_range: bool) -> void:
	if _player_in_range == is_in_range:
		return
	_player_in_range = is_in_range

	if not is_instance_valid(_prompt_panel):
		return

	_prompt_generation += 1
	_feedback_generation += 1

	if is_in_range:
		_prompt_label.text = prompt_text
		_prompt_key_panel.visible = true
		_prompt_title.visible = true
		_prompt_panel.visible = true
		_animate_prompt_entrance(_prompt_generation)
	else:
		if is_instance_valid(_prompt_pulse_tween) and _prompt_pulse_tween.is_running():
			_prompt_pulse_tween.kill()
		_prompt_panel.visible = false
		_prompt_panel.scale = Vector2.ONE


func _animate_prompt_entrance(generation: int) -> void:
	if not is_instance_valid(_prompt_panel):
		return
	if is_instance_valid(_prompt_pulse_tween) and _prompt_pulse_tween.is_running():
		_prompt_pulse_tween.kill()

	_prompt_panel.modulate.a = 0.0
	_prompt_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(_prompt_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.finished.connect(_start_prompt_pulse.bind(generation), CONNECT_ONE_SHOT)


func _start_prompt_pulse(generation: int) -> void:
	if generation != _prompt_generation or not _player_in_range or not is_instance_valid(_prompt_panel):
		return
	_prompt_pulse_tween = create_tween().set_loops()
	_prompt_pulse_tween.tween_property(_prompt_panel, "scale", Vector2(1.025, 1.025), 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_pulse_tween.tween_property(_prompt_panel, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _heal_player() -> void:
	if not is_instance_valid(PlayerProgression):
		_show_feedback("Healing is unavailable right now.")
		return

	PlayerProgression.ensure_hp_initialized()

	var max_hp: int = maxi(PlayerProgression.get_total_max_hp(), 1)
	var target_percent: float = clampf(heal_to_percent, 1.0, 100.0)
	var target_hp: int = clampi(roundi(float(max_hp) * target_percent / 100.0), 1, max_hp)
	var current_hp: int = clampi(PlayerProgression.current_hp, 0, max_hp)

	# Healing is capped at the configured target. It never removes HP if the
	# player is already above that target.
	if current_hp >= target_hp:
		_show_feedback("You're already healthy enough.")
		return

	var recovered_hp: int = target_hp - current_hp
	PlayerProgression.heal(recovered_hp)

	if is_instance_valid(GameManager) and GameManager.has_method("request_save"):
		GameManager.request_save()

	_play_healing_effect()
	var final_percent: int = roundi(float(PlayerProgression.current_hp) / float(max_hp) * 100.0)
	_show_feedback("The tree's energy restores you!  %d%% HP" % final_percent)
	print("[HEALING TREE] Restored %d HP. Current HP: %d/%d." % [recovered_hp, PlayerProgression.current_hp, max_hp])


func _show_feedback(message: String) -> void:
	if not is_instance_valid(_prompt_panel) or not is_instance_valid(_prompt_label):
		print("[HEALING TREE] " + message)
		return

	_feedback_generation += 1
	var generation := _feedback_generation
	_prompt_label.text = message
	_prompt_key_panel.visible = false
	_prompt_title.visible = false
	_prompt_panel.visible = _player_in_range
	_restore_prompt_after_feedback(generation)


func _restore_prompt_after_feedback(generation: int) -> void:
	await get_tree().create_timer(feedback_duration).timeout
	if not is_instance_valid(self) or generation != _feedback_generation:
		return
	if _player_in_range and is_instance_valid(_prompt_label):
		_prompt_label.text = prompt_text
		_prompt_key_panel.visible = true
		_prompt_title.visible = true


func _play_healing_effect() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return

	var fx_host: Node = get_tree().current_scene
	if not is_instance_valid(fx_host):
		fx_host = get_tree().root

	# A soft green glow around the player gives the heal an immediate readable cue.
	var glow := OmniLight3D.new()
	glow.name = "HealingTreeGlow"
	glow.light_color = Color(0.42, 1.0, 0.58)
	glow.light_energy = 1.8
	glow.omni_range = 3.25
	fx_host.add_child(glow)
	glow.global_position = player.global_position + Vector3(0.0, 1.0, 0.0)
	var glow_tween := create_tween()
	glow_tween.tween_property(glow, "light_energy", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.finished.connect(glow.queue_free, CONNECT_ONE_SHOT)

	# Small glowing motes rise around the player and fade away.
	for i in range(SPARKLE_COUNT):
		var sparkle := MeshInstance3D.new()
		sparkle.name = "HealingSparkle"
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.035, 0.065)
		sphere.height = sphere.radius * 2.0
		sparkle.mesh = sphere

		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var sparkle_color := Color(0.55, 1.0, 0.68, 1.0) if i % 2 == 0 else Color(1.0, 0.86, 0.4, 1.0)
		material.albedo_color = sparkle_color
		material.emission_enabled = true
		material.emission = sparkle_color
		sparkle.material_override = material
		sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_host.add_child(sparkle)

		var angle: float = TAU * float(i) / float(SPARKLE_COUNT)
		var radius: float = randf_range(0.35, 0.8)
		var start_position := player.global_position + Vector3(cos(angle) * radius, randf_range(0.15, 1.2), sin(angle) * radius)
		var end_position := start_position + Vector3(cos(angle) * 0.35, randf_range(0.75, 1.25), sin(angle) * 0.35)
		sparkle.global_position = start_position
		sparkle.scale = Vector3.ONE

		var duration: float = randf_range(0.7, 1.15)
		var sparkle_tween := create_tween()
		sparkle_tween.set_parallel(true)
		sparkle_tween.tween_property(sparkle, "global_position", end_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		sparkle_tween.tween_property(sparkle, "transparency", 1.0, duration)
		sparkle_tween.tween_property(sparkle, "scale", Vector3.ZERO, duration)
		sparkle_tween.finished.connect(sparkle.queue_free, CONNECT_ONE_SHOT)
