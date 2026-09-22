extends Node


signal loading_completed()


@onready var level_container: Node3D = $LevelContainer
@onready var player: CharacterBody3D = $Player
@onready var ui_layer: CanvasLayer = $UILayer


# ============================================================
# SCENE PATHS
# ============================================================

const BOOT_SCENE_PATH := "res://Scenes/SceneManager/Main.tscn"
const FIRST_TOWN_PATH := "res://Scenes/Main/FirstTown.tscn"


# ============================================================
# RUNTIME STATE
# ============================================================

var current_level_node: Node = null

var target_level_path: String = ""
var target_spawn_name: String = ""

var is_loading: bool = false

var pending_saved_position: Vector3 = Vector3.ZERO
var has_pending_save: bool = false

var tutorial_instance: Node = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	set_process(false)

	player.visible = false
	player.set_physics_process(false)

	# ========================================================
	# TUTORIAL PERMISSIONS
	# ========================================================

	if TutorialManager:
		TutorialManager.update_permissions()

	# ========================================================
	# TUTORIAL UI
	# ========================================================

	var tutorial_ui_path := "res://Scenes/UI/TutorialUI.tscn"

	if ResourceLoader.exists(tutorial_ui_path):
		var tutorial_packed = load(tutorial_ui_path)

		if tutorial_packed and ui_layer:
			tutorial_instance = tutorial_packed.instantiate()
			ui_layer.add_child(tutorial_instance)

			print(
				"🎓 [TUTORIAL] TutorialUI overlay successfully spawned."
			)
	else:
		push_warning(
			"TutorialUI.tscn not found at path: "
			+ tutorial_ui_path
		)

	# ========================================================
	# DETERMINE LEVEL TO LOAD
	# ========================================================

	var level_to_load := FIRST_TOWN_PATH
	var spawn_name := "DefaultSpawn"

	if GameManager.should_load_save:

		var saved_data := SaveManager.load_game()

		if not saved_data.is_empty():

			# ------------------------------------------------
			# RESTORE SCENE
			# ------------------------------------------------

			if (
				saved_data.has("current_scene")
				and saved_data["current_scene"] is String
				and not saved_data["current_scene"].is_empty()
			):

				level_to_load = _normalize_saved_level_path(
					saved_data["current_scene"]
				)

			# ------------------------------------------------
			# RESTORE PLAYER POSITION
			# ------------------------------------------------

			if saved_data.has("player_position"):

				var pos = saved_data["player_position"]

				if (
					pos is Dictionary
					and pos.has("x")
					and pos.has("y")
					and pos.has("z")
				):

					pending_saved_position = Vector3(
						float(pos["x"]),
						float(pos["y"]),
						float(pos["z"])
					)

					has_pending_save = true

					print(
						"❖ Queued save state restore for scene: ",
						level_to_load
					)

					print(
						"❖ Saved position: ",
						pending_saved_position
					)

	else:

		print(
			"✨ [RPG FLOW] Brand new user! Loading world."
		)

		await get_tree().process_frame

		SaveManager.save_game(
			player,
			level_to_load,
			false
		)

	# ========================================================
	# START LOADING
	# ========================================================

	load_new_level_async(
		level_to_load,
		spawn_name
	)


# ============================================================
# NORMALIZE SAVED SCENE
# ============================================================

func _normalize_saved_level_path(path: String) -> String:

	if path == BOOT_SCENE_PATH:

		print(
			"⚠️ [MAIN WORLD] Save points to Main.tscn."
		)

		print(
			"🔄 [MAIN WORLD] Redirecting save to FirstTown.tscn."
		)

		return FIRST_TOWN_PATH

	return path


# ============================================================
# ASYNC LEVEL LOADING
# ============================================================

func load_new_level_async(
	level_path: String,
	spawn_point_name: String
) -> void:

	if is_loading:
		return

	is_loading = true

	# Never allow the bootstrap scene to be loaded as the
	# actual gameplay level.
	target_level_path = _normalize_saved_level_path(
		level_path
	)

	target_spawn_name = spawn_point_name

	await TransitionManager.fade_out(0.4)

	# --------------------------------------------------------
	# REMOVE PREVIOUS LEVEL
	# --------------------------------------------------------

	if is_instance_valid(current_level_node):

		current_level_node.queue_free()
		current_level_node = null

		await get_tree().process_frame

	# --------------------------------------------------------
	# START THREADED LOAD
	# --------------------------------------------------------

	var error := ResourceLoader.load_threaded_request(
		target_level_path
	)

	if error != OK:

		push_error(
			"Failed to start async load for: "
			+ target_level_path
		)

		is_loading = false

		await TransitionManager.fade_in(0.2)

		return

	set_process(true)


# ============================================================
# LEVEL LOADING PROCESS
# ============================================================

func _process(_delta: float) -> void:

	if not is_loading:

		set_process(false)
		return

	var progress: Array = []

	var status := ResourceLoader.load_threaded_get_status(
		target_level_path,
		progress
	)

	match status:

		# ----------------------------------------------------
		# LOADING
		# ----------------------------------------------------

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:

			if progress.size() > 0:

				TransitionManager.update_progress(
					float(progress[0])
				)

		# ----------------------------------------------------
		# LOADED
		# ----------------------------------------------------

		ResourceLoader.THREAD_LOAD_LOADED:

			set_process(false)

			TransitionManager.update_progress(1.0)

			var loaded_resource := (
				ResourceLoader.load_threaded_get(
					target_level_path
				)
			)

			if not loaded_resource is PackedScene:

				push_error(
					"[MAIN WORLD] Loaded resource is not a PackedScene: "
					+ target_level_path
				)

				is_loading = false

				await TransitionManager.fade_in(0.2)

				return

			var packed_level := loaded_resource as PackedScene

			await _instantiate_level(
				packed_level
			)

			await TransitionManager.fade_in(0.5)

			# ------------------------------------------------
			# TUTORIAL WELCOME
			# ------------------------------------------------

			if (
				tutorial_instance
				and tutorial_instance.has_method("show_welcome")
			):

				if TutorialManager.current_active_step == "intro":

					tutorial_instance.show_welcome()

		# ----------------------------------------------------
		# FAILED
		# ----------------------------------------------------

		ResourceLoader.THREAD_LOAD_FAILED:

			push_error(
				"Async loading failed for: "
				+ target_level_path
			)

			set_process(false)

			is_loading = false

			await TransitionManager.fade_in(0.2)

		# ----------------------------------------------------
		# INVALID RESOURCE
		# ----------------------------------------------------

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:

			push_error(
				"Invalid resource while loading: "
				+ target_level_path
			)

			set_process(false)

			is_loading = false

			await TransitionManager.fade_in(0.2)


# ============================================================
# INSTANTIATE LEVEL
# ============================================================

func _instantiate_level(
	packed_level: PackedScene
) -> void:

	if packed_level == null:

		push_error(
			"[MAIN WORLD] PackedScene is null."
		)

		is_loading = false
		return

	var level_instance := packed_level.instantiate()

	if level_instance == null:

		push_error(
			"[MAIN WORLD] Failed to instantiate level: "
			+ target_level_path
		)

		is_loading = false
		return

	# --------------------------------------------------------
	# STORE CURRENT LEVEL
	# --------------------------------------------------------

	current_level_node = level_instance

	level_container.add_child(
		current_level_node
	)

	GameManager.current_level_path = target_level_path

	print(
		"🗺️ [MAIN WORLD] Active Scene Successfully Loaded & Instantiated: ",
		target_level_path
	)

	# --------------------------------------------------------
	# WAIT FOR LEVEL COLLISION
	# --------------------------------------------------------

	await _wait_for_level_collision()

	# --------------------------------------------------------
	# RESTORE SAVED POSITION
	# --------------------------------------------------------

	if has_pending_save:

		player.set_physics_process(false)
		player.velocity = Vector3.ZERO

		player.global_position = pending_saved_position

		print(
			"❖ Successfully restored player to saved position: ",
			player.global_position
		)

		# Give the physics server time to register the player
		# against the new terrain collision.

		await get_tree().physics_frame
		await get_tree().physics_frame

		player.velocity = Vector3.ZERO

		print(
			"❖ Position after physics sync: ",
			player.global_position
		)

		has_pending_save = false
		GameManager.should_load_save = false

	else:

		_teleport_player(
			target_spawn_name
		)

		await get_tree().physics_frame
		await get_tree().physics_frame

		player.velocity = Vector3.ZERO

	# --------------------------------------------------------
	# ACTIVATE PLAYER
	# --------------------------------------------------------

	player.visible = true
	player.set_physics_process(true)

	is_loading = false

	loading_completed.emit()


# ============================================================
# WAIT FOR TERRAIN INITIALIZATION
# ============================================================

func _wait_for_level_collision() -> void:

	var terrain_system: Node = null

	if is_instance_valid(current_level_node):

		terrain_system = current_level_node.find_child(
			"MarchingSquaresTerrain",
			true,
			false
		)

	# --------------------------------------------------------
	# TERRAIN FOUND
	# --------------------------------------------------------

	if (
		terrain_system != null
		and terrain_system.has_signal("load_finished")
	):

		var terrain_ready: bool = false

		var terrain_ready_callback := func() -> void:
			terrain_ready = true

		terrain_system.load_finished.connect(
			terrain_ready_callback,
			CONNECT_ONE_SHOT
		)

		print(
			"⏳ [MAIN WORLD] Waiting for terrain collision initialization..."
		)

		# Wait up to 120 frames.

		for _i in range(120):

			if terrain_ready:
				break

			await get_tree().process_frame

		if terrain_ready:

			print(
				"✅ [MAIN WORLD] Terrain initialization finished."
			)

		else:

			push_warning(
				"⚠️ [MAIN WORLD] Terrain initialization timeout. "
				+ "Continuing after safety wait."
			)

	else:

		print(
			"ℹ️ [MAIN WORLD] No MarchingSquaresTerrain found in this level."
		)

	# --------------------------------------------------------
	# PHYSICS SYNC
	# --------------------------------------------------------

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	print(
		"✅ [MAIN WORLD] Physics collision synchronization finished."
	)


# ============================================================
# DEFAULT SPAWN
# ============================================================

func _teleport_player(
	spawn_name: String
) -> void:

	if not is_instance_valid(current_level_node):
		return

	var spawn_point := current_level_node.find_child(
		spawn_name,
		true,
		false
	)

	if spawn_point and spawn_point is Node3D:

		player.global_position = (
			spawn_point.global_position
		)

		print(
			"Spawned at default level spawn point: ",
			spawn_point.global_position
		)

	else:

		push_warning(
			"Spawn point '"
			+ spawn_name
			+ "' not found!"
		)

		player.global_position = Vector3(
			0,
			5,
			0
		)


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:

	if is_loading:
		return

	if event.is_action_pressed("gotoforest"):

		print(
			"[TEST TELEPORT] Going to Forest..."
		)

		_test_change_map(
			"res://Scenes/Main/Forest.tscn"
		)

		return

	if event.is_action_pressed("firsttownreset"):

		print(
			"[TEST TELEPORT] Going to FirstTown..."
		)

		_test_change_map(
			"res://Scenes/Main/FirstTown.tscn"
		)

		return


# ============================================================
# TEST MAP CHANGE
# ============================================================

func _test_change_map(
	scene_path: String
) -> void:

	if not ResourceLoader.exists(scene_path):

		push_error(
			"[TEST TELEPORT] Scene not found: "
			+ scene_path
		)

		return

	has_pending_save = false
	GameManager.should_load_save = false

	load_new_level_async(
		scene_path,
		"DefaultSpawn"
	)
