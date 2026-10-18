extends Node3D

## World-space breadcrumb arrows for the currently tracked quest objective.
## Add this node as a direct child of Scenes/SceneManager/Main.tscn.
## Destination nodes are resolved from QuestStep.target using node names or
## common ID properties such as npc_id, enemy_id, location_id and object_id.

@export_category("Quest Waypoint")
@export_range(3.0, 5.0, 0.5) var intro_show_seconds: float = 5.0
@export_range(1.0, 4.0, 0.25) var arrow_spacing: float = 2.1
@export_range(2, 16, 1) var max_arrow_count: int = 12
@export_range(0.1, 1.0, 0.05) var arrow_ground_offset: float = 0.42
@export var arrow_color: Color = Color(1.0, 0.72, 0.22, 1.0)

const HINT_NODE_NAME: String = "QuestTrackHint"
const ROUTE_REFRESH_INTERVAL: float = 0.16
const TARGET_RETRY_INTERVAL: float = 0.75

signal tracked_quest_changed(quest_id: String)

var _player: Node3D = null
var _target: Node3D = null
var _tracked_quest_id: String = ""
var _target_id: String = ""
var _target_type: String = ""

var _arrow_nodes: Array[Node3D] = []
var _arrow_material: StandardMaterial3D
var _hint_label: Label = null

var _route_visible: bool = false
var _user_selected_quest: bool = false
var _auto_hide_remaining: float = 0.0
var _quest_log: Node = null
var _track_button: Button = null
var _route_refresh_elapsed: float = 0.0
var _target_retry_elapsed: float = 0.0


func _ready() -> void:
	name = "QuestWaypointController"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("quest_tracking_controller")

	_arrow_material = _make_arrow_material()
	_create_arrow_pool()
	_player = _find_player()
	_connect_quest_signals()
	_ensure_hint_label()

	var main_node := _find_main_node()
	if is_instance_valid(main_node) and main_node.has_signal("loading_completed"):
		var loaded_signal: Signal = Signal(main_node, "loading_completed")
		if not loaded_signal.is_connected(_on_level_loaded):
			loaded_signal.connect(_on_level_loaded)

	call_deferred("_refresh_for_current_quest", true)


func _exit_tree() -> void:
	if is_instance_valid(QuestManager):
		_disconnect_signal_if_connected(
			QuestManager.quest_started,
			_on_quest_started
		)
		_disconnect_signal_if_connected(
			QuestManager.quest_objective_updated,
			_on_objective_updated
		)
		_disconnect_signal_if_connected(
			QuestManager.quest_completed,
			_on_quest_completed
		)


func _process(delta: float) -> void:
	_ensure_hint_label()
	_ensure_quest_log_track_button()

	# Hide arrows during dialogue, cutscenes, combat, and pause.
	# The automatic-hide timer pauses while the waypoint is suppressed.
	var waypoint_suppressed := _is_waypoint_suppressed()

	if waypoint_suppressed:
		if _route_visible:
			_set_route_visible(false)
	else:
		if _auto_hide_remaining > 0.0:
			_auto_hide_remaining = maxf(
				_auto_hide_remaining - delta,
				0.0
			)

			if _auto_hide_remaining <= 0.0:
				_set_route_visible(false)

			elif (
				not _route_visible
				and is_instance_valid(_target)
				and is_instance_valid(_player)
			):
				_set_route_visible(true)

	_route_refresh_elapsed += delta
	if _route_refresh_elapsed < ROUTE_REFRESH_INTERVAL:
		return

	_route_refresh_elapsed = 0.0

	if not is_instance_valid(_player):
		_player = _find_player()

	if _route_visible:
		if not is_instance_valid(_target):
			_refresh_for_current_quest(false)
		else:
			_update_arrow_positions()

	elif not _target_id.is_empty() and not is_instance_valid(_target):
		_target_retry_elapsed += ROUTE_REFRESH_INTERVAL

		if _target_retry_elapsed >= TARGET_RETRY_INTERVAL:
			_target_retry_elapsed = 0.0
			_target = _find_target_node(_target_id, _target_type)

			if is_instance_valid(_target):
				_update_hint_label()

				if _auto_hide_remaining > 0.0:
					_set_route_visible(true)

	_update_hint_label()
	_update_quest_log_track_button()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_V:
		return

	if not is_instance_valid(GameManager):
		return

	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	if get_tree().paused:
		return

	if _is_waypoint_suppressed():
		return

	if not is_instance_valid(_target):
		_refresh_for_current_quest(false)

	if not is_instance_valid(_target):
		return

	# V is a timed reveal, never a toggle.
	# Every press starts a fresh visibility window.
	_show_temporarily()
	_update_hint_label()
	get_viewport().set_input_as_handled()


# ============================================================
# QUEST SIGNALS
# ============================================================

func _connect_quest_signals() -> void:
	if not is_instance_valid(QuestManager):
		return

	_connect_signal_if_needed(
		QuestManager.quest_started,
		_on_quest_started
	)
	_connect_signal_if_needed(
		QuestManager.quest_objective_updated,
		_on_objective_updated
	)
	_connect_signal_if_needed(
		QuestManager.quest_completed,
		_on_quest_completed
	)


func _connect_signal_if_needed(signal_ref: Signal, callback: Callable) -> void:
	if not signal_ref.is_connected(callback):
		signal_ref.connect(callback)


func _disconnect_signal_if_connected(
	signal_ref: Signal,
	callback: Callable
) -> void:
	if signal_ref.is_connected(callback):
		signal_ref.disconnect(callback)


func _on_quest_started(
	quest_id: String,
	_quest_data: QuestData
) -> void:
	var previous_id := _tracked_quest_id

	# Preserve the existing quest-selection behavior.
	# Prefer the main quest and otherwise retain the current active selection.
	if not _user_selected_quest:
		_tracked_quest_id = _get_default_active_quest_id()

		if (
			_tracked_quest_id.is_empty()
			and QuestManager.is_quest_active(quest_id)
		):
			_tracked_quest_id = quest_id

	if previous_id != _tracked_quest_id:
		tracked_quest_changed.emit(_tracked_quest_id)

	# FIX: Start the waypoint display timer when a quest becomes active.
	# Previously, quest_started updated tracking but never started this timer.
	if (
		is_instance_valid(QuestManager)
		and QuestManager.is_quest_active(quest_id)
	):
		_auto_hide_remaining = maxf(
			intro_show_seconds,
			0.1
		)

	# Resolve the current tracked quest's destination immediately after
	# the quest-start signal has finished processing.
	call_deferred("_refresh_for_current_quest", false)


func _on_objective_updated(
	quest_id: String,
	_step_index: int,
	_step: QuestStep
) -> void:
	if quest_id == _tracked_quest_id:
		call_deferred("_refresh_for_current_quest", false)
		return

	# HUD.gd also reacts to every objective event and may pick its default quest.
	# Re-apply the explicit selection after that callback so the HUD always stays
	# synchronized with the Quest Log selection, even when another quest updates.
	call_deferred("_sync_hud_tracker")
	call_deferred("_update_quest_log_track_button")

	# Recover if the previously tracked quest is no longer active.
	if not _user_selected_quest and (
		_tracked_quest_id.is_empty()
		or not QuestManager.is_quest_active(_tracked_quest_id)
	):
		call_deferred("_refresh_for_current_quest", false)


func _on_quest_completed(
	quest_id: String,
	_quest_data: QuestData
) -> void:
	if quest_id != _tracked_quest_id:
		# Completing an unrelated quest must not change tracking, and must not
		# leave HUD.gd's fallback selection displayed instead of the chosen one.
		call_deferred("_sync_hud_tracker")
		call_deferred("_update_quest_log_track_button")
		return

	var previous_id := _tracked_quest_id
	_user_selected_quest = false
	_tracked_quest_id = _get_default_active_quest_id()

	if previous_id != _tracked_quest_id:
		tracked_quest_changed.emit(_tracked_quest_id)

	call_deferred("_refresh_for_current_quest", false)


func _on_level_loaded() -> void:
	_player = _find_player()
	call_deferred("_refresh_for_current_quest", false)


func get_tracked_quest_id() -> String:
	return _tracked_quest_id


func set_tracked_quest(quest_id: String) -> void:
	# Public entry point used by the Quest Log's Track Quest button.
	if (
		not is_instance_valid(QuestManager)
		or not QuestManager.is_quest_active(quest_id)
	):
		return

	var previous_id := _tracked_quest_id
	_tracked_quest_id = quest_id
	_user_selected_quest = true

	if previous_id != _tracked_quest_id:
		tracked_quest_changed.emit(_tracked_quest_id)

	call_deferred("_refresh_for_current_quest", false)

	# Clicking Track also gives a timed route preview.
	# It does not make the arrows stay visible permanently.
	_show_temporarily()
	_sync_hud_tracker()
	_update_quest_log_track_button()


# ============================================================
# CHOOSE AND RESOLVE DESTINATION
# ============================================================

func _refresh_for_current_quest(_show_intro: bool = false) -> void:
	if not is_instance_valid(QuestManager):
		_clear_target()
		_sync_hud_tracker()
		return

	if (
		_tracked_quest_id.is_empty()
		or not QuestManager.is_quest_active(_tracked_quest_id)
	):
		if _user_selected_quest:
			_user_selected_quest = false

		var previous_id := _tracked_quest_id
		_tracked_quest_id = _get_default_active_quest_id()

		if previous_id != _tracked_quest_id:
			tracked_quest_changed.emit(_tracked_quest_id)

	if _tracked_quest_id.is_empty():
		_clear_target()
		_sync_hud_tracker()
		_update_quest_log_track_button()
		return

	var quest_data: QuestData = QuestManager.get_quest(_tracked_quest_id)
	if quest_data == null:
		_clear_target()
		_sync_hud_tracker()
		return

	var step_index: int = QuestManager.get_current_step(_tracked_quest_id)
	if step_index < 0 or step_index >= quest_data.steps.size():
		_clear_target()
		_sync_hud_tracker()
		_update_quest_log_track_button()
		return

	var step: QuestStep = quest_data.steps[step_index]
	# World waypoint arrows only support NPC objectives.
	if step.type != "talk_npc":
		_clear_target()
		_sync_hud_tracker()
		_update_quest_log_track_button()
		return
	_target_id = step.target.strip_edges()
	_target_type = step.type
	_player = _find_player()
	_target = _find_target_node(_target_id, _target_type)
	_target_retry_elapsed = 0.0

	if not is_instance_valid(_target):
		_set_route_visible(false)
		_update_hint_label()
		_sync_hud_tracker()
		_update_quest_log_track_button()
		return

	# An objective update changes the destination, not the visibility timer.
	# Routes remain visible only during the temporary reveal window.
	_set_route_visible(_auto_hide_remaining > 0.0)
	_update_arrow_positions()
	_update_hint_label()
	_sync_hud_tracker()
	_update_quest_log_track_button()


func _get_default_active_quest_id() -> String:
	if not is_instance_valid(QuestManager):
		return ""

	# Prefer an active main quest if one exists.
	for raw_id in QuestManager.active_quests.keys():
		var quest_id: String = str(raw_id)
		var data: QuestData = QuestManager.get_quest(quest_id)

		if data != null and data.is_main_quest:
			return quest_id

	# With no main quest active, retain the previous valid selection instead
	# of switching every time a side quest starts.
	if (
		not _tracked_quest_id.is_empty()
		and QuestManager.is_quest_active(_tracked_quest_id)
	):
		return _tracked_quest_id

	if not QuestManager.active_quests.is_empty():
		return str(QuestManager.active_quests.keys()[0])

	return ""


func _find_target_node(
	target_id: String,
	target_type: String
) -> Node3D:
	if target_id.strip_edges().is_empty():
		return null

	var main_node := _find_main_node()
	if not is_instance_valid(main_node):
		return null

	var level_root := main_node.get_node_or_null("LevelContainer")
	if level_root == null:
		return null

	var target_key := _normalize_id(target_id)
	var id_properties: PackedStringArray = (
		_get_id_properties_for_type(target_type)
	)

	var nodes: Array[Node] = []
	var stack: Array[Node] = [level_root]

	while not stack.is_empty():
		var current: Node = stack.pop_back()
		nodes.append(current)

		for child in current.get_children():
			stack.append(child)

	# Prefer explicit identifiers over node names.
	for candidate in nodes:
		if not candidate is Node3D:
			continue

		if candidate == self or candidate.is_ancestor_of(self):
			continue

		for property_name in id_properties:
			var property_value := _get_string_property(
				candidate,
				property_name
			)

			if (
				not property_value.is_empty()
				and _normalize_id(property_value) == target_key
			):
				return candidate as Node3D

	# Then allow a destination to be identified by its node name.
	for candidate in nodes:
		if not candidate is Node3D:
			continue

		if candidate == self or candidate.is_ancestor_of(self):
			continue

		if _normalize_id(str(candidate.name)) == target_key:
			return candidate as Node3D

	return null


func _get_id_properties_for_type(
	target_type: String
) -> PackedStringArray:
	match target_type:
		"talk_npc":
			return PackedStringArray([
				"npc_id",
				"quest_target_id",
				"target_id"
			])

		"enemy_killed":
			return PackedStringArray([
				"enemy_id",
				"quest_target_id",
				"target_id"
			])

		"reach_location":
			return PackedStringArray([
				"location_id",
				"quest_target_id",
				"target_id"
			])

		"item_collected":
			return PackedStringArray([
				"item_id",
				"quest_target_id",
				"target_id"
			])

		"interact_object":
			return PackedStringArray([
				"object_id",
				"interactable_id",
				"quest_target_id",
				"target_id"
			])

		"solve_puzzle":
			return PackedStringArray([
				"puzzle_id",
				"quest_target_id",
				"target_id"
			])

		_:
			return PackedStringArray([
				"quest_target_id",
				"target_id",
				"npc_id",
				"enemy_id",
				"location_id",
				"object_id",
				"interactable_id",
				"item_id",
				"puzzle_id"
			])


func _get_string_property(
	object: Object,
	property_name: String
) -> String:
	for property_info in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			var value: Variant = object.get(property_name)

			if value is String or value is StringName:
				return str(value)

	return ""


func _normalize_id(value: String) -> String:
	return (
		value.strip_edges()
		.to_lower()
		.replace(" ", "_")
		.replace("-", "_")
	)


func _find_player() -> Node3D:
	var player_node := get_tree().get_first_node_in_group("player")

	if player_node is Node3D:
		return player_node as Node3D

	var main_node := _find_main_node()

	if is_instance_valid(main_node):
		var direct_player := main_node.get_node_or_null("Player")

		if direct_player is Node3D:
			return direct_player as Node3D

	return null


func _find_main_node() -> Node:
	var current: Node = self

	while is_instance_valid(current):
		if current.has_signal("loading_completed"):
			return current

		current = current.get_parent()

	return null


func _find_hud() -> Control:
	var hud_node := get_tree().get_first_node_in_group("game_hud")

	if hud_node is Control:
		return hud_node as Control

	return null


# ============================================================
# ARROW CREATION AND VISIBILITY
# ============================================================

func _make_arrow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = arrow_color
	material.emission_enabled = true
	material.emission = arrow_color
	material.emission_energy_multiplier = 0.55

	return material


func _create_arrow_pool() -> void:
	_arrow_nodes.clear()

	for index in range(max_arrow_count):
		var arrow := Node3D.new()
		arrow.name = "WaypointArrow_%02d" % (index + 1)
		add_child(arrow)

		var shaft_mesh := BoxMesh.new()
		shaft_mesh.size = Vector3(0.22, 0.11, 0.82)

		var shaft := MeshInstance3D.new()
		shaft.name = "ArrowShaft"
		shaft.mesh = shaft_mesh
		shaft.material_override = _arrow_material
		shaft.position = Vector3(0.0, 0.05, -0.30)
		arrow.add_child(shaft)

		var head_mesh := CylinderMesh.new()
		head_mesh.top_radius = 0.0
		head_mesh.bottom_radius = 0.34
		head_mesh.height = 0.58
		head_mesh.radial_segments = 4

		var head := MeshInstance3D.new()
		head.name = "ArrowHead"
		head.mesh = head_mesh
		head.material_override = _arrow_material
		head.rotation.x = -PI / 2.0
		head.position = Vector3(0.0, 0.065, -0.68)
		arrow.add_child(head)

		_set_arrow_visual_visible(arrow, false)
		_arrow_nodes.append(arrow)


func _show_temporarily() -> void:
	_auto_hide_remaining = maxf(intro_show_seconds, 0.1)

	if not is_instance_valid(_target):
		_refresh_for_current_quest(false)

	if is_instance_valid(_target):
		_set_route_visible(true)
	else:
		_set_route_visible(false)


func _set_route_visible(should_show: bool) -> void:
	# FIX: Visibility is blocked while dialogue, cutscenes, or other
	# non-exploration states are active.
	_route_visible = (
		should_show
		and not _is_waypoint_suppressed()
		and is_instance_valid(_target)
		and is_instance_valid(_player)
	)

	for arrow in _arrow_nodes:
		_set_arrow_visual_visible(arrow, false)

	if _route_visible:
		_update_arrow_positions()

	_update_hint_label()


func _is_waypoint_suppressed() -> bool:
	if get_tree().paused:
		return true

	if is_instance_valid(GameManager):
		if (
			GameManager.current_state
			!= GameManager.GameState.EXPLORATION
		):
			return true

	# DialogueManager tracks dialogue separately from GameManager's state.
	if (
		is_instance_valid(DialogueManager)
		and DialogueManager.is_dialogue_active
	):
		return true

	# Cutscenes can run while GameManager remains in EXPLORATION.
	for controller in get_tree().get_nodes_in_group(
		"cutscene_controller"
	):
		if not is_instance_valid(controller):
			continue

		var active_value: Variant = controller.get(
			"is_cutscene_active"
		)

		if active_value is bool and active_value:
			return true

	return false


func _set_arrow_visual_visible(
	arrow: Node3D,
	should_show: bool
) -> void:
	for child in arrow.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).visible = should_show


func _update_arrow_positions() -> void:
	if (
		not _route_visible
		or not is_instance_valid(_player)
		or not is_instance_valid(_target)
	):
		return

	var start: Vector3 = _player.global_position
	var destination: Vector3 = _target.global_position

	var horizontal_delta := Vector3(
		destination.x - start.x,
		0.0,
		destination.z - start.z
	)

	var distance: float = horizontal_delta.length()

	if distance < 1.1:
		for arrow in _arrow_nodes:
			_set_arrow_visual_visible(arrow, false)

		return

	var direction: Vector3 = horizontal_delta.normalized()
	var arrow_count: int = clampi(
		int(distance / maxf(arrow_spacing, 0.5)),
		1,
		max_arrow_count
	)

	var horizontal_target := Vector3(
		destination.x,
		start.y,
		destination.z
	)

	for index in range(_arrow_nodes.size()):
		var arrow: Node3D = _arrow_nodes[index]

		if index >= arrow_count:
			_set_arrow_visual_visible(arrow, false)
			continue

		# Keep the first arrow away from the player and end before the target.
		var fraction: float = (
			float(index + 1) / float(arrow_count + 1)
		)

		var point: Vector3 = start.lerp(destination, fraction)
		point.y = (
			_ground_y_at(point, start, destination)
			+ arrow_ground_offset
		)

		arrow.global_position = point
		arrow.look_at(
			Vector3(horizontal_target.x, point.y, horizontal_target.z),
			Vector3.UP
		)

		_set_arrow_visual_visible(arrow, true)


func _ground_y_at(
	point: Vector3,
	start: Vector3,
	destination: Vector3
) -> float:
	var fallback_y: float = point.y
	var world: World3D = get_world_3d()

	if world == null:
		return point.y

	var top_y: float = maxf(start.y, destination.y) + 6.0
	var bottom_y: float = minf(start.y, destination.y) - 6.0

	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, top_y, point.z),
		Vector3(point.x, bottom_y, point.z)
	)

	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = false

	var exclusions: Array[RID] = []

	if _player is CollisionObject3D:
		exclusions.append((_player as CollisionObject3D).get_rid())

	if _target is CollisionObject3D:
		exclusions.append((_target as CollisionObject3D).get_rid())

	query.exclude = exclusions

	var hit: Dictionary = (
		world.direct_space_state.intersect_ray(query)
	)

	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		return hit_position.y

	return fallback_y


func _clear_target() -> void:
	_target = null
	_target_id = ""
	_target_type = ""
	_auto_hide_remaining = 0.0

	_set_route_visible(false)
	_update_hint_label()


# ============================================================
# QUEST LOG TRACK BUTTON + HUD SYNC
# ============================================================

func _ensure_quest_log_track_button() -> void:
	if is_instance_valid(_track_button) and is_instance_valid(_quest_log):
		return

	var root := get_tree().root
	var quest_log := root.find_child("QuestLog", true, false)

	if not is_instance_valid(quest_log):
		return

	var detail_vbox := quest_log.get_node_or_null(
		"Center/QuestPanel/Margin/MainVBox/Body/DetailPanel/DetailMargin/DetailVBox"
	) as VBoxContainer

	if detail_vbox == null:
		return

	_quest_log = quest_log

	_track_button = Button.new()
	_track_button.name = "TrackQuestButton"
	_track_button.custom_minimum_size = Vector2(0.0, 42.0)
	_track_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_button.text = "TRACK QUEST"
	_track_button.tooltip_text = (
		"Track this active quest on the HUD and show arrows for 5 seconds."
	)

	_track_button.add_theme_font_size_override("font_size", 14)
	_track_button.add_theme_color_override(
		"font_color",
		Color(0.94, 0.86, 0.64, 1.0)
	)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.15, 0.10, 0.96)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.72, 0.62, 0.36, 0.75)
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5

	_track_button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.22, 0.12, 1.0)

	_track_button.add_theme_stylebox_override("hover", hover)
	_track_button.add_theme_stylebox_override(
		"pressed",
		hover.duplicate()
	)

	_track_button.pressed.connect(_on_track_button_pressed)

	var objective_header := detail_vbox.get_node_or_null(
		"ObjectiveHeader"
	)

	detail_vbox.add_child(_track_button)

	if objective_header != null:
		detail_vbox.move_child(
			_track_button,
			objective_header.get_index()
		)

	if _quest_log.has_signal("quest_selected"):
		var selected_signal := Signal(_quest_log, "quest_selected")

		if not selected_signal.is_connected(
			_on_quest_log_selection_changed
		):
			selected_signal.connect(_on_quest_log_selection_changed)

	if not tracked_quest_changed.is_connected(
		_on_tracked_quest_changed
	):
		tracked_quest_changed.connect(_on_tracked_quest_changed)

	_update_quest_log_track_button()


func _on_track_button_pressed() -> void:
	if not is_instance_valid(_quest_log):
		return

	var selected_id: String = str(
		_quest_log.get("current_quest_id")
	)

	set_tracked_quest(selected_id)


func _on_quest_log_selection_changed(_quest_id: String) -> void:
	_update_quest_log_track_button()


func _on_tracked_quest_changed(_quest_id: String) -> void:
	_update_quest_log_track_button()
	_sync_hud_tracker()


func _update_quest_log_track_button() -> void:
	if (
		not is_instance_valid(_track_button)
		or not is_instance_valid(_quest_log)
	):
		return

	var selected_id := str(
		_quest_log.get("current_quest_id")
	)

	var active := (
		not selected_id.is_empty()
		and is_instance_valid(QuestManager)
		and QuestManager.is_quest_active(selected_id)
	)

	_track_button.disabled = not active

	if not active:
		_track_button.text = "TRACK QUEST"
	elif selected_id == _tracked_quest_id:
		_track_button.text = "TRACKED ✓"
	else:
		_track_button.text = "TRACK QUEST"


func _sync_hud_tracker() -> void:
	var hud := _find_hud()

	if not is_instance_valid(hud):
		return

	var quest_panel := hud.get_node_or_null(
		"QuestPanel"
	) as Control

	var title_label := hud.get_node_or_null(
		"QuestPanel/QuestMargin/QuestVBox/QuestTitleLabel"
	) as Label

	var state_label := hud.get_node_or_null(
		"QuestPanel/QuestMargin/QuestVBox/ObjectiveRow/ObjectiveStateLabel"
	) as Label

	var objective_label := hud.get_node_or_null(
		"QuestPanel/QuestMargin/QuestVBox/ObjectiveRow/ObjectiveLabel"
	) as Label

	var progress_label := hud.get_node_or_null(
		"QuestPanel/QuestMargin/QuestVBox/ObjectiveRow/ObjectiveProgressLabel"
	) as Label

	if not is_instance_valid(quest_panel):
		return

	hud.set("_current_quest_id", _tracked_quest_id)

	if (
		_tracked_quest_id.is_empty()
		or not is_instance_valid(QuestManager)
		or not QuestManager.is_quest_active(_tracked_quest_id)
	):
		quest_panel.hide()
		return

	var quest_data: QuestData = QuestManager.get_quest(
		_tracked_quest_id
	)

	if quest_data == null:
		quest_panel.hide()
		return

	if is_instance_valid(title_label):
		title_label.text = (
			quest_data.title
			if not quest_data.title.strip_edges().is_empty()
			else _tracked_quest_id.replace("_", " ").capitalize()
		)

	var step_index: int = QuestManager.get_current_step(
		_tracked_quest_id
	)

	if step_index < 0 or step_index >= quest_data.steps.size():
		if is_instance_valid(state_label):
			state_label.text = "✓"

		if is_instance_valid(objective_label):
			objective_label.text = "Quest objectives complete"

		if is_instance_valid(progress_label):
			progress_label.text = ""

		quest_panel.show()
		return

	var step: QuestStep = quest_data.steps[step_index]

	var count: int = QuestManager.get_objective_count(
		_tracked_quest_id,
		step_index
	)

	var required: int = maxi(
		QuestManager.get_objective_required_count(
			_tracked_quest_id,
			step_index
		),
		1
	)

	var completed: bool = QuestManager.is_objective_completed(
		_tracked_quest_id,
		step_index
	)

	if is_instance_valid(state_label):
		state_label.text = "✓" if completed else "○"

	if is_instance_valid(objective_label):
		objective_label.text = _format_hud_objective(step)

	if is_instance_valid(progress_label):
		progress_label.text = "%d / %d" % [
			mini(count, required),
			required
		]

	quest_panel.show()


func _format_hud_objective(step: QuestStep) -> String:
	var target := (
		step.target
		.strip_edges()
		.replace("_", " ")
		.replace("-", " ")
	)

	if target.is_empty():
		target = "the objective"
	else:
		target = target.capitalize()

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


# ============================================================
# HUD HINT
# ============================================================

func _ensure_hint_label() -> void:
	var hud := _find_hud()

	if not is_instance_valid(hud):
		_hint_label = null
		return

	if (
		is_instance_valid(_hint_label)
		and _hint_label.get_parent() == hud
	):
		return

	var existing := hud.get_node_or_null(HINT_NODE_NAME)

	if existing is Label:
		_hint_label = existing as Label
	else:
		_hint_label = Label.new()
		_hint_label.name = HINT_NODE_NAME
		hud.add_child(_hint_label)

	_hint_label.position = Vector2(28.0, 173.0)
	_hint_label.size = Vector2(330.0, 21.0)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hint_label.add_theme_color_override(
		"font_color",
		Color(0.86, 0.78, 0.57, 0.96)
	)

	_hint_label.add_theme_font_size_override("font_size", 12)

	_hint_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.04, 0.05, 0.035, 0.9)
	)

	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.text = "Press V to show arrows for 5 seconds"
	_hint_label.visible = false


func _update_hint_label() -> void:
	if not is_instance_valid(_hint_label):
		return

	var has_target: bool = (
		is_instance_valid(_target)
		and is_instance_valid(_player)
	)

	var hud := _find_hud()

	var hud_visible: bool = (
		is_instance_valid(hud)
		and hud.visible
	)

	# FIX: The hint is hidden alongside the waypoint during dialogue/cutscenes.
	_hint_label.visible = (
		has_target
		and hud_visible
		and not _is_waypoint_suppressed()
	)

	_hint_label.text = "Press V to show arrows for 5 seconds"
