extends Area3D

## Collectible first Mystic Ylang-Ylang. The Forest guardian must be defeated first.

const GUARDIAN_DEFEATED_FLAG: String = "forest_ylang_guardian_defeated"
const ITEM_OBTAINED_FLAG: String = "mystic_ylang_ylang_obtained"
const GUARD_WARNING_TIMELINE: String = "res://Scenes/Characters/NPC/Dialogic/ForestSceneDialogues/litik_ylang_guard_warning.dtl"

var _collected: bool = false


func _ready() -> void:
	monitoring = true
	if QuestManager.has_dialogue_flag(ITEM_OBTAINED_FLAG):
		_collected = true
		queue_free()
		return
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if _collected or BattleManager.battle_active or DialogueManager.is_dialogue_active:
		return

	# The boss is a real requirement, not just decoration.
	if not QuestManager.has_dialogue_flag(GUARDIAN_DEFEATED_FLAG):
		print("[MYSTIC YLANG-YLANG] The guardian must be defeated first.")
		if not QuestManager.has_dialogue_flag("litik_warned_about_ylang_guardian"):
			DialogueManager.start_forest_scene_dialogue(GUARD_WARNING_TIMELINE)
		return

	_collected = true
	QuestManager.set_dialogue_flag(ITEM_OBTAINED_FLAG, true)

	if is_instance_valid(GameEvents):
		GameEvents.item_collected.emit("mystic_ylang_ylang")

	print("[MYSTIC YLANG-YLANG] First Mystic Ylang-Ylang obtained.")
	monitoring = false

	if GameManager.has_method("request_save"):
		GameManager.request_save()

	queue_free()
