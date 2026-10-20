extends Area3D

## Returns the player from the Forest to FirstTown.
## FirstTown already contains a Marker3D named ForestGateReturnPoint.

@export_file("*.tscn") var target_scene_path: String = "res://Scenes/Main/FirstTown.tscn"
@export var target_spawn_name: String = "ForestGateReturnPoint"

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
	if BattleManager.battle_active or DialogueManager.is_dialogue_active:
		return

	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main) or not main.has_method("load_new_level_async"):
		push_error("[FOREST RETURN] Main scene manager or load_new_level_async() was not found.")
		return
	if not ResourceLoader.exists(target_scene_path):
		push_error("[FOREST RETURN] FirstTown scene was not found: " + target_scene_path)
		return

	_transitioning = true
	print("[FOREST RETURN] Returning to FirstTown...")
	main.call_deferred("load_new_level_async", target_scene_path, target_spawn_name)
