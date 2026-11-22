extends Node3D

## In-world Elder number lesson (7–10) using a well and ten stones.
## - Step 1: Talk to Elder -> top-view teaching demo starts
## - Step 2: Restore the well -> E adds, R removes, F submits; stones glow in order
## - Step 3: Return to Elder
##
## This script builds its own stones, water, labels, and teaching camera at runtime,
## so it does not require a heavy scene setup.

const QUEST_ID: String = "st_elder_well"
const ELDER_ID: String = "Elder"
const LESSON_STARTED_FLAG: String = "st_elder_lesson_started"
const LESSON_DONE_FLAG: String = "st_elder_lesson_done"
const LESSON_EVENT: String = "st_elder_numbers_learned"
const WELL_EVENT: String = "st_elder_well_restored"
const REPORT_EVENT: String = "st_elder_report_done"

const WORD_TO_COUNT: Dictionary = {
	"pitu": 7,
	"walo": 8,
	"siyam": 9,
	"apulu": 10,
}
const LESSON_WORDS: Array[String] = ["pitu", "walo", "siyam", "apulu"]
const LESSON_COUNTS: Array[int] = [7, 8, 9, 10]

# Pixel textures follow the same technique used on the Farmer's real 3D soil plots:
# nearest-filter PNG artwork on horizontal planes over physical 3D geometry.
const RIM_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_rim_top.png")
const WALL_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_wall.png")
const STONE_OFF_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_stone_off.png")
const STONE_ON_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_stone_on.png")
const WATER_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_water.png")
const GROUND_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_ground.png")
const PLAQUE_TEX: Texture2D = preload("res://Assets/SecondTown/elder_well_plaque.png")
const WELL_DONE_FLAG: String = "st_elder_well_cleared"


@export_category("Placement")
@export var well_offset_from_elder: Vector3 = Vector3(3.6, 0.0, -1.4)
@export var use_original_scene_well_position: bool = true
@export_range(1.0, 6.0, 0.1) var stone_ring_radius: float = 2.15
@export_range(1.0, 5.0, 0.1) var interaction_distance: float = 2.25

@export_category("Camera")
@export_range(6.0, 20.0, 0.1) var lesson_camera_height: float = 12.8
@export_range(0.0, 8.0, 0.1) var lesson_camera_pullback: float = 0.0

@export_category("Ritual")
@export_range(0.02, 1.0, 0.01) var water_step_height: float = 0.072
@export var guided_rounds: Array[int] = [7, 8, 9, 10]
@export var practice_rounds: Array[int] = [8, 7, 10, 9]

var _elder: CharacterBody3D = null
var _player: Node = null
var _well_root: Node3D = null
var _stone_root: Node3D = null
var _water: MeshInstance3D = null
var _water_base_y: float = 0.0
var _lesson_camera: Camera3D = null
var _old_camera: Camera3D = null
var _lesson_tween: Tween = null
var _guided_hint_delay: Tween = null
var _stone_flight_tweens: Array[Tween] = []
var _stone_effect_tweens: Dictionary = {}
var _water_surface: MeshInstance3D = null
var _well_collider: StaticBody3D = null
var _teaching_plaque: Node3D = null
var _teaching_plaque_label: Label3D = null
var _current_plaque_word: String = ""
var _control_plaque: Node3D = null
var _control_keys: Array[Label3D] = []
var _stone_off_material: StandardMaterial3D = null
var _stone_on_material: StandardMaterial3D = null
var _instruction_label: Label3D = null
var _status_label: Label3D = null
var _stones: Array[Dictionary] = []
var _mode: String = "idle" # idle, lesson, ritual, success_flash
var _lesson_index: int = 0
var _lesson_animating: bool = false
var _lesson_displayed_count: int = 0
var _ritual_active: bool = false
var _request_order: Array[int] = []
var _request_index: int = 0
var _selected_count: int = 0
var _well_cleared: bool = false
var _last_active: bool = false
var _last_complete: bool = false
var _last_step: int = -9
var _finished_visual_cleanup: bool = false
var _time_passed: float = 0.0

var _player_was_physics: bool = true
var _player_was_input: bool = true
var _player_was_unhandled: bool = true

func _ready() -> void:
	# If the scene accidentally contains two well lesson instances, only
	# the first one may construct plaques and react to quest events.
	add_to_group("elder_well_lesson_controller")
	GameEvents.npc_talked.connect(_on_npc_talked)
	QuestManager.quest_started.connect(_on_quest_state_changed)
	QuestManager.quest_completed.connect(_on_quest_state_changed)
	QuestManager.quest_objective_updated.connect(_on_objective_changed)
	call_deferred("_initialize_world")


func _initialize_world() -> void:
	# Duplicate controllers would each display a word plaque in the same place.
	var controllers: Array[Node] = get_tree().get_nodes_in_group("elder_well_lesson_controller")
	if not controllers.is_empty() and controllers[0] != self:
		push_warning("[ELDER WELL] Duplicate controller removed to prevent stacked text labels")
		queue_free()
		return
	_elder = get_parent().get_node_or_null("npc/elder") as CharacterBody3D
	if not is_instance_valid(_elder):
		push_error("[ELDER WELL] Missing SecondTown/npc/elder")
		return
	_player = get_tree().get_first_node_in_group("player")
	_elder.set("npc_id", ELDER_ID)
	_well_cleared = QuestManager.has_dialogue_flag(WELL_DONE_FLAG) or QuestManager.is_quest_completed(QUEST_ID)
	if QuestManager.is_quest_active(QUEST_ID) and QuestManager.get_current_step(QUEST_ID) >= 2:
		_well_cleared = true
	_stone_off_material = _pixel_material(STONE_OFF_TEX)
	_stone_on_material = _pixel_material(STONE_ON_TEX)
	_stone_on_material.emission_enabled = true
	_stone_on_material.emission = Color(0.16, 0.10, 0.025)
	_build_well_area()
	if _well_cleared:
		_water.position.y = _water_base_y + water_step_height * float(guided_rounds.size() + practice_rounds.size())
	_sync_dialogue_and_visibility(true)
	print("[ELDER WELL] Textured pixel-art well and stone lesson ready")


func _resolve_well_position() -> Vector3:
	# The Editor installer copies the original PropWell1 position to an anchor,
	# then removes the old mesh and its obsolete inspection trigger.
	var town: Node = get_parent()
	if use_original_scene_well_position and is_instance_valid(town):
		for candidate: String in ["ElderWellAnchor", "Houses/PropWell1", "marker/wellMarker"]:
			var target: Node3D = town.get_node_or_null(candidate) as Node3D
			if is_instance_valid(target):
				return target.global_position
	return _elder.global_position + well_offset_from_elder


func _build_well_area() -> void:
	_well_root = Node3D.new()
	_well_root.name = "ElderWellArea"
	add_child(_well_root)

	var well_position: Vector3 = _resolve_well_position()
	well_position.y = _ground_height(well_position) + 0.045
	_well_root.global_position = well_position
	# The remaining placement logic uses this base world position.
	var near_elder: Vector3 = well_position

	# A real open, three-dimensional masonry well: no white disk over the water.
	var wall_material: StandardMaterial3D = _pixel_material(WALL_TEX, false)
	var shadow_material: StandardMaterial3D = _material(Color(0.105, 0.135, 0.125), 1.0, 0.0)
	var soil_material: StandardMaterial3D = _material(Color(0.25, 0.21, 0.16), 1.0, 0.0)
	var water_material: StandardMaterial3D = _material(Color(0.17, 0.35, 0.39), 0.38, 0.0)

	_add_cylinder(_well_root, "WellFoundation", 1.10, 0.13, Vector3(0, 0.065, 0), soil_material)
	_add_cylinder(_well_root, "DarkWellOpening", 0.68, 0.055, Vector3(0, 0.12, 0), shadow_material)

	# Staggered bricks supply the actual side volume and shadows.
	# The pixel-art annulus covers ONLY their top faces, leaving a water opening.
	for layer: int in range(3):
		for i: int in range(18):
			var angle: float = TAU * (float(i) + (0.5 if layer % 2 == 1 else 0.0)) / 18.0
			var brick := BoxMesh.new()
			brick.size = Vector3(0.36, 0.25, 0.47)
			var piece := MeshInstance3D.new()
			piece.name = "Masonry_%d_%02d" % [layer, i]
			piece.mesh = brick
			piece.material_override = wall_material
			piece.position = Vector3(cos(angle) * 0.87, 0.20 + float(layer) * 0.255, sin(angle) * 0.87)
			piece.rotation.y = -angle
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_well_root.add_child(piece)

	_add_ground_texture(_well_root, "PixelStoneRim", RIM_TEX, Vector2(2.47, 2.47), Vector3(0, 0.847, 0))

	# Existing stone sprite and water textures sit on actual 3D surfaces.
	_add_cylinder(_well_root, "DarkWaterBody", 0.58, 0.05, Vector3(0, 0.17, 0), shadow_material)
	_water = _add_cylinder(_well_root, "WaterSurfaceBody", 0.595, 0.07, Vector3(0, 0.19, 0), water_material)
	_water_base_y = _water.position.y
	_water_surface = _add_ground_texture(_water, "PixelWater", WATER_TEX, Vector2(1.20, 1.20), Vector3(0, 0.040, 0))

	# Give the well a physical boundary. Stones have their own colliders below.
	var well_body := StaticBody3D.new()
	well_body.name = "WellCollision"
	_well_collider = well_body
	_well_root.add_child(well_body)
	var well_shape := CollisionShape3D.new()
	var well_cylinder := CylinderShape3D.new()
	well_cylinder.radius = 1.04
	well_cylinder.height = 0.83
	well_shape.shape = well_cylinder
	well_shape.position.y = 0.42
	well_body.add_child(well_shape)

	# Quiet world-space hints, placed BESIDE the well rather than across its center.
	_instruction_label = _make_label3d(Vector3(0, 1.55, -4.45), "", Color(0.99, 0.90, 0.67), 28, 8)
	_status_label = _make_label3d(Vector3(0, 1.20, -3.92), "", Color(0.96, 0.96, 0.83), 28, 8)
	_well_root.add_child(_instruction_label)
	_well_root.add_child(_status_label)

	# A physical painted wooden plaque (NOT a screen-space HUD).
	_teaching_plaque = Node3D.new()
	_teaching_plaque.name = "NumberPlaque"
	_teaching_plaque.position = Vector3(-3.95, _ground_height(near_elder + Vector3(-3.95, 0, 0.0)) - _well_root.global_position.y + 0.10, 0.0)
	_well_root.add_child(_teaching_plaque)
	_add_ground_texture(_teaching_plaque, "WoodPlaqueArt", PLAQUE_TEX, Vector2(3.35, 0.88), Vector3.ZERO)
	_teaching_plaque_label = Label3D.new()
	_teaching_plaque_label.name = "WellNumberWord"
	_teaching_plaque_label.text = ""
	_teaching_plaque_label.rotation_degrees.x = -90.0
	_teaching_plaque_label.position.y = 0.023
	_teaching_plaque_label.font_size = 56
	_teaching_plaque_label.pixel_size = 0.0052
	_teaching_plaque_label.outline_size = 10
	_teaching_plaque_label.modulate = Color(1.0, 0.92, 0.74)
	_teaching_plaque_label.shaded = false
	_teaching_plaque_label.no_depth_test = false
	_teaching_plaque_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teaching_plaque.add_child(_teaching_plaque_label)

	# The second sign is part of the world, not a CanvasLayer / screen HUD.
	# It is placed on the OPPOSITE side of the well from the word plaque.
	_control_plaque = Node3D.new()
	_control_plaque.name = "NumberLessonControls"
	var controls_at: Vector3 = near_elder + Vector3(3.95, 0.0, 0.0)
	_control_plaque.position = Vector3(3.95, _ground_height(controls_at) - _well_root.global_position.y + 0.10, 0.0)
	_well_root.add_child(_control_plaque)
	_add_ground_texture(_control_plaque, "ControlsWood", PLAQUE_TEX, Vector2(4.25, 1.02), Vector3.ZERO)
	# Three separate captions: each key owns its own slot on the board,
	# so the text cannot run into the neighboring caption.
	for i: int in range(3):
		var key_text: Label3D = Label3D.new()
		key_text.name = "KeyCaption_%d" % i
		key_text.rotation_degrees.x = -90.0
		key_text.position = Vector3(float(i - 1) * 1.39, 0.055, 0.0)
		key_text.font_size = 54
		key_text.pixel_size = 0.0046
		key_text.outline_size = 10
		key_text.modulate = Color(1.0, 0.94, 0.76)
		key_text.shaded = false
		key_text.no_depth_test = false
		key_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_control_plaque.add_child(key_text)
		_control_keys.append(key_text)
	_set_control_guide(true)
	_control_plaque.visible = false

	_stone_root = Node3D.new()
	_stone_root.name = "TenCarvedStones"
	_well_root.add_child(_stone_root)
	var stone_wall_mat: StandardMaterial3D = _pixel_material(WALL_TEX, false)
	for i: int in range(10):
		var angle: float = TAU * float(i) / 10.0 - PI * 0.5
		var local_pos: Vector3 = Vector3(cos(angle) * stone_ring_radius, 0, sin(angle) * stone_ring_radius)
		var sample: Vector3 = _well_root.global_position + local_pos
		# A ray launched 16m above the stone can hit tree canopy, roofs, or
		# other props. That previously made ONE stone float high above town.
		# Cast close to the well's base and reject elevated/non-ground hits.
		local_pos.y = _stone_ground_height(sample) - _well_root.global_position.y + 0.02
		var stone_node := Node3D.new()
		stone_node.name = "CarvedStone_%02d" % (i + 1)
		stone_node.position = local_pos
		_stone_root.add_child(stone_node)

		# Individual grass and shadow decals are grounded independently on uneven terrain.
		_add_ground_texture(stone_node, "MossyFootprint", GROUND_TEX, Vector2(0.95, 0.90), Vector3(0, 0.012, 0))

		var visual := Node3D.new()
		visual.name = "AnimatedStone"
		stone_node.add_child(visual)
		var rock := BoxMesh.new()
		rock.size = Vector3(0.55, 0.17, 0.53)
		var mesh := MeshInstance3D.new()
		mesh.name = "StoneBody"
		mesh.mesh = rock
		mesh.material_override = stone_wall_mat
		mesh.position.y = 0.12
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		visual.add_child(mesh)

		var art := _add_ground_texture(visual, "CarvedRune", STONE_OFF_TEX, Vector2(0.76, 0.76), Vector3(0, 0.225, 0))
		art.material_override = _stone_off_material
		art.rotation.y = float((i * 11) % 19 - 9) * 0.013

		var collider := StaticBody3D.new()
		collider.name = "StoneCollision"
		stone_node.add_child(collider)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.58, 0.20, 0.58)
		cs.shape = box
		cs.position.y = 0.10
		collider.add_child(cs)

		_stones.append({
			"node": stone_node,
			"visual": visual,
			"mesh": mesh,
			"art": art,
			"home_position": local_pos,
			"collider": collider,
			"selected": false,
			"lit": false,
		})

	_lesson_camera = Camera3D.new()
	_lesson_camera.name = "LessonTopDownCamera"
	_lesson_camera.current = false
	_lesson_camera.position = Vector3(0, lesson_camera_height, lesson_camera_pullback)
	_lesson_camera.rotation_degrees = Vector3(-90, 0, 0)
	_lesson_camera.fov = 36.0
	_well_root.add_child(_lesson_camera)


func _replace_plaque_word(next_word: String) -> void:
	# Clearing Label3D.text alone can leave an old label visible when multiple
	# 3D text draw surfaces overlap. Rebuild the SINGLE word node per round.
	if _current_plaque_word == next_word and is_instance_valid(_teaching_plaque_label):
		return
	_current_plaque_word = next_word
	if not is_instance_valid(_teaching_plaque):
		return
	if is_instance_valid(_teaching_plaque_label):
		var old_label: Label3D = _teaching_plaque_label
		old_label.visible = false
		_teaching_plaque.remove_child(old_label)
		old_label.queue_free()
		_teaching_plaque_label = null
	# Also clear any stale, older-number labels from earlier script versions.
	for child: Node in _teaching_plaque.get_children():
		if child is Label3D:
			_teaching_plaque.remove_child(child)
			child.queue_free()
	var fresh := Label3D.new()
	fresh.name = "WellNumberWord"
	fresh.text = next_word
	fresh.rotation_degrees.x = -90.0
	fresh.position = Vector3(0.0, 0.075, 0.0)
	fresh.font_size = 56
	fresh.pixel_size = 0.0052
	fresh.outline_size = 10
	fresh.modulate = Color(1.0, 0.92, 0.74)
	fresh.shaded = false
	fresh.no_depth_test = false
	fresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fresh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_teaching_plaque.add_child(fresh)
	_teaching_plaque_label = fresh


func _set_control_guide(teaching: bool) -> void:
	# Fit short, distinct labels on one real 3D board.
	var captions: Array[String] = ["E  NEXT", "R  BACK", "F  FINISH"]
	if not teaching:
		captions = ["E  +1", "R  -1", "F  CHECK"]
	for i: int in range(mini(_control_keys.size(), captions.size())):
		_control_keys[i].text = captions[i]


func _process(delta: float) -> void:
	if not is_instance_valid(_elder):
		return
	_sync_dialogue_and_visibility(false)
	_time_passed += delta
	# Slow surface movement gives water life without an expensive shader or particles.
	if is_instance_valid(_water_surface):
		_water_surface.rotation.y = sin(_time_passed * 0.36) * 0.025


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event as InputEventKey
	if not k.pressed or k.echo:
		return
	var wants_e: bool = _pressed(event, "interact", KEY_E)
	var wants_r: bool = _pressed(event, "quest_previous", KEY_R)
	var wants_f: bool = _pressed(event, "quest_submit", KEY_F)
	if not wants_e and not wants_r and not wants_f:
		return

	if _mode == "lesson":
		# Prevent double actions while the stone pop / dim animation finishes.
		if _lesson_animating:
			get_viewport().set_input_as_handled()
			return
		if wants_e:
			if _lesson_index < LESSON_COUNTS.size() - 1:
				_lesson_index += 1
				_show_lesson_page(true)
			else:
				_finish_lesson()
		elif wants_r:
			if _lesson_index > 0:
				_lesson_index -= 1
				_show_lesson_page(true)
		elif wants_f:
			_finish_lesson()
		get_viewport().set_input_as_handled()
		return

	if _mode != "ritual" or not QuestManager.is_quest_active(QUEST_ID):
		return
	if QuestManager.get_current_step(QUEST_ID) != 1:
		return
	if DialogueManager.is_dialogue_active or GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	# Even if the preview is still animating, the player can begin immediately.
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not (_player is Node3D):
		return
	var player: Node3D = _player as Node3D
	var near_well: bool = _is_near_well(player)
	var near_stone: bool = _nearest_stone_index(player) >= 0
	if not near_well and not near_stone:
		return

	# Cancel the non-interactive preview on the player's first input,
	# otherwise its scheduled reset could erase newly selected stones.
	if _guided_hint_delay != null and _guided_hint_delay.is_running():
		_guided_hint_delay.kill()
		if _lesson_tween != null and _lesson_tween.is_running():
			_lesson_tween.kill()
		_lesson_animating = false
		_lesson_displayed_count = 0
		_reset_all_stones()

	# E works by the WELL as well as by its ring of stones.
	# Controls change exactly ONE stone, so moving 8 -> 7 never replays 1..7.
	if wants_e:
		_change_selected_count(1)
	elif wants_r:
		_change_selected_count(-1)
	elif wants_f:
		if near_well:
			_submit_current_answer()
		else:
			_status_label.text = "Stand beside the well to check"
	get_viewport().set_input_as_handled()


func _pressed(event: InputEvent, action: String, keycode: Key) -> bool:
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == keycode or k.physical_keycode == keycode):
			return true
	return InputMap.has_action(action) and event.is_action_pressed(action)


func _on_quest_state_changed(quest_id: String, _quest: QuestData) -> void:
	if quest_id == QUEST_ID:
		call_deferred("_sync_dialogue_and_visibility", true)


func _on_objective_changed(quest_id: String, _step_index: int, _step_data: QuestStep) -> void:
	if quest_id == QUEST_ID:
		call_deferred("_sync_dialogue_and_visibility", true)


func _on_npc_talked(id: String) -> void:
	if id != ELDER_ID:
		return
	if not QuestManager.is_quest_active(QUEST_ID):
		return
	var step: int = QuestManager.get_current_step(QUEST_ID)
	if step == 0 and not QuestManager.has_dialogue_flag(LESSON_DONE_FLAG):
		QuestManager.set_dialogue_flag(LESSON_STARTED_FLAG, true)
		call_deferred("_start_lesson")
		return
	if step == 2 and _well_cleared:
		GameEvents.puzzle_solved.emit(REPORT_EVENT)
		GameManager.request_save()


func _start_lesson() -> void:
	if _mode == "lesson":
		return
	_mode = "lesson"
	_old_camera = get_viewport().get_camera_3d()
	_freeze_player(true)
	if is_instance_valid(_lesson_camera):
		_lesson_camera.current = true
	_lesson_index = 0
	_lesson_displayed_count = 0
	if is_instance_valid(_control_plaque):
		_set_control_guide(true)
		_control_plaque.visible = true
	_instruction_label.text = ""
	_status_label.text = ""
	_reset_all_stones()
	_show_lesson_page(true)


func _show_lesson_page(animate: bool) -> void:
	var count: int = LESSON_COUNTS[_lesson_index]
	var word: String = LESSON_WORDS[_lesson_index]
	# The word plaque updates while the second wooden sign teaches E/R/F.
	_replace_plaque_word("%s   %d" % [word.to_upper(), count])
	_instruction_label.text = ""
	_status_label.text = ""
	if animate:
		_animate_lesson(count)
	else:
		_set_lit_count(count)


func _animate_lesson(target_count: int) -> void:
	# Differential animation: 7 -> 8 lights only stone 8;
	# 8 -> 7 dims only stone 8. The initial 0 -> 7 still teaches sequentially.
	if _lesson_tween != null and _lesson_tween.is_running():
		_lesson_tween.kill()
	_lesson_animating = true
	_lesson_tween = create_tween()
	var from_count: int = _lesson_displayed_count
	if target_count > from_count:
		for i: int in range(from_count, target_count):
			_lesson_tween.tween_callback(Callable(self, "_light_stone_pop").bind(i))
			_lesson_tween.tween_interval(0.24)
	elif target_count < from_count:
		for i: int in range(from_count - 1, target_count - 1, -1):
			_lesson_tween.tween_callback(Callable(self, "_dim_stone_pop").bind(i))
			_lesson_tween.tween_interval(0.24)
	_lesson_displayed_count = target_count
	_lesson_tween.tween_callback(func() -> void:
		_lesson_animating = false
	)


func _dim_stone_pop(index: int) -> void:
	if index < 0 or index >= _stones.size():
		return
	_stop_stone_effect(index)
	_set_stone_appearance(index, false)
	var info: Dictionary = _stones[index]
	var visual: Node3D = info["visual"]
	visual.scale = Vector3.ONE
	visual.position.y = 0.0
	var fade := create_tween()
	_stone_effect_tweens[index] = fade
	fade.tween_property(visual, "scale", Vector3(0.88, 0.88, 0.88), 0.09)
	fade.parallel().tween_property(visual, "position:y", -0.028, 0.09)
	fade.tween_property(visual, "scale", Vector3.ONE, 0.15)
	fade.parallel().tween_property(visual, "position:y", 0.0, 0.15)


func _light_stone_pop(index: int) -> void:
	if index < 0 or index >= _stones.size():
		return
	_stop_stone_effect(index)
	_set_stone_appearance(index, true)
	var stone: Dictionary = _stones[index]
	var visual: Node3D = stone["visual"]
	visual.position.y = 0.0
	visual.scale = Vector3.ONE
	var flash := create_tween()
	_stone_effect_tweens[index] = flash
	flash.tween_property(visual, "scale", Vector3(1.16, 1.16, 1.16), 0.10).set_trans(Tween.TRANS_BACK)
	flash.parallel().tween_property(visual, "position:y", 0.075, 0.10)
	flash.tween_property(visual, "scale", Vector3.ONE, 0.19).set_trans(Tween.TRANS_SINE)
	flash.parallel().tween_property(visual, "position:y", 0.0, 0.19)


func _finish_lesson() -> void:
	if _mode != "lesson":
		return
	_mode = "idle"
	if _lesson_tween != null and _lesson_tween.is_running():
		_lesson_tween.kill()
	_lesson_animating = false
	if is_instance_valid(_control_plaque):
		_set_control_guide(false)
		_control_plaque.visible = true
	_freeze_player(false)
	if is_instance_valid(_old_camera):
		_old_camera.current = true
	elif is_instance_valid(_lesson_camera):
		_lesson_camera.current = false
	QuestManager.set_dialogue_flag(LESSON_DONE_FLAG, true)
	GameEvents.puzzle_solved.emit(LESSON_EVENT)
	GameManager.request_save()
	_begin_ritual()


func _begin_ritual() -> void:
	if _mode == "lesson" or _ritual_active:
		return
	_request_order.clear()
	for value: int in guided_rounds:
		_request_order.append(value)
	for value: int in practice_rounds:
		_request_order.append(value)
	_request_index = 0
	while _request_index < _request_order.size() and QuestManager.has_dialogue_flag(_round_flag(_request_index)):
		_request_index += 1
	_well_cleared = _well_cleared or QuestManager.has_dialogue_flag(WELL_DONE_FLAG)
	if _well_cleared or _request_index >= _request_order.size():
		_mode = "idle"
		_ritual_active = false
		return
	_ritual_active = true
	_mode = "ritual"
	_set_control_guide(false)
	_control_plaque.visible = true
	_reset_all_stones()
	_water.position.y = _water_base_y + water_step_height * float(_request_index)
	_update_ritual_prompt()


func _process_ritual_input() -> void:
	# All ritual keys are now handled once per keypress by _unhandled_input().
	pass


func _submit_current_answer() -> void:
	if _request_index >= _request_order.size():
		return
	var required: int = _request_order[_request_index]
	if _selected_count != required:
		_status_label.text = "WRONG"
		_flash_wrong()
		_reset_selection_only()
		return
	_status_label.text = "Correct!"
	_animate_submit(required)


func _animate_submit(_required: int) -> void:
	# Only animate the VISUAL child. Never move the persistent stone root,
	# stone collider, or its anchored position. This prevents lost stones
	# after submitting nine and then starting the next (ten-stone) round.
	_mode = "success_flash"
	_stop_stone_flights()
	var splash: Tween = create_tween()
	for i: int in range(_stones.size()):
		var info: Dictionary = _stones[i]
		if not bool(info["selected"]):
			continue
		_stop_stone_effect(i)
		var visual: Node3D = info["visual"]
		var home: Vector3 = info["home_position"]
		visual.position = Vector3.ZERO
		visual.scale = Vector3.ONE
		# Visual is a child of a stationary stone root, so this local offset
		# makes the stone fly to the middle of the well without moving its collider.
		var target_offset := Vector3(-home.x, 0.43 - home.y, -home.z)
		var flight: Tween = create_tween()
		flight.set_parallel(true)
		flight.tween_property(visual, "position", target_offset, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		flight.tween_property(visual, "scale", Vector3(0.05, 0.05, 0.05), 0.40)
		_stone_flight_tweens.append(flight)

	splash.tween_interval(0.48)
	splash.tween_callback(func() -> void:
		# Cancel all stone tweens BEFORE resetting transforms. A tween
		# must never overwrite the restored position on the next frame.
		_stop_stone_flights()
		QuestManager.set_dialogue_flag(_round_flag(_request_index), true)
		_raise_water_one_step()
		_request_index += 1
		_reset_all_stones()
		if _request_index >= _request_order.size():
			_complete_ritual()
		else:
			_mode = "ritual"
			_update_ritual_prompt()
		GameManager.request_save()
	)


func _stop_stone_flights() -> void:
	for flight: Tween in _stone_flight_tweens:
		if flight != null and flight.is_running():
			flight.kill()
	_stone_flight_tweens.clear()


func _stop_stone_effect(index: int) -> void:
	if not _stone_effect_tweens.has(index):
		return
	var effect: Tween = _stone_effect_tweens[index]
	if effect != null and effect.is_running():
		effect.kill()
	_stone_effect_tweens.erase(index)


func _stop_all_stone_effects() -> void:
	for index: Variant in _stone_effect_tweens.keys():
		var effect: Tween = _stone_effect_tweens[index]
		if effect != null and effect.is_running():
			effect.kill()
	_stone_effect_tweens.clear()


func _complete_ritual() -> void:
	_ritual_active = false
	_mode = "idle"
	_well_cleared = true
	QuestManager.set_dialogue_flag(WELL_DONE_FLAG, true)
	_replace_plaque_word("RESTORED")
	_instruction_label.text = "Return to the Elder"
	_status_label.text = "WELL RESTORED"
	GameEvents.puzzle_solved.emit(WELL_EVENT)
	GameManager.request_save()
	_sync_dialogue_and_visibility(true)


func _update_ritual_prompt() -> void:
	if _request_index >= _request_order.size():
		return
	var required: int = _request_order[_request_index]
	var word: String = _word_for_count(required)
	_replace_plaque_word(word.to_upper())
	_instruction_label.text = ""
	_status_label.text = "SELECTED: %d / 10" % _selected_count
	# Avoid giving away the answer in practice rounds.
	if _request_index < guided_rounds.size():
		_animate_guided_hint(required)
	else:
		_reset_all_stones()


func _flash_wrong() -> void:
	_status_label.modulate = Color(1.0, 0.43, 0.39)
	var flash := create_tween()
	flash.tween_interval(0.65)
	flash.tween_callback(func() -> void:
		_status_label.modulate = Color.WHITE
		_update_ritual_prompt()
	)


func _toggle_stone(index: int) -> void:
	if index < 0 or index >= _stones.size():
		return
	_stop_stone_effect(index)
	var info: Dictionary = _stones[index]
	var selected: bool = not bool(info["selected"])
	info["selected"] = selected
	_stones[index] = info
	_selected_count += 1 if selected else -1
	_set_stone_appearance(index, selected)
	var visual: Node3D = info["visual"]
	var pulse := create_tween()
	_stone_effect_tweens[index] = pulse
	pulse.tween_property(visual, "scale", Vector3(1.11, 1.11, 1.11), 0.08)
	pulse.tween_property(visual, "scale", Vector3.ONE, 0.15)
	if _request_index < _request_order.size():
		_status_label.text = "SELECTED: %d / 10" % _selected_count
	else:
		_status_label.text = "%d / 10" % _selected_count


func _change_selected_count(change: int) -> void:
	# Works while standing beside the well; no precision clicking required.
	if change > 0:
		for i: int in range(_stones.size()):
			if not bool(_stones[i]["selected"]):
				_toggle_stone(i)
				return
	elif change < 0:
		for i: int in range(_stones.size() - 1, -1, -1):
			if bool(_stones[i]["selected"]):
				_toggle_stone(i)
				return


func _reset_selection_only() -> void:
	_stop_all_stone_effects()
	for i: int in range(_stones.size()):
		var info: Dictionary = _stones[i]
		info["selected"] = false
		_stones[i] = info
		_set_stone_appearance(i, false)
		var visual: Node3D = info["visual"]
		visual.position = Vector3.ZERO
		visual.scale = Vector3.ONE
		visual.visible = true
	_selected_count = 0


func _reset_all_stones() -> void:
	_stop_stone_flights()
	_reset_selection_only()
	for i: int in range(_stones.size()):
		var info: Dictionary = _stones[i]
		var node: Node3D = info["node"]
		var home: Vector3 = info["home_position"]
		# Defensive clamp for a stale, out-of-range height from older installs.
		# X/Z remain unchanged, so the ring and interaction stay aligned.
		home.y = clampf(home.y, -0.42, 0.33)
		node.position = home
		node.scale = Vector3.ONE
		node.visible = true
		var visual: Node3D = info["visual"]
		visual.position = Vector3.ZERO
		visual.scale = Vector3.ONE
		visual.visible = true
		var body: StaticBody3D = info["collider"]
		body.collision_layer = 1 if QuestManager.is_quest_active(QUEST_ID) else 0


func _set_lit_count(count: int) -> void:
	_reset_all_stones()
	for i: int in range(mini(count, _stones.size())):
		_set_stone_appearance(i, true)
	_lesson_displayed_count = count


func _raise_water_one_step() -> void:
	if not is_instance_valid(_water):
		return
	var next_y: float = _water_base_y + water_step_height * float(_request_index + 1)
	var swell: Tween = create_tween()
	swell.tween_property(_water, "position:y", next_y + 0.035, 0.32).set_trans(Tween.TRANS_SINE)
	swell.tween_property(_water, "position:y", next_y, 0.22).set_trans(Tween.TRANS_SINE)


func _nearest_stone_index(player: Node3D) -> int:
	var nearest: int = -1
	# Limit interaction to a stone immediately beside the player.
	var best_distance: float = minf(interaction_distance, 1.22) * minf(interaction_distance, 1.22)
	for i: int in range(_stones.size()):
		var node: Node3D = _stones[i]["node"]
		var distance: float = _horizontal_distance_squared(player, node)
		if distance <= best_distance:
			best_distance = distance
			nearest = i
	return nearest


func _is_near_well(player: Node3D) -> bool:
	var reach: float = maxf(interaction_distance, 2.50)
	return _horizontal_distance_squared(player, _well_root) <= reach * reach


func _horizontal_distance_squared(a: Node3D, b: Node3D) -> float:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return INF
	var delta: Vector3 = a.global_position - b.global_position
	delta.y = 0.0
	return delta.length_squared()


func _sync_dialogue_and_visibility(force: bool) -> void:
	# Physical well and stones belong to the town at all times. Only the
	# lesson's floating text and two teaching plaques belong to the Elder quest.
	if not is_instance_valid(_elder) or not is_instance_valid(_well_root):
		return
	var active: bool = QuestManager.is_quest_active(QUEST_ID)
	var complete: bool = QuestManager.is_quest_completed(QUEST_ID)
	var step: int = QuestManager.get_current_step(QUEST_ID) if active else -1
	var changed: bool = (
		force or active != _last_active
		or complete != _last_complete or step != _last_step
	)
	_last_active = active
	_last_complete = complete
	_last_step = step

	# Never hide or delete the actual well/stone scenery after the quest.
	_well_root.visible = true
	if is_instance_valid(_stone_root):
		_stone_root.visible = true
	if is_instance_valid(_well_collider):
		_well_collider.collision_layer = 1
	for stone: Dictionary in _stones:
		var body: StaticBody3D = stone["collider"]
		body.collision_layer = 1 if active and not complete else 0

	# Apply visibility on EVERY update, including mode changes between idle,
	# teaching and ritual. Do not rely only on quest-start/step signals.
	var show_text: bool = active and not complete
	if is_instance_valid(_instruction_label):
		_instruction_label.visible = show_text and _mode == "idle"
	if is_instance_valid(_status_label):
		_status_label.visible = show_text and _mode != "lesson"
	if is_instance_valid(_teaching_plaque):
		_teaching_plaque.visible = show_text
	if is_instance_valid(_control_plaque):
		_control_plaque.visible = show_text and (_mode == "lesson" or _mode == "ritual")

	if not show_text:
		# Clear the old labels rather than leaving a hidden "RESTORED",
		# number, or E/R/F text that might show up again on scene reload.
		_clear_quest_text()
		if complete and not _finished_visual_cleanup:
			_finished_visual_cleanup = true
			_ritual_active = false
			if _guided_hint_delay != null and _guided_hint_delay.is_running():
				_guided_hint_delay.kill()
			if _lesson_tween != null and _lesson_tween.is_running():
				_lesson_tween.kill()
			_stop_stone_flights()
			_stop_all_stone_effects()
			if _mode == "lesson":
				_freeze_player(false)
				if is_instance_valid(_old_camera):
					_old_camera.current = true
				elif is_instance_valid(_lesson_camera):
					_lesson_camera.current = false
			_mode = "idle"
			_reset_all_stones()
			# Keep the restored water visible, even on a loaded completed save.
			if is_instance_valid(_water):
				_water.position.y = _water_base_y + water_step_height * float(guided_rounds.size() + practice_rounds.size())
		if changed and complete:
			_elder.set("dialogue_id", "SecondTownSceneDialogues/elder_done")
		return

	if not changed:
		return

	match step:
		0:
			_elder.set("dialogue_id", "SecondTownSceneDialogues/elder_quest")
			if not QuestManager.has_dialogue_flag(LESSON_STARTED_FLAG):
				_replace_plaque_word("7 - 10")
				_instruction_label.text = "Talk to the Elder"
				_status_label.text = "Watch the stone lesson"
		1:
			_elder.set("dialogue_id", "SecondTownSceneDialogues/elder_progress")
			if not _ritual_active and not _well_cleared:
				_begin_ritual()
		2:
			_elder.set("dialogue_id", "SecondTownSceneDialogues/elder_progress")
			_instruction_label.text = "Return to the Elder"
			_status_label.text = "The water is restored"
			_replace_plaque_word("RESTORED")


func _clear_quest_text() -> void:
	if is_instance_valid(_instruction_label):
		_instruction_label.text = ""
	if is_instance_valid(_status_label):
		_status_label.text = ""
	if not _current_plaque_word.is_empty():
		_replace_plaque_word("")
	for key: Label3D in _control_keys:
		if is_instance_valid(key):
			key.text = ""


func _freeze_player(should_freeze: bool) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return
	if should_freeze:
		_player_was_physics = _player.is_physics_processing()
		if _player.has_method("is_processing_input"):
			_player_was_input = _player.is_processing_input()
		if _player.has_method("is_processing_unhandled_input"):
			_player_was_unhandled = _player.is_processing_unhandled_input()
		if _player.has_method("set_physics_process"):
			_player.set_physics_process(false)
		if _player.has_method("set_process_input"):
			_player.set_process_input(false)
		if _player.has_method("set_process_unhandled_input"):
			_player.set_process_unhandled_input(false)
	else:
		if _player.has_method("set_physics_process"):
			_player.set_physics_process(_player_was_physics)
		if _player.has_method("set_process_input"):
			_player.set_process_input(_player_was_input)
		if _player.has_method("set_process_unhandled_input"):
			_player.set_process_unhandled_input(_player_was_unhandled)


func _stone_ground_height(at: Vector3) -> float:
	# The well is already grounded. Find ONLY nearby terrain elevation,
	# never tall world objects above the stone ring (especially the tree).
	var base_y: float = _well_root.global_position.y - 0.045
	var start: Vector3 = Vector3(at.x, base_y + 0.72, at.z)
	var finish: Vector3 = Vector3(at.x, base_y - 0.82, at.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, finish)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var ground_point: Vector3 = hit["position"]
		var hit_y: float = ground_point.y
		# Steep walls and upper surfaces of village props are not terrain.
		if normal.y > 0.65 and absf(hit_y - base_y) <= 0.34:
			return hit_y
	# Fall back to the well's ground height; never accept floating stones.
	return base_y


func _ground_height(at: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 16.0, at + Vector3.DOWN * 16.0)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var surface_normal: Vector3 = hit.get("normal", Vector3.UP)
		if surface_normal.y > 0.5:
			var surface_point: Vector3 = hit["position"]
			return surface_point.y
	return _elder.global_position.y - 0.30


func _word_for_count(value: int) -> String:
	for key: String in WORD_TO_COUNT.keys():
		if int(WORD_TO_COUNT[key]) == value:
			return key
	return str(value)


func _set_stone_appearance(index: int, lit: bool) -> void:
	var info: Dictionary = _stones[index]
	info["lit"] = lit
	_stones[index] = info
	var art: MeshInstance3D = info["art"]
	art.material_override = _stone_on_material if lit else _stone_off_material


func _animate_guided_hint(count: int) -> void:
	# Brief show-and-hide preview. The player must still select the stones.
	_reset_all_stones()
	_lesson_displayed_count = 0
	_animate_lesson(count)
	if _guided_hint_delay != null and _guided_hint_delay.is_running():
		_guided_hint_delay.kill()
	_guided_hint_delay = create_tween()
	_guided_hint_delay.tween_interval(float(count) * 0.24 + 0.48)
	_guided_hint_delay.tween_callback(func() -> void:
		if _mode != "ritual":
			return
		_reset_all_stones()
		_lesson_displayed_count = 0
		_status_label.text = "SELECTED: 0 / 10"
	)


func _round_flag(index: int) -> String:
	return "st_elder_well_round_%d_done" % (index + 1)


func _pixel_material(texture: Texture2D, with_alpha: bool = true) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	if with_alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.24
	return mat


func _add_ground_texture(parent: Node3D, item_name: String, texture: Texture2D, dimensions: Vector2, at: Vector3) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = dimensions
	var surface := MeshInstance3D.new()
	surface.name = item_name
	surface.mesh = plane
	surface.material_override = _pixel_material(texture)
	surface.position = at
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)
	return surface


func _add_cylinder(parent: Node3D, item_name: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 20
	var node := MeshInstance3D.new()
	node.name = item_name
	node.mesh = cylinder
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func _material(color: Color, roughness: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.emission_enabled = emission > 0.0
	material.emission = color * max(emission, 0.0)
	return material


func _make_label3d(pos: Vector3, txt: String, color: Color, font_size: int, outline: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.position = pos
	label.text = txt
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.shaded = false
	label.font_size = font_size
	label.outline_size = outline
	label.pixel_size = 0.004
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
