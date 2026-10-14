extends Control

## HUD quest tracker.
## This script is intentionally separate from the language-combat quiz UI.
## It listens to QuestManager and updates the existing QuestUI.tscn layout.

const POP_IN_DURATION: float = 0.24
const HIDE_DURATION: float = 0.20
const COMPLETION_DISPLAY_TIME: float = 1.8
const PANEL_SLIDE_DISTANCE: float = 455.0

@onready var quest_panel: Control = $QuestPanel
@onready var quest_title: Label = $QuestPanel/ContentMargin/MainVBox/QuestTitle
@onready var description_label: Label = $QuestPanel/ContentMargin/MainVBox/DescriptionLabel
@onready var objectives_container: VBoxContainer = $QuestPanel/ContentMargin/MainVBox/ObjectivesScroll/ObjectivesContainer
@onready var objective_template: HBoxContainer = $QuestPanel/ContentMargin/MainVBox/ObjectivesScroll/ObjectivesContainer/ObjectiveTemplate
@onready var exp_reward: Label = $QuestPanel/ContentMargin/MainVBox/RewardsContainer/ExpReward
@onready var gold_reward: Label = $QuestPanel/ContentMargin/MainVBox/RewardsContainer/GoldReward
@onready var no_rewards: Label = $QuestPanel/ContentMargin/MainVBox/RewardsContainer/NoRewards
@onready var status_label: Label = $QuestPanel/ContentMargin/MainVBox/StatusLabel
@onready var completion_overlay: Control = $QuestPanel/CompletionOverlay
@onready var completion_label: Label = $QuestPanel/CompletionOverlay/CompletionLabel
@onready var collapse_button: Button = $CollapseButton

var _tracked_quest_id: String = ""
var _panel_left: float = 24.0
var _panel_right: float = 383.0
var _panel_alpha: float = 0.65
var _collapsed: bool = false
var _transition_tween: Tween
var _presentation_token: int = 0
var _objective_rows: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel_left = quest_panel.offset_left
	_panel_right = quest_panel.offset_right
	_panel_alpha = quest_panel.modulate.a

	objective_template.visible = false
	completion_overlay.visible = false
	description_label.visible = false

	if not collapse_button.pressed.is_connected(_on_collapse_pressed):
		collapse_button.pressed.connect(_on_collapse_pressed)

	_connect_quest_signals()

	# If the scene is added while a quest is already active, restore its HUD.
	var active_ids: Array = QuestManager.active_quests.keys()
	if not active_ids.is_empty():
		_tracked_quest_id = str(active_ids[active_ids.size() - 1])
		_refresh_tracker()
		_show_tracker(false)


func _exit_tree() -> void:
	if not is_instance_valid(QuestManager):
		return

	if QuestManager.quest_started.is_connected(_on_quest_started):
		QuestManager.quest_started.disconnect(_on_quest_started)
	if QuestManager.quest_objective_updated.is_connected(_on_quest_objective_updated):
		QuestManager.quest_objective_updated.disconnect(_on_quest_objective_updated)
	if QuestManager.quest_completed.is_connected(_on_quest_completed):
		QuestManager.quest_completed.disconnect(_on_quest_completed)


func _connect_quest_signals() -> void:
	if not QuestManager.quest_started.is_connected(_on_quest_started):
		QuestManager.quest_started.connect(_on_quest_started)

	if not QuestManager.quest_objective_updated.is_connected(_on_quest_objective_updated):
		QuestManager.quest_objective_updated.connect(_on_quest_objective_updated)

	if not QuestManager.quest_completed.is_connected(_on_quest_completed):
		QuestManager.quest_completed.connect(_on_quest_completed)


func _on_quest_started(quest_id: String, _quest_data: QuestData) -> void:
	_presentation_token += 1
	_tracked_quest_id = quest_id
	_collapsed = false
	collapse_button.text = "◀"
	completion_overlay.visible = false

	_refresh_tracker()
	_show_tracker(true)


func _on_quest_objective_updated(
	quest_id: String,
	_step_index: int,
	_step: QuestStep
) -> void:
	if quest_id != _tracked_quest_id:
		return

	_refresh_tracker()


func _on_quest_completed(quest_id: String, _quest_data: QuestData) -> void:
	if quest_id != _tracked_quest_id:
		return

	_presentation_token += 1
	var token := _presentation_token

	_refresh_tracker()
	completion_label.text = "QUEST COMPLETE!"
	completion_overlay.visible = true

	await get_tree().create_timer(COMPLETION_DISPLAY_TIME).timeout

	if not is_inside_tree() or token != _presentation_token:
		return

	completion_overlay.visible = false

	var next_quest_id := _get_latest_active_quest()
	if not next_quest_id.is_empty():
		_tracked_quest_id = next_quest_id
		_refresh_tracker()
		_show_tracker(true)
	else:
		_tracked_quest_id = ""
		await _hide_tracker()


func _refresh_tracker() -> void:
	if _tracked_quest_id.is_empty():
		return

	var quest_data: QuestData = QuestManager.get_quest(_tracked_quest_id)
	if quest_data == null:
		return

	quest_title.text = _get_quest_title(_tracked_quest_id, quest_data)
	description_label.text = quest_data.description.strip_edges()
	description_label.visible = not description_label.text.is_empty()

	var is_completed: bool = QuestManager.is_quest_completed(_tracked_quest_id)
	status_label.text = "COMPLETED" if is_completed else "ACTIVE"
	status_label.modulate = (
		Color(0.72, 0.72, 0.68, 1.0)
		if is_completed
		else Color(0.42, 0.67, 0.49, 1.0)
	)

	_refresh_objective_rows(quest_data, is_completed)
	_refresh_rewards(quest_data)


func _refresh_objective_rows(quest_data: QuestData, quest_is_completed: bool) -> void:
	# Reuse existing rows. Quest objective updates can happen frequently for
	# counted objectives, so rebuilding every Control on each signal is wasteful.
	for step_index in range(quest_data.steps.size()):
		var step: QuestStep = quest_data.steps[step_index]
		if step == null:
			continue

		var row := _objective_rows.get(step_index) as HBoxContainer
		if row == null or not is_instance_valid(row):
			row = objective_template.duplicate() as HBoxContainer
			if row == null:
				continue
			row.name = "Objective_%d" % step_index
			row.visible = true
			objectives_container.add_child(row)
			_objective_rows[step_index] = row

		row.visible = true
		var state_label := row.get_node("StateLabel") as Label
		var objective_label := row.get_node("ObjectiveLabel") as Label
		var count_label := row.get_node("CountLabel") as Label

		var complete := quest_is_completed or QuestManager.is_objective_completed(
			_tracked_quest_id,
			step_index
		)
		var required_count: int = maxi(step.required_count, 1)
		var current_count: int = required_count if quest_is_completed else QuestManager.get_objective_count(
			_tracked_quest_id,
			step_index
		)

		state_label.text = "✓" if complete else "○"
		state_label.modulate = (
			Color(0.55, 0.82, 0.52, 1.0)
			if complete
			else Color(0.72, 0.73, 0.67, 1.0)
		)
		objective_label.text = _get_objective_text(step)
		objective_label.modulate = Color(0.72, 0.82, 0.70, 1.0) if complete else Color.WHITE
		count_label.text = "%d / %d" % [mini(current_count, required_count), required_count]
		count_label.modulate = Color(0.55, 0.82, 0.52, 1.0) if complete else Color(0.72, 0.73, 0.67, 1.0)

	# Hide rows left over from a longer quest instead of destroying them.
	for key in _objective_rows.keys():
		var cached_index := int(key)
		var cached_row := _objective_rows[key] as HBoxContainer
		if is_instance_valid(cached_row):
			cached_row.visible = cached_index < quest_data.steps.size()


func _refresh_rewards(quest_data: QuestData) -> void:
	var exp_amount: int = 0
	var gold_amount: int = 0

	if quest_data.rewards != null:
		exp_amount = maxi(quest_data.rewards.exp, 0)
		gold_amount = maxi(quest_data.rewards.gold, 0)

	exp_reward.text = "⭐ %d EXP" % exp_amount
	gold_reward.text = "🪙 %d GOLD" % gold_amount
	exp_reward.visible = exp_amount > 0
	gold_reward.visible = gold_amount > 0
	no_rewards.visible = exp_amount <= 0 and gold_amount <= 0


func _show_tracker(animate: bool) -> void:
	_kill_transition_tween()
	visible = true
	completion_overlay.visible = false
	collapse_button.visible = true

	if _collapsed:
		_collapsed = false
		collapse_button.text = "◀"

	if not animate:
		quest_panel.offset_left = _panel_left
		quest_panel.offset_right = _panel_right
		quest_panel.modulate.a = _panel_alpha
		return

	quest_panel.offset_left = _panel_left - 70.0
	quest_panel.offset_right = _panel_right - 70.0
	quest_panel.modulate.a = 0.0

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(quest_panel, "offset_left", _panel_left, POP_IN_DURATION)
	_transition_tween.tween_property(quest_panel, "offset_right", _panel_right, POP_IN_DURATION)
	_transition_tween.tween_property(quest_panel, "modulate:a", _panel_alpha, POP_IN_DURATION)


func _hide_tracker() -> void:
	_presentation_token += 1
	var token := _presentation_token
	_kill_transition_tween()

	if not visible:
		return

	completion_overlay.visible = false
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(quest_panel, "offset_left", _panel_left - PANEL_SLIDE_DISTANCE, HIDE_DURATION)
	_transition_tween.tween_property(quest_panel, "offset_right", _panel_right - PANEL_SLIDE_DISTANCE, HIDE_DURATION)
	_transition_tween.tween_property(quest_panel, "modulate:a", 0.0, HIDE_DURATION)

	await _transition_tween.finished

	if not is_inside_tree() or token != _presentation_token:
		return

	visible = false
	quest_panel.offset_left = _panel_left
	quest_panel.offset_right = _panel_right
	quest_panel.modulate.a = _panel_alpha


func _on_collapse_pressed() -> void:
	if not visible:
		return

	_kill_transition_tween()
	_collapsed = not _collapsed
	collapse_button.text = "▶" if _collapsed else "◀"

	var delta: float = -PANEL_SLIDE_DISTANCE if _collapsed else 0.0
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(quest_panel, "offset_left", _panel_left + delta, POP_IN_DURATION)
	_transition_tween.tween_property(quest_panel, "offset_right", _panel_right + delta, POP_IN_DURATION)


func _kill_transition_tween() -> void:
	if is_instance_valid(_transition_tween) and _transition_tween.is_running():
		_transition_tween.kill()
	_transition_tween = null


func _get_latest_active_quest() -> String:
	var latest_id: String = ""
	for quest_id in QuestManager.active_quests.keys():
		latest_id = str(quest_id)
	return latest_id


func _get_quest_title(quest_id: String, quest_data: QuestData) -> String:
	if not quest_data.title.is_empty():
		return quest_data.title
	return quest_id.replace("_", " ").capitalize()


func _get_objective_text(step: QuestStep) -> String:
	var target_text: String = _format_target(step.target)
	match step.type:
		"talk_npc":
			return "Talk to " + target_text
		"wait_time":
			return "Wait until " + target_text
		"reach_location":
			return "Go to " + target_text
		"solve_puzzle":
			return "Solve " + target_text
		"enemy_killed":
			return "Defeat " + target_text
		"interact_object":
			return "Interact with " + target_text
		"item_collected":
			return "Collect " + target_text
		_:
			return "Complete " + target_text


func _format_target(target: String) -> String:
	if target.is_empty():
		return "the objective"
	return target.replace("_", " ").capitalize()
