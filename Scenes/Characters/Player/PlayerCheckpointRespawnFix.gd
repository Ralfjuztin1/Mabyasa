extends "res://Scenes/Characters/Player/player.gd"

## Makes world-fall respawning use the CheckpointMarker recorded by CheckpointManager.
## If only the automatic "Initial Spawn" fallback is active, prefer a real
## CheckpointMarker in the loaded level (such as the town's big tree marker).

var _checkpoint_respawn_in_progress: bool = false


func _respawn_at_checkpoint() -> void:
	if _checkpoint_respawn_in_progress:
		return

	_checkpoint_respawn_in_progress = true
	is_respawning = true
	_reset_footstep_state()
	velocity = Vector3.ZERO
	set_physics_process(false)

	print("[PLAYER RESPAWN] Restoring the registered CheckpointMarker.")

	if TransitionManager:
		await TransitionManager.fade_out(0.3)

	_ensure_marker_checkpoint_selected()

	var restored: bool = false
	if is_instance_valid(CheckpointManager):
		restored = await CheckpointManager.restore_checkpoint()

	# Emergency fallback only if checkpoint restoration genuinely failed.
	# This prevents leaving the player below the world, but does not save the
	# defeat/fall location or overwrite a real marker checkpoint.
	if not restored:
		push_error(
			"[PLAYER RESPAWN] Checkpoint restore failed. Check the Output panel "
			+ "for [CHECKPOINT] errors and confirm a CheckpointMarker is active."
		)
		_fallback_to_safe_spawn()

	velocity = Vector3.ZERO
	camera_yaw = global_rotation.y
	set_physics_process(false)
	await get_tree().physics_frame

	if TransitionManager:
		await TransitionManager.fade_in(0.4)

	set_physics_process(true)
	is_respawning = false
	_checkpoint_respawn_in_progress = false


func _ensure_marker_checkpoint_selected() -> void:
	if not is_instance_valid(CheckpointManager):
		return

	# Preserve a real checkpoint already activated by walking into its area.
	# "Initial Spawn" is only a fallback based on the loaded/save position,
	# so prefer a CheckpointMarker if one exists in the active level.
	var existing_label: String = str(CheckpointManager.checkpoint_label)
	var is_only_fallback: bool = (
		not CheckpointManager.has_checkpoint
		or existing_label == "Initial Spawn"
		or existing_label == "Boss Encounter Fallback"
	)
	if not is_only_fallback:
		return

	var root: Node = get_tree().current_scene
	if not is_instance_valid(root):
		return

	var marker_script: Script = load("res://Scripts/World/CheckpointMarker.gd") as Script
	if marker_script == null:
		push_warning("[PLAYER RESPAWN] CheckpointMarker.gd could not be loaded.")
		return

	var marker_candidates: Array[Node] = root.find_children("*", "Node3D", true, false)
	var nearest_marker: Node3D = null
	var nearest_distance: float = INF

	for candidate: Node in marker_candidates:
		if candidate.get_script() != marker_script:
			continue
		if not (candidate is Node3D):
			continue

		var marker: Node3D = candidate as Node3D
		var distance: float = global_position.distance_squared_to(marker.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_marker = marker

	if nearest_marker == null:
		return

	var offset_value: Variant = nearest_marker.get("spawn_offset")
	var spawn_offset: Vector3 = Vector3.ZERO
	if offset_value is Vector3:
		spawn_offset = offset_value

	var label: String = str(nearest_marker.get("checkpoint_label"))
	if label.strip_edges().is_empty():
		label = "Checkpoint"

	var facing_y: float = global_rotation.y
	CheckpointManager.set_checkpoint(
		nearest_marker.global_transform * spawn_offset,
		str(GameManager.current_level_path),
		facing_y,
		label
	)
	print("[PLAYER RESPAWN] Selected marker '%s' at %s." % [label, str(CheckpointManager.checkpoint_position)])


func _fallback_to_safe_spawn() -> void:
	# Same emergency fallback used by the original player script. This is only
	# reached when the checkpoint manager reports failure.
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		global_position = Vector3(0.0, 5.0, 0.0)
		return

	var level_container: Node = scene_root.find_child("LevelContainer", true, false)
	var spawn_point: Node = null
	if is_instance_valid(level_container) and level_container.get_child_count() > 0:
		spawn_point = level_container.get_child(0).find_child("DefaultSpawn", true, false)

	if spawn_point is Node3D:
		global_position = (spawn_point as Node3D).global_position
	else:
		global_position = Vector3(0.0, 5.0, 0.0)
