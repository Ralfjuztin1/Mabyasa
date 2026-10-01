extends Node

## TEMPORARY CUTSCENE TEST
##
## This will eventually be deleted.
##
## F6 in-game:
##
## 1. Cinematic camera appears.
## 2. Waking-up dialogue plays automatically.
## 3. Player walks to a Marker3D.
## 4. Camera returns to the player.
## 5. Player walks back.
## 6. Normal control returns.

const WAKING_UP_TIMELINE := (
	"res://Scenes/Characters/NPC/Dialogic/"
	+ "FirstTownSceneDialogues/waking_up.dtl"
)

const MOVE_POINT_PATH := (
	"../CutscenePoints/TestMovePoint"
)

const CAMERA_POINT_PATH := (
	"../CutscenePoints/TestCameraPoint"
)

const PAUSE_AT_TARGET: float = 0.5

var _running: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if _running:
		return

	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_F6
	):
		get_viewport().set_input_as_handled()
		_run_test()


func _run_test() -> void:
	var controller := (
		get_tree()
		.current_scene
		.get_node_or_null(
			"CutsceneController"
		)
		as CutsceneController
	)

	if not is_instance_valid(controller):
		push_warning(
			"[CUTSCENE] Test: Main/CutsceneController "
			+ "was not found."
		)
		return

	var player := (
		get_tree()
		.get_first_node_in_group("player")
		as CharacterBody3D
	)

	if not is_instance_valid(player):
		push_warning(
			"[CUTSCENE] Test: player not found."
		)
		return

	var move_point := (
		get_node_or_null(
			MOVE_POINT_PATH
		)
		as Node3D
	)

	var camera_point := (
		get_node_or_null(
			CAMERA_POINT_PATH
		)
		as Node3D
	)

	if not is_instance_valid(move_point):
		push_warning(
			"[CUTSCENE] TestMovePoint not found."
		)
		return

	if not is_instance_valid(camera_point):
		push_warning(
			"[CUTSCENE] TestCameraPoint not found."
		)
		return

	if not controller.begin_cutscene():
		return

	_running = true

	print("[CUTSCENE] Test started.")

	var start_position := player.global_position

	# --------------------------------------------------------
	# CAMERA SHOT
	# --------------------------------------------------------

	await controller.camera_shot(
		camera_point,
		0.5
	)

	# --------------------------------------------------------
	# FORCED DIALOGUE
	# --------------------------------------------------------

	await controller.play_dialogue(
		WAKING_UP_TIMELINE
	)

	# --------------------------------------------------------
	# RETURN CAMERA TO PLAYER
	# --------------------------------------------------------

	await controller.return_to_player_camera(
		0.5
	)

	# --------------------------------------------------------
	# FORCED MOVEMENT
	# --------------------------------------------------------

	print(
		"[CUTSCENE] Moving player to test point."
	)

	await controller.move_player_to(
		move_point.global_position
	)

	await controller.wait(
		PAUSE_AT_TARGET
	)

	# --------------------------------------------------------
	# RETURN TO START
	# --------------------------------------------------------

	print(
		"[CUTSCENE] Returning player to start."
	)

	await controller.move_player_to(
		start_position
	)

	await controller.end_cutscene()

	print("[CUTSCENE] Test finished.")

	_running = false
