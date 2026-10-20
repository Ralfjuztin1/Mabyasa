extends Node3D

@onready var terrain = $MarchingSquaresTerrain


func _ready() -> void:
	# Start the main Forest objective as soon as the Forest scene loads.
	# QuestManager safely ignores it if it is already active or completed.
	if (
		is_instance_valid(QuestManager)
		and not QuestManager.is_quest_active("get_mystic_ylang_ylang")
		and not QuestManager.is_quest_completed("get_mystic_ylang_ylang")
		and not QuestManager.has_dialogue_flag("mystic_ylang_ylang_obtained")
	):
		QuestManager.start_quest("get_mystic_ylang_ylang")
		print("[Forest] Started quest: Find the Mystic Ylang-Ylang")

	print("[Forest] Starting terrain initialization...")

	if terrain == null:
		push_error("[Forest] MarchingSquaresTerrain not found!")
		return

	# Give the terrain node time to enter the scene tree.
	await get_tree().process_frame

	print("[Forest] Terrain found.")

	# Force Yūgen terrain to rebuild/update its material.
	if terrain.has_method("force_batch_update"):
		print("[Forest] Calling force_batch_update()")
		terrain.force_batch_update()
	else:
		print("[Forest] force_batch_update() does not exist.")

		# Fallback for versions of the addon that don't have force_batch_update().
		if terrain.has_method("refresh_chunk_surface_materials"):
			print("[Forest] Refreshing terrain materials...")
			terrain.refresh_chunk_surface_materials()

		# Mark chunks dirty so their meshes/materials update.
		for child in terrain.get_children():
			if child.has_method("mark_dirty"):
				child.mark_dirty()

			if child.has_method("queue_mesh_regen"):
				child.queue_mesh_regen(true)

	# Give Godot another frame to finish the material update.
	await get_tree().process_frame

	print("[Forest] Terrain initialization complete.")

	# Keep the existing Enter the Forest objective working.
	if is_instance_valid(GameEvents):
		GameEvents.location_reached.emit("forest")
		print("[Forest] Location reached event emitted: forest")
