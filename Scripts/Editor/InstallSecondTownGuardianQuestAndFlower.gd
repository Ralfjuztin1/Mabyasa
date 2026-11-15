@tool
extends EditorScript

## Run with SecondTown.tscn OPEN and ACTIVE in the Godot editor.
## Adds/updates only the boss, second flower and handoff controller.
const TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"
const BOSS_SCENE: String = "res://Scenes/SecondTown/SecondTownNumberGuardian.tscn"
const FLOWER_SCENE: String = "res://Scenes/SecondTown/SecondTownSecondYlangYlang.tscn"
const HANDOFF_SCRIPT: Script = preload("res://Scripts/SecondTown/SecondTownBossQuestHandoff.gd")
const MANAGER_AUTOLOAD: String = "*res://Scripts/Battle/SecondTownNumberBattleManager.gd"

func _run() -> void:
	var town: Node3D = EditorInterface.get_edited_scene_root() as Node3D
	if not is_instance_valid(town) or town.scene_file_path != TOWN_PATH:
		push_error("Open Scenes/Main/SecondTown.tscn as the active scene, then run this script.")
		return

	var flower_marker: Marker3D = town.get_node_or_null("marker/secondTownYlangYlang") as Marker3D
	var guardian_marker: Marker3D = town.get_node_or_null("marker/secondTownGuardian") as Marker3D
	if flower_marker == null or guardian_marker == null:
		push_error("Missing marker/secondTownYlangYlang or marker/secondTownGuardian in the active scene.")
		return

	var flower: Node3D = town.get_node_or_null("SecondTownYlangYlang") as Node3D
	if flower == null:
		flower = _instantiate(FLOWER_SCENE)
		if flower == null:
			return
		flower.name = "SecondTownYlangYlang"
		town.add_child(flower)
		flower.owner = town
	# Exact marker location, with no invented offset.
	flower.global_transform = flower_marker.global_transform
	print("[SECOND TOWN STORY] Second flower placed at secondTownYlangYlang: ", flower.global_position)

	var guardian: Node3D = town.get_node_or_null("SecondTownNumberGuardian") as Node3D
	if guardian == null:
		guardian = _instantiate(BOSS_SCENE)
		if guardian == null:
			return
		guardian.name = "SecondTownNumberGuardian"
		town.add_child(guardian)
		guardian.owner = town
		# Existing installed boss placements are kept; new ones spawn over the
		# dedicated Guardian marker and fall onto the terrain during runtime.
		guardian.global_position = guardian_marker.global_position + Vector3(0.0, 1.0, 0.0)
		print("[SECOND TOWN STORY] Boss added near secondTownGuardian marker.")
	else:
		print("[SECOND TOWN STORY] Existing boss preserved; no duplicates.")

	var handoff: Node = town.get_node_or_null("SecondTownBossQuestHandoff")
	if handoff == null:
		handoff = Node.new()
		handoff.name = "SecondTownBossQuestHandoff"
		handoff.set_script(HANDOFF_SCRIPT)
		town.add_child(handoff)
		handoff.owner = town
	else:
		handoff.set_script(HANDOFF_SCRIPT)

	var result: Error = EditorInterface.save_scene()
	if result != OK:
		push_error("Second Town scene could not be saved: " + str(result))
		return

	var current_manager: String = str(ProjectSettings.get_setting("autoload/BattleManager", ""))
	if current_manager == "*res://Scripts/Assessment/PairedBattleManager.gd":
		ProjectSettings.set_setting("autoload/BattleManager", MANAGER_AUTOLOAD)
		var saved: Error = ProjectSettings.save()
		if saved != OK:
			push_error("Could not update the BattleManager autoload: " + str(saved))
			return
		print("[SECOND TOWN STORY] Configured Number Guardian BattleManager. Restart Godot.")
	elif current_manager != MANAGER_AUTOLOAD:
		push_warning("BattleManager autoload differs. Confirm Number Guardian BattleManager is configured: " + current_manager)

	print("[SECOND TOWN STORY] Installed. Elder quest now unlocks Guardian quest, then flower quest.")

func _instantiate(scene_path: String) -> Node3D:
	var resource: PackedScene = load(scene_path) as PackedScene
	if resource == null:
		push_error("Missing: " + scene_path + " (install boss ZIP first)")
		return null
	return resource.instantiate() as Node3D
