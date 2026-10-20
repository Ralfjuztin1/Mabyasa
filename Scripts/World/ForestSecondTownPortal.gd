extends Area3D

## Portal toward Town 2. It stays blocked until the Mystic Ylang-Ylang is obtained.
## Since SecondTown.tscn does not exist yet, this script safely stays in the Forest
## and plays a temporary explanation after the flower has been collected.

@export_file("*.tscn") var target_scene_path: String = "res://Scenes/Main/SecondTown.tscn"
@export var target_spawn_name: String = "DefaultSpawn"
@export var required_item_flag: String = "mystic_ylang_ylang_obtained"

const LOCKED_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/ForestSceneDialogues/litik_second_town_locked.dtl"
const UNAVAILABLE_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/ForestSceneDialogues/litik_second_town_unavailable.dtl"

var _transitioning: bool = false
var _dialogue_started_here: bool = false


func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if _transitioning or _dialogue_started_here:
		return
	if BattleManager.battle_active or DialogueManager.is_dialogue_active:
		return

	# The next town cannot be entered before obtaining the flower.
	if not QuestManager.has_dialogue_flag(required_item_flag):
		print("[FOREST PORTAL] Locked. Find the Mystic Ylang-Ylang first.")
		if not QuestManager.has_dialogue_flag("litik_second_town_warning_seen"):
			_dialogue_started_here = DialogueManager.start_forest_scene_dialogue(LOCKED_TIMELINE)
		return

	# Do not try to load a scene that has not been created yet.
	if not ResourceLoader.exists(target_scene_path):
		push_warning("[FOREST PORTAL] The Mystic Ylang-Ylang is obtained, but SecondTown.tscn does not exist yet.")
		if not QuestManager.has_dialogue_flag("litik_second_town_unavailable_seen"):
			_dialogue_started_here = DialogueManager.start_forest_scene_dialogue(UNAVAILABLE_TIMELINE)
		return

	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main) or not main.has_method("load_new_level_async"):
		push_error("[FOREST PORTAL] Main scene manager or load_new_level_async() was not found.")
		return

	_transitioning = true
	print("[FOREST PORTAL] Mystic Ylang-Ylang acquired. Loading Second Town...")
	main.call_deferred("load_new_level_async", target_scene_path, target_spawn_name)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_dialogue_started_here = false
