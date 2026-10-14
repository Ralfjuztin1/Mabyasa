extends Area3D

@export var cutscene: CutsceneDirector
@export var story_flag: String = ""

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# This specific story scene has already happened.
	if QuestManager.has_dialogue_flag(story_flag):
		triggered = true
		set_deferred("monitoring", false)


func _on_body_entered(body: Node3D) -> void:
	if triggered:
		return

	if body.name != "Player":
		return

	if cutscene == null:
		push_error("[Trigger] Cutscene is not assigned.")
		return

	triggered = true
	set_deferred("monitoring", false)

	await cutscene.play_sequence()

	# Remember that this specific Litik scene has happened.
	QuestManager.set_dialogue_flag(
		story_flag,
		true
	)

	print("[TriggerUletUlet] Cutscene event completed.")
