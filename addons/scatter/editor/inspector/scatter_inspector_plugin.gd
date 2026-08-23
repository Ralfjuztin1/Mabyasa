@tool
class_name ScatterInspectorPlugin
extends EditorInspectorPlugin

signal open_requested(target: MultiMeshInstance3D)
signal rebuild_requested(target: MultiMeshInstance3D)
signal detach_requested(target: MultiMeshInstance3D)
signal configure_requested(target: MultiMeshInstance3D)
signal load_requested(target: MultiMeshInstance3D)


func _can_handle(object: Object) -> bool:
	return object is MultiMeshInstance3D


func _parse_begin(object: Object) -> void:
	var target := object as MultiMeshInstance3D
	var graph := ScatterGraphAttachment.get_graph(target)
	var has_graph := graph != null
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override(&"separation", 4)
	if not has_graph:
		var setup_actions := HBoxContainer.new()
		var configure := _action_button(
			"Create",
			&"Add",
			"Create and link a new Scatter recipe for this MultiMeshInstance3D.",
			func(): configure_requested.emit(target),
		)
		configure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setup_actions.add_child(configure)
		var load := _action_button(
			"Load",
			&"Load",
			"Link an existing Scatter recipe resource to this MultiMeshInstance3D.",
			func(): load_requested.emit(target),
		)
		load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setup_actions.add_child(load)
		panel.add_child(setup_actions)
	else:
		var recipe_path := Label.new()
		recipe_path.text = graph.resource_path
		recipe_path.tooltip_text = graph.resource_path
		recipe_path.clip_text = true
		recipe_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_path.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.add_child(recipe_path)
		
		var actions := HBoxContainer.new()
		var open := _action_button(
			"Open Editor",
			&"Edit",
			"Open the linked Scatter recipe in the graph editor.",
			func(): open_requested.emit(target),
		)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(open)
		var rebuild := _action_button(
			"Build",
			&"Play",
			"Evaluate the graph and update the saved MultiMesh buffer.",
			func(): rebuild_requested.emit(target),
		)
		actions.add_child(rebuild)
		var load := _action_button(
			"",
			&"Load",
			"Replace this recipe link with another Scatter recipe resource.",
			func(): load_requested.emit(target),
			true,
		)
		actions.add_child(load)
		var detach := _action_button(
			"",
			&"Remove",
			"Remove the Scatter graph while preserving the current MultiMesh buffer.",
			func(): detach_requested.emit(target),
			true,
		)
		actions.add_child(detach)
		panel.add_child(actions)
	add_custom_control(panel)


func _action_button(
	text: String,
	icon_name: StringName,
	tooltip: String,
	callback: Callable,
	flat := false,
) -> Button:
	var button := Button.new()
	button.text = tr(text)
	button.icon = EditorInterface.get_editor_theme().get_icon(icon_name, &"EditorIcons")
	button.tooltip_text = tr(tooltip)
	button.flat = flat
	button.pressed.connect(callback)
	return button
