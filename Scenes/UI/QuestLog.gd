extends CanvasLayer

signal closed
signal quest_selected(quest_id: String)

# The tracking HUD is created from this menu and survives when the log closes.
const MULTI_TRACK_HUD = preload("res://Scenes/UI/QuestMultiTrackHUD.gd")
var _tracking_hud: QuestMultiTrackHUD
var _track_all_button: Button
var _clear_tracks_button: Button

@onready var close_button: Button = $Center/QuestPanel/Margin/MainVBox/HeaderRow/CloseButton
@onready var subtitle_label: Label = $Center/QuestPanel/Margin/MainVBox/HeaderRow/Subtitle

@onready var all_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/JournalFilters/FilterMargin/FilterVBox/AllButton
@onready var active_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/JournalFilters/FilterMargin/FilterVBox/ActiveButton
@onready var completed_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/JournalFilters/FilterMargin/FilterVBox/CompletedButton

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
@onready var detail_track_button: Button = $Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailTrackButton


# Explicit chronology; never use alphabetical order to guide story progression.
# Optional/legacy quests sit near the main quest where they belong.
const STORY_QUEST_ORDER = [
	"walk_to_apu",
	"pet_the_animal",
	"deliver_bebang_basket",
	"bebang_talk_to_rids",
	"visit_chief_after_basket",
	"talk_to_chief",
	"get_training_gear",
	"return_to_chief",
	"first_training_battle",
	"return_to_chief_after_training",
	"return_home_to_ima",
	"greet_ima",
	"go_to_chief_final_training",
	"talk_to_pacing",
	"visit_ale_pacing",
	"defeat_chief_final_training",
	"reach_forest",
	"get_mystic_ylang_ylang",
	"follow_litik_to_second_town"
]

# Main chapters are numbered consistently across All/Active/Completed filters.
# Some older resources are incorrectly labelled main, so use narrative IDs.
const MAIN_STORY_ORDER = [
	"walk_to_apu",
	"deliver_bebang_basket",
	"visit_chief_after_basket",
	"get_training_gear",
	"return_to_chief",
	"first_training_battle",
	"return_to_chief_after_training",
	"return_home_to_ima",
	"greet_ima",
	"go_to_chief_final_training",
	"visit_ale_pacing",
	"defeat_chief_final_training",
	"reach_forest",
	"get_mystic_ylang_ylang",
	"follow_litik_to_second_town"
]


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
	detail_track_button.pressed.connect(_on_detail_track_pressed)
	get_viewport().size_changed.connect(_fit_quest_panel)
	call_deferred("_fit_quest_panel")

	objective_template.visible = false
	quest_row_template.visible = false

	_connect_quest_signals()
	_ensure_multi_tracker()
	_build_tracking_actions()

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
	if is_instance_valid(_tracking_hud):
		var update_callback: Callable = Callable(self, "_on_tracking_changed")
		if _tracking_hud.tracking_changed.is_connected(update_callback):
			_tracking_hud.tracking_changed.disconnect(update_callback)


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
	# Always start the menu at the current objective, not the oldest quest.
	current_quest_id = ""
	_refresh()
	call_deferred("_focus_selected_quest")


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
# MULTI-QUEST TRACKING (DISPLAY ONLY)
# ============================================================

func _ensure_multi_tracker() -> void:
	# GameManager is an autoload and remains alive after QuestLog closes.
	# This avoids recreating the HUD every time the menu opens.
	_tracking_hud = GameManager.get_node_or_null("QuestMultiTrackHUD") as QuestMultiTrackHUD
	if not is_instance_valid(_tracking_hud):
		_tracking_hud = MULTI_TRACK_HUD.new() as QuestMultiTrackHUD
		_tracking_hud.name = "QuestMultiTrackHUD"
		GameManager.add_child(_tracking_hud)
	if not _tracking_hud.tracking_changed.is_connected(_on_tracking_changed):
		_tracking_hud.tracking_changed.connect(_on_tracking_changed)


func _build_tracking_actions() -> void:
	var scroll: ScrollContainer = quest_list.get_parent() as ScrollContainer
	if not is_instance_valid(scroll):
		return
	var sidebar: VBoxContainer = scroll.get_parent() as VBoxContainer
	if not is_instance_valid(sidebar):
		return

	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "TrackingActions"
	actions.add_theme_constant_override("separation", 6)
	sidebar.add_child(actions)
	sidebar.move_child(actions, scroll.get_index())

	_track_all_button = Button.new()
	_track_all_button.text = "TRACK ALL"
	_track_all_button.tooltip_text = "Track every currently active quest on the HUD"
	_track_all_button.custom_minimum_size.y = 30.0
	_track_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_all_button.add_theme_font_size_override("font_size", 11)
	_track_all_button.pressed.connect(_on_track_all_pressed)
	actions.add_child(_track_all_button)

	_clear_tracks_button = Button.new()
	_clear_tracks_button.text = "CLEAR"
	_clear_tracks_button.tooltip_text = "Untrack all quests; does not affect quest progress"
	_clear_tracks_button.custom_minimum_size.y = 30.0
	_clear_tracks_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_tracks_button.add_theme_font_size_override("font_size", 11)
	_clear_tracks_button.pressed.connect(_on_clear_tracks_pressed)
	actions.add_child(_clear_tracks_button)

	# Match tracking controls to the redesigned green quest list.
	for action: Button in [_track_all_button, _clear_tracks_button]:
		action.add_theme_color_override("font_color", Color(0.92, 0.94, 0.86))
		action.add_theme_font_size_override("font_size", 11)
		action.add_theme_stylebox_override("normal", all_button.get_theme_stylebox("normal"))
		action.add_theme_stylebox_override("hover", all_button.get_theme_stylebox("hover"))
		action.add_theme_stylebox_override("pressed", all_button.get_theme_stylebox("pressed"))
		action.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		action.add_theme_color_override("font_pressed_color", Color(1, 1, 1))


func _on_track_all_pressed() -> void:
	if is_instance_valid(_tracking_hud):
		_tracking_hud.track_all_active()


func _on_clear_tracks_pressed() -> void:
	if is_instance_valid(_tracking_hud):
		_tracking_hud.clear_tracked()


func _on_track_toggled(selected: bool, quest_id: String) -> void:
	if is_instance_valid(_tracking_hud):
		_tracking_hud.set_tracked(quest_id, selected)


func _on_tracking_changed() -> void:
	if is_inside_tree():
		call_deferred("_refresh")


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
		# All and Active: open the first active quest in story sequence.
		# Completed: show the earliest completed quest.
		var default_id: String = quest_ids[0]
		for quest_id in quest_ids:
			if QuestManager.is_quest_active(quest_id):
				default_id = quest_id
				break
		_show_quest(default_id)

	_update_selected_row_states()


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

	all_button.text = "All Quests  %d" % discovered_count
	active_button.text = "Active  %d" % active_count
	completed_button.text = "Completed  %d" % completed_count

	all_button.button_pressed = current_filter == QuestFilter.ALL
	active_button.button_pressed = current_filter == QuestFilter.ACTIVE
	completed_button.button_pressed = current_filter == QuestFilter.COMPLETED

	var tracked_count: int = _tracking_hud.get_tracked_count() if is_instance_valid(_tracking_hud) else 0
	if subtitle_label != null:
		subtitle_label.text = "%d discovered   ·   %d tracked" % [discovered_count, tracked_count]
	if is_instance_valid(_track_all_button):
		_track_all_button.disabled = active_count == 0
	if is_instance_valid(_clear_tracks_button):
		_clear_tracks_button.disabled = tracked_count == 0


func _sort_quest_ids(a: String, b: String) -> bool:
	# All, Active and Completed show the same chronological story order.
	var a_index: int = STORY_QUEST_ORDER.find(a)
	var b_index: int = STORY_QUEST_ORDER.find(b)

	if a_index >= 0 and b_index >= 0:
		return a_index < b_index
	if a_index >= 0:
		return true
	if b_index >= 0:
		return false

	# Future quests absent from this list remain visible, after known chapters.
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

		# Release its node name immediately; deferred freeing alone can leave
		# a stale row with the same name during rapid quest updates.
		quest_list.remove_child(child)
		child.queue_free()


func _add_quest_row(quest_id: String) -> void:
	var quest_data: QuestData = QuestManager.get_quest(quest_id)
	if quest_data == null:
		return

	# Two distinct actions: row title opens details, checkbox tracks it.
	# The HBox keeps them aligned without nesting a button inside a button.
	var wrapper: HBoxContainer = HBoxContainer.new()
	wrapper.name = "Row_" + quest_id
	wrapper.add_theme_constant_override("separation", 4)
	quest_list.add_child(wrapper)

	var row: Button = quest_row_template.duplicate() as Button
	if row == null:
		wrapper.queue_free()
		return
	row.visible = true
	row.name = "Quest_" + quest_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.toggle_mode = true
	row.text = _get_row_text(quest_id, quest_data)
	# Keep titles to one line and show a proper ellipsis instead of hard clipping.
	# Godot's Button supports the same TextServer overrun behavior as Label.
	row.clip_text = true
	row.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.tooltip_text = _get_title(quest_id, quest_data)
	row.button_pressed = quest_id == current_quest_id
	if QuestManager.is_quest_active(quest_id):
		row.add_theme_color_override("font_color", Color(0.82, 0.91, 0.77, 1.0))
	elif QuestManager.completed_quests.has(quest_id):
		row.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70, 1.0))
	wrapper.add_child(row)

	var open_details: Callable = func() -> void:
		current_quest_id = quest_id
		_show_quest(quest_id)
		_update_selected_row_states()
	row.pressed.connect(open_details)

	var track_toggle: CheckBox = CheckBox.new()
	track_toggle.name = "TrackToggle"
	track_toggle.custom_minimum_size = Vector2(30.0, 42.0)
	track_toggle.focus_mode = Control.FOCUS_ALL
	track_toggle.tooltip_text = "Track this active quest on the HUD" if QuestManager.is_quest_active(quest_id) else "Only active quests can be tracked"
	track_toggle.disabled = not QuestManager.is_quest_active(quest_id)
	track_toggle.visible = QuestManager.is_quest_active(quest_id)
	track_toggle.button_pressed = _tracking_hud.is_tracked(quest_id) if is_instance_valid(_tracking_hud) else false
	track_toggle.toggled.connect(_on_track_toggled.bind(quest_id))
	wrapper.add_child(track_toggle)


func _update_selected_row_states() -> void:
	for wrapper: Node in quest_list.get_children():
		if not wrapper is HBoxContainer:
			continue
		var detail_button: Button = wrapper.get_node_or_null("Quest_" + current_quest_id) as Button
		for child: Node in wrapper.get_children():
			if child is Button and child != wrapper.get_node_or_null("TrackToggle"):
				(child as Button).button_pressed = child == detail_button


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

	var chapter_index: int = MAIN_STORY_ORDER.find(quest_id)
	var chapter_prefix: String = ("%02d  " % (chapter_index + 1)) if chapter_index >= 0 else "    "
	return chapter_prefix + prefix + title


# Only focus when the player explicitly opens the log; avoid stealing focus
# on background quest updates while reading another entry.
func _focus_selected_quest() -> void:
	if not visible or current_quest_id.is_empty():
		return
	var row: Button = quest_list.get_node_or_null("Row_" + current_quest_id + "/Quest_" + current_quest_id) as Button
	if is_instance_valid(row):
		row.grab_focus()


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

	# Keep the visible chapter classification consistent with the story order.
	# Several older/legacy resources have incorrect is_main_quest metadata.
	var story_main: bool = MAIN_STORY_ORDER.has(quest_id)
	var future_main: bool = (not STORY_QUEST_ORDER.has(quest_id)) and quest_data.is_main_quest
	quest_type_label.text = "MAIN QUEST" if story_main or future_main else "OPTIONAL QUEST"

	if QuestManager.completed_quests.has(quest_id):
		quest_status_label.text = "COMPLETED"
		quest_status_label.modulate = Color(0.70, 0.83, 0.69, 1.0)
	elif QuestManager.is_quest_active(quest_id):
		quest_status_label.text = "ACTIVE"
		quest_status_label.modulate = Color(0.58, 0.95, 0.63, 1.0)
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

	_sync_detail_track_button()
	quest_selected.emit(quest_id)


func _show_empty_state() -> void:
	detail_track_button.hide()
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



# The details action is optional; multi-selection still works using row checkboxes.
func _sync_detail_track_button() -> void:
	if not is_instance_valid(detail_track_button):
		return
	var can_track: bool = (
		current_quest_id != ""
		and QuestManager.is_quest_active(current_quest_id)
	)
	detail_track_button.visible = can_track
	if not can_track:
		return
	var tracked: bool = is_instance_valid(_tracking_hud) and _tracking_hud.is_tracked(current_quest_id)
	detail_track_button.text = "✓ TRACKING" if tracked else "＋ TRACK QUEST"


func _on_detail_track_pressed() -> void:
	if not is_instance_valid(_tracking_hud):
		return
	if current_quest_id.is_empty() or not QuestManager.is_quest_active(current_quest_id):
		return
	_tracking_hud.set_tracked(current_quest_id, not _tracking_hud.is_tracked(current_quest_id))
	_sync_detail_track_button()


# Scale the full journal around its center for smaller desktop game windows.
# The authored reference size remains 1180x650 for full-resolution displays.
func _fit_quest_panel() -> void:
	if not is_inside_tree():
		return
	var panel: PanelContainer = $Center/QuestPanel
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var fit: float = minf(1.0, minf(
		(viewport_size.x - 26.0) / panel_size.x,
		(viewport_size.y - 26.0) / panel_size.y
	))
	panel.pivot_offset = panel_size * 0.5
	panel.scale = Vector2.ONE * maxf(0.2, fit)
