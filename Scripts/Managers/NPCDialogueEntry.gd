class_name NPCDialogueEntry
extends Resource

## Reusable dialogue entry for NPCs.
## NPCs can hold many entries. DialogueManager selects the highest-priority
## entry whose condition is currently valid.
##
## When play_once is enabled, the entry is ignored after it has successfully
## finished once. The consumed state is stored through QuestManager's
## dialogue_flags, so it can persist with the existing save system.

enum ConditionType {
	ALWAYS,
	QUEST_NOT_STARTED,
	QUEST_ACTIVE,
	QUEST_COMPLETED,
	QUEST_VALIDATION_UNDER,
	QUEST_VALIDATION_OVER,
	DIALOGUE_FLAG
}

@export_enum(
	"Always",
	"Quest Not Started",
	"Quest Active",
	"Quest Completed",
	"Quest Validation Under",
	"Quest Validation Over",
	"Dialogue Flag"
)
var condition: int = ConditionType.ALWAYS

@export var priority: int = 0

@export var quest_id: String = ""

@export var flag_id: String = ""

@export_file("*.dtl") var timeline_path: String = ""

@export_category("Play Once")

@export var play_once: bool = false

## Optional unique ID for this one-time dialogue.
## Leave empty to automatically use: npc_id + timeline_path.
@export var play_once_id: String = ""
