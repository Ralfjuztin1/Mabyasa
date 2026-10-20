
extends Node3D

@onready var terrain = $MarchingSquaresTerrain


func _ready() -> void:
	# Start the Mystic Ylang-Ylang quest as soon as Forest loads.
	_start_mystic_ylang_quest()

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

		# Fallback for versions without force_batch_update().
		if terrain.has_method("refresh_chunk_surface_materials"):
			print("[Forest] Refreshing terrain materials...")
			terrain.refresh_chunk_surface_materials()

		# Mark chunks dirty so their meshes/materials update.
		for child in terrain.get_children():
			if child.has_method("mark_dirty"):
				child.mark_dirty()

			if child.has_method("queue_mesh_regen"):
				child.queue_mesh_regen(true)

	# Give Godot time to finish the material update.
	await get_tree().process_frame

	print("[Forest] Terrain initialization complete.")

	# Preserve the existing Enter the Forest quest behavior.
	if is_instance_valid(GameEvents):
		GameEvents.location_reached.emit("forest")
		print("[Forest] Location reached event emitted: forest")


func _start_mystic_ylang_quest() -> void:
	if not is_instance_valid(QuestManager):
		push_error("[Forest] QuestManager is unavailable.")
		return

	const QUEST_ID: String = "get_mystic_ylang_ylang"
	const OBTAINED_FLAG: String = "mystic_ylang_ylang_obtained"

	# Never restart the quest if the flower was already obtained.
	if QuestManager.has_dialogue_flag(OBTAINED_FLAG):
		print("[Forest] Mystic Ylang-Ylang already obtained.")
		return

	# Don't restart an active quest or one already completed.
	if (
		QuestManager.is_quest_active(QUEST_ID)
		or QuestManager.is_quest_completed(QUEST_ID)
	):
		print("[Forest] Mystic Ylang-Ylang quest already started or completed.")
		return

	# Start the new main objective.
	QuestManager.start_quest(QUEST_ID)

	if QuestManager.is_quest_active(QUEST_ID):
		print("[Forest] Started quest: Find the Mystic Ylang-Ylang")
	else:
		push_warning(
			"[Forest] Failed to start Mystic Ylang-Ylang quest. "
			+ "Check Data/Quests/get_mystic_ylang_ylang.tres."
		)
