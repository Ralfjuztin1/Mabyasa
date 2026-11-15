@tool
extends EditorScript

## Open Scenes/Main/SecondTown.tscn in the editor and choose File > Run.
## This adds BaseNPC instances directly under SecondTown/npc, like FirstTown.
## Existing merchant sprites/positions are preserved. No large scene replacement.

const TOWN: String = "res://Scenes/Main/SecondTown.tscn"
const BASE: PackedScene = preload("res://Scenes/Characters/NPC/BaseNPC.tscn")
const CONTROLLER: Script = preload("res://Scripts/SecondTown/MerchantDeliveryController.gd")
const ANIMATIONS = [
	"idle_front", "idle_back", "idle_left", "idle_right",
	"walk_front", "walk_back", "walk_left", "walk_right"
]
const PEOPLE = [
	{"node": "merchant", "name": "Merchant", "id": "second_town_merchant", "at": Vector3(-52.0, 0.60, 26.0)},
	{"node": "berto", "name": "Berto", "id": "st_berto", "at": Vector3(-48.0, 0.60, 17.0)},
	{"node": "mila", "name": "Mila", "id": "st_mila", "at": Vector3(-26.0, 0.60, 12.0)},
	{"node": "nena", "name": "Nena", "id": "st_nena", "at": Vector3(6.0, 0.60, 12.0)}
]


func _run() -> void:
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != TOWN:
		push_error("Open Scenes/Main/SecondTown.tscn in Godot before running this installer.")
		return

	var disk_path: String = ProjectSettings.globalize_path(TOWN)
	var backup_path: String = disk_path + ".before_merchant_deliveries.bak"
	if not FileAccess.file_exists(backup_path):
		var backup_result: Error = DirAccess.copy_absolute(disk_path, backup_path)
		if backup_result != OK:
			push_error("Could not back up SecondTown.tscn; installation cancelled.")
			return

	var npc_root: Node3D = scene.get_node_or_null("npc") as Node3D
	if npc_root == null:
		npc_root = Node3D.new()
		npc_root.name = "npc"
		scene.add_child(npc_root)
		npc_root.owner = scene

	for data: Dictionary in PEOPLE:
		_install_person(scene, npc_root, data)

	var controller_node: Node = scene.get_node_or_null("MerchantDelivery")
	if controller_node == null:
		controller_node = Node.new()
		controller_node.name = "MerchantDelivery"
		controller_node.set_script(CONTROLLER)
		scene.add_child(controller_node)
		controller_node.owner = scene
	else:
		controller_node.set_script(CONTROLLER)

	if scene.get_node_or_null("SecondTownNPCs") != null:
		push_warning("A previous SecondTownNPCs wrapper still exists; remove its duplicate merchant if present.")
	if scene.find_child("MerchantCountingLesson", true, false) != null:
		push_warning("Remove the old stand-alone MerchantCountingLesson placeholder to avoid two merchants.")

	EditorInterface.mark_scene_as_unsaved()
	print("[MERCHANT] Added direct delivery NPCs; press Ctrl+S to save SecondTown.tscn.")


func _install_person(scene: Node, npc_root: Node3D, data: Dictionary) -> void:
	var short_id: String = str(data["node"])
	var person: CharacterBody3D = npc_root.get_node_or_null(short_id) as CharacterBody3D
	var new_person: bool = person == null
	if new_person:
		person = BASE.instantiate() as CharacterBody3D
		person.name = short_id
		npc_root.add_child(person)
		person.owner = scene
		person.position = data["at"]

	person.set("npc_name", str(data["name"]))
	person.set("npc_id", str(data["id"]))
	person.set("can_wander", false)
	person.set("dialogue_entries", [])
	person.set("dialogue_id", "SecondTownSceneDialogues/merchant_quest" if short_id == "merchant" else "SecondTownSceneDialogues/st_delivery_" + short_id + "_wait")

	var sprite: AnimatedSprite3D = person.get_node("AnimatedSprite3D") as AnimatedSprite3D
	var current_frames: SpriteFrames = person.get("npc_frames") as SpriteFrames
	if current_frames == null or _frame_total(current_frames) == 0:
		current_frames = _new_placeholder_frames(short_id)
		person.set("npc_frames", current_frames)
		sprite.sprite_frames = current_frames
	elif sprite.sprite_frames == null:
		sprite.sprite_frames = current_frames
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle_front"):
		sprite.animation = &"idle_front"
	person.get_node("NameLabel").set("text", str(data["name"]))
	print("[MERCHANT] ", "Added" if new_person else "Updated", " ", short_id)


func _frame_total(frames: SpriteFrames) -> int:
	var total: int = 0
	for animation_name: StringName in frames.get_animation_names():
		total += frames.get_frame_count(animation_name)
	return total


func _new_placeholder_frames(character_id: String) -> SpriteFrames:
	var result: SpriteFrames = SpriteFrames.new()
	if result.has_animation(&"default"):
		result.remove_animation(&"default")
	var art: Texture2D = load("res://Assets/SecondTown/" + character_id + "_placeholder.png") as Texture2D
	for animation_name: String in ANIMATIONS:
		result.add_animation(animation_name)
		result.set_animation_loop(animation_name, true)
		result.set_animation_speed(animation_name, 5.0)
		if art != null:
			result.add_frame(animation_name, art)
	return result
