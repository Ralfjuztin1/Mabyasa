@tool
extends EditorScript

const SCENE_PATH := "res://Scenes/Main/SecondTown.tscn"
const LESSON_SCENE_PATH := "res://Scenes/SecondTown/ElderWellLesson.tscn"

func _run() -> void:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null or root.name != "SecondTown":
		push_error("Open Scenes/Main/SecondTown.tscn before running this installer.")
		return

	var packed: PackedScene = load(LESSON_SCENE_PATH)
	if packed == null:
		push_error("Could not load " + LESSON_SCENE_PATH)
		return

	var existing := root.get_node_or_null("ElderWellLesson")
	if existing != null:
		existing.queue_free()

	var instance: Node = packed.instantiate()
	instance.name = "ElderWellLesson"
	root.add_child(instance)
	_set_owner_recursive(instance, root)

	var scene_pack := PackedScene.new()
	var pack_err := scene_pack.pack(root)
	if pack_err != OK:
		push_error("Could not pack SecondTown scene. Error code: %d" % pack_err)
		return
	var save_err := ResourceSaver.save(scene_pack, SCENE_PATH)
	if save_err != OK:
		push_error("Could not save SecondTown.tscn. Error code: %d" % save_err)
		return

	print("[ELDER WELL] Installed ElderWellLesson into SecondTown.tscn")


func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
