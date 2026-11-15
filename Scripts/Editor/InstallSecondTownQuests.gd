@tool
extends EditorScript

## One-time installer. Uses regular BaseNPC instances directly under
## SecondTown/npc, matching Scenes/Main/FirstTown.tscn.
## Open SecondTown.tscn and use File > Run. Then Ctrl+S.

const TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"
const BASE_NPC: PackedScene = preload("res://Scenes/Characters/NPC/BaseNPC.tscn")
const PLACEHOLDER_SCRIPT: Script = preload("res://Scripts/SecondTown/NPCSpritePlaceholder.gd")
const QUEST_SCRIPT: Script = preload("res://Scripts/SecondTown/SecondTownQuestController.gd")
const WELL_SCRIPT: Script = preload("res://Scripts/SecondTown/SecondTownWellInteraction.gd")

const ANIMATIONS: Array[String] = [
	"idle_front", "idle_back", "idle_left", "idle_right",
	"walk_front", "walk_back", "walk_left", "walk_right"
]

const NPCS := [
	{
		"node": "merchant", "name": "Merchant", "id": "second_town_merchant",
		"dialogue": "SecondTownSceneDialogues/merchant_quest",
		"position": Vector3(-52.5, 0.75, 25.5),
		"clothes": Color(0.13, 0.33, 0.24), "skin": Color(0.77, 0.58, 0.38)
	},
	{
		"node": "farmer", "name": "Farmer", "id": "second_town_farmer",
		"dialogue": "SecondTownSceneDialogues/farmer_locked",
		"position": Vector3(-44.0, 0.75, 17.5),
		"clothes": Color(0.41, 0.30, 0.16), "skin": Color(0.66, 0.44, 0.27)
	},
	{
		"node": "elder", "name": "Elder", "id": "second_town_elder",
		"dialogue": "SecondTownSceneDialogues/elder_locked",
		"position": Vector3(6.1, 0.75, 3.8),
		"clothes": Color(0.35, 0.24, 0.43), "skin": Color(0.72, 0.52, 0.34)
	}
]


func _run() -> void:
	var town: Node = EditorInterface.get_edited_scene_root()
	if town == null or town.scene_file_path != TOWN_PATH:
		push_error("Open Scenes/Main/SecondTown.tscn FIRST, then run InstallSecondTownQuests.gd")
		return

	# Refuse to touch scene if we cannot preserve an on-disk backup.
	var original_path: String = ProjectSettings.globalize_path(TOWN_PATH)
	var backup_path: String = original_path + ".before_second_town_quests.bak"
	if not FileAccess.file_exists(backup_path):
		var result: Error = DirAccess.copy_absolute(original_path, backup_path)
		if result != OK:
			push_error("Could not back up SecondTown.tscn; aborting.")
			return

	var npc_parent: Node3D = town.get_node_or_null("npc") as Node3D
	if npc_parent == null:
		npc_parent = Node3D.new()
		npc_parent.name = "npc"
		town.add_child(npc_parent)
		npc_parent.owner = town

	# Migrates the older stand-alone group if it was installed before the direct NPC pack.
	var old_group: Node = town.get_node_or_null("SecondTownNPCs")
	for data: Dictionary in NPCS:
		_install_npc(npc_parent, town, old_group, data)

	if is_instance_valid(old_group):
		town.remove_child(old_group)
		old_group.queue_free()
		print("[SECOND TOWN] Removed old stand-alone NPC group.")

	var controller: Node = town.get_node_or_null("SecondTownQuests")
	if controller == null:
		controller = Node.new()
		controller.name = "SecondTownQuests"
		controller.set_script(QUEST_SCRIPT)
		town.add_child(controller)
		controller.owner = town
	else:
		controller.set_script(QUEST_SCRIPT)

	var well: Area3D = town.get_node_or_null("WellInspection") as Area3D
	if well == null:
		well = Area3D.new()
		well.name = "WellInspection"
		well.position = Vector3(2.1, 0.0, 1.8)
		well.collision_layer = 0
		well.collision_mask = 1
		well.monitoring = true
		well.set_script(WELL_SCRIPT)
		town.add_child(well)
		well.owner = town

		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.position.y = 0.75
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 2.0
		collision.shape = sphere
		well.add_child(collision)
		collision.owner = town

		var prompt: Label3D = Label3D.new()
		prompt.name = "Prompt"
		prompt.text = "[E] Inspect Well"
		prompt.position.y = 2.0
		prompt.font_size = 28
		prompt.pixel_size = 0.005
		prompt.billboard = 2
		prompt.no_depth_test = true
		prompt.visible = false
		well.add_child(prompt)
		prompt.owner = town

		var clue: Label3D = Label3D.new()
		clue.name = "Clue"
		clue.position.y = 2.4
		clue.font_size = 26
		clue.pixel_size = 0.005
		clue.billboard = 2
		clue.no_depth_test = true
		clue.visible = false
		well.add_child(clue)
		clue.owner = town
	else:
		well.set_script(WELL_SCRIPT)

	EditorInterface.mark_scene_as_unsaved()
	print("[SECOND TOWN] Merchant, Farmer, Elder + lessons + well interaction ready. Press Ctrl+S.")


func _install_npc(npc_parent: Node3D, town: Node, old_group: Node, data: Dictionary) -> void:
	var node_name: String = str(data["node"])
	var npc: CharacterBody3D = npc_parent.get_node_or_null(node_name) as CharacterBody3D
	var is_new: bool = npc == null
	if is_new:
		npc = BASE_NPC.instantiate() as CharacterBody3D
		npc.name = node_name
		npc_parent.add_child(npc)
		npc.owner = town
		npc.position = data["position"]

	npc.set("npc_name", str(data["name"]))
	npc.set("npc_id", str(data["id"]))
	npc.set("dialogue_id", str(data["dialogue"]))
	# Existing introductory entry arrays would override dialogue_id. This
	# chapter uses its own dialogue-selection controller instead.
	var existing_entries: Variant = npc.get("dialogue_entries")
	if existing_entries is Array and not (existing_entries as Array).is_empty():
		push_warning("[SECOND TOWN] " + node_name + " has custom dialogue_entries; these override dialogue_id. Clear them for the new quests.")
	npc.set("can_wander", false)

	var sprite: AnimatedSprite3D = npc.get_node("AnimatedSprite3D") as AnimatedSprite3D
	var frames: SpriteFrames = npc.get("npc_frames") as SpriteFrames
	if frames == null or _count_frames(frames) == 0:
		if is_instance_valid(old_group):
			var previous: Node = old_group.find_child(str(data["name"]), true, false)
			if is_instance_valid(previous):
				var old_frames: Variant = previous.get("npc_frames")
				if old_frames is SpriteFrames and _count_frames(old_frames as SpriteFrames) > 0:
					frames = (old_frames as SpriteFrames).duplicate(true) as SpriteFrames
					frames.resource_path = ""
				if is_new:
					npc.position = previous.position
		if frames == null or _count_frames(frames) == 0:
			frames = _blank_frames()
		npc.set("npc_frames", frames)
		sprite.sprite_frames = frames
	else:
		sprite.sprite_frames = frames

	# Preserve the player's custom sprite frames and NPC positions on reruns.
	sprite.position.y = 0.29
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle_front"):
		sprite.animation = &"idle_front"

	var name_label: Label3D = npc.get_node("NameLabel") as Label3D
	name_label.text = str(data["name"])
	name_label.position.y = 0.55
	var talk_prompt: Label3D = npc.get_node("InteractionPrompt") as Label3D
	talk_prompt.position.y = 0.67

	if npc.get_node_or_null("VisualPlaceholder") == null:
		_add_placeholder(npc, town, data)
	print("[SECOND TOWN] ", "Added " if is_new else "Updated ", node_name)


func _count_frames(frames: SpriteFrames) -> int:
	var count: int = 0
	for anim: StringName in frames.get_animation_names():
		count += frames.get_frame_count(anim)
	return count


func _blank_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for anim: String in ANIMATIONS:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 5.0)
		frames.set_animation_loop(anim, true)
	return frames


func _add_placeholder(npc: CharacterBody3D, town: Node, data: Dictionary) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "VisualPlaceholder"
	holder.set_script(PLACEHOLDER_SCRIPT)
	npc.add_child(holder)
	holder.owner = town

	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = data["clothes"]
	var skin_material: StandardMaterial3D = StandardMaterial3D.new()
	skin_material.albedo_color = data["skin"]

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.095
	body_mesh.height = 0.34
	body.mesh = body_mesh
	body.material_override = body_material
	body.position.y = 0.15
	holder.add_child(body)
	body.owner = town

	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "Head"
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.105
	head_mesh.height = 0.21
	head.mesh = head_mesh
	head.material_override = skin_material
	head.position.y = 0.40
	holder.add_child(head)
	head.owner = town
