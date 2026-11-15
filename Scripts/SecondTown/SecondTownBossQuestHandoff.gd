extends Node

## Runs in Second Town. No rewrites to the merchant/farmer/Elder quest controller.
## Restores the next quest when loading an existing save as well.
const ELDER_QUEST: String = "st_elder_well"
const GUARDIAN_QUEST: String = "st_second_town_guardian"
const FLOWER_QUEST: String = "st_second_town_ylang"
const BOSS_ID: String = "second_town_number_guardian"
const BOSS_DEFEATED_FLAG: String = "st_number_guardian_defeated"
const FLOWER_OBTAINED_FLAG: String = "st_second_town_ylang_obtained"

var _syncing: bool = false

func _ready() -> void:
    if not QuestManager.quest_completed.is_connected(_on_quest_completed):
        QuestManager.quest_completed.connect(_on_quest_completed)
    call_deferred("_ensure_next_quest")

func _on_quest_completed(quest_id: String, _quest_data: QuestData) -> void:
    if quest_id == ELDER_QUEST or quest_id == GUARDIAN_QUEST:
        call_deferred("_ensure_next_quest")

func _ensure_next_quest() -> void:
    if _syncing or not is_inside_tree():
        return
    if not QuestManager.is_quest_completed(ELDER_QUEST):
        return
    _syncing = true

    # Never reopen an already-defeated boss in saves created before this quest.
    var defeated: bool = QuestManager.has_dialogue_flag(BOSS_DEFEATED_FLAG)
    if not QuestManager.is_quest_completed(GUARDIAN_QUEST) and not defeated:
        if not QuestManager.is_quest_active(GUARDIAN_QUEST):
            _start_if_registered(GUARDIAN_QUEST)
        _syncing = false
        return

    # For an older save where the boss was defeated before this quest existed:
    # don't strand the player with an impossible kill objective.
    if QuestManager.is_quest_active(GUARDIAN_QUEST) and defeated and not QuestManager.is_quest_completed(GUARDIAN_QUEST):
        GameEvents.enemy_killed.emit(BOSS_ID)

    if not QuestManager.is_quest_completed(FLOWER_QUEST) and not QuestManager.has_dialogue_flag(FLOWER_OBTAINED_FLAG):
        if not QuestManager.is_quest_active(FLOWER_QUEST):
            _start_if_registered(FLOWER_QUEST)

    _syncing = false

func _start_if_registered(quest_id: String) -> void:
    if QuestManager.get_quest(quest_id) == null:
        push_error("[SECOND TOWN STORY] Missing quest resource for: " + quest_id)
        return
    QuestManager.start_quest(quest_id)
    if QuestManager.is_quest_active(quest_id):
        print("[SECOND TOWN STORY] Started: " + quest_id)
        if GameManager.has_method("request_save"):
            GameManager.request_save()
