extends Node3D

# First Town story guidance. Works with the EXISTING NPCs and quest managers.
# No changes to BaseNPC.gd, quest data, player controls or scene hierarchy needed.

@onready var terrain = $MarchingSquaresTerrain
@onready var _town_npcs: Node = get_node_or_null("npc")

var _hint_canvas: CanvasLayer
var _hint_panel: PanelContainer
var _hint_text: Label
var _hint_token: int = 0


func _ready() -> void:
	print("[FirstTown] Starting terrain initialization...")

	if terrain == null:
		push_error("[FirstTown] MarchingSquaresTerrain not found!")
		return

	# Give the terrain node time to enter the scene tree.
	await get_tree().process_frame
	print("[FirstTown] Terrain found.")

	# Preserve the existing terrain material refresh behavior.
	if terrain.has_method("force_batch_update"):
		print("[FirstTown] Calling force_batch_update()")
		terrain.force_batch_update()
	else:
		print("[FirstTown] force_batch_update() does not exist.")
		if terrain.has_method("refresh_chunk_surface_materials"):
			print("[FirstTown] Refreshing terrain materials...")
			terrain.refresh_chunk_surface_materials()

		for child in terrain.get_children():
			if child.has_method("mark_dirty"):
				child.mark_dirty()
			if child.has_method("queue_mesh_regen"):
				child.queue_mesh_regen(true)

	await get_tree().process_frame
	print("[FirstTown] Terrain initialization complete.")


# This runs BEFORE BaseNPC._unhandled_input(), which is where E-to-talk
# normally starts. An early interaction is consumed before quest events fire.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return
	if get_tree().paused:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	if get_viewport().is_input_handled():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return

	var target: Node3D = _nearest_interactable_npc()
	if target == null:
		return

	var target_id: String = str(target.get("npc_id")).to_lower().strip_edges()
	var hint: String = get_early_npc_message(target_id)
	if hint.is_empty():
		return

	get_viewport().set_input_as_handled()
	show_story_hint(hint)


func _nearest_interactable_npc() -> Node3D:
	if not is_instance_valid(_town_npcs):
		return null

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return null

	var best: Node3D = null
	var best_distance: float = INF
	for child in _town_npcs.get_children():
		if not child is Node3D:
			continue
		# Match BaseNPC's actual interaction range rather than guessing a radius.
		if child.get("player_in_range") != true:
			continue
		var distance: float = player.global_position.distance_squared_to(child.global_position)
		if distance < best_distance:
			best = child as Node3D
			best_distance = distance

	return best


func _active(quest_id: String) -> bool:
	return QuestManager.is_quest_active(quest_id)


func _completed(quest_id: String) -> bool:
	return QuestManager.is_quest_completed(quest_id)


func _flag(flag_id: String) -> bool:
	return QuestManager.has_dialogue_flag(flag_id)


# Public: used by ForestGate and the narrow-path trigger, too.
func get_story_direction() -> String:
	if _active("walk_to_apu"):
		return "Ima asked me to meet Apu beside the big tree first."
	if _active("deliver_bebang_basket"):
		return "I should finish Apu's errand and deliver the basket to Bebang."
	if _active("visit_chief_after_basket"):
		return "Bebang said Chief is waiting. I should speak with him next."
	if _active("get_training_gear"):
		return "Chief asked me to collect my training gear from Panday first."
	if _active("return_to_chief") or _active("first_training_battle"):
		return "I have my gear. I should return to Chief for training."
	if _active("return_to_chief_after_training"):
		return "I should speak with Chief about the training battle."
	if _active("return_home_to_ima"):
		if QuestManager.get_current_step("return_home_to_ima") == 0:
			return "Chief told me to restore my strength at the Big Tree first."
		return "I've rested at the Big Tree. I should return home to Ima."
	if _active("greet_ima"):
		return "It's morning. I should greet Ima before heading out."
	if _active("go_to_chief_final_training"):
		if not _flag("ale_path_cleared"):
			return "Ale Pacing is blocking the narrow path. I should ask her to let me pass politely before visiting Chief."
		return "The narrow path is clear. I can go to Chief for final training."
	if _active("visit_ale_pacing"):
		return "I should use 'Makilabas ku pu' to ask Ale Pacing to clear the path."
	if _active("defeat_chief_final_training"):
		return "I should finish Chief's final training trial."
	if _active("reach_forest") or _completed("defeat_chief_final_training"):
		return "Chief has cleared me to enter the forest. I should follow the path to the Forest Gate."
	if not _completed("walk_to_apu"):
		return "Ima asked me to find Apu beside the big tree."
	return "I should check the Quest Log to see what I need to do next."


# Returns an empty string when the NPC's original interaction is allowed.
# Do NOT block story NPCs in their normal quest, battle or healing/retry states.
func get_early_npc_message(npc_id: String) -> String:
	match npc_id:
		"pacing":
			# During final training, walking near Ale triggers the existing
			# narrow-path cutscene automatically. Do not intercept E or
			# tell the player to wait for an unrelated movement scene.
			if _active("go_to_chief_final_training") or _active("visit_ale_pacing"):
				return ""
			if _flag("ale_path_cleared"):
				return ""
			return get_story_direction()

		"chief":
			# Never interfere with the scripted Chief training/battle/retry dialogue.
			if _flag("chief_training_battle_lost") or _flag("chief_training_healed"):
				return ""
			if _flag("chief_final_training_battle_lost") or _flag("chief_final_training_battle_healed"):
				return ""
			if _active("visit_chief_after_basket") or _active("return_to_chief"):
				return ""
			if _active("first_training_battle") or _active("return_to_chief_after_training"):
				return ""
			if _active("defeat_chief_final_training") or _flag("chief_final_training_battle_completed"):
				return ""
			if _active("go_to_chief_final_training"):
				if not _flag("ale_path_cleared"):
					return "I should clear the narrow path with Ale Pacing before starting Chief's final training."
				return ""
			return get_story_direction()

		"panday":
			if _active("get_training_gear"):
				return ""
			if _active("walk_to_apu") or _active("deliver_bebang_basket") or _active("visit_chief_after_basket"):
				return get_story_direction()
			# Do not block the shop or unrelated story stages.
			return ""

		"bebang":
			if _active("walk_to_apu"):
				return get_story_direction()
			return ""

		"ima":
			if _active("walk_to_apu"):
				return get_story_direction()
			if _active("return_home_to_ima") and QuestManager.get_current_step("return_home_to_ima") == 0:
				return get_story_direction()
			return ""

		"apu":
			if _active("deliver_bebang_basket"):
				return get_story_direction()
			return ""

	return ""


# A small, non-blocking hint in the game's existing forest-and-gold palette.
# Created on demand, so no extra scene nodes or texture assets are required.
func show_story_hint(message: String, duration: float = 3.6) -> void:
	if message.strip_edges().is_empty():
		return
	_ensure_hint_ui()
	if not is_instance_valid(_hint_panel) or not is_instance_valid(_hint_text):
		return

	if _hint_panel.visible and _hint_text.text == message:
		return

	_hint_text.text = message
	_hint_panel.visible = true
	_hint_token += 1
	var token: int = _hint_token

	await get_tree().create_timer(duration).timeout
	if token == _hint_token and is_instance_valid(_hint_panel):
		_hint_panel.visible = false


func _ensure_hint_ui() -> void:
	if is_instance_valid(_hint_panel):
		return

	_hint_canvas = CanvasLayer.new()
	_hint_canvas.name = "FirstTownStoryGuidance"
	_hint_canvas.layer = 85
	add_child(_hint_canvas)

	var full_screen: Control = Control.new()
	full_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_canvas.add_child(full_screen)
	full_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_hint_panel = PanelContainer.new()
	_hint_panel.name = "StoryHint"
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left = -330.0
	_hint_panel.offset_right = 330.0
	_hint_panel.offset_top = -148.0
	_hint_panel.offset_bottom = -42.0
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	full_screen.add_child(_hint_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.14, 0.12, 0.96)
	style.border_color = Color(0.89, 0.70, 0.37)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
	_hint_panel.add_theme_stylebox_override("panel", style)

	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(content)

	var heading: Label = Label.new()
	heading.text = "STORY REMINDER"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.93, 0.76, 0.45))
	content.add_child(heading)

	_hint_text = Label.new()
	_hint_text.name = "HintText"
	_hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_text.add_theme_font_size_override("font_size", 20)
	_hint_text.add_theme_color_override("font_color", Color(0.97, 0.95, 0.85))
	content.add_child(_hint_text)
