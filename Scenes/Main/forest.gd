extends Node3D

## Forest chapter handoff: Guardian -> Mystic Ylang-Ylang -> Litik -> next town.
## All terrain initialization and current Forest quest logic are retained.

const FLOWER_QUEST: String = "get_mystic_ylang_ylang"
const NEXT_TOWN_QUEST: String = "follow_litik_to_second_town"
const FLOWER_COLLECTED_FLAG: String = "mystic_ylang_ylang_obtained"
const LITIK_BRIEFING_FLAG: String = "litik_after_ylang_briefing_done"
const LITIK_BRIEFING_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/ForestSceneDialogues/litik_after_ylang.dtl"
const SECOND_TOWN_PORTAL_SCENE: String = "res://Scenes/World/ForestSecondTownPortal.tscn"

# Forest.tscn does not currently instance ForestSecondTownPortal.tscn.
# Position it relative to the existing MysticYlangYlang node, so the original
# Forest scene and terrain files do not need replacing.
@export var second_town_portal_offset: Vector3 = Vector3(-2.0, 0.10, -9.0)

@onready var terrain: Node = $MarchingSquaresTerrain

var _litik_briefing_pending: bool = false
var _litik_briefing_delay: float = 0.0
var _next_town_portal: Area3D


func _ready() -> void:
	# Do not change quest rewards or the existing Mystic Ylang-Ylang pickup.
	if not QuestManager.quest_completed.is_connected(_on_quest_completed):
		QuestManager.quest_completed.connect(_on_quest_completed)
	if not QuestManager.dialogue_flag_changed.is_connected(_on_dialogue_flag_changed):
		QuestManager.dialogue_flag_changed.connect(_on_dialogue_flag_changed)

	_start_mystic_ylang_quest()
	_spawn_next_town_portal()
	_recover_litik_followup_if_needed()

	print("[Forest] Starting terrain initialization...")
	if terrain == null:
		push_error("[Forest] MarchingSquaresTerrain not found!")
		return

	await get_tree().process_frame
	print("[Forest] Terrain found.")

	if terrain.has_method("force_batch_update"):
		print("[Forest] Calling force_batch_update()")
		terrain.force_batch_update()
	else:
		print("[Forest] force_batch_update() does not exist.")
		if terrain.has_method("refresh_chunk_surface_materials"):
			print("[Forest] Refreshing terrain materials...")
			terrain.refresh_chunk_surface_materials()
		for child: Node in terrain.get_children():
			if child.has_method("mark_dirty"):
				child.mark_dirty()
			if child.has_method("queue_mesh_regen"):
				child.queue_mesh_regen(true)

	await get_tree().process_frame
	print("[Forest] Terrain initialization complete.")

	if is_instance_valid(GameEvents):
		GameEvents.location_reached.emit("forest")
		print("[Forest] Location reached event emitted: forest")


func _process(delta: float) -> void:
	if not _litik_briefing_pending:
		return

	_litik_briefing_delay = maxf(0.0, _litik_briefing_delay - delta)
	if _litik_briefing_delay > 0.0:
		return
	if BattleManager.battle_active or DialogueManager.is_dialogue_active:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	if not is_instance_valid(get_tree().get_first_node_in_group("player")):
		return

	if QuestManager.has_dialogue_flag(LITIK_BRIEFING_FLAG):
		_litik_briefing_pending = false
		_ensure_next_town_quest()
		return

	if DialogueManager.start_forest_scene_dialogue(LITIK_BRIEFING_TIMELINE):
		_litik_briefing_pending = false
		print("[FOREST STORY] Litik discusses the recovered Mystic Ylang-Ylang.")
	else:
		# Do not hammer the dialogue loader every frame if an asset is missing.
		_litik_briefing_delay = 2.0


func _on_quest_completed(quest_id: String, _quest_data: QuestData) -> void:
	if quest_id == FLOWER_QUEST:
		_queue_litik_briefing()


func _on_dialogue_flag_changed(flag_id: String) -> void:
	if flag_id == FLOWER_COLLECTED_FLAG:
		_queue_litik_briefing()
	elif flag_id == LITIK_BRIEFING_FLAG:
		_litik_briefing_pending = false
		_ensure_next_town_quest()
		if GameManager.has_method("request_save"):
			GameManager.request_save()


func _queue_litik_briefing() -> void:
	if not QuestManager.has_dialogue_flag(FLOWER_COLLECTED_FLAG):
		return
	if QuestManager.has_dialogue_flag(LITIK_BRIEFING_FLAG):
		_ensure_next_town_quest()
		return
	_litik_briefing_pending = true
	_litik_briefing_delay = 0.85


func _recover_litik_followup_if_needed() -> void:
	# Older saves can have the flower without this newly added story quest.
	if not QuestManager.has_dialogue_flag(FLOWER_COLLECTED_FLAG):
		return
	if QuestManager.has_dialogue_flag(LITIK_BRIEFING_FLAG):
		_ensure_next_town_quest()
	else:
		_queue_litik_briefing()


func _ensure_next_town_quest() -> void:
	if not QuestManager.has_dialogue_flag(FLOWER_COLLECTED_FLAG):
		return
	if not QuestManager.has_dialogue_flag(LITIK_BRIEFING_FLAG):
		return
	if QuestManager.is_quest_active(NEXT_TOWN_QUEST):
		return
	if QuestManager.is_quest_completed(NEXT_TOWN_QUEST):
		return
	if QuestManager.get_quest(NEXT_TOWN_QUEST) == null:
		push_error("[FOREST STORY] Missing quest: " + NEXT_TOWN_QUEST)
		return
	QuestManager.start_quest(NEXT_TOWN_QUEST)


func _spawn_next_town_portal() -> void:
	# The portal scene already exists in the repo but Forest.tscn never used it.
	if has_node("ForestSecondTownPortal"):
		_next_town_portal = get_node("ForestSecondTownPortal") as Area3D
		return

	var prefab: PackedScene = load(SECOND_TOWN_PORTAL_SCENE) as PackedScene
	if prefab == null:
		push_error("[FOREST STORY] Missing portal scene: " + SECOND_TOWN_PORTAL_SCENE)
		return

	_next_town_portal = prefab.instantiate() as Area3D
	if not is_instance_valid(_next_town_portal):
		push_error("[FOREST STORY] Portal scene root must be Area3D.")
		return

	_next_town_portal.name = "ForestSecondTownPortal"
	add_child(_next_town_portal)

	# Taken from the real Forest.tscn flower location as a recovery fallback.
	var flower_anchor: Vector3 = Vector3(-41.63405, 0.0, -8.181941)
	var flower: Node3D = get_node_or_null("MysticYlangYlang") as Node3D
	if is_instance_valid(flower):
		flower_anchor = flower.global_position

	_next_town_portal.global_position = flower_anchor + second_town_portal_offset
	print("[FOREST STORY] Route to the next town placed at: ", _next_town_portal.global_position)


func _start_mystic_ylang_quest() -> void:
	if not is_instance_valid(QuestManager):
		push_error("[Forest] QuestManager is unavailable.")
		return

	if QuestManager.has_dialogue_flag(FLOWER_COLLECTED_FLAG):
		print("[Forest] Mystic Ylang-Ylang already obtained.")
		return

	if QuestManager.is_quest_active(FLOWER_QUEST) or QuestManager.is_quest_completed(FLOWER_QUEST):
		print("[Forest] Mystic Ylang-Ylang quest already started or completed.")
		return

	QuestManager.start_quest(FLOWER_QUEST)
	if QuestManager.is_quest_active(FLOWER_QUEST):
		print("[Forest] Started quest: Find the Mystic Ylang-Ylang")
	else:
		push_warning("[Forest] Failed to start Mystic Ylang-Ylang quest. Check Data/Quests/get_mystic_ylang_ylang.tres.")
