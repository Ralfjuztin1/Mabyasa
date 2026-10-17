class_name CutsceneDirector
extends Node

## High-level, reusable cutscene sequencer for MABIYASA.
## Child CutsceneAction and CutsceneParallel nodes execute in tree order.
## Story requirements and completion flags are configured in the Inspector.

@export_category("Sequence")
@export var play_on_ready: bool = false
@export_range(0.0, 10.0, 0.05) var start_delay: float = 0.0
@export var end_cutscene_automatically: bool = true

@export_category("Story Flags")
## A readable ID used for debugging. It does not itself create a story flag.
@export var cutscene_id: String = ""
## Every non-empty flag here must be true before this cutscene can play.
@export var required_flags: Array[String] = []
## If any non-empty flag here is true, this cutscene cannot play.
@export var blocked_flags: Array[String] = []
## This flag is set to true only after this sequence finishes successfully.
@export var completion_flag: String = ""
## If true, the completion flag prevents the director from playing again.
@export var prevent_replay_when_completed: bool = true

var is_playing: bool = false
var _controller: CutsceneController = null


func _ready() -> void:
	if play_on_ready:
		call_deferred("play_sequence")


# ============================================================
# STORY FLAG API
# ============================================================

func can_play_sequence() -> bool:
	if is_playing:
		return false

	if prevent_replay_when_completed and is_completed():
		return false

	for flag: String in required_flags:
		var clean_flag: String = flag.strip_edges()
		if clean_flag.is_empty():
			continue
		if not QuestManager.has_dialogue_flag(clean_flag):
			return false

	for flag: String in blocked_flags:
		var clean_flag: String = flag.strip_edges()
		if clean_flag.is_empty():
			continue
		if QuestManager.has_dialogue_flag(clean_flag):
			return false

	return true


func is_completed() -> bool:
	var flag: String = completion_flag.strip_edges()
	if flag.is_empty():
		return false
	return QuestManager.has_dialogue_flag(flag)


func get_debug_id() -> String:
	if not cutscene_id.strip_edges().is_empty():
		return cutscene_id.strip_edges()
	return name


# ============================================================
# PUBLIC API
# ============================================================

func play_sequence() -> bool:
	if not can_play_sequence():
		print(
			"[CUTSCENE DIRECTOR] Not ready or already completed: ",
			get_debug_id()
		)
		return false

	_controller = _find_controller()
	if not is_instance_valid(_controller):
		push_error(
			"[CUTSCENE DIRECTOR] CutsceneController could not be found for: "
			+ get_debug_id()
		)
		return false

	is_playing = true

	if start_delay > 0.0:
		await _controller.wait(start_delay)

	if not is_playing:
		return false

	if not _controller.begin_cutscene():
		is_playing = false
		return false

	print("[CUTSCENE DIRECTOR] Sequence started: ", get_debug_id())

	for child: Node in get_children():
		if not is_playing:
			break

		if child is CutsceneAction or child is CutsceneParallel:
			await child.execute(self)

	if end_cutscene_automatically and is_instance_valid(_controller):
		if _controller.is_cutscene_active:
			await _controller.end_cutscene()

	var finished_successfully: bool = is_playing
	is_playing = false

	if finished_successfully:
		var flag: String = completion_flag.strip_edges()
		if not flag.is_empty():
			QuestManager.set_dialogue_flag(flag, true)
			print(
				"[CUTSCENE DIRECTOR] Completion flag set: ",
				flag
			)

		print("[CUTSCENE DIRECTOR] Sequence finished: ", get_debug_id())
		return true

	print("[CUTSCENE DIRECTOR] Sequence stopped: ", get_debug_id())
	return false


func stop_sequence() -> void:
	is_playing = false

	if is_instance_valid(_controller) and _controller.is_cutscene_active:
		await _controller.end_cutscene()


# ============================================================
# ACTION EXECUTION
# ============================================================

func execute_action(action: CutsceneAction) -> void:
	if not is_instance_valid(action):
		return

	match action.action_type:
		CutsceneAction.ActionType.WAIT:
			await _controller.wait(action.seconds)

		CutsceneAction.ActionType.TELEPORT:
			var teleport_actor := resolve_actor(action.actor_id)
			var teleport_target := resolve_point(action.target_id)
			if teleport_actor == null or teleport_target == null:
				return
			teleport_actor_to(
				teleport_actor,
				teleport_target,
				action.reset_visual_state,
				action.copy_target_y_rotation
			)

		CutsceneAction.ActionType.MOVE:
			var move_actor := resolve_actor(action.actor_id)
			var move_target := resolve_point(action.target_id)
			if move_actor == null or move_target == null:
				return
			await move_actor_to(
				move_actor,
				move_target.global_position,
				action.stopping_distance
			)

		CutsceneAction.ActionType.FACE_ACTOR:
			var facing_actor := resolve_actor(action.actor_id)
			var facing_target_actor := resolve_actor(action.target_actor_id)
			if facing_actor == null or facing_target_actor == null:
				return
			face_actor_to_actor(facing_actor, facing_target_actor)

		CutsceneAction.ActionType.FACE_POINT:
			var point_actor := resolve_actor(action.actor_id)
			var point_target := resolve_point(action.target_id)
			if point_actor == null or point_target == null:
				return
			face_actor_to_position(point_actor, point_target.global_position)

		CutsceneAction.ActionType.FACE_DIRECTION:
			var direction_actor := resolve_actor(action.actor_id)
			if direction_actor == null:
				return
			face_actor_to_direction(direction_actor, action.face_direction)

		CutsceneAction.ActionType.PLAY_ANIMATION:
			var animation_actor := resolve_actor(action.actor_id)
			if animation_actor == null:
				return
			set_actor_animation(animation_actor, action.animation_name)

		CutsceneAction.ActionType.DIALOGUE:
			var dialogue_path: String = action.timeline_path
			if dialogue_path.is_empty():
				dialogue_path = _find_legacy_dialogue_path()
			await _controller.play_dialogue(dialogue_path)

		CutsceneAction.ActionType.CAMERA_SHOT:
			var camera_marker := resolve_point(action.target_id)
			if camera_marker == null:
				return
			await _controller.camera_shot(camera_marker, action.fade_duration)

		CutsceneAction.ActionType.RETURN_CAMERA:
			await _controller.return_to_player_camera(action.fade_duration)

		CutsceneAction.ActionType.FADE_OUT:
			await TransitionManager.fade_out(action.fade_duration)

		CutsceneAction.ActionType.FADE_IN:
			await TransitionManager.fade_in(action.fade_duration)

		CutsceneAction.ActionType.SHOW_HIDE:
			var visibility_actor := resolve_actor(action.actor_id)
			if visibility_actor == null:
				return
			visibility_actor.visible = action.visible_state


# ============================================================
# ACTOR CONTROL
# ============================================================

func teleport_actor_to(
	actor: Node3D,
	target: Node3D,
	reset_visual_state: bool = true,
	copy_target_y_rotation: bool = false
) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return

	var body: CharacterBody3D = null
	if actor is CharacterBody3D:
		body = actor as CharacterBody3D
		body.velocity = Vector3.ZERO

	actor.global_position = target.global_position
	if copy_target_y_rotation:
		actor.global_rotation.y = target.global_rotation.y

	if reset_visual_state:
		reset_actor_visual(actor)

	if body != null:
		await get_tree().physics_frame
		body.velocity = Vector3.ZERO


func move_actor_to(
	actor: Node3D,
	target_position: Vector3,
	stopping_distance: float = 0.05
) -> void:
	if not is_instance_valid(actor):
		return

	if actor == resolve_actor("Player"):
		await _controller.move_player_to(target_position, stopping_distance)
		return

	if actor is CharacterBody3D:
		await _controller.move_npc_to(actor as CharacterBody3D, target_position, stopping_distance)
		return

	push_warning("[CUTSCENE DIRECTOR] Actor cannot be moved: " + actor.name)


func face_actor_to_actor(actor: Node3D, target: Node3D) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return
	face_actor_to_position(actor, target.global_position)


func face_actor_to_position(actor: Node3D, position: Vector3) -> void:
	if not is_instance_valid(actor):
		return
	var direction: Vector3 = position - actor.global_position
	direction.y = 0.0
	face_actor_to_direction(actor, direction)


func face_actor_to_direction(actor: Node3D, direction: Vector3) -> void:
	if not is_instance_valid(actor):
		return
	var flat_direction: Vector3 = direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() <= 0.000001:
		return
	flat_direction = flat_direction.normalized()
	actor.global_rotation.y = atan2(flat_direction.x, flat_direction.z)

	if actor.get("last_movement_direction") is Vector3:
		actor.set("last_movement_direction", flat_direction)


func set_actor_animation(actor: Node3D, animation_name: String) -> void:
	if not is_instance_valid(actor) or animation_name.is_empty():
		return

	var sprite := _find_animated_sprite(actor)
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		push_warning(
			"[CUTSCENE DIRECTOR] Animation '" + animation_name
			+ "' not found on " + actor.name
		)
		return
	sprite.play(animation_name)


func reset_actor_visual(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	var sprite := _find_animated_sprite(actor)
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return

	sprite.stop()
	if sprite.sprite_frames.has_animation("idle_front"):
		sprite.play("idle_front")
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _find_animated_sprite(node: Node) -> AnimatedSprite3D:
	if node is AnimatedSprite3D:
		return node as AnimatedSprite3D
	for child: Node in node.get_children():
		var found := _find_animated_sprite(child)
		if is_instance_valid(found):
			return found
	return null


# ============================================================
# DIALOGUE / NODE RESOLUTION
# ============================================================

func _find_legacy_dialogue_path() -> String:
	var level_root := _find_level_root()
	if not is_instance_valid(level_root):
		return ""

	var legacy := level_root.get_node_or_null("FirstTownIntro")
	if legacy == null:
		legacy = level_root.find_child("FirstTownIntro", true, false)

	if legacy != null:
		var path: Variant = legacy.get("intro_timeline")
		if path is String:
			return path
	return ""


func resolve_actor(actor_id: String) -> Node3D:
	if actor_id.is_empty():
		return null

	var normalized: String = actor_id.to_lower()
	if normalized == "player" or normalized == "mc":
		return get_tree().get_first_node_in_group("player") as Node3D

	var level_root := _find_level_root()
	if not is_instance_valid(level_root):
		return null

	var direct_npc := level_root.get_node_or_null("npc/" + actor_id)
	if direct_npc is Node3D:
		return direct_npc as Node3D

	var direct_node := level_root.get_node_or_null(actor_id)
	if direct_node is Node3D:
		return direct_node as Node3D

	var recursive := level_root.find_child(actor_id, true, false)
	if recursive is Node3D:
		return recursive as Node3D

	push_warning("[CUTSCENE DIRECTOR] Actor not found: " + actor_id)
	return null


func resolve_point(point_id: String) -> Node3D:
	if point_id.is_empty():
		return null

	var level_root := _find_level_root()
	if not is_instance_valid(level_root):
		return null

	var direct_point := level_root.get_node_or_null("CutscenePoints/" + point_id)
	if direct_point is Node3D:
		return direct_point as Node3D

	var recursive := level_root.find_child(point_id, true, false)
	if recursive is Node3D:
		return recursive as Node3D

	push_warning("[CUTSCENE DIRECTOR] Point not found: " + point_id)
	return null


func _find_level_root() -> Node:
	var current: Node = self
	while is_instance_valid(current):
		if (
			current.get_node_or_null("CutscenePoints") != null
			or current.get_node_or_null("npc") != null
		):
			return current
		current = current.get_parent()
	return null


func _find_controller() -> CutsceneController:
	var controller := get_tree().get_first_node_in_group("cutscene_controller") as CutsceneController
	if is_instance_valid(controller):
		return controller
	return get_tree().root.find_child("CutsceneController", true, false) as CutsceneController
