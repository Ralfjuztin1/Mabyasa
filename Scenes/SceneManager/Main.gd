extends Node


signal loading_completed()


@onready var level_container: Node3D = $LevelContainer
@onready var player: CharacterBody3D = $Player
@onready var ui_layer: CanvasLayer = $UILayer


# The loaded level itself does not need to be Node3D.
var current_level_node: Node = null

var target_level_path: String = ""
var target_spawn_name: String = ""

var is_loading: bool = false

var pending_saved_position: Vector3 = Vector3.ZERO
var has_pending_save: bool = false

var tutorial_instance: Node = null


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

	var level_to_load := "res://Scenes/Main/FirstTown.tscn"
	var spawn_name := "DefaultSpawn"


	if GameManager.should_load_save:
		var saved_data := SaveManager.load_game()

		if not saved_data.is_empty():

			if (
				saved_data.has("current_scene")
				and not saved_data["current_scene"].is_empty()
			):
				level_to_load = saved_data["current_scene"]


			if saved_data.has("player_position"):
				var pos = saved_data["player_position"]

				pending_saved_position = Vector3(
					pos["x"],
					pos["y"],
					pos["z"]
				)

				has_pending_save = true

				print(
					"❖ Queued save state restore for scene: ",
					level_to_load
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


	load_new_level_async(
		level_to_load,
		spawn_name
	)


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

	target_level_path = level_path
	target_spawn_name = spawn_point_name


	await TransitionManager.fade_out(0.4)


	# Remove previous level.
	if is_instance_valid(current_level_node):
		current_level_node.queue_free()
		current_level_node = null


	var error := ResourceLoader.load_threaded_request(
		level_path
	)

	if error != OK:
		push_error(
			"Failed to start async load for: "
			+ level_path
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

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:

			if progress.size() > 0:
				TransitionManager.update_progress(
					progress[0]
				)


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

			_instantiate_level(packed_level)

			await TransitionManager.fade_in(0.5)


			# Tutorial welcome box.
			if (
				tutorial_instance
				and tutorial_instance.has_method("show_welcome")
			):
				if TutorialManager.current_active_step == "intro":
					tutorial_instance.show_welcome()


		ResourceLoader.THREAD_LOAD_FAILED:
			push_error(
				"Async loading failed for: "
				+ target_level_path
			)

			set_process(false)

			is_loading = false

			await TransitionManager.fade_in(0.2)


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

func _instantiate_level(packed_level: PackedScene) -> void:

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


	# Important:
	# The level root does NOT have to be Node3D.
	current_level_node = level_instance


	level_container.add_child(
		current_level_node
	)


	# Tell GameManager which actual level is loaded.
	GameManager.current_level_path = target_level_path


	print(
		"🗺️ [MAIN WORLD] Active Scene Successfully Loaded & Instantiated: ",
		target_level_path
	)


	# Give the level time to initialize.
	await get_tree().process_frame
	await get_tree().process_frame


	# ========================================================
	# RESTORE SAVED POSITION
	# ========================================================

	if has_pending_save:

		player.global_position = pending_saved_position

		print(
			"❖ Successfully restored player to saved position: ",
			player.global_position
		)

		has_pending_save = false
		GameManager.should_load_save = false

	else:

		_teleport_player(
			target_spawn_name
		)


	# ========================================================
	# ACTIVATE PLAYER
	# ========================================================

	player.visible = true
	player.set_physics_process(true)


	is_loading = false

	loading_completed.emit()


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

func _unhandled_input(event: InputEvent) -> void:
	if is_loading:
		return

	if event.is_action_pressed("gotoforest"):
		print("[TEST TELEPORT] Going to Forest...")
		_test_change_map("res://Scenes/Main/Forest.tscn")
		return

	if event.is_action_pressed("firsttownreset"):
		print("[TEST TELEPORT] Going to FirstTown...")
		_test_change_map("res://Scenes/Main/FirstTown.tscn")
		return


func _test_change_map(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("[TEST TELEPORT] Scene not found: " + scene_path)
		return

	# Make sure a previous saved position does not override
	# the test teleport.
	has_pending_save = false
	GameManager.should_load_save = false

	load_new_level_async(scene_path, "DefaultSpawn")
