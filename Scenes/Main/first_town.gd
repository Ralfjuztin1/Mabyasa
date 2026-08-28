extends Node3D

@onready var terrain = $MarchingSquaresTerrain


func _ready() -> void:
	print("[FirstTown] Starting terrain initialization...")

	if terrain == null:
		push_error("[FirstTown] MarchingSquaresTerrain not found!")
		return

	# Give the terrain node time to enter the scene tree.
	await get_tree().process_frame

	print("[FirstTown] Terrain found.")

	# --------------------------------------------------
	# Force Yūgen terrain to rebuild/update its material.
	# --------------------------------------------------
	if terrain.has_method("force_batch_update"):
		print("[FirstTown] Calling force_batch_update()")
		terrain.force_batch_update()
	else:
		print("[FirstTown] force_batch_update() does not exist.")

		# Fallback for versions of the addon that don't
		# have force_batch_update().
		if terrain.has_method("refresh_chunk_surface_materials"):
			print("[FirstTown] Refreshing terrain materials...")
			terrain.refresh_chunk_surface_materials()

		# Mark chunks dirty so their meshes/materials update.
		for child in terrain.get_children():
			if child.has_method("mark_dirty"):
				child.mark_dirty()

			if child.has_method("queue_mesh_regen"):
				child.queue_mesh_regen(true)

	# Give Godot another frame to finish the material update.
	await get_tree().process_frame

	print("[FirstTown] Terrain initialization complete.")
