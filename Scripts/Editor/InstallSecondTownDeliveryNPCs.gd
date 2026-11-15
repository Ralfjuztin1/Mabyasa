@tool
extends EditorScript

## Adds three real, editor-visible BaseNPC instances to SecondTown/npc.
## Run once while Scenes/Main/SecondTown.tscn is the edited scene, then Ctrl+S.
## No gameplay code is changed and existing recipients are not duplicated.

const TOWN_PATH: String = "res://Scenes/Main/SecondTown.tscn"
const BASE_NPC: PackedScene = preload("res://Scenes/Characters/NPC/BaseNPC.tscn")
const DIALOGUE_FOLDER: String = "SecondTownSceneDialogues/"
const RECIPIENTS = [
	{"node": "berto", "name": "Berto", "id": "Berto", "count": 1, "position": Vector3(-48.0, 0.60, 17.0), "clothes": Color(0.35, 0.40, 0.18)},
	{"node": "mila", "name": "Mila", "id": "Mila", "count": 2, "position": Vector3(-26.0, 0.60, 12.0), "clothes": Color(0.44, 0.24, 0.43)},
	{"node": "nena", "name": "Nena", "id": "Nena", "count": 3, "position": Vector3(6.0, 0.60, 12.0), "clothes": Color(0.26, 0.35, 0.52)}
]


func _run() -> void:
	var town: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(town) or town.scene_file_path != TOWN_PATH:
		push_error("Open Scenes/Main/SecondTown.tscn in the 3D editor before running this script.")
		return
	var npc_root: Node3D = town.get_node_or_null("npc") as Node3D
	if not is_instance_valid(npc_root):
		push_error("SecondTown is missing its npc node. Aborting without changing your scene.")
		return

	# Preserve an unmodified disk copy before touching the edited scene.
	var original_file: String = ProjectSettings.globalize_path(TOWN_PATH)
	var backup_file: String = original_file + ".before_delivery_npcs.bak"
	if not FileAccess.file_exists(backup_file):
		if not FileAccess.file_exists(original_file):
			push_error("SecondTown.tscn is not saved yet. Save it first, then run the installer.")
			return
		var backup_result: Error = DirAccess.copy_absolute(original_file, backup_file)
		if backup_result != OK:
			push_error("Backup failed (error %d). No scene changes made." % backup_result)
			return

	var added: int = 0
	for recipient: Dictionary in RECIPIENTS:
		var short_id: String = str(recipient["node"])
		var actor: CharacterBody3D = npc_root.get_node_or_null(short_id) as CharacterBody3D
		if is_instance_valid(actor):
			print("[SECOND TOWN NPCS] Already exists in scene: ", short_id, " (kept in place)")
			# Do not change an artist's existing recipient or override its position.
			continue

		actor = BASE_NPC.instantiate() as CharacterBody3D
		if not is_instance_valid(actor):
			push_error("Could not instantiate BaseNPC.tscn for " + short_id)
			continue
		actor.name = short_id
		npc_root.add_child(actor)
		actor.owner = town
		actor.position = recipient["position"]
		actor.set("npc_name", str(recipient["name"]))
		actor.set("npc_id", str(recipient["id"]))
		actor.set("dialogue_id", DIALOGUE_FOLDER + "st_delivery_" + short_id + "_wait")
		actor.set("dialogue_entries", [])
		actor.set("can_wander", false)

		var name_label: Label3D = actor.get_node_or_null("NameLabel") as Label3D
		if is_instance_valid(name_label):
			name_label.text = str(recipient["name"])
		var sprite: AnimatedSprite3D = actor.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
		if is_instance_valid(sprite):
			# BaseNPC comes with empty SpriteFrames. Show a permanent 3D stand-in.
			sprite.visible = false

		_build_visible_actor(actor, town, recipient)
		_build_delivery_sign(actor, town, str(recipient["name"]), int(recipient["count"]))
		added += 1
		print("[SECOND TOWN NPCS] Added ", short_id, " at ", actor.position)

	if added > 0:
		EditorInterface.mark_scene_as_unsaved()
		print("[SECOND TOWN NPCS] Added %d editable NPC instances to SecondTown/npc. Press Ctrl+S NOW." % added)
	else:
		print("[SECOND TOWN NPCS] All recipients already exist. Nothing to add.")


func _build_visible_actor(actor: CharacterBody3D, scene_root: Node, recipient: Dictionary) -> void:
	# Visible geometry is permanently stored in SecondTown.tscn and remains
	# editable in the scene tree. Parent BaseNPC has scale 3, as the town's
	# existing NPCs do; these dimensions use the same local scale.
	var holder: Node3D = Node3D.new()
	holder.name = "DeliveryActorVisual"
	actor.add_child(holder)
	holder.owner = scene_root

	var clothes: StandardMaterial3D = StandardMaterial3D.new()
	clothes.albedo_color = recipient["clothes"]
	clothes.roughness = 1.0
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.79, 0.57, 0.39)
	skin.roughness = 1.0
	var hair: StandardMaterial3D = StandardMaterial3D.new()
	hair.albedo_color = Color(0.13, 0.10, 0.09)
	hair.roughness = 1.0

	_add_part(holder, scene_root, "Torso", _capsule(0.17, 0.52), Vector3(0.0, 0.17, 0.0), clothes)
	_add_part(holder, scene_root, "Head", _sphere(0.17, 0.34), Vector3(0.0, 0.50, 0.0), skin)
	_add_part(holder, scene_root, "Hair", _sphere(0.176, 0.19), Vector3(0.0, 0.61, 0.0), hair)
	for x: float in [-0.11, 0.11]:
		var leg_mesh: BoxMesh = BoxMesh.new()
		leg_mesh.size = Vector3(0.13, 0.28, 0.15)
		_add_part(holder, scene_root, "LeftLeg" if x < 0.0 else "RightLeg", leg_mesh, Vector3(x, -0.18, 0.0), clothes)


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _add_part(parent: Node3D, scene_root: Node, part_name: String, mesh: Mesh, at: Vector3, material: Material) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	part.owner = scene_root
	part.position = at


func _build_delivery_sign(actor: CharacterBody3D, scene_root: Node, recipient_name: String, basket_count: int) -> void:
	var sign: Label3D = Label3D.new()
	sign.name = "DeliveryPointLabel"
	sign.text = "DELIVERY / " + recipient_name.to_upper()
	sign.position = Vector3(0.0, 0.83, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.shaded = false
	sign.font_size = 30
	sign.pixel_size = 0.005
	sign.outline_size = 10
	sign.modulate = Color(0.99, 0.79, 0.40)
	actor.add_child(sign)
	sign.owner = scene_root

	# A subtle editor-visible clue. The active objective/interaction logic
	# remains in MerchantDeliveryController; this is not an auto-completion area.
	var badge: Label3D = Label3D.new()
	badge.name = "DeliveryCountLabel"
	badge.text = "%d %s" % [basket_count, "BASKET" if basket_count == 1 else "BASKETS"]
	badge.position = Vector3(0.0, 0.70, 0.0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.shaded = false
	badge.font_size = 23
	badge.pixel_size = 0.005
	badge.outline_size = 8
	badge.modulate = Color(0.91, 0.93, 0.78)
	actor.add_child(badge)
	badge.owner = scene_root
