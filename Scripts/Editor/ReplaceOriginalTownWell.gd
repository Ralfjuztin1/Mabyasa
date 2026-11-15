@tool
extends EditorScript

## One-time scene migration.
## Replaces the existing PropWell1 with an anchor for the runtime-built Elder well.
## This modifies the currently OPEN SecondTown scene, preserving all other nodes.

const LESSON_PATH: String = "res://Scenes/SecondTown/ElderWellLesson.tscn"

func _run() -> void:
	var town: Node3D = EditorInterface.get_edited_scene_root() as Node3D
	if not is_instance_valid(town) or town.name != "SecondTown" or town.scene_file_path != "res://Scenes/Main/SecondTown.tscn":
		push_error("Open Scenes/Main/SecondTown.tscn as the active scene, then run this script.")
		return

	var original: Node3D = town.get_node_or_null("Houses/PropWell1") as Node3D
	var anchor: Marker3D = town.get_node_or_null("ElderWellAnchor") as Marker3D
	var reference: Node3D = town.get_node_or_null("marker/wellMarker") as Node3D

	# An exact scene-position source is required: never move the well blindly.
	if not is_instance_valid(original) and not is_instance_valid(anchor) and not is_instance_valid(reference):
		push_error("Could not find Houses/PropWell1 or the town's wellMarker. No changes made.")
		return

	# Ensure the new controller exists BEFORE removing the original prop.
	var controller: Node = town.get_node_or_null("ElderWellLesson")
	var new_controller: Node = null
	if not is_instance_valid(controller):
		var packed: PackedScene = load(LESSON_PATH) as PackedScene
		if not is_instance_valid(packed):
			push_error("Missing " + LESSON_PATH + " - original well has not been removed.")
			return
		new_controller = packed.instantiate()
		if not is_instance_valid(new_controller):
			push_error("Could not instantiate ElderWellLesson. No changes made.")
			return

	var original_position: Vector3 = Vector3.ZERO
	if is_instance_valid(original):
		original_position = original.global_position
	elif is_instance_valid(anchor):
		original_position = anchor.global_position
	else:
		original_position = reference.global_position

	if not is_instance_valid(anchor):
		anchor = Marker3D.new()
		anchor.name = "ElderWellAnchor"
		town.add_child(anchor)
		anchor.owner = town
	anchor.global_position = original_position

	if is_instance_valid(new_controller):
		new_controller.name = "ElderWellLesson"
		town.add_child(new_controller)
		new_controller.owner = town

	# Remove the old visual ONLY after the anchor and replacement are ready.
	if is_instance_valid(original):
		original.get_parent().remove_child(original)
		original.free()

	# This old trigger listens for E and shows '[E] Inspect Well' during the
	# new quest, so it conflicts with the new well's E/R/F interactions.
	var obsolete_trigger: Node = town.get_node_or_null("WellInspection")
	if is_instance_valid(obsolete_trigger):
		obsolete_trigger.get_parent().remove_child(obsolete_trigger)
		obsolete_trigger.free()

	# Preserve marker/wellMarker, player spawns, NPCs, terrain and quest chain.
	EditorInterface.mark_scene_as_unsaved()
	var save_result: Error = EditorInterface.save_scene()
	if save_result != OK:
		push_error("Well replacement applied in editor but could not save. Press Ctrl+S. Error: %d" % save_result)
		return
	print("[ELDER WELL] Replaced old PropWell1 with textured quest well at: ", original_position)
	print("[ELDER WELL] Anchor: SecondTown/ElderWellAnchor; controller: SecondTown/ElderWellLesson")
