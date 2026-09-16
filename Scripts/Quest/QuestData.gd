class_name QuestData
extends Resource


@export_category("Quest Identity")
@export var quest_id: String = ""
@export var title: String = ""

@export_multiline
var description: String = ""


@export_category("Quest Rewards")
@export var rewards: QuestReward


@export_category("Quest Objectives")
@export var steps: Array[QuestStep] = []
