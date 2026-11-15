extends Node3D

## Nine physical planting fields arranged 3x3 in SecondTown.
## Each field has nine seed cells, while only APAT/LIMA/ANAM are taught.
## The targets are randomly shuffled (three of each), and persisted in quest flags.
## Every field can be solved independently, with no CanvasLayer or movement lock.

const QUEST_ID: String = "st_farmer_supplies"
const FARMER_ID: String = "Farmer"
const DEMO_FLAG: String = "st_farmer_world_demo_started"
const LESSON_FLAG: String = "st_farmer_lesson_done"
const LESSON_EVENT: String = "st_farmer_world_numbers_learned"
const REPORT_EVENT: String = "st_farmer_world_report_done"
const FIELD_EVENT: String = "st_farmer_field_completed"
const LAYOUT_FLAG: String = "st_farmer_9_fields_layout_ready"
const WORDS: Array[String] = ["apat", "lima", "anam"]
const FIELD_COLUMNS: int = 3
const FIELD_ROWS: int = 3
const FIELD_COUNT: int = FIELD_COLUMNS * FIELD_ROWS
const REQUIRED_STEPS: int = 3  # Farmer -> complete 9 fields -> Farmer
const GRID_COLUMNS: int = 3
const GRID_ROWS: int = 3
const MAX_SEEDLINGS: int = GRID_COLUMNS * GRID_ROWS
const FIELD_INITIAL_COUNTS: Array[int] = [2, 1, 3, 0, 2, 1, 3, 1, 2]
const LEGACY_TARGETS: Array[int] = [6, 5, 6]

# Textures share Second Town's muted olive / sandy-brown palette.
const PLOT_TOP_TEXTURE: Texture2D = preload("res://Assets/SecondTown/farmer_plot_top.png")
const PLANT_FRONT_TEXTURE: Texture2D = preload("res://Assets/SecondTown/farmer_plant_front.png")
const RIM_TEXTURE: Texture2D = preload("res://Assets/SecondTown/farmer_rim_brick.png")
const SOIL_CELL_TEXTURES = [
	preload("res://Assets/SecondTown/farmer_soil_cell_01.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_02.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_03.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_04.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_05.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_06.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_07.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_08.png"),
	preload("res://Assets/SecondTown/farmer_soil_cell_09.png")
]


@export_category("World Placement (offsets from Farmer, in world meters)")
@export var demo_offset: Vector3 = Vector3(3.7, 0.0, 2.9)
@export var first_field_offset: Vector3 = Vector3(6.7, 0.0, -1.0)
@export var field_spacing: Vector3 = Vector3(3.9, 0.0, 0.0)
@export_range(3.2, 10.0, 0.1) var row_spacing: float = 4.0
@export_range(1.0, 5.0, 0.1) var interaction_distance: float = 2.7

var _farmer: CharacterBody3D = null
var _demo: Node3D = null
var _demo_plants: Node3D = null
var _demo_sign: Label3D = null
var _demo_page: int = 0
var _plot_details: Array[Dictionary] = []
var _plots: Array[Node3D] = []
var _plot_plants: Array[Node3D] = []
var _plot_signs: Array[Label3D] = []
var _counts: Array[int] = []
var _built: bool = false
var _had_old_layout: bool = false
var _last_quest_step: int = -9
var _last_active: bool = false
var _clock: float = 0.0


func _ready() -> void:
	GameEvents.npc_talked.connect(_on_npc_talked)
	QuestManager.quest_started.connect(_on_quest_changed)
	QuestManager.quest_completed.connect(_on_quest_changed)
	QuestManager.quest_objective_updated.connect(_on_objective_changed)
	# Editor-installed labels exist even before the merchant quest begins.
	# Hide them immediately, before the first regular world refresh.
	_sync_merchant_delivery_labels()
	call_deferred("_initialize_world")


func _initialize_world() -> void:
	_farmer = get_parent().get_node_or_null("npc/farmer") as CharacterBody3D
	if not is_instance_valid(_farmer):
		push_error("[FARMER WORLD] Missing SecondTown/npc/farmer")
		return
	# This readable ID makes the existing quest tracker display 'Talk to Farmer'.
	_farmer.set("npc_id", FARMER_ID)
	_had_old_layout = not QuestManager.has_dialogue_flag(LAYOUT_FLAG)
	_prepare_field_layout()
	_create_demo()
	for i: int in range(FIELD_COUNT):
		_create_plot(i)
	_built = true
	_migrate_old_active_quest()
	_sync_world(true)
	print("[FARMER WORLD] In-town seedlings and nine shuffled fields ready; no UI used")


func _completed_flag(index: int) -> String:
	return "st_farmer_field_%d_completed" % (index + 1)


func _target_flag(index: int, value: int) -> String:
	return "st_farmer_field_%d_target_%d" % [index + 1, value]


func _prepare_field_layout() -> void:
	# Persist the shuffled answers so leaving town doesn't silently change them.
	var targets: Array[int] = []
	var valid_saved: bool = QuestManager.has_dialogue_flag(LAYOUT_FLAG)
	if valid_saved:
		for index: int in range(FIELD_COUNT):
			var saved_target: int = 0
			for choice: int in range(4, 7):
				if QuestManager.has_dialogue_flag(_target_flag(index, choice)):
					saved_target = choice
					break
			if saved_target == 0:
				valid_saved = false
				break
			targets.append(saved_target)
	if not valid_saved:
		targets.clear()
		# Three copies of each taught number, shuffled across the nine beds.
		# Keep the answers for completed old three-field quest beds if migrating.
		var pool: Array[int] = [4, 4, 4, 5, 5, 5, 6, 6, 6]
		var forced: Dictionary = {}
		if QuestManager.is_quest_active(QUEST_ID):
			var old_state: Dictionary = QuestManager.active_quests.get(QUEST_ID, {})
			var old_objectives: Array = old_state.get("objectives", [])
			if old_objectives.size() == 5 or (old_objectives.size() == 3 and _had_old_layout):
				# QuestManager's loader trims old five-step saves to the new step
				# count. In that case the first TWO old field states survive.
				var old_count: int = 3 if old_objectives.size() == 5 else 2
				for index: int in range(old_count):
					if bool(old_objectives[index + 1].get("completed", false)):
						forced[index] = LEGACY_TARGETS[index]
						pool.erase(LEGACY_TARGETS[index])
		pool.shuffle()
		for index: int in range(FIELD_COUNT):
			var target: int = int(forced[index]) if forced.has(index) else pool.pop_back()
			targets.append(target)
			for choice: int in range(4, 7):
				QuestManager.set_dialogue_flag(_target_flag(index, choice), choice == target)
		QuestManager.set_dialogue_flag(LAYOUT_FLAG, true)
		GameManager.request_save()
	for index: int in range(FIELD_COUNT):
		var target: int = targets[index]
		var initial_count: int = FIELD_INITIAL_COUNTS[index]
		_plot_details.append({
			"id": "farmer_field_%d" % (index + 1),
			"needed": target,
			"initial": initial_count,
			"word": WORDS[target - 4]
		})
		_counts.append(initial_count)


func _migrate_old_active_quest() -> void:
	if not QuestManager.is_quest_active(QUEST_ID) or QuestManager.is_quest_completed(QUEST_ID):
		return
	var saved: Dictionary = QuestManager.active_quests.get(QUEST_ID, {})
	var old: Array = saved.get("objectives", [])
	if old.size() == REQUIRED_STEPS and not _had_old_layout:
		return

	var demo_completed: bool = false
	var demo_count: int = 0
	if old.size() > 0:
		demo_completed = bool(old[0].get("completed", false))
		demo_count = int(old[0].get("count", 0))
	if old.size() == 5 or (old.size() == REQUIRED_STEPS and _had_old_layout):
		# Existing saves had 5 objectives. The standard QuestManager loader
		# truncates them to three under the new quest resource; preserve the
		# first two field states when that happens.
		var old_count: int = 3 if old.size() == 5 else 2
		for i: int in range(old_count):
			if bool(old[i + 1].get("completed", false)):
				QuestManager.set_dialogue_flag(_completed_flag(i), true)

	var done_count: int = 0
	for i: int in range(FIELD_COUNT):
		if QuestManager.has_dialogue_flag(_completed_flag(i)):
			done_count += 1
	var demo_state: Dictionary = {"count": 1 if demo_completed else demo_count, "completed": demo_completed, "validation_state": "correct" if demo_completed else "none"}
	var fields_state: Dictionary = {"count": done_count, "completed": done_count >= FIELD_COUNT, "validation_state": "correct" if done_count >= FIELD_COUNT else "none"}
	var report_state: Dictionary = {"count": 0, "completed": false, "validation_state": "none"}
	var states: Array = [demo_state, fields_state, report_state]
	var next_step: int = 0 if not demo_completed else (1 if done_count < FIELD_COUNT else 2)
	QuestManager.active_quests[QUEST_ID] = {
		"current_step": next_step,
		"current_count": int(states[next_step].get("count", 0)),
		"validation_state": str(states[next_step].get("validation_state", "none")),
		"objectives": states
	}
	var data: QuestData = QuestManager.get_quest(QUEST_ID)
	if data != null and data.steps.size() == REQUIRED_STEPS:
		QuestManager.quest_objective_updated.emit(QUEST_ID, next_step, data.steps[next_step])
	GameManager.request_save()
	_had_old_layout = false
	print("[FARMER WORLD] Migrated earlier field progress to 9-field quest")

func _process(delta: float) -> void:
	_clock += delta
	if not _built or _clock < 0.45:
		return
	_clock = 0.0
	_migrate_old_active_quest()
	_sync_world(false)


func _on_quest_changed(quest_id: String, _quest: QuestData) -> void:
	if quest_id == QUEST_ID:
		call_deferred("_sync_world", true)
	elif quest_id == "st_merchant_orders":
		_sync_merchant_delivery_labels()


func _on_objective_changed(quest_id: String, _index: int, _step: QuestStep) -> void:
	if quest_id == QUEST_ID:
		call_deferred("_sync_world", true)
	elif quest_id == "st_merchant_orders":
		_sync_merchant_delivery_labels()


func _on_npc_talked(id: String) -> void:
	if id != FARMER_ID or not QuestManager.is_quest_active(QUEST_ID):
		return
	var stage: int = QuestManager.get_current_step(QUEST_ID)
	if stage == 0:
		if not QuestManager.has_dialogue_flag(DEMO_FLAG):
			QuestManager.set_dialogue_flag(DEMO_FLAG, true)
			_demo_page = 0
			GameManager.request_save()
		call_deferred("_sync_world", true)
	elif stage == 2:
		# Completing this requires the final Farmer conversation, not merely
		# walking past him. DialogueManager emits npc_talked after it closes.
		GameEvents.puzzle_solved.emit(REPORT_EVENT)
		GameManager.request_save()


func _sync_world(force: bool = false) -> void:
	# Always keep the merchant markers in sync, even while the farmer quest is idle.
	_sync_merchant_delivery_labels()
	if not _built or not is_instance_valid(_farmer):
		return
	_sync_farmer_dialogue()
	var active: bool = QuestManager.is_quest_active(QUEST_ID)
	var completed: bool = QuestManager.is_quest_completed(QUEST_ID)
	var step: int = QuestManager.get_current_step(QUEST_ID) if active else -1
	if not force and active == _last_active and step == _last_quest_step:
		return
	_last_active = active
	_last_quest_step = step

	if is_instance_valid(_demo):
		_demo.visible = active and step >= 0 and step <= 1 and QuestManager.has_dialogue_flag(DEMO_FLAG)
		# A hidden demonstration must not leave an invisible collision wall.
		_set_bed_collision_enabled(_demo, _demo.visible)
		if _demo.visible:
			_show_demo_page()
	for i: int in range(_plots.size()):
		var plot: Node3D = _plots[i]
		# Keep completed beds as physical town scenery; the quest-only labels vanish.
		plot.visible = active or completed
		# Unstarted plots are hidden AND non-colliding; active/completed beds block the player.
		_set_bed_collision_enabled(plot, plot.visible)
		if completed or QuestManager.has_dialogue_flag(_completed_flag(i)):
			_counts[i] = int(_plot_details[i]["needed"])
		_refresh_field(i)
		# Do not spoil plot instructions before the lesson or leave floating
		# FIELD x / 9 COMPLETE labels after finishing the quest.
		_plot_signs[i].visible = active and not completed and step == 1


func _sync_merchant_delivery_labels() -> void:
	# Berto/Mila/Nena are permanent NPCs in SecondTown.tscn. Their old
	# DELIVERY labels must not be present outside the merchant quest.
	var town: Node = get_parent()
	if not is_instance_valid(town):
		return
	var npc_root: Node = town.get_node_or_null("npc")
	if not is_instance_valid(npc_root):
		return
	var active: bool = QuestManager.is_quest_active("st_merchant_orders") and not QuestManager.is_quest_completed("st_merchant_orders")
	var step: int = QuestManager.get_current_step("st_merchant_orders") if active else -1
	var names: Array[String] = ["berto", "mila", "nena"]
	for index: int in range(names.size()):
		var npc: Node = npc_root.get_node_or_null(names[index])
		if not is_instance_valid(npc):
			continue
		# Show only the recipient relevant to the current delivery objective.
		var show_marker: bool = active and step == index + 1
		for label_name: String in ["DeliveryPointLabel", "DeliveryCountLabel"]:
			var label: Label3D = npc.get_node_or_null(label_name) as Label3D
			if is_instance_valid(label):
				label.visible = show_marker
	# An old scene installer also added DELIVERY / FARMER by mistake.
	# Farmer is not a merchant delivery recipient, so never display those labels.
	var farmer_npc: Node = npc_root.get_node_or_null("farmer")
	if is_instance_valid(farmer_npc):
		for label_name: String in ["DeliveryPointLabel", "DeliveryCountLabel"]:
			var label: Label3D = farmer_npc.get_node_or_null(label_name) as Label3D
			if is_instance_valid(label):
				label.visible = false


func _sync_farmer_dialogue() -> void:
	# SecondTownQuestController also chooses the farmer's dialogue. This node
	# runs AFTER it in the scene tree and corrects the stage-specific variant.
	if not is_instance_valid(_farmer):
		return
	var variant: String = "farmer_locked"
	if QuestManager.is_quest_completed(QUEST_ID):
		variant = "farmer_done"
	elif QuestManager.is_quest_active(QUEST_ID) or QuestManager.is_quest_completed("st_merchant_orders"):
		variant = "farmer_quest"
		if QuestManager.is_quest_active(QUEST_ID):
			var step: int = QuestManager.get_current_step(QUEST_ID)
			if step >= 2:
				variant = "farmer_turnin"
			elif step >= 1:
				variant = "farmer_progress"
	var dialogue: String = "SecondTownSceneDialogues/" + variant
	if str(_farmer.get("dialogue_id")) != dialogue:
		_farmer.set("dialogue_id", dialogue)


func _create_demo() -> void:
	_demo = Node3D.new()
	_demo.name = "FarmerNumberDemonstration"
	add_child(_demo)
	_place_on_ground(_demo, _farmer.global_position + demo_offset)
	_demo_plants = Node3D.new()
	_demo_plants.name = "VisibleDemoSeedlings"
	_demo.add_child(_demo_plants)
	_make_soil_bed(_demo, MAX_SEEDLINGS)
	_demo_sign = _make_sign(_demo, Vector3(0.0, 1.65, 0.0), "", Color(0.96, 0.86, 0.51))
	_demo.visible = false


func _show_demo_page() -> void:
	if not is_instance_valid(_demo):
		return
	var number: int = _demo_page + 4
	_demo_sign.text = "%s = %d SEEDLINGS\nE: NEXT    R: PREVIOUS" % [WORDS[_demo_page].to_upper(), number]
	if _demo_page == 2:
		if QuestManager.get_current_step(QUEST_ID) == 0:
			_demo_sign.text = "ANAM = 6 SEEDLINGS\nE: START PLANTING    R: PREVIOUS"
		else:
			_demo_sign.text = "ANAM = 6 SEEDLINGS\nE: REVIEW APAT    R: PREVIOUS"
	_clear_children(_demo_plants)
	for i: int in range(number):
		var crop: Node3D = _make_seedling(_demo_plants, _grounded_slot_position(_demo, i), true)
		crop.scale = Vector3(0.05, 0.05, 0.05)
		var tween: Tween = crop.create_tween()
		tween.tween_property(crop, "scale", Vector3.ONE, 0.25).set_delay(float(i) * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	LanguageProgress.mark_encountered(WORDS[_demo_page])


func _create_plot(index: int) -> void:
	var data: Dictionary = _plot_details[index]
	var root: Node3D = Node3D.new()
	root.name = str(data["id"])
	add_child(root)
	var column: int = index % FIELD_COLUMNS
	var row: int = floori(float(index) / float(FIELD_COLUMNS))
	var field_offset: Vector3 = Vector3(field_spacing.x * float(column), 0.0, row_spacing * float(row))
	_place_on_ground(root, _farmer.global_position + first_field_offset + field_offset)
	_make_soil_bed(root, MAX_SEEDLINGS)
	var plants: Node3D = Node3D.new()
	plants.name = "PlantedSeedlings"
	root.add_child(plants)
	var sign: Label3D = _make_sign(root, Vector3(0.0, 1.62, -0.2), "", Color(0.96, 0.87, 0.59))
	_plot_plants.append(plants)
	_plot_signs.append(sign)
	_plots.append(root)
	root.visible = false


func _refresh_field(index: int) -> void:
	if index < 0 or index >= _plots.size():
		return
	var data: Dictionary = _plot_details[index]
	var plants: Node3D = _plot_plants[index]
	_clear_children(plants)
	for j: int in range(_counts[index]):
		_make_seedling(plants, _grounded_slot_position(_plots[index], j), false)
	var complete: bool = QuestManager.is_quest_completed(QUEST_ID) or (QuestManager.is_quest_active(QUEST_ID) and QuestManager.has_dialogue_flag(_completed_flag(index)))
	var sign: Label3D = _plot_signs[index]
	if complete:
		sign.text = "FIELD %d / %d COMPLETE" % [index + 1, FIELD_COUNT]
	else:
		sign.text = "FIELD %d / %d: %s\nE: PLANT    R: REMOVE    F: CHECK" % [index + 1, FIELD_COUNT, str(data["word"]).to_upper()]


func _unhandled_input(event: InputEvent) -> void:
	if not _built or not QuestManager.is_quest_active(QUEST_ID):
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION or DialogueManager.is_dialogue_active:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var wants_e: bool = key_event.is_action_pressed("interact")
	var wants_r: bool = key_event.physical_keycode == KEY_R or key_event.keycode == KEY_R
	var wants_f: bool = key_event.physical_keycode == KEY_F or key_event.keycode == KEY_F
	if not wants_e and not wants_r and not wants_f:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return
	var step: int = QuestManager.get_current_step(QUEST_ID)
	var plot_index: int = _nearest_available_plot(player) if step == 1 else -1
	var near_demo: bool = step >= 0 and step <= 1 and QuestManager.has_dialogue_flag(DEMO_FLAG) and _is_near(player, _demo)
	# The demonstration is reviewable, but never steals input from a closer plot.
	if near_demo and (wants_e or wants_r):
		var demo_distance: float = _horizontal_distance_squared(player, _demo)
		var plot_distance: float = _horizontal_distance_squared(player, _plots[plot_index]) if plot_index >= 0 else INF
		if demo_distance <= plot_distance:
			if wants_e:
				if _demo_page < 2:
					_demo_page += 1
					_show_demo_page()
				else:
					if step == 0:
						_finish_demonstration()
					else:
						_demo_page = 0
						_show_demo_page()
			elif wants_r:
				_demo_page = maxi(0, _demo_page - 1)
				_show_demo_page()
			get_viewport().set_input_as_handled()
			return
	# After the lesson, ALL incomplete fields accept input regardless of order.
	if step == 1 and plot_index >= 0:
		if wants_e:
			_counts[plot_index] = mini(MAX_SEEDLINGS, _counts[plot_index] + 1)
		elif wants_r:
			_counts[plot_index] = maxi(int(_plot_details[plot_index]["initial"]), _counts[plot_index] - 1)
		elif wants_f:
			_check_field(plot_index)
			get_viewport().set_input_as_handled()
			return
		_refresh_field(plot_index)
		get_viewport().set_input_as_handled()


func _finish_demonstration() -> void:
	if QuestManager.get_current_step(QUEST_ID) != 0:
		return
	if not QuestManager.has_dialogue_flag(LESSON_FLAG):
		LanguageProgress.mark_learned("apat+lima+anam")
		QuestManager.set_dialogue_flag(LESSON_FLAG, true)
	GameEvents.puzzle_solved.emit(LESSON_EVENT)
	GameManager.request_save()
	call_deferred("_sync_world", true)


func _check_field(index: int) -> void:
	if QuestManager.get_current_step(QUEST_ID) != 1:
		return
	if QuestManager.has_dialogue_flag(_completed_flag(index)):
		return
	var target: int = int(_plot_details[index]["needed"])
	if _counts[index] != target:
		# Identical response for too few and too many. No answer spoilers.
		_plot_signs[index].text = "WRONG\nE: PLANT    R: REMOVE    F: CHECK"
		return
	# Each individual plot is locked and persisted, independent of completion order.
	QuestManager.set_dialogue_flag(_completed_flag(index), true)
	GameEvents.object_interacted.emit(FIELD_EVENT)
	if _all_fields_completed():
		GameEvents.puzzle_solved.emit("st_farmer_supplies_prepared")
	GameManager.request_save()
	call_deferred("_sync_world", true)


func _all_fields_completed() -> bool:
	for index: int in range(FIELD_COUNT):
		if not QuestManager.has_dialogue_flag(_completed_flag(index)):
			return false
	return true

func _nearest_available_plot(player: Node3D) -> int:
	var best_index: int = -1
	var best_distance: float = interaction_distance * interaction_distance
	for i: int in range(_plots.size()):
		if QuestManager.has_dialogue_flag(_completed_flag(i)):
			continue
		if not _plots[i].visible:
			continue
		var distance: float = _horizontal_distance_squared(player, _plots[i])
		if distance <= best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _horizontal_distance_squared(a: Node3D, b: Node3D) -> float:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return INF
	var delta: Vector3 = a.global_position - b.global_position
	delta.y = 0.0
	return delta.length_squared()


func _is_near(player: Node3D, target: Node3D) -> bool:
	return _horizontal_distance_squared(player, target) <= interaction_distance * interaction_distance


func _place_on_ground(node: Node3D, approx: Vector3) -> void:
	# Each bed is ONE level 3D object. Place it above the highest terrain sample
	# within its footprint, rather than letting individual cells sink into ground.
	var ground_y: float = _ground_height(approx)
	for row: int in range(GRID_ROWS):
		for column: int in range(GRID_COLUMNS):
			var offset: Vector3 = Vector3((float(column) - 1.0) * 0.84, 0.0, (float(row) - 1.0) * 1.08)
			ground_y = maxf(ground_y, _ground_height(approx + offset))
	for offset: Vector3 in [Vector3(-1.14, 0.0, -1.43), Vector3(1.14, 0.0, -1.43), Vector3(-1.14, 0.0, 1.43), Vector3(1.14, 0.0, 1.43)]:
		ground_y = maxf(ground_y, _ground_height(approx + offset))
	node.global_position = Vector3(approx.x, ground_y + 0.055, approx.z)


func _ground_height(at: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 16.0, at + Vector3.DOWN * 16.0)
	query.collision_mask = 1
	query.collide_with_areas = false
	var excluded: Array[RID] = []
	if is_instance_valid(_farmer):
		excluded.append(_farmer.get_rid())
	var player: CollisionObject3D = get_tree().get_first_node_in_group("player") as CollisionObject3D
	if is_instance_valid(player):
		excluded.append(player.get_rid())
	query.exclude = excluded
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if hit_normal.y > 0.5:
			var hit_position: Vector3 = hit["position"]
			return hit_position.y
	return _farmer.global_position.y - 0.45


func _make_soil_bed(parent: Node3D, slots: int) -> void:
	# All geometry remains physical 3D; only its TOP faces carry the pixel texture.
	# The solid foundation follows the same 3x3 footprint as before.
	var dirt_side: StandardMaterial3D = _material(Color(0.27, 0.20, 0.16))
	var deep_outline: StandardMaterial3D = _material(Color(0.10, 0.10, 0.075))
	var rim: StandardMaterial3D = _texture_material(RIM_TEXTURE)
	# Extend the physical foundation downward to hide gaps on sloping terrain.
	# The TOP surface stays at Y=0.11, matching the original bed geometry.
	_add_box(parent, "GardenBase", Vector3(2.30, 0.46, 2.86), Vector3(0.0, -0.12, 0.0), dirt_side)
	# One solid collider for the entire 3x3 planter: no gaps between soil cells.
	# Bottom matches the foundation (-0.35), top matches the raised soil (+0.21).
	# Keep it on physics layer 1 so the existing player CharacterBody3D can hit it.
	var bed_body: StaticBody3D = StaticBody3D.new()
	bed_body.name = "GardenSolidCollision"
	bed_body.collision_layer = 1
	bed_body.collision_mask = 1
	parent.add_child(bed_body)
	var bed_shape: BoxShape3D = BoxShape3D.new()
	bed_shape.size = Vector3(2.30, 0.56, 2.86)
	var bed_collider: CollisionShape3D = CollisionShape3D.new()
	bed_collider.name = "BedCollisionShape"
	bed_collider.shape = bed_shape
	bed_collider.position = Vector3(0.0, -0.07, 0.0)
	bed_body.add_child(bed_collider)
	_add_ground_texture(parent, "GardenTopPixelArt", PLOT_TOP_TEXTURE,
		Vector2(2.39, 2.97), Vector3(0.0, 0.117, 0.0), true)
	for i: int in range(slots):
		# All nine tiles sit at the SAME level; only the bed root follows terrain.
		var at: Vector3 = _grounded_slot_position(parent, i)
		# Nearly black seams between tiles make each planting cell readable.
		_add_box(parent, "CellOutline_%d" % i,
			Vector3(0.67, 0.146, 0.76), at + Vector3(0.0, -0.007, 0.0), deep_outline)
		_add_box(parent, "CellVolume_%d" % i,
			Vector3(0.60, 0.13, 0.68), at, dirt_side)
		var variant: int = i % SOIL_CELL_TEXTURES.size()
		_add_ground_texture(parent, "SoilTexture_%d" % i, SOIL_CELL_TEXTURES[variant],
			Vector2(0.592, 0.672), at + Vector3(0.0, 0.070, 0.0), false)
	# Shaded brick/wood-colored 3D rails (instead of four flat brown bars).
	_add_box(parent, "GardenEdge_Left", Vector3(0.11, 0.18, 2.83), Vector3(-1.11, 0.105, 0.0), rim)
	_add_box(parent, "GardenEdge_Right", Vector3(0.11, 0.18, 2.83), Vector3(1.11, 0.105, 0.0), rim)
	_add_box(parent, "GardenEdge_Back", Vector3(2.30, 0.18, 0.11), Vector3(0.0, 0.105, -1.40), rim)
	_add_box(parent, "GardenEdge_Front", Vector3(2.30, 0.18, 0.11), Vector3(0.0, 0.105, 1.40), rim)


func _set_bed_collision_enabled(bed: Node3D, enabled: bool) -> void:
	var solid: StaticBody3D = bed.get_node_or_null("GardenSolidCollision") as StaticBody3D
	if not is_instance_valid(solid):
		return
	# The layer is safe to toggle during quest signals and physics ticks; it also
	# stops hidden plot nodes from silently trapping the player.
	solid.collision_layer = 1 if enabled else 0


func _add_ground_texture(parent: Node3D, label: String, art: Texture2D,
	size: Vector2, location: Vector3, alpha_edges: bool) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	var surface: MeshInstance3D = MeshInstance3D.new()
	surface.name = label
	surface.mesh = plane
	surface.material_override = _texture_material(art, alpha_edges)
	surface.position = location
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)


func _texture_material(art: Texture2D, alpha_edges: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = art
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.metallic = 0.0
	if alpha_edges:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.45
	return material


func _slot_position(i: int) -> Vector3:
	# All beds share a true 3 x 3 layout (9 distinct planting cells).
	var column: int = i % GRID_COLUMNS
	var row: int = floori(float(i) / float(GRID_COLUMNS))
	return Vector3((float(column) - 1.0) * 0.74, 0.0, (float(row) - 1.0) * 0.92)


func _grounded_slot_position(_bed: Node3D, i: int) -> Vector3:
	# Previous implementation sampled terrain PER CELL, which made some soil
	# squares disappear into uneven ground. A physical planter must be level.
	var point: Vector3 = _slot_position(i)
	point.y = 0.14
	return point


func _make_seedling(parent: Node3D, local_at: Vector3, is_demo: bool) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "GrowingSeedling"
	parent.add_child(root)
	# The plant and plot are separate objects; the plant stands on the 3D soil surface.
	root.position = local_at + Vector3.UP * 0.075
	var variation: int = parent.get_child_count() % 4
	var plant: Sprite3D = Sprite3D.new()
	plant.name = "PixelCropFront"
	plant.texture = PLANT_FRONT_TEXTURE
	plant.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plant.shaded = true
	plant.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	plant.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	plant.pixel_size = 0.00079 * (1.0 + float(variation - 1) * 0.035)
	# Sprite3D is centered; half-height lift plants the stem at soil level.
	plant.position = Vector3(0.0, PLANT_FRONT_TEXTURE.get_height() * plant.pixel_size * 0.5, 0.0)
	if is_demo:
		plant.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		plant.modulate = Color(0.93 + float(variation) * 0.02, 0.96 + float(variation) * 0.012, 0.93, 1.0)
	root.add_child(plant)
	# Soft, physical contact at the stem base so the crop does not look pasted on.
	var mound: StandardMaterial3D = _material(Color(0.32, 0.23, 0.17))
	var dirt: SphereMesh = SphereMesh.new()
	dirt.radius = 0.075
	dirt.height = 0.055
	var contact: MeshInstance3D = MeshInstance3D.new()
	contact.name = "StemSoilMound"
	contact.mesh = dirt
	contact.material_override = mound
	contact.position = Vector3(0.0, 0.001, 0.0)
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(contact)
	return root


func _add_box(parent: Node3D, name: String, dimensions: Vector3, position: Vector3, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	var actor: MeshInstance3D = MeshInstance3D.new()
	actor.name = name
	actor.mesh = mesh
	actor.material_override = material
	actor.position = position
	actor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(actor)


func _add_cylinder(parent: Node3D, name: String, radius: float, height: float, position: Vector3, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var actor: MeshInstance3D = MeshInstance3D.new()
	actor.name = name
	actor.mesh = mesh
	actor.material_override = material
	actor.position = position
	parent.add_child(actor)


func _add_leaf(parent: Node3D, name: String, position: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var actor: MeshInstance3D = MeshInstance3D.new()
	actor.name = name
	actor.mesh = mesh
	actor.material_override = material
	actor.position = position
	actor.scale = dimensions
	parent.add_child(actor)


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _make_sign(parent: Node3D, where: Vector3, words: String, color: Color) -> Label3D:
	var sign: Label3D = Label3D.new()
	sign.name = "InWorldQuestInstructions"
	sign.position = where
	sign.text = words
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.shaded = false
	sign.font_size = 35
	sign.pixel_size = 0.005
	sign.modulate = color
	sign.outline_size = 10
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(sign)
	return sign


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
