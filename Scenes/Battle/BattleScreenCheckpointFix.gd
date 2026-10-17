extends "res://Scenes/Battle/BattleScreen.gd"

## On normal-battle defeat, returns the player to CheckpointMarker instead of
## simply closing the battle UI. Normal victories and boss review flow are kept.

var _normal_battle_lost: bool = false


func _ready() -> void:
	super._ready()

	# Rebind these two callbacks on this derived script explicitly. This avoids
	# depending on how an inherited script's signal Callable resolves overrides.
	for connection: Dictionary in continue_button.pressed.get_connections():
		var callback: Callable = connection["callable"]
		if callback.get_object() == self:
			continue_button.pressed.disconnect(callback)
	continue_button.pressed.connect(_on_continue_pressed)

	for connection: Dictionary in BattleManager.battle_ended.get_connections():
		var callback: Callable = connection["callable"]
		if (
			callback.get_object() == self
			and callback.get_method() == "_on_battle_ended"
		):
			BattleManager.battle_ended.disconnect(callback)
	BattleManager.battle_ended.connect(_on_battle_ended)


func _on_battle_ended(victory: bool) -> void:
	var enemy_is_boss: bool = (
		BattleManager.current_enemy != null
		and BattleManager.current_enemy.is_boss
	)

	if not enemy_is_boss:
		_normal_battle_lost = not victory

	super._on_battle_ended(victory)

	if not enemy_is_boss:
		continue_button.text = "CONTINUE" if victory else "RETURN TO CHECKPOINT"


func _on_continue_pressed() -> void:
	if not _normal_battle_lost:
		super._on_continue_pressed()
		return

	continue_button.disabled = true
	bottom_bar.visible = false

	_ensure_marker_checkpoint_selected()

	var restored: bool = false
	if is_instance_valid(CheckpointManager):
		restored = await CheckpointManager.restore_checkpoint()

	if not restored:
		# Crucially, do not save the defeated location as the new player save.
		# A failed restore must not turn the battle location into a fake checkpoint.
		push_error(
			"[BATTLE RESPAWN] Checkpoint restoration failed. Check the Output panel "
			+ "for [CHECKPOINT] errors and confirm a CheckpointMarker exists."
		)
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)

	if is_instance_valid(self):
		closed.emit()
		queue_free()


func _ensure_marker_checkpoint_selected() -> void:
	if not is_instance_valid(CheckpointManager):
		return

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
		push_warning("[BATTLE RESPAWN] CheckpointMarker.gd could not be loaded.")
		return

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var origin: Vector3 = player.global_position if is_instance_valid(player) else Vector3.ZERO
	var marker_candidates: Array[Node] = root.find_children("*", "Node3D", true, false)
	var nearest_marker: Node3D = null
	var nearest_distance: float = INF

	for candidate: Node in marker_candidates:
		if candidate.get_script() != marker_script or not (candidate is Node3D):
			continue

		var marker: Node3D = candidate as Node3D
		var distance: float = origin.distance_squared_to(marker.global_position)
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

	var facing_y: float = player.global_rotation.y if is_instance_valid(player) else nearest_marker.global_rotation.y
	CheckpointManager.set_checkpoint(
		nearest_marker.global_transform * spawn_offset,
		str(GameManager.current_level_path),
		facing_y,
		label
	)
	print("[BATTLE RESPAWN] Selected marker '%s' at %s." % [label, str(CheckpointManager.checkpoint_position)])


var _boss_checkpoint_return_in_progress: bool = false


func _on_boss_assessment_finished(victory: bool) -> void:
	# Keep the existing boss-victory rewards/review flow.
	if victory:
		super._on_boss_assessment_finished(true)
		return

	# A defeat should restore the most recent real CheckpointMarker.
	# If only the automatic saved-position fallback exists, choose a marker
	# in the active streamed level before asking CheckpointManager to restore.
	if _boss_checkpoint_return_in_progress:
		return
	_boss_checkpoint_return_in_progress = true

	_ensure_marker_checkpoint_selected()

	var restored: bool = false
	if is_instance_valid(CheckpointManager):
		restored = await CheckpointManager.restore_checkpoint()

	if not restored:
		push_error(
			"[BOSS RESPAWN] Checkpoint restoration failed. "
			+ "Confirm that a CheckpointMarker is present in the loaded level "
			+ "and inspect the [CHECKPOINT] errors in Output."
		)
		if is_instance_valid(GameManager):
			GameManager.set_game_state(GameManager.GameState.EXPLORATION)

		# Keep the review open and let the player retry instead of silently
		# closing at the boss location or saving that location as progress.
		var overlay: Node = get_node_or_null("BossAssessmentOverlay")
		if is_instance_valid(overlay) and overlay.has_method("show_checkpoint_error"):
			overlay.call(
				"show_checkpoint_error",
				"Could not restore the checkpoint. Check that the town's "
				+ "CheckpointMarker has been activated, then press retry."
			)
		_boss_checkpoint_return_in_progress = false
		return

	if is_instance_valid(self):
		closed.emit()
		queue_free()
