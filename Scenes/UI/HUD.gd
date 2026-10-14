extends Control

## Exploration HUD for Mabiyasa.
## Updates through signals; no per-frame polling is required.

@onready var quest_panel: PanelContainer = $QuestPanel
@onready var quest_title_label: Label = $QuestPanel/QuestMargin/QuestVBox/QuestTitleLabel
@onready var objective_state_label: Label = $QuestPanel/QuestMargin/QuestVBox/ObjectiveRow/ObjectiveStateLabel
@onready var objective_label: Label = $QuestPanel/QuestMargin/QuestVBox/ObjectiveRow/ObjectiveLabel
@onready var objective_progress_label: Label = $QuestPanel/QuestMargin/QuestVBox/ObjectiveRow/ObjectiveProgressLabel

@onready var portrait: TextureRect = $StatusPanel/StatusMargin/StatusRow/PortraitFrame/PortraitMargin/Portrait
@onready var level_label: Label = $StatusPanel/StatusMargin/StatusRow/InfoBox/HeaderRow/LevelLabel
@onready var gold_label: Label = $StatusPanel/StatusMargin/StatusRow/InfoBox/HeaderRow/GoldLabel
@onready var hp_value_label: Label = $StatusPanel/StatusMargin/StatusRow/InfoBox/HPRow/HPValueLabel
@onready var hp_bar: ProgressBar = $StatusPanel/StatusMargin/StatusRow/InfoBox/HPBar
@onready var exp_bar: ProgressBar = $StatusPanel/StatusMargin/StatusRow/InfoBox/EXPRow/EXPBar
@onready var exp_value_label: Label = $StatusPanel/StatusMargin/StatusRow/InfoBox/EXPRow/EXPValueLabel

@onready var inventory_button: Button = $ShortcutBar/InventoryButton
@onready var wordbook_button: Button = $ShortcutBar/WordbookButton
@onready var quest_log_button: Button = $ShortcutBar/QuestLogButton

@onready var location_label: Label = $LocationPanel/LocationRow/LocationLabel
@onready var interaction_prompt: PanelContainer = $InteractionPrompt
@onready var interaction_key_label: Label = $InteractionPrompt/PromptMargin/PromptRow/KeyCap/KeyLabel
@onready var interaction_text: Label = $InteractionPrompt/PromptMargin/PromptRow/PromptText
@onready var notice_panel: PanelContainer = $NoticePanel
@onready var notice_label: Label = $NoticePanel/NoticeLabel
@onready var notice_timer: Timer = $NoticeTimer

var _current_quest_id: String = ""
var _active_overlay: CanvasLayer = null
var _overlay_opened_from_hud: bool = false
var _pause_was_started_by_hud: bool = false
var _interaction_source: Node = null

# Game-state visibility and tutorial visibility are handled separately.
var _game_state_allows_hud: bool = true


func _ready() -> void:
	add_to_group("game_hud")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	interaction_prompt.hide()
	notice_panel.hide()
	quest_panel.hide()

	inventory_button.pressed.connect(_on_inventory_pressed)
	wordbook_button.pressed.connect(_on_wordbook_pressed)
	quest_log_button.pressed.connect(_on_quest_log_pressed)
	notice_timer.timeout.connect(_hide_notice)

	_connect_progression_signals()
	_connect_game_signals()
	_connect_quest_signals()

	# Read the current game state in case the HUD is created mid-game.
	if is_instance_valid(GameManager):
		_game_state_allows_hud = (
			GameManager.current_state
			== GameManager.GameState.EXPLORATION
		)

	# Initial visibility check also handles the tutorial welcome screen.
	_apply_hud_visibility()

	_refresh_player_status()
	_refresh_player_portrait()
	_refresh_location()
	_refresh_quest_tracker()


func _exit_tree() -> void:
	if is_instance_valid(PlayerProgression):
		_disconnect_if_connected(
			PlayerProgression.stats_changed,
			_refresh_player_status
		)
		_disconnect_if_connected(
			PlayerProgression.leveled_up,
			_refresh_player_status
		)
		_disconnect_if_connected(
			PlayerProgression.hp_changed,
			_refresh_player_status
		)

	if is_instance_valid(QuestManager):
		_disconnect_if_connected(
			QuestManager.quest_started,
			_on_quest_state_changed
		)
		_disconnect_if_connected(
			QuestManager.quest_objective_updated,
			_on_quest_state_changed
		)
		_disconnect_if_connected(
			QuestManager.quest_completed,
			_on_quest_state_changed
		)

	if (
		is_instance_valid(GameManager)
		and GameManager.has_signal("hud_visibility_changed")
	):
		_disconnect_if_connected(
			GameManager.hud_visibility_changed,
			_on_hud_visibility_changed
		)

	if is_instance_valid(TutorialManager):
		_disconnect_if_connected(
			TutorialManager.step_changed,
			_on_tutorial_step_changed
		)

	var main_node := _find_main_node()

	if (
		is_instance_valid(main_node)
		and main_node.has_signal("loading_completed")
	):
		_disconnect_if_connected(
			Signal(main_node, "loading_completed"),
			_on_level_loaded
		)


# ============================================================
# SIGNAL CONNECTIONS
# ============================================================

func _connect_progression_signals() -> void:
	if not is_instance_valid(PlayerProgression):
		return

	_connect_if_needed(
		PlayerProgression.stats_changed,
		_refresh_player_status
	)
	_connect_if_needed(
		PlayerProgression.leveled_up,
		_refresh_player_status
	)
	_connect_if_needed(
		PlayerProgression.hp_changed,
		_refresh_player_status
	)

	if PlayerProgression.has_method("ensure_hp_initialized"):
		PlayerProgression.ensure_hp_initialized()


func _connect_game_signals() -> void:
	if (
		is_instance_valid(GameManager)
		and GameManager.has_signal("hud_visibility_changed")
	):
		_connect_if_needed(
			GameManager.hud_visibility_changed,
			_on_hud_visibility_changed
		)

	# Re-evaluate HUD visibility whenever the tutorial step changes.
	if is_instance_valid(TutorialManager):
		_connect_if_needed(
			TutorialManager.step_changed,
			_on_tutorial_step_changed
		)

	var main_node := _find_main_node()

	if (
		is_instance_valid(main_node)
		and main_node.has_signal("loading_completed")
	):
		_connect_if_needed(
			Signal(main_node, "loading_completed"),
			_on_level_loaded
		)


func _connect_quest_signals() -> void:
	if not is_instance_valid(QuestManager):
		return

	_connect_if_needed(
		QuestManager.quest_started,
		_on_quest_state_changed
	)
	_connect_if_needed(
		QuestManager.quest_objective_updated,
		_on_quest_state_changed
	)
	_connect_if_needed(
		QuestManager.quest_completed,
		_on_quest_state_changed
	)


func _connect_if_needed(
	signal_ref: Signal,
	callback: Callable
) -> void:
	if not signal_ref.is_connected(callback):
		signal_ref.connect(callback)


func _disconnect_if_connected(
	signal_ref: Signal,
	callback: Callable
) -> void:
	if signal_ref.is_connected(callback):
		signal_ref.disconnect(callback)


func _find_main_node() -> Node:
	var node: Node = self

	while is_instance_valid(node):
		if node.has_signal("loading_completed"):
			return node

		node = node.get_parent()

	return null


# ============================================================
# HUD VISIBILITY
# ============================================================

func _on_hud_visibility_changed(should_show: bool) -> void:
	# GameManager controls pause, dialogue, quiz, and battle visibility.
	_game_state_allows_hud = should_show
	_apply_hud_visibility()


func _on_tutorial_step_changed(_step_name: String) -> void:
	_apply_hud_visibility()


func _apply_hud_visibility() -> void:
	# Only show the exploration HUD once the tutorial is finished.
	# The missing-manager fallback allows the HUD to work if the
	# tutorial system is disabled in another build.
	var tutorial_finished: bool = (
		not is_instance_valid(TutorialManager)
		or TutorialManager.current_active_step == "finished"
	)

	visible = _game_state_allows_hud and tutorial_finished

	if not visible:
		interaction_prompt.hide()
		notice_panel.hide()
	elif is_instance_valid(_interaction_source):
		interaction_prompt.show()


# ============================================================
# PLAYER STATUS
# ============================================================

func _refresh_player_status() -> void:
	if not is_instance_valid(PlayerProgression):
		return

	if PlayerProgression.has_method("ensure_hp_initialized"):
		PlayerProgression.ensure_hp_initialized()

	var level: int = int(PlayerProgression.level)
	var hp_max: int = maxi(
		int(PlayerProgression.get_total_max_hp()),
		1
	)
	var hp_current: int = clampi(
		int(PlayerProgression.current_hp),
		0,
		hp_max
	)

	var exp_max: int = maxi(
		int(PlayerProgression.get_max_exp(level)),
		1
	)
	var exp_current: int = clampi(
		int(PlayerProgression.current_exp),
		0,
		exp_max
	)

	level_label.text = "Lv. %d" % level
	gold_label.text = "%d G" % int(PlayerProgression.gold)

	hp_value_label.text = "%d / %d" % [
		hp_current,
		hp_max
	]
	hp_bar.max_value = hp_max
	hp_bar.value = hp_current

	exp_bar.max_value = exp_max
	exp_bar.value = exp_current
	exp_value_label.text = "%d / %d" % [
		exp_current,
		exp_max
	]


func _refresh_player_portrait() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		return

	var sprite := player.get_node_or_null(
		"AnimatedSprite3D"
	) as AnimatedSprite3D

	if sprite == null or sprite.sprite_frames == null:
		return

	var frames: SpriteFrames = sprite.sprite_frames
	var portrait_animation: StringName = &"idle_front"

	if not frames.has_animation(portrait_animation):
		portrait_animation = sprite.animation

	if (
		frames.has_animation(portrait_animation)
		and frames.get_frame_count(portrait_animation) > 0
	):
		portrait.texture = frames.get_frame_texture(
			portrait_animation,
			0
		)


func _on_level_loaded() -> void:
	_refresh_location()
	_refresh_player_portrait()


func _refresh_location() -> void:
	var level_path := ""

	if is_instance_valid(GameManager):
		level_path = str(
			GameManager.get("current_level_path")
		)

	var scene_name := level_path.get_file().get_basename()

	if scene_name.is_empty():
		location_label.text = "YATU VILLAGE"
		return

	match scene_name.to_lower():
		"firsttown":
			location_label.text = "YATU VILLAGE"
		"forest":
			location_label.text = "FOREST"
		_:
			location_label.text = (
				scene_name.replace("_", " ").to_upper()
			)


# ============================================================
# INTERACTION PROMPT
# ============================================================

func show_interaction_prompt(
	prompt_text: String,
	source: Node = null,
	key_text: String = "E"
) -> void:
	# Called by an interactable when the player enters interaction range.
	_interaction_source = source

	var clean_text := prompt_text.strip_edges()
	interaction_text.text = (
		clean_text if not clean_text.is_empty() else "Interact"
	)
	interaction_key_label.text = key_text

	if visible:
		interaction_prompt.show()


func hide_interaction_prompt(source: Node = null) -> void:
	# Prevent one NPC from hiding another NPC's active prompt.
	if (
		source != null
		and (
			not is_instance_valid(_interaction_source)
			or source != _interaction_source
		)
	):
		return

	_interaction_source = null
	interaction_prompt.hide()


# ============================================================
# QUEST TRACKER
# ============================================================

func _on_quest_state_changed(
	_quest_id: String,
	_value_1: Variant = null,
	_value_2: Variant = null
) -> void:
	_refresh_quest_tracker()


func _refresh_quest_tracker() -> void:
	if not is_instance_valid(QuestManager):
		quest_panel.hide()
		_current_quest_id = ""
		return

	var active_quests: Dictionary = QuestManager.active_quests

	if active_quests.is_empty():
		_current_quest_id = ""
		quest_panel.hide()
		return

	var selected_id := ""

	# Prefer a main quest so the tracker prioritizes the main story.
	for quest_key in active_quests.keys():
		var candidate_id := str(quest_key)
		var candidate_data: QuestData = QuestManager.get_quest(
			candidate_id
		)

		if (
			candidate_data != null
			and candidate_data.is_main_quest
		):
			selected_id = candidate_id
			break

	# Otherwise keep the current quest to avoid unnecessary switching.
	if (
		selected_id.is_empty()
		and active_quests.has(_current_quest_id)
	):
		selected_id = _current_quest_id

	if selected_id.is_empty():
		selected_id = str(active_quests.keys()[0])

	_current_quest_id = selected_id

	var quest_data: QuestData = QuestManager.get_quest(
		_current_quest_id
	)

	if quest_data == null:
		quest_panel.hide()
		return

	quest_title_label.text = (
		quest_data.title
		if not quest_data.title.strip_edges().is_empty()
		else _current_quest_id.replace("_", " ").capitalize()
	)

	var step_index: int = QuestManager.get_current_step(
		_current_quest_id
	)

	if step_index < 0 or step_index >= quest_data.steps.size():
		objective_state_label.text = "✓"
		objective_label.text = "Quest objectives complete"
		objective_progress_label.text = ""
		quest_panel.show()
		return

	var step: QuestStep = quest_data.steps[step_index]
	var current_count: int = QuestManager.get_objective_count(
		_current_quest_id,
		step_index
	)
	var required_count: int = maxi(
		QuestManager.get_objective_required_count(
			_current_quest_id,
			step_index
		),
		1
	)
	var objective_complete: bool = QuestManager.is_objective_completed(
		_current_quest_id,
		step_index
	)

	objective_state_label.text = (
		"✓" if objective_complete else "○"
	)
	objective_label.text = _format_objective(step)
	objective_progress_label.text = "%d / %d" % [
		mini(current_count, required_count),
		required_count
	]

	quest_panel.show()


func _format_objective(step: QuestStep) -> String:
	var target := _format_target(step.target)

	match step.type:
		"talk_npc":
			return "Talk to " + target
		"reach_location":
			return "Go to " + target
		"wait_time":
			return "Wait until " + target
		"solve_puzzle":
			return "Solve " + target
		"enemy_killed":
			return "Defeat " + target
		"item_collected":
			return "Collect " + target
		"interact_object":
			return "Interact with " + target
		_:
			return target


func _format_target(raw_target: String) -> String:
	var target := raw_target.strip_edges()
	target = target.replace("_", " ").replace("-", " ")

	if target.is_empty():
		return "the objective"

	return target.capitalize()


# ============================================================
# SHORTCUT BUTTONS
# ============================================================

func _on_inventory_pressed() -> void:
	_show_notice("Inventory is not available yet")


func _on_wordbook_pressed() -> void:
	_show_notice("Wordbook is not available yet")


func _on_quest_log_pressed() -> void:
	_open_pause_menu_overlay("quest_log")


func _show_notice(message: String) -> void:
	notice_timer.stop()
	notice_label.text = message

	if visible:
		notice_panel.show()

	notice_timer.start()


func _hide_notice() -> void:
	notice_panel.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if (
		not visible
		or get_tree().paused
		or not key_event.pressed
		or key_event.echo
	):
		return

	match key_event.keycode:
		KEY_I:
			_on_inventory_pressed()
			get_viewport().set_input_as_handled()
		KEY_J:
			_on_wordbook_pressed()
			get_viewport().set_input_as_handled()
		KEY_L:
			_on_quest_log_pressed()
			get_viewport().set_input_as_handled()


# ============================================================
# OPEN EXISTING QUEST LOG
# ============================================================

func _open_pause_menu_overlay(overlay_property: String) -> void:
	var ui_layer := get_parent()

	if not is_instance_valid(ui_layer):
		return

	var pause_menu := ui_layer.get_node_or_null(
		"PauseMenu"
	) as CanvasLayer

	if not is_instance_valid(pause_menu):
		push_warning(
			"[HUD] PauseMenu could not be found under UILayer."
		)
		return

	var overlay_value: Variant = pause_menu.get(
		overlay_property
	)

	if not (overlay_value is CanvasLayer):
		push_warning(
			"[HUD] Existing menu '%s' is not available yet."
			% overlay_property
		)
		return

	var overlay := overlay_value as CanvasLayer

	if (
		not overlay.has_method("open")
		or not overlay.has_signal("closed")
	):
		push_warning(
			"[HUD] Menu '%s' does not expose open() and closed."
			% overlay_property
		)
		return

	if _overlay_opened_from_hud:
		return

	_pause_was_started_by_hud = not get_tree().paused

	if (
		_pause_was_started_by_hud
		and is_instance_valid(GameManager)
		and GameManager.has_method("toggle_pause")
	):
		GameManager.toggle_pause()

	_active_overlay = overlay
	_overlay_opened_from_hud = true

	var closed_signal := Signal(overlay, "closed")
	var close_callback := Callable(
		self,
		"_on_overlay_closed_from_hud"
	).bind(overlay, pause_menu)

	if not closed_signal.is_connected(close_callback):
		closed_signal.connect(close_callback)

	# Reuse PauseMenu's existing menu instance instead of duplicating it.
	if overlay.get_parent() != ui_layer:
		overlay.reparent(ui_layer)

	overlay.layer = 20
	pause_menu.hide()
	overlay.open()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_overlay_closed_from_hud(
	overlay: CanvasLayer,
	pause_menu: CanvasLayer
) -> void:
	if (
		not _overlay_opened_from_hud
		or overlay != _active_overlay
	):
		return

	pause_menu.hide()

	if is_instance_valid(overlay):
		overlay.layer = 1

		if overlay.get_parent() != pause_menu:
			overlay.reparent(pause_menu)

	var should_resume_game := _pause_was_started_by_hud

	_overlay_opened_from_hud = false
	_active_overlay = null
	_pause_was_started_by_hud = false

	if should_resume_game:
		if (
			get_tree().paused
			and is_instance_valid(GameManager)
			and GameManager.has_method("toggle_pause")
		):
			GameManager.toggle_pause()
		else:
			pause_menu.hide()
	else:
		pause_menu.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
