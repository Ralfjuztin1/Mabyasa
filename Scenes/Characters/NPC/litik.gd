extends Node3D

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@export_category("NPC Identity")

@export var npc_name: String = "Townsman":
	set(value):
		npc_name = value

		if is_inside_tree() and has_node("NameLabel"):
			$NameLabel.text = value

@export var npc_id: String = ""

@export var dialogue_id: String = ""
@export var dialogue_entries: Array[NPCDialogueEntry] = []

func _ready() -> void:
	sprite.play("idle")
