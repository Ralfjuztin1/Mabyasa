@tool
extends EditorScript

## One-time installation. Uses the OPEN Second Town scene so unsaved
## well/merchant/farmer changes are not silently replaced by old GitHub data.
const TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"
const BOSS_SCENE: String = "res://Scenes/SecondTown/SecondTownNumberGuardian.tscn"
const MANAGER_AUTOLOAD: String = "*res://Scripts/Battle/SecondTownNumberBattleManager.gd"

func _run() -> void:
	var town: Node3D = EditorInterface.get_edited_scene_root() as Node3D
	if not is_instance_valid(town) or town.name != "SecondTown" or town.scene_file_path != TOWN_PATH:
		push_error("Open Scenes/Main/SecondTown.tscn as the active editor scene, then run installer.")
		return
	var packed: PackedScene = load(BOSS_SCENE) as PackedScene
	if not is_instance_valid(packed):
		push_error("Missing boss scene. Extract the ZIP before running installer.")
		return

	var current: Node3D = town.get_node_or_null("SecondTownNumberGuardian") as Node3D
	if not is_instance_valid(current):
		current = packed.instantiate() as Node3D
		if not is_instance_valid(current):
			push_error("Failed to instantiate number guardian.")
			return
		current.name = "SecondTownNumberGuardian"
		town.add_child(current)
		current.owner = town

		# Dedicated guardian marker already exists in SecondTown.tscn.
		var marker: Node3D = town.get_node_or_null("marker/secondTownGuardian") as Node3D
		var spawn: Vector3 = Vector3(-55.97242, 2.0, 12.833124)
		if is_instance_valid(marker):
			spawn = marker.global_position + Vector3(0.0, 2.0, 6.0)
		current.global_position = spawn
		print("[NUMBERS BOSS] Added boss near the dedicated Guardian marker: " + str(spawn))
	else:
		print("[NUMBERS BOSS] Boss already exists; no duplicate created.")

	# Save the actual open scene, not an older disk copy.
	var saved: Error = EditorInterface.save_scene()
	if saved != OK:
		push_error("Could not save the edited Second Town scene: " + str(saved))
		return

	var current_manager: String = str(ProjectSettings.get_setting("autoload/BattleManager", ""))
	if current_manager != MANAGER_AUTOLOAD:
		if current_manager != "*res://Scripts/Assessment/PairedBattleManager.gd":
			push_error("[NUMBERS BOSS] BattleManager differs from the expected PairedBattleManager: " + current_manager + ". Autoload NOT replaced. Check current manager before using this boss.")
			return
		ProjectSettings.set_setting("autoload/BattleManager", MANAGER_AUTOLOAD)
		var settings_saved: Error = ProjectSettings.save()
		if settings_saved != OK:
			push_error("Failed to save BattleManager autoload: " + str(settings_saved))
			return
		print("[NUMBERS BOSS] BattleManager autoload updated, keeping paired-boss parent behavior.")

	print("[NUMBERS BOSS] Installed. Restart Godot before testing.")
