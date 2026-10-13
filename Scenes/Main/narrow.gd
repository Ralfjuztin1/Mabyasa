extends Area3D

@export var narrow_cutscene: CutsceneDirector
@export var story_flag: String = "scene_narrow_intro"

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Do not replay this cutscene if it already happened.
	if QuestManager.has_dialogue_flag(story_flag):
		triggered = true
		set_deferred("monitoring", false)


func _on_body_entered(body: Node3D) -> void:
	if triggered:
		return

	if body.name != "Player":
		return

	if narrow_cutscene == null:
		push_error("[NarrowTrigger] NarrowCutscene is not assigned.")
		return

	triggered = true
	set_deferred("monitoring", false)

	await narrow_cutscene.play_sequence()

	# Save this event separately from the Litik event.
	QuestManager.set_dialogue_flag(
		story_flag,
		true
	)

	print("[NarrowTrigger] Narrow cutscene completed.")
