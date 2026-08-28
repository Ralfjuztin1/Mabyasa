extends Node

@onready var level_container = $LevelContainer
@onready var player = $Player
@onready var ui_layer = $UILayer

var current_level_node: Node3D = null
var is_loading_level := false


func _ready():
	# Hide player while world loads
	player.visible = false
	player.set_physics_process(false)

	# Load starting world
	await load_new_level(
		"res://Scenes/Main/FirstTown.tscn",
		"DefaultSpawn"
	)


func load_new_level(level_path: String, spawn_point_name: String):
	if is_loading_level:
		return

	is_loading_level = true

	print("----------------------------------------")
	print("Loading level: ", level_path)
	print("----------------------------------------")

	# Remove previous level
	if current_level_node != null and is_instance_valid(current_level_node):
		current_level_node.queue_free()
		await current_level_node.tree_exited
		current_level_node = null

	# Load scene
	var packed_level: PackedScene = load(level_path)

	if packed_level == null:
		push_error("ERROR: Could not load level: " + level_path)
		is_loading_level = false
		return

	print("PackedScene loaded successfully.")

	# Instantiate
	current_level_node = packed_level.instantiate()

	if current_level_node == null:
		push_error("ERROR: Could not instantiate level.")
		is_loading_level = false
		return

	# Add to tree
	level_container.add_child(current_level_node)

	print("Level added to LevelContainer.")

	# --------------------------------------------------
	# Wait for FirstTown._ready()
	# --------------------------------------------------
	await get_tree().process_frame

	# --------------------------------------------------
	# Wait one more frame for terrain material updates
	# --------------------------------------------------
	await get_tree().process_frame

	print("Terrain initialization frames completed.")

	# Teleport player
	_teleport_player(spawn_point_name)

	# Enable player
	player.visible = true
	player.set_physics_process(true)

	is_loading_level = false

	print("----------------------------------------")
	print("LEVEL LOADED SUCCESSFULLY")
	print("----------------------------------------")


func _teleport_player(target_spawn_name: String):
	if current_level_node == null:
		return

	var spawn_point = current_level_node.find_child(
		target_spawn_name,
		true,
		false
	)

	if spawn_point != null and spawn_point is Node3D:
		player.global_position = spawn_point.global_position

		print(
			"Player spawned at: ",
			spawn_point.global_position
		)

	else:
		print(
			"Warning: Spawn point '",
			target_spawn_name,
			"' not found!"
		)

		player.global_position = Vector3(0, 5, 0)
