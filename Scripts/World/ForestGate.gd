extends Area3D

## Blocks access to the Forest until the player defeats Chief's final trial.
## Add this to an Area3D at the FirstTown forest entrance.

@export_file("*.tscn") var target_scene_path: String = "res://Scenes/Main/Forest.tscn"
@export var target_spawn_name: String = "DefaultSpawn"
@export var required_quest_id: String = "defeat_chief_final_training"
## Assign a Marker3D placed safely behind the gate in FirstTown.
@export var locked_return_point: Marker3D

var _transitioning: bool = false


func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if _transitioning:
		return

	if not QuestManager.is_quest_completed(required_quest_id):
		print("[FOREST GATE] Locked. Defeat Chief's final training battle first.")
		if is_instance_valid(locked_return_point):
			body.set_deferred("global_position", locked_return_point.global_position)
			if body is CharacterBody3D:
				body.set_deferred("velocity", Vector3.ZERO)
		else:
			push_error("[FOREST GATE] Assign locked_return_point so the locked gate can block the player.")
		return

	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main):
		push_error("[FOREST GATE] Main scene manager was not found.")
		return
	if not main.has_method("load_new_level_async"):
		push_error("[FOREST GATE] Main is missing load_new_level_async().")
		return
	if not ResourceLoader.exists(target_scene_path):
		push_error("[FOREST GATE] Target scene does not exist: " + target_scene_path)
		return

	_transitioning = true
	main.call_deferred("load_new_level_async", target_scene_path, target_spawn_name)
