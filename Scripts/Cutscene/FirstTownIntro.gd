extends Node


# ============================================================
# SCENE 1 SETTINGS
# ============================================================

@export_category("Scene 1")

@export_file("*.dtl")
var intro_timeline: String = ""


@export_category("Cutscene System")
## When enabled, Scene 1 is driven by the reusable CutsceneDirector.
## If the director node is missing, the old scripted sequence is used.
@export var use_cutscene_director: bool = true


@export_category("Timing")

@export_range(0.0, 1.0, 0.05)
var start_delay: float = 0.15

@export_range(0.0, 2.0, 0.05)
var waking_camera_hold: float = 0.5


# ============================================================
# RUNTIME STATE
# ============================================================

var scene_1_started: bool = false

var tutorial_ui: Node = null
var cutscene_controller: Node = null
var cutscene_director: CutsceneDirector = null
var player: CharacterBody3D = null

var ima: Node3D = null
var apu: Node3D = null
var bebang: CharacterBody3D = null

var scene_1_start_point: Node3D = null
var waking_up_camera: Node3D = null
var ima_talk_point: Node3D = null
var well_point: Node3D = null
var bebang_talk_point: Node3D = null

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	call_deferred("_initialize")


# ============================================================
# INITIALIZE
# ============================================================

func _initialize() -> void:

	var level_root: Node = get_parent()

	# ========================================================
	# FIND TUTORIAL UI
	# ========================================================

	tutorial_ui = get_tree().get_first_node_in_group(
		"tutorial_ui"
	)

	if tutorial_ui == null:
		tutorial_ui = get_tree().root.find_child(
			"TutorialUI",
			true,
			false
		)

	if tutorial_ui != null:
		if tutorial_ui.has_signal("tutorial_finished"):

			if not tutorial_ui.tutorial_finished.is_connected(
				_on_tutorial_finished
			):
				tutorial_ui.tutorial_finished.connect(
					_on_tutorial_finished
				)

			print(
				"🎓 [SCENE 1] Waiting for tutorial to finish..."
			)

		else:
			push_error(
				"[SCENE 1] TutorialUI does not have "
				+ "'tutorial_finished' signal."
			)
	else:
		push_error(
			"[SCENE 1] TutorialUI could not be found."
		)

	# ========================================================
	# FIND CUTSCENE CONTROLLER
	# ========================================================

	cutscene_controller = get_tree().root.find_child(
		"CutsceneController",
		true,
		false
	)

	if cutscene_controller == null:
		push_error(
			"[SCENE 1] CutsceneController could not be found."
		)

	# ========================================================
	# FIND CUTSCENE DIRECTOR
	# ========================================================

	if use_cutscene_director:
		cutscene_director = level_root.get_node_or_null(
			"Scene1Cutscene"
		) as CutsceneDirector

		if cutscene_director == null:
			push_warning(
				"[SCENE 1] Scene1Cutscene director not found. "
				+ "Falling back to the old scripted sequence."
			)

	# ========================================================
	# FIND PLAYER
	# ========================================================

	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody3D

	if player == null:
		player = get_tree().root.find_child(
			"Player",
			true,
			false
		) as CharacterBody3D

	if player == null:
		push_error(
			"[SCENE 1] Player could not be found."
		)

	# ========================================================
	# FIND IMA
	# ========================================================
	bebang = level_root.get_node_or_null(
		"npc/bebang"
	) as CharacterBody3D
	
	if bebang == null:
		bebang = level_root.find_child(
			"bebang",
			true,
			false
		) as CharacterBody3D
		

	ima = level_root.get_node_or_null(
		"npc/ima"
	) as Node3D

	if ima == null:
		ima = level_root.find_child(
			"ima",
			true,
			false
		) as Node3D

	if ima == null:
		push_error(
			"[SCENE 1] NPC 'ima' could not be found."
		)
	else:
		print(
			"👩 [SCENE 1] Ima found."
		)

	# ========================================================
	# FIND APU
	# ========================================================

	apu = level_root.get_node_or_null(
		"npc/apu"
	) as Node3D

	if apu == null:
		apu = level_root.find_child(
			"apu",
			true,
			false
		) as Node3D

	if apu == null:
		push_error(
			"[SCENE 1] NPC 'apu' could not be found."
		)
	else:
		print(
			"👴 [SCENE 1] Apu found."
		)

	# ========================================================
	# FIND CUTSCENE POINTS
	# ========================================================

	scene_1_start_point = _find_point(
		level_root,
		"Scene1StartPoint"
	)

	waking_up_camera = _find_point(
		level_root,
		"WakingUpCamera"
	)

	ima_talk_point = _find_point(
		level_root,
		"ImaTalkPoint"
	)

	well_point = _find_point(
		level_root,
		"WellPoint"
	)
	bebang_talk_point = _find_point(
		level_root,
		"BebangTalkPoint"
	)
	if scene_1_start_point == null:
		push_error(
			"[SCENE 1] Scene1StartPoint not found."
		)

	if waking_up_camera == null:
		push_error(
			"[SCENE 1] WakingUpCamera not found."
		)

	if ima_talk_point == null:
		push_error(
			"[SCENE 1] ImaTalkPoint not found."
		)

	if well_point == null:
		push_error(
			"[SCENE 1] WellPoint not found."
		)

	# ========================================================
	# TIMELINE CHECK
	# ========================================================

	if intro_timeline.is_empty():
		push_warning(
			"[SCENE 1] No Dialogic timeline assigned."
			+ " Assign waking_up.dtl in the Inspector."
		)


# ============================================================
# FIND POINT
# ============================================================

func _find_point(
	root: Node,
	node_name: String
) -> Node3D:

	if root == null:
		return null

	var direct_node := root.get_node_or_null(
		"CutscenePoints/" + node_name
	)

	if direct_node is Node3D:
		return direct_node as Node3D

	var recursive_node := root.find_child(
		node_name,
		true,
		false
	)

	if recursive_node is Node3D:
		return recursive_node as Node3D

	return null


# ============================================================
# TUTORIAL FINISHED
# ============================================================

func _on_tutorial_finished() -> void:
	if scene_1_started:
		return

	scene_1_started = true

	print(
		"🎬 [SCENE 1] Tutorial finished. "
		+ "Starting Scene 1."
	)

	# New reusable cutscene system.
	# If it is not configured yet, keep the existing working sequence.
	if use_cutscene_director and is_instance_valid(cutscene_director):
		await cutscene_director.play_sequence()
		return

	await get_tree().create_timer(
		start_delay
	).timeout

	await _start_scene_1()


# ============================================================
# START SCENE 1
# ============================================================

func _start_scene_1() -> void:

	if cutscene_controller == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "CutsceneController is missing."
		)
		return

	if player == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "Player is missing."
		)
		return

	if scene_1_start_point == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "Scene1StartPoint is missing."
		)
		return

	if waking_up_camera == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "WakingUpCamera is missing."
		)
		return

	if ima_talk_point == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "ImaTalkPoint is missing."
		)
		return

	if well_point == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "WellPoint is missing."
		)
		return

	if ima == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "Ima is missing."
		)
		return

	if apu == null:
		push_error(
			"[SCENE 1] Cannot start. "
			+ "Apu is missing."
		)
		return

	if intro_timeline.is_empty():
		push_error(
			"[SCENE 1] Cannot start. "
			+ "No Dialogic timeline assigned."
		)
		return

	# ========================================================
	# TAKE CONTROL
	# ========================================================

	if not cutscene_controller.begin_cutscene():
		push_error(
			"[SCENE 1] CutsceneController refused "
			+ "to start the cutscene."
		)
		return

	# ========================================================
	# FADE TO BLACK
	# ========================================================

	await TransitionManager.fade_out(
		0.2
	)

	# ========================================================
	# TELEPORT PLAYER
	# ========================================================

	player.velocity = Vector3.ZERO

	player.global_position = (
		scene_1_start_point.global_position
	)

	await get_tree().physics_frame
	await get_tree().physics_frame

	player.velocity = Vector3.ZERO

	print(
		"📍 [SCENE 1] Player moved to "
		+ "Scene1StartPoint: ",
		player.global_position
	)

	# ========================================================
	# POSITION IMA
	# ========================================================

	ima.global_position = (
		ima_talk_point.global_position
	)
	

	
	print(
		"👩 [SCENE 1] Ima moved to ImaTalkPoint: ",
		ima.global_position
	)

	# ========================================================
	# MAKE SURE APU IS ACTIVE
	# ========================================================

	apu.visible = true

	print(
		"👴 [SCENE 1] Apu is waiting at the well."
	)

	# ========================================================
	# CINEMATIC CAMERA
	# ========================================================

	await cutscene_controller.camera_shot(
		waking_up_camera,
		0.18
	)

	# Release the Main transition black overlay.
	await TransitionManager.fade_in(
		0.3
	)

	# ========================================================
	# CAMERA HOLD
	# ========================================================

	if waking_camera_hold > 0.0:
		await cutscene_controller.wait(
			waking_camera_hold
		)

	# ========================================================
	# SCENE 1 DIALOGUE
	# ========================================================

	print(
		"💬 [SCENE 1] Playing waking_up timeline."
	)
	cutscene_controller.move_npc_to(
		bebang,
		bebang_talk_point.global_position
	)
	await cutscene_controller.play_dialogue(
		intro_timeline
		
	)

	# ========================================================
	# RETURN TO PLAYER CAMERA
	# ========================================================

	await cutscene_controller.return_to_player_camera(
		0.18
	)

	# ========================================================
	# WALK TO WELL
	# ========================================================

	print(
		"🚶 [SCENE 1] Player walking to the well."
	)

	await cutscene_controller.move_player_to(
		well_point.global_position
	)

	# ========================================================
	# END SCENE 1
	# ========================================================

	cutscene_controller.end_cutscene()

	print(
		"✅ [SCENE 1] Waking-up sequence complete."
	)
