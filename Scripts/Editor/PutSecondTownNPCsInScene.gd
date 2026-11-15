@tool
extends EditorScript

## ONE-TIME editor tool. Places regular BaseNPC instances directly in
## Scenes/Main/SecondTown.tscn under a plain `npc` Node3D, matching FirstTown.
## Do not attach this script to any scene. Open it and choose File > Run.

const TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"
const BASE_NPC: PackedScene = preload("res://Scenes/Characters/NPC/BaseNPC.tscn")
const PLACEHOLDER_SCRIPT: Script = preload("res://Scripts/SecondTown/NPCSpritePlaceholder.gd")
const ANIMATIONS: Array[String] = [
	"idle_front", "idle_back", "idle_left", "idle_right",
	"walk_front", "walk_back", "walk_left", "walk_right"
]
const NPCS := [
	{
		"node": "merchant",
		"name": "Merchant",
		"id": "second_town_merchant",
		"dialogue": "SecondTownSceneDialogues/merchant_intro",
		"position": [-52.5, 0.75, 25.5],
		"clothes": Color(0.13, 0.33, 0.24),
		"skin": Color(0.77, 0.58, 0.38)
	},
	{
		"node": "farmer",
		"name": "Farmer",
		"id": "second_town_farmer",
		"dialogue": "SecondTownSceneDialogues/farmer_intro",
		"position": [-44.0, 0.75, 17.5],
		"clothes": Color(0.41, 0.30, 0.16),
		"skin": Color(0.66, 0.44, 0.27)
	},
	{
		"node": "elder",
		"name": "Elder",
		"id": "second_town_elder",
		"dialogue": "SecondTownSceneDialogues/elder_intro",
		"position": [6.1, 0.75, 3.8],
		"clothes": Color(0.35, 0.24, 0.43),
		"skin": Color(0.72, 0.52, 0.34)
	}
]


func _run() -> void:
	var town: Node = EditorInterface.get_edited_scene_root()
	if town == null or town.scene_file_path != TOWN_PATH:
		push_error("Open Scenes/Main/SecondTown.tscn in the editor FIRST, then run this script.")
		return

	# Keep a disk copy of the original full town before the editor saves changes.
	var original_path: String = ProjectSettings.globalize_path(TOWN_PATH)
	var backup_path: String = original_path + ".before_direct_npcs.bak"
	if not FileAccess.file_exists(backup_path):
		var copy_error: Error = DirAccess.copy_absolute(original_path, backup_path)
		if copy_error != OK:
			push_error("Could not back up SecondTown.tscn. Nothing was modified.")
			return

	var npc_parent: Node3D = town.get_node_or_null("npc") as Node3D
	if npc_parent == null:
		npc_parent = Node3D.new()
		npc_parent.name = "npc"
		town.add_child(npc_parent)
		npc_parent.owner = town

	# The earlier pack had one extra instanced group scene. Migrate its frames
	# where possible, then remove that group so there are no duplicate villagers.
	var old_group: Node = town.get_node_or_null("SecondTownNPCs")
	var created: int = 0
	for definition: Dictionary in NPCS:
		var node_name: String = str(definition["node"])
		if npc_parent.has_node(node_name):
			print("[SECOND TOWN] Already exists; skipping: ", node_name)
			continue

		var character: CharacterBody3D = BASE_NPC.instantiate() as CharacterBody3D
		character.name = node_name
		npc_parent.add_child(character)
		character.owner = town
		character.set("npc_name", str(definition["name"]))
		character.set("npc_id", str(definition["id"]))
		character.set("dialogue_id", str(definition["dialogue"]))
		character.set("can_wander", false)

		var coords: Array = definition["position"]
		character.position = Vector3(float(coords[0]), float(coords[1]), float(coords[2]))

		var frames: SpriteFrames = _blank_frames()
		if is_instance_valid(old_group):
			var previous: Node = old_group.find_child(str(definition["name"]), true, false)
			if is_instance_valid(previous):
				var previous_frames: Variant = previous.get("npc_frames")
				if previous_frames is SpriteFrames:
					frames = (previous_frames as SpriteFrames).duplicate(true) as SpriteFrames
					# The frames are embedded locally, just like in FirstTown.
					frames.resource_path = ""
				character.position = previous.position

		character.set("npc_frames", frames)
		var sprite: AnimatedSprite3D = character.get_node("AnimatedSprite3D") as AnimatedSprite3D
		sprite.sprite_frames = frames
		sprite.animation = &"idle_front"
		sprite.position.y = 0.29

		var name_label: Label3D = character.get_node("NameLabel") as Label3D
		name_label.text = str(definition["name"])
		name_label.position.y = 0.55
		var prompt: Label3D = character.get_node("InteractionPrompt") as Label3D
		prompt.position.y = 0.67

		_add_placeholder(character, town, definition)
		created += 1

	if is_instance_valid(old_group):
		town.remove_child(old_group)
		old_group.queue_free()
		print("[SECOND TOWN] Removed old SecondTownNPCs group scene.")

	# Scene nodes are REAL direct children of SecondTown/npc, not separate NPC .tscn files.
	# Save SecondTown.tscn from the editor to write these changes to the project.
	EditorInterface.mark_scene_as_unsaved()
	print("[SECOND TOWN] Created ", created, " direct BaseNPC instances. Press Ctrl+S to save SecondTown.tscn.")


func _blank_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for animation_name: String in ANIMATIONS:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 5.0)
		frames.set_animation_loop(animation_name, true)
	return frames


func _add_placeholder(character: CharacterBody3D, town: Node, definition: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "VisualPlaceholder"
	holder.set_script(PLACEHOLDER_SCRIPT)
	character.add_child(holder)
	holder.owner = town

	var clothing := StandardMaterial3D.new()
	clothing.albedo_color = definition["clothes"]
	clothing.roughness = 1.0
	var skin := StandardMaterial3D.new()
	skin.albedo_color = definition["skin"]
	skin.roughness = 1.0

	var torso := MeshInstance3D.new()
	torso.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.095
	body_mesh.height = 0.34
	torso.mesh = body_mesh
	torso.material_override = clothing
	torso.position.y = 0.15
	holder.add_child(torso)
	torso.owner = town

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.105
	head_mesh.height = 0.21
	head.mesh = head_mesh
	head.material_override = skin
	head.position.y = 0.40
	holder.add_child(head)
	head.owner = town
