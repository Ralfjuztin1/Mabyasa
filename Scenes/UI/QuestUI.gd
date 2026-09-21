extends Control


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var quest_panel: Control = $QuestPanel
@onready var content_margin: MarginContainer = $QuestPanel/ContentMargin
@onready var main_vbox: VBoxContainer = $QuestPanel/ContentMargin/MainVBox

@onready var quest_title: Label = $QuestPanel/ContentMargin/MainVBox/QuestTitle
@onready var description_label: Label = $QuestPanel/ContentMargin/MainVBox/DescriptionLabel

@onready var objectives_scroll: ScrollContainer = (
	$QuestPanel/ContentMargin/MainVBox/ObjectivesScroll
)

@onready var objectives_container: VBoxContainer = (
	$QuestPanel/ContentMargin/MainVBox/ObjectivesScroll/ObjectivesContainer
)

@onready var objective_template: HBoxContainer = (
	$QuestPanel/ContentMargin/MainVBox/ObjectivesScroll/ObjectivesContainer/ObjectiveTemplate
)

@onready var exp_reward: Label = (
	$QuestPanel/ContentMargin/MainVBox/RewardsContainer/ExpReward
)

@onready var gold_reward: Label = (
	$QuestPanel/ContentMargin/MainVBox/RewardsContainer/GoldReward
)

@onready var no_rewards: Label = (
	$QuestPanel/ContentMargin/MainVBox/RewardsContainer/NoRewards
)

@onready var status_label: Label = (
	$QuestPanel/ContentMargin/MainVBox/StatusLabel
)

@onready var completion_overlay: Panel = (
	$QuestPanel/CompletionOverlay
)

@onready var completion_label: Label = (
	$QuestPanel/CompletionOverlay/CompletionLabel
)

@onready var collapse_button: Button = $CollapseButton


# ============================================================
# LAYOUT
# ============================================================

@export_category("Layout")

@export_range(240.0, 600.0, 10.0)
var min_width: float = 320.0

@export_range(280.0, 700.0, 10.0)
var max_width: float = 420.0

@export_range(0.20, 0.45, 0.01)
var viewport_width_ratio: float = 0.30

@export_range(60.0, 400.0, 10.0)
var max_objectives_height: float = 180.0

@export_range(24.0, 80.0, 2.0)
var collapsed_reveal_width: float = 2.0

@export_range(0.0, 20.0, 1.0)
var arrow_gap: float = 4.0


# ============================================================
# ANIMATION
# ============================================================

@export_category("Animation")

@export_range(0.1, 1.0, 0.05)
var pop_duration: float = 0.35

@export_range(0.05, 0.5, 0.05)
var fade_duration: float = 0.22

@export_range(1.0, 15.0, 1.0)
var shake_amount: float = 5.0

@export_range(0.01, 0.1, 0.01)
var shake_step: float = 0.04

@export_range(0.5, 2.0, 0.05)
var completion_hold_time: float = 0.75

@export_range(0.15, 0.8, 0.05)
var collapse_duration: float = 0.30


# ============================================================
# RUNTIME
# ============================================================

var current_quest_id: String = ""

var quest_order: Array[String] = []

var panel_base_position: Vector2 = Vector2.ZERO

var panel_tween: Tween
var completion_tween: Tween
var collapse_tween: Tween

var completion_running: bool = false
var is_collapsed: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	objective_template.visible = false
	completion_overlay.visible = false

	panel_base_position = quest_panel.position

	collapse_button.visible = false
	collapse_button.mouse_filter = Control.MOUSE_FILTER_STOP
	collapse_button.focus_mode = Control.FOCUS_NONE
	collapse_button.pressed.connect(_toggle_collapsed)

	_connect_signals()

	call_deferred("_refresh")


# ============================================================
# SIGNALS
# ============================================================

func _connect_signals() -> void:
	if QuestManager == null:
		push_error("[QUEST UI] QuestManager not found.")
		return

	if not QuestManager.quest_started.is_connected(_on_quest_started):
		QuestManager.quest_started.connect(_on_quest_started)

	if not QuestManager.quest_objective_updated.is_connected(
		_on_objective_updated
	):
		QuestManager.quest_objective_updated.connect(
			_on_objective_updated
		)

	if not QuestManager.quest_validation_failed.is_connected(
		_on_validation_failed
	):
		QuestManager.quest_validation_failed.connect(
			_on_validation_failed
		)

	if not QuestManager.quest_completed.is_connected(_on_quest_completed):
		QuestManager.quest_completed.connect(_on_quest_completed)


# ============================================================
# QUEST STARTED
# ============================================================

func _on_quest_started(
	quest_id: String,
	_quest_data: QuestData
) -> void:
	_add_to_quest_order(quest_id)

	if completion_running:
		return

	if not current_quest_id.is_empty():
		if QuestManager.is_quest_active(current_quest_id):
			return

		current_quest_id = ""

	_refresh()


# ============================================================
# OBJECTIVE UPDATED
# ============================================================

func _on_objective_updated(
	quest_id: String,
	_step_index: int,
	_step: QuestStep
) -> void:
	if completion_running:
		return

	if not QuestManager.is_quest_active(quest_id):
		return

	_add_to_quest_order(quest_id)

	if quest_id != current_quest_id:
		return

	_refresh_current()
	_shake_panel()


# ============================================================
# VALIDATION FAILED
# ============================================================

func _on_validation_failed(
	quest_id: String,
	_quest_data: QuestData,
	_step: QuestStep
) -> void:
	if completion_running:
		return

	if not QuestManager.is_quest_active(quest_id):
		return

	if quest_id != current_quest_id:
		return

	_refresh_current()
	_shake_panel()


# ============================================================
# QUEST COMPLETED
# ============================================================

func _on_quest_completed(
	quest_id: String,
	quest_data: QuestData
) -> void:
	quest_order.erase(quest_id)

	if completion_running:
		return

	if quest_id != current_quest_id:
		return

	completion_running = true

	if panel_tween != null and panel_tween.is_valid():
		panel_tween.kill()

	if collapse_tween != null and collapse_tween.is_valid():
		collapse_tween.kill()

	visible = true
	collapse_button.visible = false
	is_collapsed = false
	quest_panel.position = panel_base_position

	_update_quest_text(quest_data)
	_update_rewards(quest_data)
	_build_completed_objectives(quest_data)
	_resize_panel()

	call_deferred("_play_completion_animation")


# ============================================================
# QUEST ORDER
# ============================================================

func _add_to_quest_order(quest_id: String) -> void:
	if quest_id.is_empty():
		return

	if not quest_order.has(quest_id):
		quest_order.append(quest_id)


func _sync_quest_order() -> void:
	if QuestManager == null:
		return

	var active_quests: Dictionary = QuestManager.active_quests

	for index: int in range(quest_order.size() - 1, -1, -1):
		if not active_quests.has(quest_order[index]):
			quest_order.remove_at(index)

	for quest_id in active_quests.keys():
		var id: String = str(quest_id)

		if not quest_order.has(id):
			quest_order.append(id)


func _get_next_quest_id() -> String:
	if QuestManager == null:
		return ""

	var active_quests: Dictionary = QuestManager.active_quests

	_sync_quest_order()

	for quest_id: String in quest_order:
		if active_quests.has(quest_id):
			return quest_id

	for quest_id in active_quests.keys():
		return str(quest_id)

	return ""


# ============================================================
# REFRESH
# ============================================================

func _refresh() -> void:
	if completion_running:
		return

	if QuestManager == null:
		return

	_sync_quest_order()

	var active_quests: Dictionary = QuestManager.active_quests

	if active_quests.is_empty():
		current_quest_id = ""
		visible = false
		collapse_button.visible = false
		is_collapsed = false
		return

	if (
		not current_quest_id.is_empty()
		and active_quests.has(current_quest_id)
	):
		_refresh_current()
		return

	var next_quest_id: String = _get_next_quest_id()

	if next_quest_id.is_empty():
		visible = false
		current_quest_id = ""
		return

	current_quest_id = next_quest_id
	_show_quest()


func _refresh_current() -> void:
	if current_quest_id.is_empty():
		_refresh()
		return

	if not QuestManager.is_quest_active(current_quest_id):
		current_quest_id = ""
		_refresh()
		return

	_show_quest()


func _show_quest() -> void:
	if current_quest_id.is_empty():
		return

	var quest_data: QuestData = QuestManager.get_quest(current_quest_id)

	if quest_data == null:
		visible = false
		collapse_button.visible = false
		return

	var was_hidden: bool = not visible

	visible = true
	collapse_button.visible = true

	_update_quest_text(quest_data)
	_rebuild_objectives(current_quest_id, quest_data)
	_update_rewards(quest_data)

	status_label.text = "ACTIVE"

	_resize_panel()

	if is_collapsed:
		quest_panel.position = _get_collapsed_position()
	else:
		quest_panel.position = panel_base_position

	_update_collapse_button_position()

	if was_hidden:
		call_deferred("_animate_pop_in")


# ============================================================
# QUEST TEXT
# ============================================================

func _update_quest_text(quest_data: QuestData) -> void:
	quest_title.text = quest_data.title

	description_label.visible = not quest_data.description.is_empty()
	description_label.text = quest_data.description


# ============================================================
# OBJECTIVES
# ============================================================

func _rebuild_objectives(
	quest_id: String,
	quest_data: QuestData
) -> void:
	for child: Node in objectives_container.get_children():
		if child != objective_template:
			child.free()

	for step_index: int in range(quest_data.steps.size()):
		var step: QuestStep = quest_data.steps[step_index]
		var row: HBoxContainer = objective_template.duplicate() as HBoxContainer

		if row == null:
			continue

		row.visible = true

		_update_objective_row(
			row,
			quest_id,
			step_index,
			step
		)

		objectives_container.add_child(row)


func _update_objective_row(
	row: HBoxContainer,
	quest_id: String,
	step_index: int,
	step: QuestStep
) -> void:
	var state_label: Label = row.get_node_or_null("StateLabel") as Label
	var objective_label: Label = row.get_node_or_null("ObjectiveLabel") as Label
	var count_label: Label = row.get_node_or_null("CountLabel") as Label

	var completed: bool = QuestManager.is_objective_completed(
		quest_id,
		step_index
	)

	var current_count: int = QuestManager.get_objective_count(
		quest_id,
		step_index
	)

	var required_count: int = max(
		QuestManager.get_objective_required_count(
			quest_id,
			step_index
		),
		1
	)

	if state_label != null:
		state_label.text = "✓" if completed else "☐"

	if objective_label != null:
		objective_label.text = _get_objective_text(step)

	if count_label != null:
		count_label.text = "%d / %d" % [
			current_count,
			required_count
		]


# ============================================================
# REWARDS
# ============================================================

func _update_rewards(quest_data: QuestData) -> void:
	var exp_value: int = 0
	var gold_value: int = 0

	if quest_data.rewards != null:
		exp_value = quest_data.rewards.exp
		gold_value = quest_data.rewards.gold

	exp_reward.visible = exp_value > 0
	gold_reward.visible = gold_value > 0
	no_rewards.visible = exp_value <= 0 and gold_value <= 0

	if exp_value > 0:
		exp_reward.text = "⭐ %d EXP" % exp_value

	if gold_value > 0:
		gold_reward.text = "🪙 %d GOLD" % gold_value


# ============================================================
# OBJECTIVE TEXT
# ============================================================

func _get_objective_text(step: QuestStep) -> String:
	match step.type:
		"talk_npc":
			return "Talk to " + _format_target(step.target)

		"wait_time":
			return "Wait until " + _format_target(step.target)

		"reach_location":
			return "Go to " + _format_target(step.target)

		"solve_puzzle":
			return "Solve " + _format_target(step.target)

		"enemy_killed":
			return "Defeat " + _format_target(step.target)

		"interact_object":
			return "Interact with " + _format_target(step.target)

		"item_collected":
			return "Collect " + _format_target(step.target)

		_:
			return "Complete the objective"


func _format_target(target: String) -> String:
	if target.is_empty():
		return "the target"

	return target.replace("_", " ").capitalize()


# ============================================================
# PANEL SIZE
# ============================================================

func _resize_panel() -> void:
	if not is_instance_valid(quest_panel):
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	var target_width: float = clampf(
		viewport_size.x * viewport_width_ratio,
		min_width,
		max_width
	)

	var objective_minimum: Vector2 = (
		objectives_container.get_combined_minimum_size()
	)

	var objective_height: float = clampf(
		objective_minimum.y,
		28.0,
		max_objectives_height
	)

	objectives_scroll.custom_minimum_size = Vector2(
		0.0,
		objective_height
	)

	quest_panel.size.x = target_width

	var content_size: Vector2 = main_vbox.get_combined_minimum_size()

	var margin_x: float = (
		content_margin.get_theme_constant("margin_left")
		+ content_margin.get_theme_constant("margin_right")
	)

	var margin_y: float = (
		content_margin.get_theme_constant("margin_top")
		+ content_margin.get_theme_constant("margin_bottom")
	)

	quest_panel.size = Vector2(
		max(target_width, content_size.x + margin_x),
		content_size.y + margin_y
	)

	_update_collapse_button_position()


# ============================================================
# POP-IN
# ============================================================

func _animate_pop_in() -> void:
	if completion_running or not visible:
		return

	if not is_instance_valid(quest_panel):
		return

	if is_collapsed:
		return

	if panel_tween != null and panel_tween.is_valid():
		panel_tween.kill()

	await get_tree().process_frame

	_resize_panel()

	quest_panel.position = panel_base_position
	_update_collapse_button_position()
	quest_panel.pivot_offset = quest_panel.size / 2.0
	quest_panel.scale = Vector2(0.8, 0.8)
	quest_panel.modulate.a = 0.0

	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	panel_tween.set_trans(Tween.TRANS_BACK)
	panel_tween.set_ease(Tween.EASE_OUT)

	panel_tween.tween_property(
		quest_panel,
		"scale",
		Vector2.ONE,
		pop_duration
	)

	panel_tween.tween_property(
		quest_panel,
		"modulate:a",
		1.0,
		fade_duration
	)


# ============================================================
# COLLAPSE / EXPAND
# ============================================================

func _toggle_collapsed() -> void:
	if completion_running:
		return

	if not visible:
		return

	is_collapsed = not is_collapsed

	if collapse_tween != null and collapse_tween.is_valid():
		collapse_tween.kill()

	var target_position: Vector2

	if is_collapsed:
		target_position = _get_collapsed_position()
		collapse_button.text = "▶"
	else:
		target_position = panel_base_position
		collapse_button.text = "◀"

	var arrow_target_position := _get_arrow_position(is_collapsed)

	collapse_tween = create_tween()
	collapse_tween.set_parallel(true)
	collapse_tween.set_trans(Tween.TRANS_CUBIC)
	collapse_tween.set_ease(Tween.EASE_IN_OUT)

	collapse_tween.tween_property(
		quest_panel,
		"position",
		target_position,
		collapse_duration
	)

	collapse_tween.tween_property(
		collapse_button,
		"position",
		arrow_target_position,
		collapse_duration
	)

	collapse_button.scale = Vector2(0.9, 0.9)

	collapse_tween.tween_property(
		collapse_button,
		"scale",
		Vector2.ONE,
		collapse_duration
	)


func _get_collapsed_position() -> Vector2:
	return Vector2(
		-quest_panel.size.x + collapsed_reveal_width,
		panel_base_position.y
	)


func _get_arrow_position(collapsed: bool) -> Vector2:
	var x: float

	if collapsed:
		x = 4.0
	else:
		x = (
			panel_base_position.x
			+ quest_panel.size.x
			+ arrow_gap
		)

	var y: float = (
		panel_base_position.y
		+ (quest_panel.size.y - collapse_button.size.y) / 2.0
	)

	return Vector2(x, y)


func _update_collapse_button_position() -> void:
	if not is_instance_valid(collapse_button):
		return

	collapse_button.text = "▶" if is_collapsed else "◀"
	collapse_button.position = _get_arrow_position(is_collapsed)


# ============================================================
# SHAKE
# ============================================================

func _shake_panel() -> void:
	if completion_running or not visible:
		return

	if not is_instance_valid(quest_panel):
		return

	if panel_tween != null and panel_tween.is_valid():
		panel_tween.kill()

	var base_position: Vector2 = (
		_get_collapsed_position()
		if is_collapsed
		else panel_base_position
	)

	quest_panel.position = base_position

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)

	for index: int in range(4):
		var offset: float = (
			shake_amount
			if index % 2 == 0
			else -shake_amount
		)

		tween.tween_property(
			quest_panel,
			"position:x",
			base_position.x + offset,
			shake_step
		)

	tween.tween_property(
		quest_panel,
		"position:x",
		base_position.x,
		shake_step
	)

	panel_tween = tween


# ============================================================
# COMPLETED OBJECTIVES
# ============================================================

func _build_completed_objectives(quest_data: QuestData) -> void:
	for child: Node in objectives_container.get_children():
		if child != objective_template:
			child.free()

	for step: QuestStep in quest_data.steps:
		var row: HBoxContainer = objective_template.duplicate() as HBoxContainer

		if row == null:
			continue

		row.visible = true

		var state_label: Label = row.get_node_or_null("StateLabel") as Label
		var objective_label: Label = row.get_node_or_null("ObjectiveLabel") as Label
		var count_label: Label = row.get_node_or_null("CountLabel") as Label

		var required: int = max(step.required_count, 1)

		if state_label != null:
			state_label.text = "✓"

		if objective_label != null:
			objective_label.text = _get_objective_text(step)

		if count_label != null:
			count_label.text = "%d / %d" % [
				required,
				required
			]

		objectives_container.add_child(row)


# ============================================================
# COMPLETION ANIMATION
# ============================================================

func _play_completion_animation() -> void:
	if not completion_running:
		return

	if not is_instance_valid(quest_panel):
		_finish_completion()
		return

	if not is_instance_valid(completion_overlay):
		_finish_completion()
		return

	if not is_instance_valid(completion_label):
		_finish_completion()
		return

	await get_tree().process_frame

	quest_panel.pivot_offset = quest_panel.size / 2.0
	completion_label.pivot_offset = completion_label.size / 2.0

	completion_overlay.visible = true
	completion_overlay.modulate.a = 0.0
	completion_label.modulate.a = 0.0
	completion_label.scale = Vector2(0.7, 0.7)

	quest_panel.scale = Vector2(0.9, 0.9)
	quest_panel.modulate.a = 0.85

	completion_tween = create_tween()
	completion_tween.set_parallel(true)
	completion_tween.set_trans(Tween.TRANS_BACK)
	completion_tween.set_ease(Tween.EASE_OUT)

	completion_tween.tween_property(
		quest_panel,
		"scale",
		Vector2.ONE,
		0.25
	)

	completion_tween.tween_property(
		quest_panel,
		"modulate:a",
		1.0,
		0.18
	)

	completion_tween.tween_property(
		completion_overlay,
		"modulate:a",
		1.0,
		0.10
	)

	completion_tween.tween_property(
		completion_label,
		"modulate:a",
		1.0,
		0.14
	)

	completion_tween.tween_property(
		completion_label,
		"scale",
		Vector2.ONE,
		0.22
	)

	await completion_tween.finished

	await _completion_shake()

	await get_tree().create_timer(
		completion_hold_time
	).timeout

	completion_tween = create_tween()
	completion_tween.set_parallel(true)

	completion_tween.tween_property(
		completion_overlay,
		"modulate:a",
		0.0,
		0.30
	)

	completion_tween.tween_property(
		completion_label,
		"modulate:a",
		0.0,
		0.30
	)

	completion_tween.tween_property(
		quest_panel,
		"modulate:a",
		0.0,
		0.35
	)

	completion_tween.tween_property(
		quest_panel,
		"scale",
		Vector2(0.94, 0.94),
		0.35
	)

	await completion_tween.finished

	_finish_completion()


func _completion_shake() -> void:
	var original_x: float = panel_base_position.x

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)

	tween.tween_property(
		quest_panel,
		"position:x",
		original_x + 5.0,
		0.035
	)

	tween.tween_property(
		quest_panel,
		"position:x",
		original_x - 5.0,
		0.035
	)

	tween.tween_property(
		quest_panel,
		"position:x",
		original_x + 3.0,
		0.035
	)

	tween.tween_property(
		quest_panel,
		"position:x",
		original_x - 3.0,
		0.035
	)

	tween.tween_property(
		quest_panel,
		"position:x",
		original_x,
		0.035
	)

	await tween.finished


# ============================================================
# FINISH COMPLETION
# ============================================================

func _finish_completion() -> void:
	completion_overlay.visible = false
	collapse_button.visible = false
	is_collapsed = false

	quest_panel.scale = Vector2.ONE
	quest_panel.modulate.a = 1.0
	quest_panel.position = panel_base_position

	completion_label.scale = Vector2.ONE
	completion_label.modulate.a = 0.0
	completion_overlay.modulate.a = 0.0

	completion_running = false
	current_quest_id = ""

	_sync_quest_order()

	if QuestManager != null and not QuestManager.active_quests.is_empty():
		visible = false
		collapse_button.visible = false
		_refresh()
	else:
		visible = false
		collapse_button.visible = false
