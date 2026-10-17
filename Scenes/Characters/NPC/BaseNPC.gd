@tool
extends CharacterBody3D


@export_category("NPC Identity")

@export var npc_name: String = "Townsman":
	set(value):
		npc_name = value
		if is_inside_tree() and has_node("NameLabel"):
			$NameLabel.text = value

@export var npc_id: String = ""


@export_category("Dialogue")

@export var dialogue_id: String = ""
@export var dialogue_entries: Array[NPCDialogueEntry] = []


@export_category("Interaction Cutscenes")

## Multiple story cutscenes can be assigned in order.
## The first available cutscene is played when the player selects Talk.
@export var interaction_cutscenes: Array[CutsceneDirector] = []

## One flag per cutscene, matching the same array index.
## Leave a flag empty if the cutscene should be repeatable.
@export var cutscene_flags: Array[String] = []

## Enable this for NPCs like Chief when a successful interaction cutscene
## should be followed immediately by the NPC's selected Dialogue Entry.
## Leave disabled when the cutscene already contains its own dialogue.
@export var continue_to_dialogue_after_interaction_cutscene: bool = false


@export var npc_frames: SpriteFrames:
	set(value):
		npc_frames = value
		if Engine.is_editor_hint() and has_node("AnimatedSprite3D"):
			$AnimatedSprite3D.sprite_frames = value


@export_category("NPC Behavior")

@export var can_wander: bool = false
@export var move_speed: float = 2.0
@export var wander_radius: float = 3.0


@export_category("Food Market")
## When enabled, Talk and Shop choices are shown when the player interacts.
@export var opens_food_market: bool = false


@export_category("Blacksmith")
## When enabled, Talk and Blacksmith choices are shown when the player interacts.
@export var opens_blacksmith: bool = false


# ============================================================
# MOVEMENT
# ============================================================

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var wander_direction: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var start_position: Vector3
var previous_position: Vector3 = Vector3.ZERO


# ============================================================
# INTERACTION
# ============================================================

var player_in_range: bool = false
var _interaction_menu_open: bool = false
var _interaction_menu_layer: CanvasLayer = null
var _interaction_menu_player: Node = null
var _menu_player_was_physics_processing: bool = true
var _menu_player_was_input_processing: bool = true
var _menu_player_was_unhandled_input_processing: bool = true
var _menu_previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


# ============================================================
# ANIMATION
# ============================================================

var cutscene_controlled: bool = false
var current_facing: String = "front"
var is_idling: bool = true
var active_camera: Camera3D = null
var last_look_dir: Vector3 = Vector3(0, 0, 1)
var cutscene_facing: bool = false


@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var name_label: Label3D = $NameLabel
@onready var interaction_prompt: Label3D = $InteractionPrompt


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	if has_node("NameLabel"):
		name_label.text = npc_name

	if has_node("InteractionPrompt"):
		interaction_prompt.visible = false
		if opens_food_market or opens_blacksmith:
			interaction_prompt.text = "[E] Interact"
		else:
			interaction_prompt.text = "[E] Talk"

	if Engine.is_editor_hint():
		return

	start_position = global_position
	previous_position = global_position

	if npc_frames:
		animated_sprite.sprite_frames = npc_frames
		if animated_sprite.sprite_frames.has_animation("idle_front"):
			animated_sprite.play("idle_front")


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if cutscene_controlled:
		_update_direction_from_position()
		_update_animation()
		previous_position = global_position
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if can_wander:
		if wander_timer > 0.0:
			wander_timer -= delta
		else:
			_switch_wander_state()

		velocity.x = wander_direction.x * move_speed
		velocity.z = wander_direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

	if is_on_wall() and can_wander and not is_idling:
		_switch_wander_state(true)

	if velocity.x != 0.0 or velocity.z != 0.0:
		var movement_direction := Vector3(velocity.x, 0.0, velocity.z)
		if movement_direction.length_squared() > 0.001:
			last_look_dir = movement_direction.normalized()
	else:
		_update_direction_from_position()

	_update_animation()
	previous_position = global_position


func _update_direction_from_position() -> void:
	var movement := global_position - previous_position
	movement.y = 0.0
	if movement.length_squared() > 0.00001:
		last_look_dir = movement.normalized()


# ============================================================
# WANDER STATE
# ============================================================

func _switch_wander_state(forced_wall_bump: bool = false) -> void:
	if forced_wall_bump or not is_idling:
		is_idling = true
		wander_direction = Vector3.ZERO
		if forced_wall_bump:
			wander_timer = randf_range(0.5, 1.2)
		else:
			wander_timer = randf_range(2.0, 4.0)
		return

	is_idling = false
	if global_position.distance_to(start_position) > wander_radius:
		wander_direction = (start_position - global_position).normalized()
	else:
		wander_direction = Vector3(
			randf_range(-1.0, 1.0),
			0.0,
			randf_range(-1.0, 1.0)
		).normalized()
	wander_timer = randf_range(1.5, 3.5)


# ============================================================
# CAMERA / ANIMATION
# ============================================================

func _get_active_camera() -> Camera3D:
	var camera := get_viewport().get_camera_3d()
	if camera is Camera3D:
		return camera
	return null


func _update_animation() -> void:
	var is_moving: bool = (
		last_look_dir.length_squared() > 0.001
		and (
			velocity.x != 0.0
			or velocity.z != 0.0
			or global_position.distance_squared_to(previous_position) > 0.00001
		)
	)

	active_camera = _get_active_camera()
	if active_camera:
		var cam_forward := -active_camera.global_transform.basis.z
		var cam_right := active_camera.global_transform.basis.x
		cam_forward.y = 0.0
		cam_right.y = 0.0

		if cam_forward.length_squared() > 0.001:
			cam_forward = cam_forward.normalized()
		if cam_right.length_squared() > 0.001:
			cam_right = cam_right.normalized()

		var forward_amount: float = last_look_dir.dot(cam_forward)
		var right_amount: float = last_look_dir.dot(cam_right)

		if abs(right_amount) > abs(forward_amount):
			current_facing = "right" if right_amount > 0.0 else "left"
		else:
			current_facing = "back" if forward_amount > 0.0 else "front"

	var animation_name: String = ("walk_" if is_moving else "idle_") + current_facing
	if animated_sprite.animation != animation_name:
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
			animated_sprite.play(animation_name)


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	# Escape closes the choice menu before any normal gameplay input is handled.
	if _interaction_menu_open:
		if event.is_action_pressed("ui_cancel"):
			_close_interaction_choice_menu()
			get_viewport().set_input_as_handled()
		return

	if not player_in_range:
		return

	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()

		# Vendors and blacksmiths offer multiple options instead of forcing one action.
		if opens_food_market or opens_blacksmith:
			_open_interaction_choice_menu()
			return

		await _perform_talk_interaction()


func _perform_talk_interaction() -> void:
	QuestManager.handle_npc_interaction(npc_id)

	var cutscene_played: bool = await _try_play_interaction_cutscene()
	if (
		cutscene_played
		and not continue_to_dialogue_after_interaction_cutscene
	):
		return

	# If no cutscene was eligible or the director rejected it because its
	# story flags were not satisfied, do not consume the interaction.
	# Start the selected dialogue normally.
	DialogueManager.start_dialogue(self)


# ============================================================
# INTERACTION CHOICE MENU
# ============================================================

func _open_interaction_choice_menu() -> void:
	if _interaction_menu_open:
		return

	_interaction_menu_open = true
	_menu_previous_mouse_mode = Input.mouse_mode

	_interaction_menu_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_interaction_menu_player):
		_menu_player_was_physics_processing = _interaction_menu_player.is_physics_processing()
		_menu_player_was_input_processing = _interaction_menu_player.is_processing_input()
		_menu_player_was_unhandled_input_processing = _interaction_menu_player.is_processing_unhandled_input()
		_interaction_menu_player.set_physics_process(false)
		_interaction_menu_player.set_process_input(false)
		_interaction_menu_player.set_process_unhandled_input(false)

	GameManager.set_game_state(GameManager.GameState.DIALOGUE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var layer := CanvasLayer.new()
	layer.name = "NPCInteractionChoiceMenu"
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_interaction_menu_layer = layer

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.color = Color(0.0, 0.0, 0.0, 0.48)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	margin.add_child(contents)

	var title := Label.new()
	title.text = npc_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	contents.add_child(title)

	var hint := Label.new()
	hint.text = "What would you like to do?"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(hint)

	var first_button: Button = _add_interaction_choice_button(
		contents,
		"Talk",
		"talk"
	)

	if opens_food_market:
		_add_interaction_choice_button(
			contents,
			"Shop",
			"food_shop"
		)

	if opens_blacksmith:
		_add_interaction_choice_button(
			contents,
			"Blacksmith",
			"blacksmith"
		)

	_add_interaction_choice_button(
		contents,
		"Cancel",
		"cancel"
	)

	get_tree().root.add_child(layer)
	first_button.grab_focus()


func _add_interaction_choice_button(
	container: VBoxContainer,
	button_text: String,
	choice_id: String
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(280.0, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_interaction_choice_selected.bind(choice_id))
	container.add_child(button)
	return button


func _on_interaction_choice_selected(choice_id: String) -> void:
	_close_interaction_choice_menu()

	match choice_id:
		"talk":
			await _perform_talk_interaction()
		"food_shop":
			InventoryManager.open_market()
		"blacksmith":
			_open_blacksmith_menu()
		"cancel":
			return


func _close_interaction_choice_menu() -> void:
	_interaction_menu_open = false

	var menu := _interaction_menu_layer
	_interaction_menu_layer = null
	if is_instance_valid(menu):
		menu.queue_free()

	if is_instance_valid(_interaction_menu_player):
		_interaction_menu_player.set_physics_process(_menu_player_was_physics_processing)
		_interaction_menu_player.set_process_input(_menu_player_was_input_processing)
		_interaction_menu_player.set_process_unhandled_input(_menu_player_was_unhandled_input_processing)

	_interaction_menu_player = null
	GameManager.set_game_state(GameManager.GameState.EXPLORATION)
	Input.set_mouse_mode(_menu_previous_mouse_mode)


# ============================================================
# INTERACTION CUTSCENES
# ============================================================

func _try_play_interaction_cutscene() -> bool:
	if interaction_cutscenes.is_empty():
		return false

	for index in range(interaction_cutscenes.size()):
		var cutscene := interaction_cutscenes[index]
		if not is_instance_valid(cutscene):
			continue

		var flag := ""
		if index < cutscene_flags.size():
			flag = cutscene_flags[index].strip_edges()

		# Skip already-consumed legacy interaction cutscenes.
		if not flag.is_empty() and QuestManager.has_dialogue_flag(flag):
			continue

		# The flexible CutsceneDirector exposes its prerequisite checks.
		# A blocked/completed director must not swallow the NPC interaction.
		if not cutscene.can_play_sequence():
			print(
				"[NPC] Cutscene is not available; continue to dialogue: ",
				cutscene.get_debug_id()
			)
			continue

		print("[NPC] Playing interaction cutscene: ", cutscene.get_debug_id())
		var did_play: bool = await cutscene.play_sequence()

		# Do not consume the interaction when the director declined to play.
		if not did_play:
			continue

		# Cutscenes bypass DialogueManager, so notify the quest system only
		# after the sequence really finished.
		GameEvents.npc_talked.emit(npc_id)
		if not flag.is_empty():
			QuestManager.set_dialogue_flag(flag, true)
		return true

	return false


# ============================================================
# PLAYER ENTERED / EXITED
# ============================================================

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true
	if has_node("InteractionPrompt"):
		interaction_prompt.visible = true

	print("[NPC] Player entered interaction range: ", npc_name)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false
	if has_node("InteractionPrompt"):
		interaction_prompt.visible = false

	print("[NPC] Player left interaction range: ", npc_name)


# ============================================================
# BLACKSMITH MENU
# ============================================================

func _open_blacksmith_menu() -> void:
	var menu_scene := load("res://Scenes/UI/BlacksmithMenu.tscn") as PackedScene
	if menu_scene == null:
		push_error("[NPC] Could not load BlacksmithMenu.tscn.")
		return

	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
