extends Node

const DIALOGUE_PATH: String = "res://Scenes/Characters/NPC/Dialogic/"
const DIALOGUE_CAMERA_DISTANCE: float = 0.5
const CAMERA_TWEEN_TIME: float = 0.35

var current_npc: Node = null
var is_dialogue_active: bool = false

var player_was_physics_processing: bool = true
var player_was_input_processing: bool = true

var npc_was_physics_processing: bool = true
var npc_was_unhandled_input_processing: bool = true

var player_camera_distance: float = 5.2


func _ready() -> void:
	Dialogic.timeline_started.connect(_on_dialogue_started)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)


func start_dialogue(npc: Node) -> void:
	if is_dialogue_active:
		return

	if not is_instance_valid(npc):
		return

	var dialogue_id: String = npc.dialogue_id

	if dialogue_id.is_empty():
		push_warning("[DIALOGUE] NPC has no dialogue ID: " + str(npc.npc_name))
		return

	current_npc = npc

	var dialogue_path := DIALOGUE_PATH + dialogue_id + ".dtl"

	print("[DIALOGUE] Starting: ", dialogue_path)

	Dialogic.start(dialogue_path)


func _on_dialogue_started() -> void:
	is_dialogue_active = true

	GameManager.set_game_state(GameManager.GameState.DIALOGUE)

	var player := get_tree().get_first_node_in_group("player")

	if player:
		player_was_physics_processing = player.is_physics_processing()
		player_was_input_processing = player.is_processing_input()

		player.set_physics_process(false)
		player.set_process_input(false)

		_zoom_camera_in(player)

	if is_instance_valid(current_npc):
		npc_was_physics_processing = current_npc.is_physics_processing()
		npc_was_unhandled_input_processing = current_npc.is_processing_unhandled_input()

		current_npc.set_physics_process(false)
		current_npc.set_process_unhandled_input(false)

		if "velocity" in current_npc:
			current_npc.velocity = Vector3.ZERO

		if current_npc.has_node("InteractionPrompt"):
			current_npc.get_node("InteractionPrompt").visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	print("[DIALOGUE] Dialogue started.")


func _on_dialogue_ended() -> void:
	is_dialogue_active = false

	var player := get_tree().get_first_node_in_group("player")

	if player:
		_zoom_camera_out(player)

		player.set_physics_process(player_was_physics_processing)
		player.set_process_input(player_was_input_processing)

	if is_instance_valid(current_npc):
		current_npc.set_physics_process(npc_was_physics_processing)
		current_npc.set_process_unhandled_input(npc_was_unhandled_input_processing)

	current_npc = null

	GameManager.set_game_state(GameManager.GameState.EXPLORATION)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	print("[DIALOGUE] Dialogue ended.")


func _get_player_spring_arm(player: Node) -> SpringArm3D:
	if player.has_node("Head/SpringArm3D"):
		return player.get_node("Head/SpringArm3D") as SpringArm3D

	return null


func _zoom_camera_in(player: Node) -> void:
	var spring_arm := _get_player_spring_arm(player)

	if not spring_arm:
		return

	player_camera_distance = spring_arm.spring_length

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		spring_arm,
		"spring_length",
		DIALOGUE_CAMERA_DISTANCE,
		CAMERA_TWEEN_TIME
	)


func _zoom_camera_out(player: Node) -> void:
	var spring_arm := _get_player_spring_arm(player)

	if not spring_arm:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		spring_arm,
		"spring_length",
		player_camera_distance,
		CAMERA_TWEEN_TIME
	)
