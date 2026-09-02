extends Node

signal loading_progress_updated(percent: float)
signal loading_completed()

@onready var level_container: Node3D = $LevelContainer
@onready var player: CharacterBody3D = $Player
@onready var ui_layer: CanvasLayer = $UILayer

var current_level_node: Node3D = null
var target_level_path: String = ""
var target_spawn_name: String = ""
var is_loading := false

var pending_saved_position: Vector3 = Vector3.ZERO
var has_pending_save := false

func _ready() -> void:
	set_process(false) 
	player.visible = false
	player.set_physics_process(false)
	
	var level_to_load = "res://Scenes/Main/FirstTown.tscn"
	var spawn_name = "DefaultSpawn"
	
	if GameManager.should_load_save:
		var saved_data = SaveManager.load_game()
		if not saved_data.is_empty():
			if saved_data.has("current_scene") and not saved_data["current_scene"].is_empty():
				level_to_load = saved_data["current_scene"]
			
			if saved_data.has("player_position"):
				var pos = saved_data["player_position"]
				pending_saved_position = Vector3(pos["x"], pos["y"], pos["z"])
				has_pending_save = true
				print("❖ Queued save state restore for scene: ", level_to_load)

	load_new_level_async(level_to_load, spawn_name)

func load_new_level_async(level_path: String, spawn_point_name: String) -> void:
	if is_loading:
		return

	is_loading = true
	target_level_path = level_path
	target_spawn_name = spawn_point_name

	await TransitionManager.fade_out(0.4)

	if is_instance_valid(current_level_node):
		current_level_node.queue_free()
		current_level_node = null

	var error = ResourceLoader.load_threaded_request(level_path)
	if error != OK:
		push_error("Failed to start async load for: " + level_path)
		is_loading = false
		await TransitionManager.fade_in(0.2)
		return

	set_process(true)

func _process(_delta: float) -> void:
	if not is_loading:
		set_process(false)
		return

	var progress := []
	var status = ResourceLoader.load_threaded_get_status(target_level_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				TransitionManager.update_progress(progress[0])

		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			TransitionManager.update_progress(1.0) 
			
			var packed_level: PackedScene = ResourceLoader.load_threaded_get(target_level_path)
			_instantiate_level(packed_level)
			
			await TransitionManager.fade_in(0.5)

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Async loading failed for: " + target_level_path)
			set_process(false)
			is_loading = false
			TransitionManager.fade_in(0.2)

func _instantiate_level(packed_level: PackedScene) -> void:
	current_level_node = packed_level.instantiate() as Node3D
	
	if not current_level_node:
		push_error("Failed to instantiate level or root node is not a Node3D!")
		is_loading = false
		return

	level_container.add_child(current_level_node)
	
	# Update active tracker
	GameManager.current_level_path = target_level_path

	# --- DEBUG CONSOLE LOG ---
	print("🗺️ [MAIN WORLD] Active Scene Successfully Loaded & Instantiated: ", target_level_path)

	await get_tree().process_frame
	await get_tree().process_frame

	if has_pending_save:
		player.global_position = pending_saved_position
		print("❖ Successfully restored player to saved position: ", player.global_position)
		has_pending_save = false
		GameManager.should_load_save = false
	else:
		_teleport_player(target_spawn_name)

	player.visible = true
	player.set_physics_process(true)

	is_loading = false
	loading_completed.emit()

func _teleport_player(spawn_name: String) -> void:
	if not is_instance_valid(current_level_node):
		return

	var spawn_point = current_level_node.find_child(spawn_name, true, false)
	if spawn_point and spawn_point is Node3D:
		player.global_position = spawn_point.global_position
		print("Spawned at default level spawn point: ", spawn_point.global_position)
	else:
		push_warning("Spawn point '" + spawn_name + "' not found!")
		player.global_position = Vector3(0, 5, 0)
