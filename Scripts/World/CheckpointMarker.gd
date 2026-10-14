extends Area3D

## Place this Area3D at a safe location. The player must be in the "player" group.
## The saved path is the active gameplay level, not the persistent Main.tscn root.

@export var checkpoint_label: String = "Checkpoint"
@export var spawn_offset: Vector3 = Vector3(0.0, 0.0, 1.5)


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	call_deferred("_check_existing_overlaps")


func _check_existing_overlaps() -> void:
	for body: Node3D in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var checkpoint_manager := get_node_or_null("/root/CheckpointManager")
	if checkpoint_manager == null:
		push_error("[CHECKPOINT] Autoload '/root/CheckpointManager' is missing. Add Scripts/Managers/CheckpointManager.gd in Project Settings > Autoload.")
		return

	var scene_path := ""
	if is_instance_valid(GameManager):
		scene_path = str(GameManager.current_level_path)

	checkpoint_manager.call(
		"set_checkpoint",
		global_transform * spawn_offset,
		scene_path,
		body.global_rotation.y,
		checkpoint_label
	)
