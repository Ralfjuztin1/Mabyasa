class_name QuestStep
extends Resource


@export_category("Objective")
@export_enum(
	"talk_npc",
	"wait_time",
	"reach_location",
	"solve_puzzle",
	"enemy_killed",
	"interact_object",
	"item_collected"
)
var type: String = "talk_npc"

@export var target: String = ""


@export_category("Count")
@export_range(1, 999, 1)
var required_count: int = 1


@export_category("Count Validation")
@export var validation_type: String = "none"

@export var validation_target: String = ""
