extends CanvasLayer

signal closed
signal quest_selected(quest_id: String)

@onready var close_button: Button = $Center/QuestPanel/Margin/MainVBox/SubHeaderRow/CloseButton
@onready var subtitle_label: Label = $Center/QuestPanel/Margin/MainVBox/SubHeaderRow/Subtitle

@onready var all_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/Sidebar/SidebarMargin/SidebarVBox/AllButton
@onready var active_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/Sidebar/SidebarMargin/SidebarVBox/ActiveButton
@onready var completed_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/Sidebar/SidebarMargin/SidebarVBox/CompletedButton

@onready var quest_list: VBoxContainer = $Center/QuestPanel/Margin/MainVBox/Body/Sidebar/SidebarMargin/SidebarVBox/QuestListScroll/QuestList
@onready var quest_row_template: Button = $Center/QuestPanel/Margin/MainVBox/Body/Sidebar/SidebarMargin/SidebarVBox/QuestListScroll/QuestList/QuestRowTemplate

@onready var quest_type_row: HBoxContainer = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/QuestTypeRow
@onready var quest_type_label: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/QuestTypeRow/QuestTypeLabel
@onready var quest_status_label: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/QuestTypeRow/QuestStatusLabel
@onready var quest_title: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/QuestTitle
@onready var quest_description: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/QuestDescription
@onready var objective_header: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/ObjectiveHeader
@onready var objectives_scroll: ScrollContainer = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/ObjectivesScroll
@onready var rewards_separator: HSeparator = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/Separator
@onready var rewards_header: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/RewardsHeader
@onready var rewards_row: HBoxContainer = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/RewardsRow

@onready var objectives_container: VBoxContainer = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/ObjectivesScroll/ObjectivesContainer
@onready var objective_template: PanelContainer = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/ObjectivesScroll/ObjectivesContainer/ObjectiveTemplate

@onready var exp_icon: TextureRect = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/RewardsRow/ExpIcon
@onready var rewards_label: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/RewardsRow/RewardsLabel
@onready var gold_icon: TextureRect = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/RewardsRow/GoldIcon
@onready var gold_label: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/RewardsRow/GoldLabel
@onready var empty_label: Label = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/EmptyLabel


enum QuestFilter {
	ALL,
	ACTIVE,
	COMPLETED
}

var current_filter: QuestFilter = QuestFilter.ALL
var current_quest_id: String = ""


func _ready() -> void:
	# This scene is intended to be opened as a menu.
	# It does not replace the existing small quest tracker.
	process_mode = Node.PROCESS_MODE_ALWAYS

	close_button.pressed.connect(close)
	all_button.pressed.connect(_set_filter_all)
	active_button.pressed.connect(_set_filter_active)
	completed_button.pressed.connect(_set_filter_completed)

	objective_template.visible = false
	quest_row_template.visible = false

	_connect_quest_signals()

	_refresh()


func _connect_quest_signals() -> void:
	if QuestManager == null:
		return

	if not QuestManager.quest_started.is_connected(_on_quest_changed):
		QuestManager.quest_started.connect(_on_quest_changed)

	if not QuestManager.quest_objective_updated.is_connected(_on_quest_changed):
		QuestManager.quest_objective_updated.connect(_on_quest_changed)

	if not QuestManager.quest_completed.is_connected(_on_quest_changed):
		QuestManager.quest_completed.connect(_on_quest_changed)

	if not QuestManager.dialogue_flag_changed.is_connected(_on_dialogue_flag_changed):
		QuestManager.dialogue_flag_changed.connect(_on_dialogue_flag_changed)


func _exit_tree() -> void:
	_disconnect_quest_signals()


func _disconnect_quest_signals() -> void:
	if QuestManager == null:
		return

	if QuestManager.quest_started.is_connected(_on_quest_changed):
		QuestManager.quest_started.disconnect(_on_quest_changed)
	if QuestManager.quest_objective_updated.is_connected(_on_quest_changed):
		QuestManager.quest_objective_updated.disconnect(_on_quest_changed)
	if QuestManager.quest_completed.is_connected(_on_quest_changed):
		QuestManager.quest_completed.disconnect(_on_quest_changed)
	if QuestManager.dialogue_flag_changed.is_connected(_on_dialogue_flag_changed):
		QuestManager.dialogue_flag_changed.disconnect(_on_dialogue_flag_changed)


func _on_quest_changed(_quest_id: String, _value_1 = null, _value_2 = null) -> void:
	call_deferred("_refresh")


func _on_dialogue_flag_changed(_flag_id: String) -> void:
	call_deferred("_refresh")


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ============================================================
# FILTER BUTTONS
# ============================================================

func _set_filter_all() -> void:
	current_filter = QuestFilter.ALL
	_refresh()


func _set_filter_active() -> void:
	current_filter = QuestFilter.ACTIVE
	_refresh()


func _set_filter_completed() -> void:
	current_filter = QuestFilter.COMPLETED
	_refresh()


# ============================================================
# MAIN REFRESH
# ============================================================

func _refresh() -> void:
	if QuestManager == null:
		return

	_update_filter_labels()
	_clear_quest_rows()

	var quest_ids: Array[String] = _get_filtered_quest_ids()

	if quest_ids.is_empty():
		current_quest_id = ""
		_show_empty_state()
		return

	for quest_id in quest_ids:
		_add_quest_row(quest_id)

	if not current_quest_id.is_empty() and quest_ids.has(current_quest_id):
		_show_quest(current_quest_id)
	else:
		_show_quest(quest_ids[0])


func _get_filtered_quest_ids() -> Array[String]:
	var result: Array[String] = []

	for quest_id_variant in QuestManager.quest_database.keys():
		var quest_id: String = str(quest_id_variant)

		# A quest is discovered only after the player starts it or completes it.
		# Resources in the database alone must not appear in the log.
		if not _is_quest_discovered(quest_id):
			continue

		match current_filter:
			QuestFilter.ACTIVE:
				if QuestManager.is_quest_active(quest_id):
					result.append(quest_id)

			QuestFilter.COMPLETED:
				if QuestManager.completed_quests.has(quest_id):
					result.append(quest_id)

			QuestFilter.ALL:
				result.append(quest_id)

	result.sort_custom(_sort_quest_ids)
	return result


func _is_quest_discovered(quest_id: String) -> bool:
	return QuestManager.is_quest_active(quest_id) or QuestManager.completed_quests.has(quest_id)


func _update_filter_labels() -> void:
	var discovered_count: int = 0
	var active_count: int = 0
	var completed_count: int = 0

	for quest_id_variant in QuestManager.quest_database.keys():
		var quest_id: String = str(quest_id_variant)
		if QuestManager.is_quest_active(quest_id):
			active_count += 1
			discovered_count += 1
		elif QuestManager.completed_quests.has(quest_id):
			completed_count += 1
			discovered_count += 1

	all_button.text = "ALL  ·  %d" % discovered_count
	active_button.text = "ACTIVE  ·  %d" % active_count
	completed_button.text = "COMPLETED  ·  %d" % completed_count

	all_button.button_pressed = current_filter == QuestFilter.ALL
	active_button.button_pressed = current_filter == QuestFilter.ACTIVE
	completed_button.button_pressed = current_filter == QuestFilter.COMPLETED

	if subtitle_label != null:
		subtitle_label.text = "%d discovered quest%s" % [discovered_count, "" if discovered_count == 1 else "s"]


func _sort_quest_ids(a: String, b: String) -> bool:
	var a_active: bool = QuestManager.is_quest_active(a)
	var b_active: bool = QuestManager.is_quest_active(b)

	if a_active != b_active:
		return a_active

	var a_completed: bool = QuestManager.completed_quests.has(a)
	var b_completed: bool = QuestManager.completed_quests.has(b)

	if a_completed != b_completed:
		return not a_completed

	var a_data: QuestData = QuestManager.get_quest(a)
	var b_data: QuestData = QuestManager.get_quest(b)

	if a_data != null and b_data != null:
		if a_data.is_main_quest != b_data.is_main_quest:
			return a_data.is_main_quest

	return a.nocasecmp_to(b) < 0


# ============================================================
# QUEST ROWS
# ============================================================

func _clear_quest_rows() -> void:
	for child in quest_list.get_children():
		if child == quest_row_template:
			continue

		child.queue_free()


func _add_quest_row(quest_id: String) -> void:
	var quest_data: QuestData = QuestManager.get_quest(quest_id)

	if quest_data == null:
		return

	var row: Button = quest_row_template.duplicate() as Button

	if row == null:
		return

	row.visible = true
	row.name = "Quest_" + quest_id
	row.toggle_mode = true
	row.text = _get_row_text(quest_id, quest_data)
	row.button_pressed = quest_id == current_quest_id

	if QuestManager.is_quest_active(quest_id):
		row.add_theme_color_override("font_color", Color(0.82, 0.91, 0.77, 1.0))
	elif QuestManager.completed_quests.has(quest_id):
		row.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70, 1.0))

	var callable := func() -> void:
		current_quest_id = quest_id
		_show_quest(quest_id)
		_update_selected_row_states()

	row.pressed.connect(callable)
	quest_list.add_child(row)

	if quest_id == current_quest_id:
		row.grab_focus()


func _update_selected_row_states() -> void:
	for child in quest_list.get_children():
		if child is Button and child != quest_row_template:
			child.button_pressed = child.name == "Quest_" + current_quest_id


func _get_row_text(quest_id: String, quest_data: QuestData) -> String:
	var prefix: String = ""

	if QuestManager.is_quest_active(quest_id):
		prefix = "● "
	elif QuestManager.completed_quests.has(quest_id):
		prefix = "✓ "
	else:
		prefix = "○ "

	var title: String = quest_data.title

	if title.is_empty():
		title = quest_id.replace("_", " ").capitalize()

	return prefix + title


# ============================================================
# QUEST DETAILS
# ============================================================

func _show_quest(quest_id: String) -> void:
	var quest_data: QuestData = QuestManager.get_quest(quest_id)

	if quest_data == null or not _is_quest_discovered(quest_id):
		_show_empty_state()
		return

	current_quest_id = quest_id
	empty_label.visible = false
	quest_type_row.show()
	quest_title.show()
	quest_description.show()
	objective_header.show()
	objectives_scroll.show()
	rewards_separator.show()
	rewards_header.show()
	rewards_row.show()

	quest_type_label.text = "MAIN QUEST" if quest_data.is_main_quest else "SIDE QUEST"

	if QuestManager.completed_quests.has(quest_id):
		quest_status_label.text = "COMPLETED"
		quest_status_label.modulate = Color(0.72, 0.72, 0.68, 1.0)
	elif QuestManager.is_quest_active(quest_id):
		quest_status_label.text = "ACTIVE"
		quest_status_label.modulate = Color(0.42, 0.67, 0.49, 1.0)
	else:
		# Defensive guard: the quest list should never allow an undiscovered quest here.
		_show_empty_state()
		return

	quest_title.text = _get_title(quest_id, quest_data)
	quest_description.text = quest_data.description

	if quest_description.text.is_empty():
		quest_description.text = "No description."

	_rebuild_objectives(quest_id, quest_data)
	_update_rewards(quest_data)

	quest_selected.emit(quest_id)


func _show_empty_state() -> void:
	quest_type_row.hide()
	quest_title.hide()
	quest_description.hide()
	objective_header.hide()
	objectives_scroll.hide()
	rewards_separator.hide()
	rewards_header.hide()
	rewards_row.hide()
	quest_title.text = ""
	quest_description.text = ""
	quest_type_label.text = ""
	quest_status_label.text = ""
	rewards_label.text = ""
	rewards_label.visible = false
	exp_icon.visible = false
	gold_icon.visible = false
	gold_label.visible = false
	_clear_objectives()

	match current_filter:
		QuestFilter.ACTIVE:
			empty_label.text = "No active quests yet.\n\nStart a quest by speaking with a character or progressing through the story."
		QuestFilter.COMPLETED:
			empty_label.text = "No completed quests yet.\n\nYour finished quests will be recorded here."
		_:
			empty_label.text = "No quests discovered yet.\n\nSpeak with characters and follow the story to discover quests."

	empty_label.visible = true


func _get_title(quest_id: String, quest_data: QuestData) -> String:
	if not quest_data.title.is_empty():
		return quest_data.title

	return quest_id.replace("_", " ").capitalize()


# ============================================================
# OBJECTIVES
# ============================================================

func _clear_objectives() -> void:
	for child in objectives_container.get_children():
		if child == objective_template:
			continue

		child.queue_free()


func _rebuild_objectives(quest_id: String, quest_data: QuestData) -> void:
	_clear_objectives()

	for step_index in range(quest_data.steps.size()):
		var step: QuestStep = quest_data.steps[step_index]

		if step == null:
			continue

		var row: PanelContainer = objective_template.duplicate() as PanelContainer

		if row == null:
			continue

		row.visible = true
		row.name = "Objective_%d" % step_index

		_update_objective_row(
			row,
			quest_id,
			step_index,
			step
		)

		objectives_container.add_child(row)


func _update_objective_row(
	row: PanelContainer,
	quest_id: String,
	step_index: int,
	step: QuestStep
) -> void:
	var state_label: Label = row.get_node(
		"Margin/Row/StateLabel"
	) as Label

	var objective_label: Label = row.get_node(
		"Margin/Row/ObjectiveLabel"
	) as Label

	var count_label: Label = row.get_node(
		"Margin/Row/CountLabel"
	) as Label

	var completed: bool = false
	var current_count: int = 0
	var required_count: int = max(step.required_count, 1)

	if QuestManager.completed_quests.has(quest_id):
		completed = true
		current_count = required_count
	elif QuestManager.is_quest_active(quest_id):
		completed = QuestManager.is_objective_completed(
			quest_id,
			step_index
		)

		current_count = QuestManager.get_objective_count(
			quest_id,
			step_index
		)

	if completed:
		state_label.text = "✓"
		state_label.modulate = Color(0.42, 0.67, 0.49, 1.0)
	else:
		state_label.text = "☐"
		state_label.modulate = Color(0.70, 0.70, 0.66, 1.0)

	objective_label.text = _get_objective_text(step)

	if step.required_count > 1 or QuestManager.is_quest_active(quest_id):
		count_label.text = "%d / %d" % [
			min(current_count, required_count),
			required_count
		]
	else:
		count_label.text = ""


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


# ============================================================
# REWARDS
# ============================================================

func _update_rewards(quest_data: QuestData) -> void:
	var has_exp: bool = false
	var has_gold: bool = false
	var exp_amount: int = 0
	var gold_amount: int = 0

	if quest_data.rewards != null:
		var rewards: QuestReward = quest_data.rewards
		exp_amount = rewards.exp
		gold_amount = rewards.gold
		has_exp = exp_amount > 0
		has_gold = gold_amount > 0

	exp_icon.visible = has_exp
	gold_icon.visible = has_gold
	gold_label.visible = has_gold
	rewards_label.visible = has_exp or (not has_exp and not has_gold)

	if has_exp:
		rewards_label.text = "+%d EXP" % exp_amount
	elif not has_gold:
		rewards_label.text = "No rewards"
	else:
		rewards_label.text = ""

	if has_gold:
		gold_label.text = "+%d GOLD" % gold_amount

