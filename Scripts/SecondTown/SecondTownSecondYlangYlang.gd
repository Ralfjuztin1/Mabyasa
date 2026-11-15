extends Area3D

## The *second* Mystic Ylang-Ylang; does not change the Forest flower's flag.
const GUARDIAN_QUEST: String = "st_second_town_guardian"
const GUARDIAN_DEFEATED_FLAG: String = "st_number_guardian_defeated"
const FLOWER_OBTAINED_FLAG: String = "st_second_town_ylang_obtained"
const ITEM_ID: String = "second_town_ylang_ylang"

var _collected: bool = false

func _ready() -> void:
    if QuestManager.has_dialogue_flag(FLOWER_OBTAINED_FLAG):
        _collected = true
        queue_free()
        return
    monitoring = true
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player") and body.name != "Player":
        return
    if _collected or BattleManager.battle_active or DialogueManager.is_dialogue_active:
        return
    if not QuestManager.is_quest_completed(GUARDIAN_QUEST) and not QuestManager.has_dialogue_flag(GUARDIAN_DEFEATED_FLAG):
        print("[SECOND YLANG] Defeat the Second Town Number Guardian first.")
        return

    _collected = true
    monitoring = false
    QuestManager.set_dialogue_flag(FLOWER_OBTAINED_FLAG, true)
    GameEvents.item_collected.emit(ITEM_ID)
    print("[SECOND YLANG] Second Mystic Ylang-Ylang collected.")
    if GameManager.has_method("request_save"):
        GameManager.request_save()
    queue_free()
