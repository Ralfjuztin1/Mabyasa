
extends Node3D

const FIRST_TOWN_PATH := "res://Scenes/Main/FirstTown.tscn"
const FIRST_TOWN_SPAWN := "Scene1StartPoint"

var _transition_started: bool = false


func _ready() -> void:
	call_deferred("_connect_tutorial_ui")


func _connect_tutorial_ui() -> void:
	var tutorial_ui: Node = get_tree().get_first_node_in_group(
        "tutorial_ui"
	)

	if tutorial_ui == null:
		push_error(
            "[TUTORIAL ZONE] TutorialUI was not found. "
			+ "Main.gd should instantiate it before loading this level."
		)
		return

	if not tutorial_ui.has_signal("tutorial_finished"):
		push_error(
            "[TUTORIAL ZONE] TutorialUI has no tutorial_finished signal."
		)
		return

	var callback := Callable(self, "_on_tutorial_finished")

	if not tutorial_ui.tutorial_finished.is_connected(callback):
		tutorial_ui.tutorial_finished.connect(callback)

	print("[TUTORIAL ZONE] Waiting for controls tutorial completion.")


func _on_tutorial_finished() -> void:
	if _transition_started:
		return

	_transition_started = true

	if is_instance_valid(GameManager):
		GameManager.pending_first_town_intro = true

	var main_scene: Node = get_tree().current_scene

	if (
		not is_instance_valid(main_scene)
		or not main_scene.has_method("load_new_level_async")
	):
		push_error(
            "[TUTORIAL ZONE] Main scene cannot load FirstTown."
		)
		_transition_started = false
		return

	print("[TUTORIAL ZONE] Tutorial finished. Loading FirstTown.")

	main_scene.call(
		"load_new_level_async",
		FIRST_TOWN_PATH,
		FIRST_TOWN_SPAWN
	)
