extends Area3D

## Forest passage toward Second Town. Litik guides the player here after
## recovering the flower. The second objective finishes only in Second Town.

@export_file("*.tscn") var target_scene_path: String = "res://Scenes/Main/SecondTown.tscn"
@export var target_spawn_name: String = "DefaultSpawn"
@export var required_item_flag: String = "mystic_ylang_ylang_obtained"

const FOLLOWUP_QUEST: String = "follow_litik_to_second_town"
const BRIEFING_FLAG: String = "litik_after_ylang_briefing_done"
const ROAD_LOCATION_ID: String = "forest_second_town_path"
const LOCKED_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/ForestSceneDialogues/litik_second_town_locked.dtl"
const UNAVAILABLE_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/ForestSceneDialogues/litik_second_town_unavailable.dtl"

var _transitioning: bool = false
var _dialogue_started_here: bool = false
var _road_reached_this_visit: bool = false


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

	if not QuestManager.has_dialogue_flag(required_item_flag):
		print("[FOREST PORTAL] The flower must be collected first.")
		_dialogue_started_here = DialogueManager.start_forest_scene_dialogue(LOCKED_TIMELINE)
		return

	# Litik's first conversation is part of the chapter. Do not skip it by
	# sprinting into the portal before the queued dialogue begins.
	if not QuestManager.has_dialogue_flag(BRIEFING_FLAG):
		return

	if not QuestManager.is_quest_active(FOLLOWUP_QUEST) and not QuestManager.is_quest_completed(FOLLOWUP_QUEST):
		if QuestManager.get_quest(FOLLOWUP_QUEST) != null:
			QuestManager.start_quest(FOLLOWUP_QUEST)

	# Completing this first objective does NOT imply arriving in Second Town.
	if not _road_reached_this_visit:
		_road_reached_this_visit = true
		GameEvents.location_reached.emit(ROAD_LOCATION_ID)
		print("[FOREST PORTAL] Player reached the route to Second Town.")

	if not ResourceLoader.exists(target_scene_path):
		# SecondTown.tscn is not in the current repository. Keep the second
		# objective pending and explain why the route is not yet usable.
		push_warning("[FOREST PORTAL] SecondTown.tscn has not been created yet.")
		_dialogue_started_here = DialogueManager.start_forest_scene_dialogue(UNAVAILABLE_TIMELINE)
		return

	var main: Node = get_tree().root.get_node_or_null("Main")
	if not is_instance_valid(main) or not main.has_method("load_new_level_async"):
		push_error("[FOREST PORTAL] Main or load_new_level_async() missing.")
		return

	_transitioning = true
	print("[FOREST PORTAL] Taking the player to Second Town...")
	main.call_deferred("load_new_level_async", target_scene_path, target_spawn_name)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_dialogue_started_here = false
		_road_reached_this_visit = false
