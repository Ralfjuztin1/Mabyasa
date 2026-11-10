extends "res://Scenes/Tutorial/TutorialZone.gd"

const PRE_ASSESSMENT_SCENE: PackedScene = preload(
	"res://Scenes/Assessment/PreAssessment.tscn"
)

var _pre_assessment: CanvasLayer = null


func _on_tutorial_finished() -> void:
	if _transition_started:
		return

	_transition_started = true

	# A baseline is one-time per account. Do not silently overwrite it.
	if SaveManager.has_method("has_pre_assessment") and SaveManager.has_pre_assessment():
		_continue_to_first_town()
		return

	_pre_assessment = PRE_ASSESSMENT_SCENE.instantiate() as CanvasLayer
	if not is_instance_valid(_pre_assessment):
		push_error("[TUTORIAL ZONE] Could not instantiate PreAssessment.tscn.")
		_transition_started = false
		return

	add_child(_pre_assessment)

	if not _pre_assessment.has_signal("closed"):
		push_error("[TUTORIAL ZONE] PreAssessment has no closed signal.")
		_pre_assessment.queue_free()
		_pre_assessment = null
		_transition_started = false
		return

	_pre_assessment.closed.connect(
		_on_pre_assessment_closed,
		CONNECT_ONE_SHOT
	)

	_pre_assessment.call_deferred("open_pre_assessment")


func _on_pre_assessment_closed() -> void:
	_continue_to_first_town()


func _continue_to_first_town() -> void:
	if is_instance_valid(GameManager):
		GameManager.pending_first_town_intro = true

	var main_scene: Node = get_tree().current_scene
	if (
		not is_instance_valid(main_scene)
		or not main_scene.has_method("load_new_level_async")
	):
		push_error("[TUTORIAL ZONE] Main scene cannot load FirstTown.")
		return

	main_scene.call(
		"load_new_level_async",
		FIRST_TOWN_PATH,
		FIRST_TOWN_SPAWN
	)
