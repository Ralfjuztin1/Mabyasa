class_name QuestMultiTrackHUD
extends CanvasLayer

## Local, account-scoped selection for the quest journal.
## This is only a display preference; it never starts or completes quests.

signal tracking_changed

const PANEL_WIDTH: float = 330.0
const STORY_ORDER: Array[String] = [
	"walk_to_apu", "pet_the_animal", "deliver_bebang_basket",
	"bebang_talk_to_rids", "visit_chief_after_basket", "talk_to_chief",
	"get_training_gear", "return_to_chief", "first_training_battle",
	"return_to_chief_after_training", "return_home_to_ima", "greet_ima",
	"go_to_chief_final_training", "talk_to_pacing", "visit_ale_pacing",
	"defeat_chief_final_training", "reach_forest", "get_mystic_ylang_ylang",
	"follow_litik_to_second_town"
]
const MAX_VIEWPORT_FRACTION: float = 0.65
const COLOR_GOLD: Color = Color(0.91, 0.77, 0.42)
const COLOR_MUTED: Color = Color(0.70, 0.77, 0.67)
const COLOR_TEXT: Color = Color(0.93, 0.94, 0.85)

var tracked_ids: Array[String] = []
var _account_key: String = ""
var _last_visibility: bool = false
var _refresh_due: bool = true
var _last_active_signature: String = ""

var _root: Control
var _card: PanelContainer
var _header: Label
var _scroll: ScrollContainer
var _entries: VBoxContainer


func _ready() -> void:
	name = "QuestMultiTrackHUD"
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_sync_account(true)
	if is_instance_valid(QuestManager):
		QuestManager.quest_started.connect(_on_quest_event)
		QuestManager.quest_completed.connect(_on_quest_event)
		QuestManager.quest_objective_updated.connect(_on_objective_event)
	_refresh()


func _process(_delta: float) -> void:
	_sync_account()
	# QuestManager.load_save_data does not emit quest_started for restored quests.
	# Detect that change so saved tracking preferences reappear after login.
	var ids: Array = QuestManager.active_quests.keys()
	ids.sort()
	var active_signature: String = str(ids)
	if active_signature != _last_active_signature:
		_last_active_signature = active_signature
		_refresh_due = true
	var show_now: bool = (
		get_tracked_count() > 0
		and not get_tree().paused
		and is_instance_valid(GameManager)
		and GameManager.current_state == GameManager.GameState.EXPLORATION
	)
	if show_now != _last_visibility:
		_last_visibility = show_now
		_root.visible = show_now
	if _refresh_due:
		_refresh()


func is_tracked(quest_id: String) -> bool:
	_sync_account()
	return tracked_ids.has(quest_id) and QuestManager.is_quest_active(quest_id)


func set_tracked(quest_id: String, enabled: bool) -> void:
	_sync_account()
	if enabled and not QuestManager.is_quest_active(quest_id):
		return
	if enabled:
		if not tracked_ids.has(quest_id):
			tracked_ids.append(quest_id)
	else:
		tracked_ids.erase(quest_id)
	_finalize_selection()


func track_all_active() -> void:
	_sync_account()
	for quest_id_variant: Variant in QuestManager.active_quests.keys():
		var quest_id: String = str(quest_id_variant)
		if not tracked_ids.has(quest_id):
			tracked_ids.append(quest_id)
	_finalize_selection()


func clear_tracked() -> void:
	_sync_account()
	tracked_ids.clear()
	_finalize_selection()


func get_tracked_count() -> int:
	_sync_account()
	var count: int = 0
	for quest_id: String in tracked_ids:
		if QuestManager.is_quest_active(quest_id):
			count += 1
	return count


func _finalize_selection() -> void:
	_prune_inactive()
	_save_selection()
	_refresh_due = true
	tracking_changed.emit()


func _prune_inactive() -> bool:
	var changed: bool = false
	for i: int in range(tracked_ids.size() - 1, -1, -1):
		if not QuestManager.is_quest_active(tracked_ids[i]):
			tracked_ids.remove_at(i)
			changed = true
	return changed


func _on_quest_event(_id: String, _quest: QuestData) -> void:
	if _prune_inactive():
		_save_selection()
		tracking_changed.emit()
	_refresh_due = true


func _on_objective_event(_id: String, _index: int, _step: QuestStep) -> void:
	_refresh_due = true


func _get_account_key() -> String:
	if is_instance_valid(SupabaseManager):
		var user_id: String = str(SupabaseManager.current_user_id)
		if not user_id.is_empty():
			return user_id
	if is_instance_valid(GameManager):
		var email: String = str(GameManager.active_user_email)
		if not email.is_empty():
			return email
	return "__no_session__"


func _config_path() -> String:
	return "user://mabyasa_tracked_quests_%s.cfg" % _account_key.sha256_text().substr(0, 20)


func _sync_account(force: bool = false) -> void:
	var next_key: String = _get_account_key()
	if not force and next_key == _account_key:
		return
	_account_key = next_key
	tracked_ids.clear()
	if _account_key != "__no_session__":
		var config: ConfigFile = ConfigFile.new()
		if config.load(_config_path()) == OK:
			var saved: Variant = config.get_value("tracking", "quest_ids", [])
			if saved is Array:
				for entry: Variant in saved:
					var quest_id: String = str(entry)
					# Keep selected IDs during login; quest state may load later.
					if not tracked_ids.has(quest_id):
						tracked_ids.append(quest_id)
	_refresh_due = true
	tracking_changed.emit()


func _save_selection() -> void:
	if _account_key == "__no_session__":
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("tracking", "quest_ids", tracked_ids)
	var error: Error = config.save(_config_path())
	if error != OK:
		push_warning("[QUEST TRACKER] Could not save local tracking preference: %s" % error)


func _build() -> void:
	_root = Control.new()
	_root.name = "TrackerAnchors"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_card = PanelContainer.new()
	_card.name = "TrackedQuests"
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.offset_left = -PANEL_WIDTH - 16.0
	_card.offset_right = -16.0
	_card.offset_top = 18.0
	_card.offset_bottom = 90.0
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.065, 0.052, 0.91)
	style.border_color = Color(0.56, 0.49, 0.29, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_card.add_theme_stylebox_override("panel", style)
	_root.add_child(_card)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(stack)

	_header = Label.new()
	_header.name = "TrackHeading"
	_header.add_theme_color_override("font_color", COLOR_GOLD)
	_header.add_theme_font_size_override("font_size", 15)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_header)

	_scroll = ScrollContainer.new()
	_scroll.name = "TrackedQuestScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(_scroll)

	_entries = VBoxContainer.new()
	_entries.name = "TrackedQuestEntries"
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 9)
	_entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_entries)


func _refresh() -> void:
	_refresh_due = false
	if not is_instance_valid(_entries):
		return
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()

	if get_tracked_count() == 0:
		_root.visible = false
		_last_visibility = false
		return

	_header.text = "TRACKED QUESTS   %d" % get_tracked_count()
	var ordered: Array[String] = tracked_ids.duplicate()
	ordered.sort_custom(_sort_quest_ids)
	for quest_id: String in ordered:
		var quest: QuestData = QuestManager.get_quest(quest_id)
		if quest == null or not QuestManager.is_quest_active(quest_id):
			continue
		var item: VBoxContainer = VBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 2)
		_entries.add_child(item)

		var name_label: Label = Label.new()
		name_label.text = quest.title if not quest.title.is_empty() else quest_id.replace("_", " ").capitalize()
		name_label.add_theme_color_override("font_color", COLOR_TEXT)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(name_label)

		var objective_label: Label = Label.new()
		objective_label.text = _objective_summary(quest_id, quest)
		objective_label.add_theme_color_override("font_color", COLOR_MUTED)
		objective_label.add_theme_font_size_override("font_size", 11)
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(objective_label)

	var max_height: float = maxf(140.0, get_viewport().get_visible_rect().size.y * MAX_VIEWPORT_FRACTION)
	var allowed_scroll_height: float = maxf(90.0, max_height - 65.0)
	var desired_height: float = minf(_entries.get_combined_minimum_size().y, allowed_scroll_height)
	_scroll.custom_minimum_size.y = desired_height
	_card.offset_bottom = _card.offset_top + minf(max_height, desired_height + 65.0)


func _objective_summary(quest_id: String, quest: QuestData) -> String:
	for index: int in range(quest.steps.size()):
		if QuestManager.is_objective_completed(quest_id, index):
			continue
		var step: QuestStep = quest.steps[index]
		if step == null:
			continue
		var target: String = step.target.replace("_", " ").capitalize()
		match step.type:
			"talk_npc": return "Talk to " + target
			"reach_location": return "Go to " + target
			"enemy_killed": return "Defeat " + target
			"item_collected": return "Collect " + target
			"interact_object": return "Interact with " + target
			"solve_puzzle": return "Complete " + target
			"wait_time": return "Wait until " + target
			_: return "Complete " + target
	return "Objectives completed"


func _sort_quest_ids(a: String, b: String) -> bool:
	var a_index: int = STORY_ORDER.find(a)
	var b_index: int = STORY_ORDER.find(b)
	if a_index == -1 and b_index != -1:
		return false
	if b_index == -1 and a_index != -1:
		return true
	if a_index == -1:
		return a.nocasecmp_to(b) < 0
	return a_index < b_index
