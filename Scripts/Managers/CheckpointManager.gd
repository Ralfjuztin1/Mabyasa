extends Node

## Runtime checkpoint state for the Main scene's streamed world levels.
## Register this script as the CheckpointManager Autoload.

const BOOTSTRAP_SCENE_PATH: String = "res://Scenes/SceneManager/Main.tscn"
const RESPAWN_HP_FRACTION: float = 0.05
const MAX_LEVEL_LOAD_FRAMES: int = 1800

var has_checkpoint: bool = false
var checkpoint_position: Vector3 = Vector3.ZERO
var checkpoint_rotation_y: float = 0.0
var checkpoint_scene_path: String = ""
var checkpoint_label: String = "Checkpoint"


func _ready() -> void:
	# Autoloads initialize before the gameplay level. Wait until Main.gd has
	# finished placing/activating the player, then record the initial spawn as
	# a safe fallback. Any actual CheckpointMarker can replace this afterward.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_capture_initial_spawn_checkpoint")


func _capture_initial_spawn_checkpoint() -> void:
	var tree := get_tree()

	for _frame in range(MAX_LEVEL_LOAD_FRAMES):
		await tree.process_frame

		if has_checkpoint:
			return

		var root := tree.current_scene
		if not is_instance_valid(root) or not root.has_method("load_new_level_async"):
			continue

		# Main.gd keeps the bootstrap scene and streams the real level inside it.
		if bool(root.get("is_loading")):
			continue

		var player := tree.get_first_node_in_group("player") as Node3D
		if player == null or not player.visible:
			continue

		if _get_gameplay_scene_path().is_empty():
			continue

		# Let the spawn/physics setup settle. If a checkpoint marker registered
		# during these frames, preserve that more specific checkpoint.
		await tree.physics_frame
		await tree.physics_frame

		if has_checkpoint:
			return
		if not is_instance_valid(player):
			continue

		set_checkpoint_from_player(player, "Initial Spawn")
		return

	push_warning("[CHECKPOINT] Initial spawn checkpoint was not captured. Check the player group and Main level loading.")


func set_checkpoint(
	world_position: Vector3,
	scene_path: String = "",
	rotation_y: float = 0.0,
	label: String = "Checkpoint"
) -> void:
	var resolved_scene_path := scene_path.strip_edges()

	# The game keeps Main.tscn as a persistent root and loads FirstTown or
	# other gameplay scenes under Main/LevelContainer. Never save Main.tscn
	# as the checkpoint's gameplay-level path.
	if resolved_scene_path.is_empty() or resolved_scene_path == BOOTSTRAP_SCENE_PATH:
		resolved_scene_path = _get_gameplay_scene_path()

	if resolved_scene_path.is_empty() or not ResourceLoader.exists(resolved_scene_path):
		push_warning("[CHECKPOINT] Could not set checkpoint. Invalid gameplay scene path: " + resolved_scene_path)
		return

	checkpoint_position = world_position
	checkpoint_rotation_y = rotation_y
	checkpoint_scene_path = resolved_scene_path
	checkpoint_label = label if not label.strip_edges().is_empty() else "Checkpoint"
	has_checkpoint = true
	print("[CHECKPOINT] Set '%s' at %s in %s" % [checkpoint_label, str(checkpoint_position), checkpoint_scene_path])


func set_checkpoint_from_player(player: Node3D, label: String = "Checkpoint") -> void:
	if not is_instance_valid(player):
		return
	set_checkpoint(
		player.global_position,
		_get_gameplay_scene_path(),
		player.global_rotation.y,
		label
	)


func ensure_checkpoint_at_player() -> void:
	if has_checkpoint:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("[CHECKPOINT] No player found; could not create fallback checkpoint.")
		return
	set_checkpoint_from_player(player, "Boss Encounter Fallback")


func restore_checkpoint() -> bool:
	# Never create a checkpoint at defeat time: the player would still be at
	# the boss, which would make the boss position the new "checkpoint."
	if not has_checkpoint:
		push_error("[CHECKPOINT] No checkpoint is registered. No defeat-location fallback was created.")
		ensure_respawn_hp()
		return false

	# GameManager.current_level_path tracks the actual active level. The
	# SceneTree current_scene is normally Main.tscn and is not the level.
	var active_level_path := _get_gameplay_scene_path()
	if active_level_path != checkpoint_scene_path:
		var loaded: bool = await _load_gameplay_level(checkpoint_scene_path)
		if not loaded:
			push_error("[CHECKPOINT] Could not load checkpoint level: " + checkpoint_scene_path)
			ensure_respawn_hp()
			return false

	var tree := get_tree()
	var player := tree.get_first_node_in_group("player") as Node3D
	if player == null:
		# Level loading is asynchronous in Main.gd. Give the player a brief
		# chance to be available before treating this as a failure.
		for _frame in range(120):
			await tree.process_frame
			player = tree.get_first_node_in_group("player") as Node3D
			if player != null:
				break

	if player == null:
		push_error("[CHECKPOINT] Player not found after level restore.")
		ensure_respawn_hp()
		return false

	if player is CharacterBody3D:
		(player as CharacterBody3D).set_physics_process(false)
		(player as CharacterBody3D).velocity = Vector3.ZERO

	player.global_position = checkpoint_position
	player.global_rotation.y = checkpoint_rotation_y

	# Wait for physics to register the teleported position before movement resumes.
	await tree.physics_frame
	await tree.physics_frame

	if not is_instance_valid(player):
		push_error("[CHECKPOINT] Player was removed during position restoration.")
		ensure_respawn_hp()
		return false

	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
		(player as CharacterBody3D).set_physics_process(true)

	ensure_respawn_hp()

	if is_instance_valid(GameManager):
		GameManager.current_level_path = checkpoint_scene_path
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)
		if GameManager.has_method("request_save"):
			GameManager.request_save()

	print("[CHECKPOINT] Restored '%s' at %s with %d/%d HP." % [
		checkpoint_label,
		str(player.global_position),
		PlayerProgression.current_hp if is_instance_valid(PlayerProgression) else 0,
		PlayerProgression.get_total_max_hp() if is_instance_valid(PlayerProgression) else 0
	])
	return true


func ensure_respawn_hp() -> void:
	if not is_instance_valid(PlayerProgression):
		return

	var max_hp: int = maxi(PlayerProgression.get_total_max_hp(), 1)
	var minimum_hp: int = maxi(1, int(ceil(float(max_hp) * RESPAWN_HP_FRACTION)))

	if PlayerProgression.current_hp < minimum_hp:
		PlayerProgression.current_hp = minimum_hp
		if PlayerProgression.has_signal("hp_changed"):
			PlayerProgression.hp_changed.emit()
		if PlayerProgression.has_signal("stats_changed"):
			PlayerProgression.stats_changed.emit()


func clear_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_position = Vector3.ZERO
	checkpoint_rotation_y = 0.0
	checkpoint_scene_path = ""
	checkpoint_label = "Checkpoint"


func _load_gameplay_level(level_path: String) -> bool:
	var tree := get_tree()
	var root := tree.current_scene

	# Mabiyasa keeps Main.tscn alive and streams gameplay scenes inside it.
	# Use its level loader instead of change_scene_to_file(), which would
	# destroy the persistent player/HUD/scene manager.
	if is_instance_valid(root) and root.has_method("load_new_level_async"):
		if bool(root.get("is_loading")):
			for _frame in range(MAX_LEVEL_LOAD_FRAMES):
				await tree.process_frame
				if not is_instance_valid(root) or not bool(root.get("is_loading")):
					break
			if not is_instance_valid(root) or bool(root.get("is_loading")):
				return false

		root.call("load_new_level_async", level_path, "")
		for _frame in range(MAX_LEVEL_LOAD_FRAMES):
			await tree.process_frame
			if not is_instance_valid(root):
				return false
			if not bool(root.get("is_loading")):
				if is_instance_valid(GameManager) and GameManager.current_level_path == level_path:
					await tree.physics_frame
					await tree.physics_frame
					return true
				push_error("[CHECKPOINT] Level loader stopped before loading " + level_path)
				return false

		push_error("[CHECKPOINT] Timed out waiting for level loader: " + level_path)
		return false

	# Fallback for projects where the gameplay level itself is current_scene.
	if is_instance_valid(root) and root.scene_file_path == level_path:
		return true

	var error: Error = tree.change_scene_to_file(level_path)
	if error != OK:
		push_error("[CHECKPOINT] change_scene_to_file failed for %s (error %d)." % [level_path, error])
		return false

	await tree.scene_changed
	await tree.process_frame
	await tree.physics_frame
	if is_instance_valid(GameManager):
		GameManager.current_level_path = level_path
	return true


func _get_gameplay_scene_path() -> String:
	if is_instance_valid(GameManager):
		var path := str(GameManager.current_level_path).strip_edges()
		if not path.is_empty() and path != BOOTSTRAP_SCENE_PATH and ResourceLoader.exists(path):
			return path

	var current_scene := get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		if current_scene.scene_file_path != BOOTSTRAP_SCENE_PATH:
			return current_scene.scene_file_path

	return ""
