extends Node

@onready var level_container = $LevelContainer
@onready var player = $Player
@onready var ui_layer = $UILayer

var current_level_node: Node3D = null

func _ready():
	# Hide the player and lock their physics until the world is fully loaded
	player.visible = false
	player.set_physics_process(false)
	
	# Load our starting world (we will create this in the next step)
	load_new_level("res://Scenes/Main/FirstTown.tscn", "DefaultSpawn")

func load_new_level(level_path: String, spawn_point_name: String):
	# 1. Delete the old level (and its terrain) if one exists to free up memory
	if current_level_node != null:
		current_level_node.queue_free()
		await current_level_node.tree_exited 
		
	# 2. Load the new level file
	var packed_level = load(level_path)
	if packed_level:
		current_level_node = packed_level.instantiate()
		level_container.add_child(current_level_node)
		
		# 3. Teleport the player to the correct marker in the new level
		_teleport_player(spawn_point_name)
		
		# 4. Reveal the player and enable movement
		player.visible = true
		player.set_physics_process(true)
	else:
		print("ERROR: Could not load level at path: ", level_path)

func _teleport_player(target_spawn_name: String):
	# Search the new level for a Marker3D matching the exact spawn name
	var spawn_point = current_level_node.find_child(target_spawn_name, true, false)
	
	if spawn_point and spawn_point is Node3D:
		player.global_position = spawn_point.global_position
	else:
		print("Warning: Spawn point '", target_spawn_name, "' not found!")
		# Fallback: Drop them near the center of the terrain slightly in the air
		player.global_position = Vector3(0, 5, 0)
