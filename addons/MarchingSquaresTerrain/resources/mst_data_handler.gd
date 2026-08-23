@tool
class_name MSTDataHandler
extends RefCounted
## Central handler for all external terrain data storage operations.


const ChunkData = preload("res://addons/MarchingSquaresTerrain/resources/mst_chunk_data.gd")

## Generate a unique terrain ID (called once on first save).
static func generate_terrain_uid() -> String:
	return "%08x" % (randi() ^ int(Time.get_unix_time_from_system()))

#region directory management

## Ensure directory exists, create one if needed.
static func ensure_directory_exists(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	
	var err := DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		printerr("MSTDataHandler: Failed to create directory: ", path, " Error: ", err)
		return false
	
	return true


## Get the resolved data directory path for the terrain node.
## Path format: [SceneDir]/[SceneName]_TerrainData/[NodeName]_[data_UID]/
static func generate_data_directory(terrain: MarchingSquaresTerrain) -> String:
	# generate default path based on scene location with unique data_UID
	var tree := terrain.get_tree()
	if not tree:
		return ""  # Node not in scene tree yet
	var inst := EngineWrapper.instance
	var scene_root := inst.get_root_for_node(terrain)
	if not scene_root or scene_root.scene_file_path.is_empty():
		return ""
	
	var scene_path := scene_root.scene_file_path
	var scene_dir := scene_path.get_base_dir()
	var scene_name := scene_path.get_file().get_basename()
	# Include data_UID in path to prevent collisions when nodes are recreated with same name
	return scene_dir.path_join(scene_name + "_TerrainData").path_join(terrain.name + "_" + generate_terrain_uid())


static func copy_recursive(from_path: String, to_path: String) -> void:
	var dir := DirAccess.open(from_path)
	if dir == null:
		push_error("Cannot open source directory: " + from_path)
		return
	
	DirAccess.make_dir_recursive_absolute(to_path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var src = from_path.path_join(file_name)
		var dst = to_path.path_join(file_name)
		
		if dir.current_is_dir():
			copy_recursive(src, dst)
		else:
			var err = DirAccess.copy_absolute(src, dst)
			if err != OK:
				push_error("Failed to copy file: %s -> %s" % [src, dst])
		file_name = dir.get_next()
	dir.list_dir_end()


## Check if a terrains data directory is unique
static func is_data_directory_unique(terrain: MarchingSquaresTerrain) -> bool:
	if not (EngineWrapper.instance.is_editor() and terrain.is_inside_tree()):
		return true
	var scene_root := EngineWrapper.instance.get_root_for_node(terrain)
	var dirs := _collect_terrain_dirs_recursive(scene_root)

	var simplified_path := terrain.data_directory.simplify_path()
	if not dirs.has(simplified_path):
		return true
	match dirs[simplified_path].size():
		0: return true
		1: return dirs[simplified_path][0] == terrain
		_: return false


## Check if metadata.res exists for a chunk.
static func metadata_exists(dir_path: String, coords: Vector2i) -> bool:
	if dir_path.is_empty():
		return false
	var chunk_dir := dir_path.path_join("chunk_%d_%d" % [coords.x, coords.y])
	return FileAccess.file_exists(chunk_dir.path_join("metadata.res"))

#endregion

#region save operations

## Save all dirty chunks to external .res files.
## Called from terrain._notification(NOTIFICATION_EDITOR_PRE_SAVE).
static func save_all_chunks(terrain: MarchingSquaresTerrain) -> void:
	
	var dir_path := terrain.data_directory
	if dir_path.is_empty():
		# No valid data directory - scene might not be saved yet
		return
	
	# Ensure directory exists
	if not ensure_directory_exists(dir_path):
		printerr("MSTDataHandler: Failed to create data directory: ", dir_path)
		return
	
	# Calculate initial size
	var initial_size : int = MarchingSquaresFileUtils.get_directory_size_recursive(dir_path)
	
	var saved_count := 0
	for chunk_coords in terrain.chunks:
		var chunk : MarchingSquaresTerrainChunk = terrain.chunks[chunk_coords]
		
		# Skip chunks being removed during undo/redo
		if chunk._skip_save_on_exit:
			continue
		
		# Determine if chunk needs saving:
		var needs_save : bool = chunk._data_dirty
		if not needs_save and not metadata_exists(dir_path, chunk_coords):
			needs_save = true
		
		if needs_save:
			save_chunk_resources(terrain, chunk)
			chunk._data_dirty = false
			saved_count += 1
	
	if saved_count > 0:
		_report_storage_size_change(terrain, dir_path, initial_size, saved_count)
		terrain._last_storage_mode = terrain.storage_mode
	
	# Clean up orphaned chunk directories that no longer exist in scene
	cleanup_orphaned_chunk_files(terrain)
	
	# Clean up orphaned terrain directories (terrains that no longer exist in scene)
	cleanup_orphaned_terrain_directories(terrain)
	
	terrain._storage_initialized = true


## Save chunk data to external file.
static func save_chunk_resources(terrain: MarchingSquaresTerrain, chunk: MarchingSquaresTerrainChunk) -> void:
	var dir_path := terrain.data_directory
	if dir_path.is_empty():
		printerr("MSTDataHandler: Cannot save chunk - no valid data directory")
		return
	
	var chunk_name := "chunk_%d_%d" % [chunk.chunk_coords.x, chunk.chunk_coords.y]
	var chunk_dir := dir_path.path_join(chunk_name)
	ensure_directory_exists(chunk_dir)
	
	# Export chunk data 
	var data : MSTChunkData = export_chunk_data(chunk)
	
	# Clear ephemeral data based on mode and config
	var is_baked_mode : bool = terrain.storage_mode == MarchingSquaresTerrain.StorageMode.BAKED
	
	if not is_baked_mode:
		data.mesh = null
	
	if not is_baked_mode or not terrain.bake_grass:
		data.grass_multimesh = null
	
	if not is_baked_mode or not terrain.bake_collision:
		data.collision_faces = PackedVector3Array()
	
	var metadata_path := chunk_dir.path_join("metadata.res")
	var err := ResourceSaver.save(data, metadata_path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("MSTDataHandler: Failed to save metadata to ", metadata_path)
	
	print_verbose("MSTDataHandler: Saved chunk ", chunk.chunk_coords)

#endregion

#region load operations

## Load all terrain data from external files.
static func load_terrain_data(terrain: MarchingSquaresTerrain) -> void:
	var dir_path := terrain.data_directory
	print_verbose("MSTDataHandler: load_terrain_data")
	if dir_path.is_empty():
		return
	
	# Scan for chunk directories (format: chunk_X_Y/)
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	
	var chunk_dirs : Array[Vector2i] = []
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name.begins_with("chunk_"):
			# Parse chunk coordinates from folder name: chunk_X_Y
			var parts := folder_name.trim_prefix("chunk_").split("_")
			if parts.size() == 2:
				var coords := Vector2i(int(parts[0]), int(parts[1]))
				chunk_dirs.append(coords)
		folder_name = dir.get_next()
	dir.list_dir_end()
	
	if chunk_dirs.is_empty():
		return
	
	print_verbose("MSTDataHandler: Loading ", chunk_dirs.size(), " chunk(s) from ", dir_path)
	
	for coords in chunk_dirs:
		load_chunk_from_directory(terrain, coords)


## Load a single chunk's source data from metadata file.
static func load_chunk_from_directory(terrain: MarchingSquaresTerrain, coords: Vector2i) -> void:
	var dir_path := terrain.data_directory
	var chunk_name := "chunk_%d_%d" % [coords.x, coords.y]
	var chunk_dir := dir_path.path_join(chunk_name)
	
	# Mesh, collision, and grass are regenerated separately by the chunk
	var chunk : MarchingSquaresTerrainChunk = terrain.chunks.get(coords)
	if not chunk:
		return
	
	# Load metadata source data
	var metadata_path := chunk_dir.path_join("metadata.res")
	if ResourceLoader.exists(metadata_path):
		var data : MSTChunkData = load(metadata_path)
		if data:
			import_chunk_data(chunk, data)
	
	print_verbose("MSTDataHandler: Loaded chunk ", coords)

#endregion

#region data export 

## Export chunk state to MSTChunkData for external storage.
## Converts color maps to compact byte arrays.
static func export_chunk_data(chunk: MarchingSquaresTerrainChunk) -> MSTChunkData:
	var data := MSTChunkData.new()
	data.chunk_coords = chunk.chunk_coords
	data.merge_mode = chunk.merge_mode
	
	# Source data
	data.height_map = chunk.height_map.duplicate(true)
	
	# Convert to new data model
	var cell_count : int = chunk.color_map_0.size()
	data.ground_texture_idx.resize(cell_count)
	data.wall_texture_idx.resize(cell_count)
	data.grass_mask.resize(cell_count)
	
	for i in cell_count:
		data.ground_texture_idx[i] = _colors_to_texture_idx(chunk.color_map_0[i], chunk.color_map_1[i])
		data.wall_texture_idx[i] = _colors_to_texture_idx(chunk.wall_color_map_0[i], chunk.wall_color_map_1[i])
		data.grass_mask[i] = 1 if chunk.grass_mask_map[i].r > 0.5 else 0
	
	# Ephemeral data for BAKED mode
	data.mesh = chunk.mesh
	
	if chunk.terrain_system.bake_grass and chunk.grass_planter:
		data.grass_multimesh = chunk.grass_planter.multimesh
	
	if chunk.terrain_system.bake_collision:
		# Find collision shape
		for child in chunk.get_children():
			if child is StaticBody3D:
				for shape_child in child.get_children():
					if shape_child is CollisionShape3D and shape_child.shape is ConcavePolygonShape3D:
						data.set_collision_from_shape(shape_child.shape)
						break
	
	# Clear legacy arrays 
	data.color_map_0 = PackedColorArray()
	data.color_map_1 = PackedColorArray()
	data.wall_color_map_0 = PackedColorArray()
	data.wall_color_map_1 = PackedColorArray()
	data.grass_mask_map = PackedColorArray()
	
	return data

#endregion

#region data import 

## Restore chunk state from MSTChunkData (loaded from external file).
## Expands compact byte arrays back to color arrays for runtime use.
static func import_chunk_data(chunk: MarchingSquaresTerrainChunk, data: MSTChunkData) -> void:
	if not data:
		printerr("MSTDataHandler: import_chunk_data called with null data")
		return
	
	chunk.chunk_coords = data.chunk_coords
	chunk.merge_mode = data.merge_mode as MarchingSquaresTerrainChunk.Mode
	chunk.height_map = data.height_map.duplicate(true)
	
	# Restore baked assets if present
	if data.mesh:
		chunk.mesh = data.mesh
	elif chunk.terrain_system.storage_mode == MarchingSquaresTerrain.StorageMode.BAKED:
		push_warning("Baking enabled, but terrain-resource does not contain mesh data")
		
	if chunk.terrain_system.bake_grass and not data.grass_multimesh:
		push_warning("Grass baking enabled, but terrain-resource does not contain grass data")
	
	if chunk.terrain_system.bake_collision and data.collision_faces.is_empty():
		push_warning("Collision baking enabled, but terrain-resource does not contain collision data")
	
	if data.grass_multimesh:
		chunk._temp_grass_multimesh = data.grass_multimesh
	
	if not data.collision_faces.is_empty():
		chunk._temp_collision_shapes = [data.get_collision_shape()]
	
	# Check format version
	var is_v2 : bool = data.is_v2_format()
	
	if is_v2:
		# if we use the new forma, we expand the compact arrays
		var cell_count : int = data.ground_texture_idx.size()
		chunk.color_map_0.resize(cell_count)
		chunk.color_map_1.resize(cell_count)
		chunk.wall_color_map_0.resize(cell_count)
		chunk.wall_color_map_1.resize(cell_count)
		chunk.grass_mask_map.resize(cell_count)
	
		for i in cell_count:
			var ground_colors : Array = _texture_idx_to_colors(data.ground_texture_idx[i])
			chunk.color_map_0[i] = ground_colors[0]
			chunk.color_map_1[i] = ground_colors[1]
			
			var wall_colors : Array = _texture_idx_to_colors(data.wall_texture_idx[i])
			chunk.wall_color_map_0[i] = wall_colors[0]
			chunk.wall_color_map_1[i] = wall_colors[1]
			
			chunk.grass_mask_map[i] = Color(1, 0, 0, 0) if data.grass_mask[i] > 0 else Color(0, 0, 0, 0)
	else:
		# V1. or v1.1 legacy format: direct copy
		chunk.color_map_0 = data.color_map_0.duplicate()
		chunk.color_map_1 = data.color_map_1.duplicate()
		chunk.wall_color_map_0 = data.wall_color_map_0.duplicate()
		chunk.wall_color_map_1 = data.wall_color_map_1.duplicate()
		chunk.grass_mask_map = data.grass_mask_map.duplicate()
		# Mark dirty to force re-save 
		chunk._data_dirty = true

#endregion

#region migration

## Check if this terrain needs migration from embedded to external storage.
static func needs_migration(terrain: MarchingSquaresTerrain) -> bool:
	# If already initialized with external storage, no migration needed
	if terrain._storage_initialized:
		return false
	
	# Check if any chunks have embedded data but no external files exist
	var dir_path := terrain.data_directory
	if dir_path.is_empty():
		return false
	
	for chunk_coords in terrain.chunks:
		var chunk : MarchingSquaresTerrainChunk = terrain.chunks[chunk_coords]
		# Check if chunk has embedded data (height_map populated)
		if chunk.height_map and not chunk.height_map.is_empty():
			if not metadata_exists(dir_path, chunk_coords):
				return true
	
	return false


## Migrate existing embedded data to external storage.
## Marks all chunks as dirty and triggers save.
static func migrate_to_external_storage(terrain: MarchingSquaresTerrain) -> void:
	print("MSTDataHandler: Migrating to external storage...")
	
	# Mark all chunks as dirty to force save
	for chunk_coords in terrain.chunks:
		var chunk : MarchingSquaresTerrainChunk = terrain.chunks[chunk_coords]
		chunk._data_dirty = true
	
	save_all_chunks(terrain)
	
	print("MSTDataHandler: Migration complete. External data saved to: ", terrain.data_directory)

#endregion

#region cleanup

## Clean up orphaned chunk directories that no longer exist in the scene.
static func cleanup_orphaned_chunk_files(terrain: MarchingSquaresTerrain) -> void:
	var dir_path := terrain.data_directory
	if dir_path.is_empty():
		return
	
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	
	var orphaned_dirs : Array[String] = []
	
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name.begins_with("chunk_"):
			# Parse chunk coordinates from folder name: chunk_X_Y
			var parts := folder_name.trim_prefix("chunk_").split("_")
			if parts.size() == 2:
				var coords := Vector2i(int(parts[0]), int(parts[1]))
				# If chunk doesn't exist in scene, mark for deletion
				if not terrain.chunks.has(coords):
					orphaned_dirs.append(dir_path.path_join(folder_name))
		folder_name = dir.get_next()
	dir.list_dir_end()
	
	# Delete orphaned directories
	for orphaned_dir in orphaned_dirs:
		_delete_chunk_directory(orphaned_dir)
		print_verbose("MSTDataHandler: Cleaned up orphaned chunk at ", orphaned_dir)


## Delete a chunk directory and all its contents.
static func _delete_chunk_directory(chunk_dir: String) -> void:
	var dir := DirAccess.open(chunk_dir)
	if not dir:
		return
	
	# Delete all files in directory
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var err : Error
	while file_name != "":
		if not dir.current_is_dir():
			err = dir.remove(file_name)
			if err != OK:
				printerr("MSTDataHandler: Failed to delete file ", file_name, " in ", chunk_dir)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Remove the directory itself
	err = DirAccess.remove_absolute(chunk_dir.trim_suffix("/"))
	if err != OK:
		printerr("MSTDataHandler: Failed to delete directory ", chunk_dir)

#endregion

#region color conversion helpers

## Convert Color pair to texture index (0-15).
## Uses the 4×4 vertex color channel encoding system.
static func _colors_to_texture_idx(c0: Color, c1: Color) -> int:
	var c0_idx := 0
	var c0_max := c0.r
	if c0.g > c0_max: c0_max = c0.g; c0_idx = 1
	if c0.b > c0_max: c0_max = c0.b; c0_idx = 2
	if c0.a > c0_max: c0_idx = 3
	
	var c1_idx := 0
	var c1_max := c1.r
	if c1.g > c1_max: c1_max = c1.g; c1_idx = 1
	if c1.b > c1_max: c1_max = c1.b; c1_idx = 2
	if c1.a > c1_max: c1_idx = 3
	
	return c0_idx * 4 + c1_idx


## Convert texture index (0-15) to Color pair.
## Reverses the encoding: index / 4 = c0 channel, index % 4 = c1 channel.
static func _texture_idx_to_colors(idx: int) -> Array:
	var c0 := Color(0, 0, 0, 0)
	var c1 := Color(0, 0, 0, 0)
	@warning_ignore_start("integer_division") 
	var c0_ch := idx / 4
	var c1_ch := idx % 4
	@warning_ignore_restore("integer_division")
	
	match c0_ch:
		0: c0.r = 1.0
		1: c0.g = 1.0
		2: c0.b = 1.0
		3: c0.a = 1.0
	
	match c1_ch:
		0: c1.r = 1.0
		1: c1.g = 1.0
		2: c1.b = 1.0
		3: c1.a = 1.0
	
	return [c0, c1]

#endregion

#region terrain directory cleanup

## Clean up terrain data directories for terrains that no longer exist in the scene.
## Called during save to prevent disk bloat from deleted terrains.
static func cleanup_orphaned_terrain_directories(terrain: MarchingSquaresTerrain) -> void:
	var tree := terrain.get_tree()
	if not tree:
		return
	
	var scene_root := EngineWrapper.instance.get_root_for_node(terrain)
	if not scene_root or scene_root.scene_file_path.is_empty():
		return
	
	# Get the TerrainData folder for this scene
	var scene_path := scene_root.scene_file_path
	var scene_dir := scene_path.get_base_dir()
	var scene_name := scene_path.get_file().get_basename()
	var terrain_data_dir := scene_dir.path_join(scene_name + "_TerrainData")
	
	if not DirAccess.dir_exists_absolute(terrain_data_dir):
		return
	
	# Collect all terrain data_UID currently in the scene
	var active_dirs : Dictionary[String, Array] = _collect_terrain_dirs_recursive(scene_root)
	
	# Scan terrain data directory for orphaned folders
	var dir := DirAccess.open(terrain_data_dir)
	if not dir:
		return
	
	var orphaned_dirs : Array[String] = []
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir():
			var res_name := terrain_data_dir.path_join(folder_name).simplify_path()
			if not active_dirs.has(res_name):
				orphaned_dirs.append(res_name)
		folder_name = dir.get_next()
	dir.list_dir_end()
	
	# Delete orphaned directories
	for orphaned_dir in orphaned_dirs:
		_delete_directory_recursive(orphaned_dir)
		print("MSTDataHandler: Cleaned up orphaned terrain data at ", orphaned_dir)


## Recursively collect terrain data dirs from scene tree.
static func _collect_terrain_dirs_recursive(node: Node, dirs: Dictionary[String, Array] = {}) -> Dictionary[String, Array]:
	var terrain := node as MarchingSquaresTerrain
	if terrain and not terrain.data_directory.is_empty():
		var simplified_path := terrain.data_directory.simplify_path()
		if not dirs.has(simplified_path):
			dirs.set(simplified_path, [terrain])
		else:
			dirs[simplified_path].append(terrain)
	for child in node.get_children():
		_collect_terrain_dirs_recursive(child, dirs)
	return dirs


## Delete a directory and all its contents recursively.
static func _delete_directory_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var item_name := dir.get_next()
	while item_name != "":
		if dir.current_is_dir():
			_delete_directory_recursive(dir_path.path_join(item_name))
		else:
			dir.remove(item_name)
		item_name = dir.get_next()
	dir.list_dir_end()
	
	DirAccess.remove_absolute(dir_path.trim_suffix("/"))


## Report the storage size change after a save operation.
static func _report_storage_size_change(terrain: MarchingSquaresTerrain, dir_path: String, initial_size: int, saved_count: int) -> void:
	var final_size : int = MarchingSquaresFileUtils.get_directory_size_recursive(dir_path)
	var size_difference_bytes : int = final_size - initial_size
	var percentage_change : float = 0.0
	
	if initial_size > 0:
		percentage_change = (float(size_difference_bytes) / float(initial_size)) * 100.0
	elif size_difference_bytes > 0:
		percentage_change = 100.0
	
	var sign_string := "+" if size_difference_bytes >= 0 else ""
	
	var previous_storage_mode_name : String = MarchingSquaresTerrain.StorageMode.keys()[terrain._last_storage_mode]
	var current_storage_mode_name : String = MarchingSquaresTerrain.StorageMode.keys()[terrain.storage_mode]
	
	print("MSTDataHandler: Saved ", saved_count, " chunk(s) to ", dir_path)
	print("MSTDataHandler: Storage Size: %s (%s) -> %s (%s) (%s%.2f%%)" % [
		String.humanize_size(initial_size), 
		previous_storage_mode_name,
		String.humanize_size(final_size), 
		current_storage_mode_name,
		sign_string, 
		percentage_change
	])

#endregion
