extends CanvasLayer

## MABYASA — debug-build-only F10 story checkpoint selector.
## Autoload once as QuestCheckpointDebug. Uses existing QuestManager save schema.
## Quest jumps CAN SAVE to the active account. Test on a separate account.

const FIRST_TOWN: String = "res://Scenes/Main/FirstTown.tscn"
const FOREST: String = "res://Scenes/Main/Forest.tscn"

# Order of main-story checkpoints, not ResourceLoader's alphabetical order.
# The optional checkpoint after the Guardian uses the same quest ID but a
# different guardian flag. Litik's new quest is present after its earlier ZIP.
const STAGES = [
	{"id": "walk_to_apu", "area": "town", "spawn": "Apu_player_pos", "note": "Speak with Apu about the curse."},
	{"id": "deliver_bebang_basket", "area": "town", "spawn": "BebangBasketPlayerPoint", "note": "Return Apu's basket to Bebang."},
	{"id": "visit_chief_after_basket", "area": "town", "spawn": "ChiefAfternoonPlayerPoint", "note": "Meet Chief for the first time."},
	{"id": "get_training_gear", "area": "town", "spawn": "BlacksmithQuizPlayerPoint", "note": "Collect the training equipment from Panday."},
	{"id": "return_to_chief", "area": "town", "spawn": "ChiefAfternoonPlayerPoint", "note": "Return to Chief after visiting Panday."},
	{"id": "first_training_battle", "area": "town", "spawn": "ChiefAfternoonPlayerPoint", "note": "First training battle with Chief."},
	{"id": "return_to_chief_after_training", "area": "town", "spawn": "ChiefAfternoonPlayerPoint", "note": "Speak with Chief after the first battle."},
	{"id": "return_home_to_ima", "area": "town", "spawn": "ImaEveningPlayerPoint", "note": "Restore health at the Big Tree, then visit Ima."},
	{"id": "greet_ima", "area": "town", "spawn": "ImaEveningPlayerPoint", "note": "Morning greeting and final training instructions."},
	{"id": "go_to_chief_final_training", "area": "town", "spawn": "player_narrow_path", "note": "Approach Ale's narrow path and ask her to let you pass."},
	{"id": "visit_ale_pacing", "area": "town", "spawn": "DefaultSpawn", "note": "Polite phrase with Ale; Chief's travel quest stays active."},
	{"id": "defeat_chief_final_training", "area": "town", "spawn": "finalchief", "note": "Chief's final battle checkpoint. The Ale route is already clear."},
	{"id": "reach_forest", "area": "town", "spawn": "ForestGateReturnPoint", "note": "Enter the Forest through its gate."},
	{"id": "get_mystic_ylang_ylang", "area": "forest", "spawn": "DefaultSpawn", "note": "Fight the forest Guardian and collect the Mystic Ylang-Ylang."},
	{"id": "get_mystic_ylang_ylang", "area": "forest", "spawn": "DefaultSpawn", "special": "after_guardian", "note": "Guardian already defeated. Collect the flower immediately."},
	{"id": "follow_litik_to_second_town", "area": "forest", "spawn": "DefaultSpawn", "note": "Flower collected; test Litik's travel quest and the forest exit."}
]

# Only these story flags are rewritten. Unrelated dialogue flags stay untouched.
const CONTROLLED_FLAGS = [
	"bebang_basket_delivered", "training_gear_ready", "training_gear_received",
	"training_battle_requested", "chief_training_battle_started",
	"chief_training_battle_completed", "chief_training_battle_lost",
	"chief_training_healed", "sleep_transition_requested",
	"final_training_unlocked", "pacing_move", "narrow_path_litik",
	"ale_path_cleared", "final_training_battle_requested",
	"chief_final_training_battle_started", "chief_final_training_battle_completed",
	"chief_final_training_battle_lost", "chief_final_training_battle_healed",
	"forest_ylang_guardian_defeated", "litik_warned_about_ylang_guardian",
	"mystic_ylang_ylang_obtained", "litik_after_ylang_briefing_done",
	"litik_second_town_warning_seen", "litik_second_town_unavailable_seen"
]

const GOLD: Color = Color(0.93, 0.72, 0.37)
const TEXT: Color = Color(0.91, 0.92, 0.85)

var _overlay: Control
var _options: OptionButton
var _summary: Label
var _warning: Label
var _apply: Button
var _confirm_armed: bool = false
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _jumping: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_input(false)
		return
	_build_menu()
	_overlay.hide()
	print("[QUEST DEBUG] F10 opens quest checkpoint selector (DEBUG BUILD ONLY).")


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or _jumping:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F10 or key.physical_keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_close_menu()
		else:
			_open_menu()
	elif key.keycode == KEY_ESCAPE and _overlay.visible:
		get_viewport().set_input_as_handled()
		_close_menu()


func _build_menu() -> void:
	layer = 110
	_overlay = Control.new()
	_overlay.name = "QuestCheckpointMenu"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.83)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)

	var centering: CenterContainer = CenterContainer.new()
	centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.add_child(centering)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(630, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	centering.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	column.add_child(_label("STORY CHECKPOINT DEBUG  ·  F10", 24, GOLD))
	column.add_child(_label("Jump straight to a main quest. Earlier story quests become completed.", 15, TEXT))

	_options = OptionButton.new()
	_options.custom_minimum_size.y = 45
	_options.add_theme_font_size_override("font_size", 16)
	for i: int in range(STAGES.size()):
		var stage: Dictionary = STAGES[i]
		var quest_id: String = str(stage.get("id", ""))
		var data: QuestData = QuestManager.get_quest(quest_id)
		var title: String = data.title if data != null else quest_id
		if str(stage.get("special", "")) == "after_guardian":
			title = "Mystic Ylang-Ylang — Guardian already defeated"
		elif quest_id == "follow_litik_to_second_town":
			title = "Follow Litik to the Next Town"
		if data == null:
			title += "  [MISSING QUEST FILE]"
		_options.add_item("%02d · %s" % [i + 1, title], i)
		if data == null:
			_options.set_item_disabled(i, true)
	column.add_child(_options)
	_options.item_selected.connect(_on_option_selected)

	_summary = _label("", 15, TEXT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.y = 80
	column.add_child(_summary)

	_warning = _label("DEBUG CHANGES MAY AUTOSAVE TO THIS ACCOUNT (INCLUDING CLOUD). USE A TEST ACCOUNT.", 13, Color(1.0, 0.68, 0.50))
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_warning)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var close_button: Button = Button.new()
	close_button.text = "CANCEL"
	close_button.custom_minimum_size = Vector2(140, 44)
	close_button.pressed.connect(_close_menu)
	actions.add_child(close_button)
	_apply = Button.new()
	_apply.text = "JUMP TO CHECKPOINT"
	_apply.custom_minimum_size = Vector2(220, 44)
	_apply.pressed.connect(_on_apply_pressed)
	actions.add_child(_apply)
	_update_description()


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.09, 0.075, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _open_menu() -> void:
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main) or bool(main.get("is_loading")):
		return
	_previous_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_confirm_armed = false
	_apply.text = "JUMP TO CHECKPOINT"
	_update_description()
	_overlay.show()


func _close_menu() -> void:
	_overlay.hide()
	_confirm_armed = false
	_apply.text = "JUMP TO CHECKPOINT"
	Input.set_mouse_mode(_previous_mouse_mode)


func _on_option_selected(_index: int) -> void:
	_confirm_armed = false
	_apply.text = "JUMP TO CHECKPOINT"
	_update_description()


func _selected_checkpoint() -> int:
	if _options.selected < 0:
		return -1
	return _options.get_selected_id()


func _update_description() -> void:
	var index: int = _selected_checkpoint()
	if index < 0 or index >= STAGES.size():
		_summary.text = "No checkpoint selected."
		_apply.disabled = true
		return
	var stage: Dictionary = STAGES[index]
	var quest_id: String = str(stage.get("id", ""))
	var scene_name: String = "FOREST" if str(stage.get("area", "town")) == "forest" else "FIRST TOWN"
	var total: int = _count_earlier_quests(index)
	_summary.text = "SCENE: %s     PREVIOUS QUESTS COMPLETED: %d\n%s\nQuest ID: %s" % [scene_name, total, str(stage.get("note", "")), quest_id]
	_apply.disabled = QuestManager.get_quest(quest_id) == null


func _count_earlier_quests(index: int) -> int:
	var unique: Dictionary = {}
	var chosen_id: String = str(STAGES[index].get("id", ""))
	for i: int in range(index):
		var quest_id: String = str(STAGES[i].get("id", ""))
		if quest_id != chosen_id and QuestManager.get_quest(quest_id) != null:
			unique[quest_id] = true
	return unique.size()


func _on_apply_pressed() -> void:
	var index: int = _selected_checkpoint()
	if index < 0 or index >= STAGES.size() or _jumping:
		return
	if not _confirm_armed:
		_confirm_armed = true
		_apply.text = "CONFIRM DEBUG JUMP"
		return
	_perform_jump(index)


func _perform_jump(index: int) -> void:
	if not OS.is_debug_build():
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main) or bool(main.get("is_loading")):
		return
	var stage: Dictionary = STAGES[index]
	var quest_id: String = str(stage.get("id", ""))
	if QuestManager.get_quest(quest_id) == null:
		push_warning("[QUEST DEBUG] Missing quest resource: " + quest_id)
		return

	_jumping = true
	_close_menu()

	var completed: Array[String] = []
	var active_side: Dictionary = {}
	for value: Variant in QuestManager.active_quests.keys():
		var other_id: String = str(value)
		var resource: QuestData = QuestManager.get_quest(other_id)
		if resource != null and not resource.is_main_quest:
			active_side[other_id] = QuestManager.active_quests[other_id].duplicate(true)
	for value: Variant in QuestManager.completed_quests:
		var other_id: String = str(value)
		var resource: QuestData = QuestManager.get_quest(other_id)
		if resource != null and not resource.is_main_quest and not completed.has(other_id):
			completed.append(other_id)

	for i: int in range(index):
		var previous_id: String = str(STAGES[i].get("id", ""))
		if previous_id == quest_id:
			continue
		if index == 10 and previous_id == "go_to_chief_final_training":
			continue  # Ale is a subquest during travel to Chief.
		if QuestManager.get_quest(previous_id) != null and not completed.has(previous_id):
			completed.append(previous_id)

	var flags: Dictionary = QuestManager.dialogue_flags.duplicate(true)
	for flag: String in CONTROLLED_FLAGS:
		flags.erase(flag)
	_apply_checkpoint_flags(flags, index)

	QuestManager.load_save_data({
		"active_quests": active_side,
		"completed_quests": completed,
		"dialogue_flags": flags
	})

	# Set time BEFORE starting the quest to avoid completing time objectives.
	var hour: String = "morning"
	if index >= 2 and index <= 7:
		hour = "afternoon"
	elif index == 8:
		hour = "night"
	TimeManager.set_time(hour)

	_grant_skipped_lesson_words(index)
	PlayerProgression.heal(100000)

	if index == 10:
		QuestManager.start_quest("go_to_chief_final_training")
	QuestManager.start_quest(quest_id)

	# Do not resume a previous tutorial or saved-position restoration on reload.
	GameManager.pending_first_town_intro = false
	GameManager.should_load_save = false
	main.set("has_pending_save", false)
	main.set("start_first_town_intro_after_load", false)

	var target_scene: String = FOREST if str(stage.get("area", "town")) == "forest" else FIRST_TOWN
	var spawn_name: String = str(stage.get("spawn", "DefaultSpawn"))
	main.connect("loading_completed", Callable(self, "_on_level_loaded").bind(index), CONNECT_ONE_SHOT)
	print("[QUEST DEBUG] Jump -> %s, completed earlier quests: %d" % [quest_id, completed.size()])
	main.call("load_new_level_async", target_scene, spawn_name)


func _apply_checkpoint_flags(flags: Dictionary, index: int) -> void:
	# Threshold means the associated story event already happened BEFORE
	# the selected checkpoint (not a quest the user still needs to complete).
	if index >= 2:
		flags["bebang_basket_delivered"] = true
	if index >= 3:
		flags["training_gear_ready"] = true
	if index >= 4:
		flags["training_gear_received"] = true
	if index >= 6:
		flags["chief_training_battle_started"] = true
		flags["chief_training_battle_completed"] = true
	if index >= 9:
		flags["sleep_transition_requested"] = true
		flags["final_training_unlocked"] = true
	if index >= 11:
		flags["ale_path_cleared"] = true
		flags["narrow_path_litik"] = true
	if index >= 12:
		flags["chief_final_training_battle_started"] = true
		flags["chief_final_training_battle_completed"] = true
	if index >= 14:
		flags["forest_ylang_guardian_defeated"] = true
	if index >= 15:
		flags["mystic_ylang_ylang_obtained"] = true
		flags["litik_after_ylang_briefing_done"] = true

	var hour: String = "morning"
	if index >= 2 and index <= 7:
		hour = "afternoon"
	elif index == 8:
		hour = "night"
	flags["time_morning"] = hour == "morning"
	flags["time_afternoon"] = hour == "afternoon"
	flags["time_night"] = hour == "night"


func _grant_skipped_lesson_words(index: int) -> void:
	# Necessary when jumping past the story's language lessons: boss sentence
	# questions require encountered words and their components.
	if not is_instance_valid(LanguageProgress):
		return
	var ids: PackedStringArray = PackedStringArray()
	if index >= 2:
		ids.append("salamat")
		ids.append("dakal_a_salamat")
		ids.append("ala_pung_nanu_man")
	if index >= 3:
		ids.append("mayap_a_gatpanapun")
	if index >= 9:
		ids.append("mayap_a_abak")
		ids.append("mayap_a_bengi")
	if index >= 11:
		ids.append("makilabas_ku_pu")
	if not ids.is_empty():
		LanguageProgress.debug_grant(ids)


func _on_level_loaded(index: int) -> void:
	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main):
		_jumping = false
		return
	var player: CharacterBody3D = main.get("player") as CharacterBody3D
	if is_instance_valid(player) and index >= 13:
		# Keep the player off the collectible trigger and allow a short walk.
		var target: Vector3 = Vector3(-41.7, 0.5, -4.6)
		if index == 14:
			target = Vector3(-38.9, 0.5, -8.2)
		elif index == 15:
			target = Vector3(-43.6, 0.5, -13.3)
		player.velocity = Vector3.ZERO
		player.global_position = target
	GameManager.request_save()
	_jumping = false
	print("[QUEST DEBUG] Checkpoint ready; open Quest Log to view previous completed quests.")
