@tool
extends EditorScript

## One-time scene installation. Adds a permanent, editable scene instance.
## Run with SecondTown.tscn open in Godot's 3D editor, then save the town.

const TOWN: String = "res://Scenes/Main/SecondTown.tscn"
const FIELD_SCENE: PackedScene = preload("res://Scenes/SecondTown/FarmerFieldQuest.tscn")

func _run() -> void:
	var edited: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited) or edited.scene_file_path != TOWN:
		push_error("Open Scenes/Main/SecondTown.tscn first, then run this script.")
		return
	if edited.get_node_or_null("FarmerFieldQuest") != null:
		print("[FARMER] Already present under SecondTown; no duplicate added.")
		return
	var source: String = ProjectSettings.globalize_path(TOWN)
	var backup: String = source + ".before_farmer_world_quest.bak"
	if not FileAccess.file_exists(source):
		push_error("Save SecondTown.tscn before running this installer.")
		return
	if not FileAccess.file_exists(backup):
		var copy_result: Error = DirAccess.copy_absolute(source, backup)
		if copy_result != OK:
			push_error("Failed to back up SecondTown.tscn; refusing to install")
			return
	var field: Node3D = FIELD_SCENE.instantiate() as Node3D
	if not is_instance_valid(field):
		push_error("Failed to instantiate FarmerFieldQuest.tscn")
		return
	field.name = "FarmerFieldQuest"
	edited.add_child(field)
	field.owner = edited
	EditorInterface.mark_scene_as_unsaved()
	print("[FARMER] Added SecondTown/FarmerFieldQuest. Press Ctrl+S to save it.")
