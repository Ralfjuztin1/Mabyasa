extends CanvasLayer

## Debug-only command console for Mabyasa.
## Add DeveloperConsole.tscn as a child of Scenes/SceneManager/Main.tscn.
## The console is removed automatically from non-debug builds.

const MAX_OUTPUT_LINES: int = 250

var _root: Control = null
var _output: RichTextLabel = null
var _command_input: LineEdit = null
var _status_summary: Label = null
var _quest_list: ItemList = null
var _quest_selection_label: Label = null
var _flag_list: ItemList = null
var _flag_id_input: LineEdit = null
var _flag_value_true: CheckBox = null
var _clear_flags_confirmation: ConfirmationDialog = null
var _pending_redo_quest_id: String = ""
var _selected_quest_id: String = ""
var _selected_flag_id: String = ""

var _console_open: bool = false
var _tree_was_paused: bool = false
var _previous_game_state: int = 0
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	if not OS.is_debug_build():
		queue_free()
		return

	_build_ui()
	_root.visible = false
	_write_line("MABYASA DEVELOPER CONSOLE | DEBUG BUILD ONLY")
	_write_line("Type 'help' to see commands. Press F10 to close this console.")
	_write_line("Note: quest changes may trigger the game's normal autosave.")
	_refresh_tool_views()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_F10:
		if _console_open:
			_close_console()
		else:
			_open_console()
		get_viewport().set_input_as_handled()
		return

	if _console_open and key_event.keycode == KEY_ESCAPE:
		_close_console()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "ConsoleOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "DimBackground"
	dim.color = Color(0.015, 0.02, 0.03, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ConsolePanel"
	panel.custom_minimum_size = Vector2(1100.0, 640.0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var title: Label = Label.new()
	title.text = "MABYASA  /  DEVELOPER TOOLS"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var debug_badge: Label = Label.new()
	debug_badge.text = "DEBUG BUILD"
	debug_badge.add_theme_color_override("font_color", Color(0.55, 0.95, 0.66, 1.0))
	debug_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(debug_badge)

	var close_button: Button = Button.new()
	close_button.text = "CLOSE  [F10]"
	close_button.custom_minimum_size = Vector2(125.0, 30.0)
	close_button.pressed.connect(_close_console)
	header.add_child(close_button)

	var subtitle: Label = Label.new()
	subtitle.text = "Click common actions or use the command bar below. The game is paused while this panel is open."
	subtitle.add_theme_font_size_override("font_size", 12)
	layout.add_child(subtitle)

	# Navigation tabs
	var tabs: TabContainer = TabContainer.new()
	tabs.name = "DeveloperTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(0.0, 285.0)
	layout.add_child(tabs)

	_build_quick_actions_tab(tabs)
	_build_quests_tab(tabs)
	_build_story_flags_tab(tabs)
	_build_command_help_tab(tabs)

	_clear_flags_confirmation = ConfirmationDialog.new()
	_clear_flags_confirmation.name = "ClearStoryFlagsConfirmation"
	_clear_flags_confirmation.title = "Clear All Story Flags?"
	_clear_flags_confirmation.dialog_text = "This will clear every dialogue/story flag before redoing the selected quest. Earlier cutscene prerequisites may also be removed. Continue only for a clean-slate test."
	_clear_flags_confirmation.ok_button_text = "Redo and Clear Flags"
	_clear_flags_confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	_clear_flags_confirmation.confirmed.connect(_confirm_redo_clearflags_selected_quest)
	add_child(_clear_flags_confirmation)

	var output_header: Label = Label.new()
	output_header.text = "OUTPUT"
	output_header.add_theme_font_size_override("font_size", 12)
	layout.add_child(output_header)

	_output = RichTextLabel.new()
	_output.name = "ConsoleOutput"
	_output.custom_minimum_size = Vector2(0.0, 105.0)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.bbcode_enabled = false
	_output.scroll_active = true
	_output.scroll_following = true
	_output.selection_enabled = true
	layout.add_child(_output)

	var prompt_row: HBoxContainer = HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 8)
	layout.add_child(prompt_row)

	var prompt: Label = Label.new()
	prompt.text = ">"
	prompt.custom_minimum_size = Vector2(18.0, 0.0)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_row.add_child(prompt)

	_command_input = LineEdit.new()
	_command_input.name = "CommandInput"
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.placeholder_text = "Command line: addgold 500, redo return_to_chief, setflag training_gear_received true ..."
	_command_input.clear_button_enabled = true
	_command_input.text_submitted.connect(_on_command_submitted)
	prompt_row.add_child(_command_input)

	var run_button: Button = Button.new()
	run_button.text = "RUN  [ENTER]"
	run_button.custom_minimum_size = Vector2(110.0, 32.0)
	run_button.pressed.connect(func() -> void:
		_on_command_submitted(_command_input.text)
	)
	prompt_row.add_child(run_button)

	var footer: Label = Label.new()
	footer.text = "F10: toggle console   |   ESC: close   |   Buttons use the same commands as the command line"
	footer.add_theme_font_size_override("font_size", 10)
	layout.add_child(footer)


func _build_quick_actions_tab(tabs: TabContainer) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "Quick Actions"
	page.add_theme_constant_override("separation", 10)
	tabs.add_child(page)

	_status_summary = Label.new()
	_status_summary.name = "PlayerStatusSummary"
	_status_summary.text = "Loading player status..."
	_status_summary.add_theme_font_size_override("font_size", 15)
	page.add_child(_status_summary)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var player_column: VBoxContainer = VBoxContainer.new()
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_column.add_theme_constant_override("separation", 8)
	columns.add_child(player_column)
	_add_section_header(player_column, "PLAYER STATS")

	_add_numeric_action_row(
		player_column, "Gold", 100, -9999999, 99999999,
		[{"label": "+ Add", "command": "addgold"}, {"label": "Set", "command": "setgold"}]
	)
	_add_numeric_action_row(
		player_column, "EXP", 250, 0, 99999999,
		[{"label": "+ Add EXP", "command": "addexp"}]
	)
	_add_numeric_action_row(
		player_column, "Current HP", 50, 0, 999999,
		[{"label": "Set HP", "command": "sethp"}]
	)
	_add_numeric_action_row(
		player_column, "Level", 5, 1, 999,
		[{"label": "Set Level", "command": "setlevel"}]
	)

	var utility_column: VBoxContainer = VBoxContainer.new()
	utility_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utility_column.add_theme_constant_override("separation", 8)
	columns.add_child(utility_column)
	_add_section_header(utility_column, "ONE-CLICK ACTIONS")
	_add_action_button(utility_column, "Full Heal", "fullheal", "Restore HP to the current maximum.")
	_add_action_button(utility_column, "Refresh Status", "status", "Print current player and quest status.")
	_add_action_button(utility_column, "List All Quests", "quests", "Print all loaded quests and their states.")
	_add_action_button(utility_column, "List Active Quests", "activequests", "Print only active quests.")
	_add_action_button(utility_column, "List Story Flags", "flags", "Print known dialogue/story flags.")
	_add_action_button(utility_column, "Help / Commands", "help", "Print all available typed commands.")


func _build_quests_tab(tabs: TabContainer) -> void:
	var page: HBoxContainer = HBoxContainer.new()
	page.name = "Quest Tools"
	page.add_theme_constant_override("separation", 14)
	tabs.add_child(page)

	var list_column: VBoxContainer = VBoxContainer.new()
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(list_column)

	_add_section_header(list_column, "QUEST DATABASE  |  Select a quest")
	_quest_list = ItemList.new()
	_quest_list.name = "QuestList"
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_list.custom_minimum_size = Vector2(600.0, 200.0)
	_quest_list.select_mode = ItemList.SELECT_SINGLE
	_quest_list.item_selected.connect(_on_quest_item_selected)
	list_column.add_child(_quest_list)

	var action_column: VBoxContainer = VBoxContainer.new()
	action_column.custom_minimum_size = Vector2(250.0, 0.0)
	action_column.add_theme_constant_override("separation", 8)
	page.add_child(action_column)
	_add_section_header(action_column, "SELECTED QUEST")

	_quest_selection_label = Label.new()
	_quest_selection_label.text = "No quest selected"
	_quest_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_column.add_child(_quest_selection_label)

	_add_action_button(action_column, "Start Selected", "__ui_start_selected_quest", "Start the selected quest if it is not already completed.")
	_add_action_button(action_column, "Force Complete", "__ui_complete_selected_quest", "Force-complete the selected quest and grant rewards.")
	_add_action_button(action_column, "Redo From Selected", "__ui_redo_selected_quest", "Undo selected and later completed quests, then restart the selected quest.")
	_add_action_button(action_column, "Redo + Clear All Flags", "__ui_redo_clearflags_selected_quest", "Destructive: also clears every dialogue/story flag.")
	_add_action_button(action_column, "Refresh Quest List", "__ui_refresh_quests", "Reload quest statuses from QuestManager.")

	var warning: Label = Label.new()
	warning.text = "Redo follows completion order, not an authored dependency tree. Clear flags only for clean-slate tests."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 11)
	warning.add_theme_color_override("font_color", Color(1.0, 0.78, 0.46, 1.0))
	action_column.add_child(warning)


func _build_story_flags_tab(tabs: TabContainer) -> void:
	var page: HBoxContainer = HBoxContainer.new()
	page.name = "Story Flags"
	page.add_theme_constant_override("separation", 14)
	tabs.add_child(page)

	var list_column: VBoxContainer = VBoxContainer.new()
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(list_column)
	_add_section_header(list_column, "KNOWN FLAGS  |  Select a flag to edit it")

	_flag_list = ItemList.new()
	_flag_list.name = "StoryFlagList"
	_flag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flag_list.custom_minimum_size = Vector2(600.0, 200.0)
	_flag_list.select_mode = ItemList.SELECT_SINGLE
	_flag_list.item_selected.connect(_on_flag_item_selected)
	_flag_list.item_activated.connect(_on_flag_item_activated)
	list_column.add_child(_flag_list)

	var editor: VBoxContainer = VBoxContainer.new()
	editor.custom_minimum_size = Vector2(250.0, 0.0)
	editor.add_theme_constant_override("separation", 8)
	page.add_child(editor)
	_add_section_header(editor, "EDIT FLAG")

	var flag_label: Label = Label.new()
	flag_label.text = "Flag ID"
	editor.add_child(flag_label)

	_flag_id_input = LineEdit.new()
	_flag_id_input.placeholder_text = "e.g. training_gear_received"
	_flag_id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(_flag_id_input)

	_flag_value_true = CheckBox.new()
	_flag_value_true.text = "Flag value = true"
	_flag_value_true.button_pressed = true
	editor.add_child(_flag_value_true)

	_add_action_button(editor, "Apply Value", "__ui_set_flag_value", "Set the flag to the checkbox value.")
	_add_action_button(editor, "Set True", "__ui_set_flag_true", "Set this flag to true.")
	_add_action_button(editor, "Set False / Clear", "__ui_set_flag_false", "Set this flag to false without deleting its key.")
	_add_action_button(editor, "Refresh Flag List", "__ui_refresh_flags", "Reload known flags from QuestManager.")

	var warning: Label = Label.new()
	warning.text = "Flags are separate from quest completion. Rewinding a quest does not automatically undo flags."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 11)
	editor.add_child(warning)


func _build_command_help_tab(tabs: TabContainer) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "Command Help"
	page.add_theme_constant_override("separation", 8)
	tabs.add_child(page)
	_add_section_header(page, "COMMAND LINE CHEATSHEET")

	var help_text: RichTextLabel = RichTextLabel.new()
	help_text.bbcode_enabled = false
	help_text.fit_content = true
	help_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help_text.text = "PLAYER\n  addgold 500      setgold 1000      addexp 300      sethp 40\n  fullheal          setlevel 10       status\n\nQUESTS\n  quests            activequests       startquest <quest_id>\n  completequest <quest_id>             redo <quest_id>\n  redo <quest_id> clearflags\n\nSTORY FLAGS\n  flags              setflag <flag_id> true|false\n  clearflag <flag_id>\n\nTip: you can still type any supported command in the bottom command bar. Use the Quest Tools and Story Flags tabs for click-based controls."
	page.add_child(help_text)


func _add_section_header(parent: Control, text_value: String) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.89, 0.78, 0.50, 1.0))
	parent.add_child(label)


func _add_action_button(
	parent: Control,
	button_text: String,
	command_text: String,
	tooltip: String = ""
) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match command_text:
		"__ui_start_selected_quest":
			button.pressed.connect(_on_start_selected_quest)
		"__ui_complete_selected_quest":
			button.pressed.connect(_on_complete_selected_quest)
		"__ui_redo_selected_quest":
			button.pressed.connect(_on_redo_selected_quest)
		"__ui_redo_clearflags_selected_quest":
			button.pressed.connect(_on_redo_clearflags_selected_quest)
		"__ui_refresh_quests":
			button.pressed.connect(_refresh_quest_list)
		"__ui_set_flag_value":
			button.pressed.connect(_on_apply_flag_value)
		"__ui_set_flag_true":
			button.pressed.connect(_on_set_flag_true)
		"__ui_set_flag_false":
			button.pressed.connect(_on_set_flag_false)
		"__ui_refresh_flags":
			button.pressed.connect(_refresh_flag_list)
		_:
			button.pressed.connect(_run_command_button.bind(command_text))

	parent.add_child(button)
	return button


func _add_numeric_action_row(
	parent: Control,
	label_text: String,
	default_value: float,
	minimum: float,
	maximum: float,
	actions: Array
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var value: SpinBox = SpinBox.new()
	value.min_value = minimum
	value.max_value = maximum
	value.step = 1.0
	value.value = default_value
	value.custom_minimum_size = Vector2(115.0, 0.0)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)

	for action in actions:
		var button: Button = Button.new()
		button.text = str(action.get("label", "Run"))
		button.tooltip_text = "%s %d" % [str(action.get("command", "")), int(value.value)]
		button.custom_minimum_size = Vector2(80.0, 30.0)
		button.pressed.connect(_run_numeric_command.bind(str(action.get("command", "")), value))
		row.add_child(button)


func _run_numeric_command(command_name: String, value_control: SpinBox) -> void:
	_run_command_button("%s %d" % [command_name, int(value_control.value)])


func _run_command_button(command_line: String) -> void:
	if command_line.begins_with("__ui_"):
		return
	_write_line("> " + command_line)
	_execute_command(command_line)
	_refresh_tool_views()


func _refresh_tool_views() -> void:
	_refresh_status_summary()
	_refresh_quest_list()
	_refresh_flag_list()


func _refresh_status_summary() -> void:
	if not is_instance_valid(_status_summary):
		return
	if not is_instance_valid(PlayerProgression) or not is_instance_valid(QuestManager):
		_status_summary.text = "Player or QuestManager is unavailable."
		return

	PlayerProgression.ensure_hp_initialized()
	_status_summary.text = "LEVEL %d    |    EXP %d / %d    |    GOLD %d    |    HP %d / %d    |    QUESTS %d active / %d completed" % [
		PlayerProgression.level,
		PlayerProgression.current_exp,
		PlayerProgression.get_max_exp(PlayerProgression.level),
		PlayerProgression.gold,
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp(),
		QuestManager.active_quests.size(),
		QuestManager.completed_quests.size()
	]


func _refresh_quest_list() -> void:
	if not is_instance_valid(_quest_list) or not is_instance_valid(QuestManager):
		return

	var preserve_id: String = _selected_quest_id
	_quest_list.clear()
	var ids: Array = QuestManager.quest_database.keys()
	ids.sort()
	_selected_quest_id = ""

	for raw_id in ids:
		var quest_id: String = str(raw_id)
		var data: QuestData = QuestManager.get_quest(quest_id)
		var status: String = "NOT STARTED"
		if QuestManager.is_quest_active(quest_id):
			status = "ACTIVE"
		elif QuestManager.is_quest_completed(quest_id):
			status = "COMPLETED"
		var quest_title: String = data.title if data != null else quest_id
		var index: int = _quest_list.item_count
		_quest_list.add_item("[%s] %s  |  %s" % [status, quest_title, quest_id])
		_quest_list.set_item_metadata(index, quest_id)
		if quest_id == preserve_id:
			_quest_list.select(index)
			_selected_quest_id = quest_id

	if _selected_quest_id.is_empty() and _quest_list.item_count > 0:
		_quest_list.select(0)
		_selected_quest_id = str(_quest_list.get_item_metadata(0))

	_update_quest_selection_label()


func _on_quest_item_selected(index: int) -> void:
	if not is_instance_valid(_quest_list):
		return
	_selected_quest_id = str(_quest_list.get_item_metadata(index))
	_update_quest_selection_label()


func _update_quest_selection_label() -> void:
	if not is_instance_valid(_quest_selection_label):
		return
	if _selected_quest_id.is_empty():
		_quest_selection_label.text = "No quest selected"
		return
	var data: QuestData = QuestManager.get_quest(_selected_quest_id)
	var status: String = "NOT STARTED"
	if QuestManager.is_quest_active(_selected_quest_id):
		status = "ACTIVE"
	elif QuestManager.is_quest_completed(_selected_quest_id):
		status = "COMPLETED"
	_quest_selection_label.text = "%s\n%s\n\nStatus: %s" % [data.title if data != null else _selected_quest_id, _selected_quest_id, status]


func _on_start_selected_quest() -> void:
	if _selected_quest_id.is_empty():
		_write_line("Select a quest first.")
		return
	_run_command_button("startquest " + _selected_quest_id)


func _on_complete_selected_quest() -> void:
	if _selected_quest_id.is_empty():
		_write_line("Select a quest first.")
		return
	_run_command_button("completequest " + _selected_quest_id)


func _on_redo_selected_quest() -> void:
	if _selected_quest_id.is_empty():
		_write_line("Select a quest first.")
		return
	_run_command_button("redo " + _selected_quest_id)


func _on_redo_clearflags_selected_quest() -> void:
	if _selected_quest_id.is_empty():
		_write_line("Select a quest first.")
		return
	_pending_redo_quest_id = _selected_quest_id
	_clear_flags_confirmation.popup_centered(Vector2i(620, 220))


func _confirm_redo_clearflags_selected_quest() -> void:
	if _pending_redo_quest_id.is_empty():
		return
	_run_command_button("redo " + _pending_redo_quest_id + " clearflags")
	_pending_redo_quest_id = ""


func _refresh_flag_list() -> void:
	if not is_instance_valid(_flag_list) or not is_instance_valid(QuestManager):
		return

	var preserve_id: String = _selected_flag_id
	_flag_list.clear()
	var ids: Array = QuestManager.dialogue_flags.keys()
	ids.sort()
	_selected_flag_id = ""

	for raw_id in ids:
		var flag_id: String = str(raw_id)
		var flag_value: bool = QuestManager.has_dialogue_flag(flag_id)
		var index: int = _flag_list.item_count
		_flag_list.add_item("[%s] %s" % ["TRUE" if flag_value else "FALSE", flag_id])
		_flag_list.set_item_metadata(index, flag_id)
		if flag_id == preserve_id:
			_flag_list.select(index)
			_selected_flag_id = flag_id

	if _selected_flag_id.is_empty() and _flag_list.item_count > 0:
		_flag_list.select(0)
		_selected_flag_id = str(_flag_list.get_item_metadata(0))

	# Keep typed text for a new flag instead of unexpectedly replacing it with
	# the previously selected flag. For an existing selected flag, update value.
	if (
		not _selected_flag_id.is_empty()
		and is_instance_valid(_flag_id_input)
		and (
			_flag_id_input.text.strip_edges().is_empty()
			or _flag_id_input.text.strip_edges() == preserve_id
		)
	):
		_sync_flag_editor_from_selection()


func _on_flag_item_selected(index: int) -> void:
	if not is_instance_valid(_flag_list):
		return
	_selected_flag_id = str(_flag_list.get_item_metadata(index))
	_sync_flag_editor_from_selection()


func _on_flag_item_activated(index: int) -> void:
	_on_flag_item_selected(index)
	_on_apply_flag_value()


func _sync_flag_editor_from_selection() -> void:
	if _selected_flag_id.is_empty():
		return
	if is_instance_valid(_flag_id_input):
		_flag_id_input.text = _selected_flag_id
	if is_instance_valid(_flag_value_true):
		_flag_value_true.button_pressed = QuestManager.has_dialogue_flag(_selected_flag_id)


func _get_flag_id_for_edit() -> String:
	if is_instance_valid(_flag_id_input):
		return _flag_id_input.text.strip_edges()
	return _selected_flag_id


func _on_apply_flag_value() -> void:
	var flag_id: String = _get_flag_id_for_edit()
	if flag_id.is_empty():
		_write_line("Enter a flag ID or select one from the list.")
		return
	_run_command_button("setflag %s %s" % [flag_id, "true" if _flag_value_true.button_pressed else "false"])
	_selected_flag_id = flag_id
	_refresh_flag_list()


func _on_set_flag_true() -> void:
	var flag_id: String = _get_flag_id_for_edit()
	if flag_id.is_empty():
		_write_line("Enter a flag ID or select one from the list.")
		return
	_run_command_button("setflag %s true" % flag_id)
	_selected_flag_id = flag_id
	_refresh_flag_list()
	_sync_flag_editor_from_selection()


func _on_set_flag_false() -> void:
	var flag_id: String = _get_flag_id_for_edit()
	if flag_id.is_empty():
		_write_line("Enter a flag ID or select one from the list.")
		return
	_run_command_button("clearflag %s" % flag_id)
	_selected_flag_id = flag_id
	_refresh_flag_list()
	_sync_flag_editor_from_selection()


func _open_console() -> void:
	if not is_instance_valid(_root):
		return

	# Avoid interrupting a live Dialogic timeline or quiz. The console can be
	# opened during exploration, while paused, or during a battle test.
	if is_instance_valid(GameManager):
		if GameManager.current_state in [GameManager.GameState.DIALOGUE, GameManager.GameState.QUIZ]:
			_write_line("Open the console outside dialogue or quiz screens.")
			return

	_tree_was_paused = get_tree().paused
	_previous_game_state = int(GameManager.current_state) if is_instance_valid(GameManager) else 0
	_previous_mouse_mode = Input.mouse_mode

	_console_open = true
	_root.visible = true
	get_tree().paused = true

	if is_instance_valid(GameManager):
		GameManager.set_game_state(GameManager.GameState.PAUSED)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_command_input.clear()
	_refresh_tool_views()
	_command_input.grab_focus()


func _close_console() -> void:
	if not _console_open:
		return

	_console_open = false
	_root.visible = false

	if _tree_was_paused:
		get_tree().paused = true
		if is_instance_valid(GameManager):
			GameManager.set_game_state(GameManager.GameState.PAUSED)
	else:
		get_tree().paused = false
		if is_instance_valid(GameManager):
			# Dialogue and quiz states are blocked when opening the console, so
			# exploration or combat are the only unpaused states to restore.
			if _previous_game_state == int(GameManager.GameState.COMBAT):
				GameManager.set_game_state(GameManager.GameState.COMBAT)
			else:
				GameManager.set_game_state(GameManager.GameState.EXPLORATION)

	Input.mouse_mode = _previous_mouse_mode


func _on_command_submitted(raw_command: String) -> void:
	var command_line: String = raw_command.strip_edges()
	_command_input.clear()
	_command_input.grab_focus()

	if command_line.is_empty():
		return

	_write_line("> " + command_line)
	_execute_command(command_line)
	_refresh_tool_views()


func _execute_command(command_line: String) -> void:
	var args: PackedStringArray = command_line.split(" ", false)
	if args.is_empty():
		return

	var command: String = args[0].to_lower()

	match command:
		"help", "?":
			_print_help()

		"status":
			_cmd_status()

		"addgold", "gold":
			if not _require_integer(args, 1, "Usage: addgold <amount>"):
				return
			var gold_delta: int = int(args[1])
			PlayerProgression.gold = maxi(PlayerProgression.gold + gold_delta, 0)
			PlayerProgression.stats_changed.emit()
			_write_line("Gold is now %d." % PlayerProgression.gold)

		"setgold":
			if not _require_integer(args, 1, "Usage: setgold <amount>"):
				return
			PlayerProgression.gold = maxi(int(args[1]), 0)
			PlayerProgression.stats_changed.emit()
			_write_line("Gold set to %d." % PlayerProgression.gold)

		"addexp", "exp":
			if not _require_integer(args, 1, "Usage: addexp <amount>"):
				return
			var exp_amount: int = int(args[1])
			if exp_amount < 0:
				_write_line("EXP amount must be zero or greater.")
				return
			var old_level: int = PlayerProgression.level
			PlayerProgression.add_exp(exp_amount)
			_write_line("Added %d EXP. Level: %d -> %d. EXP: %d / %d." % [
				exp_amount,
				old_level,
				PlayerProgression.level,
				PlayerProgression.current_exp,
				PlayerProgression.get_max_exp(PlayerProgression.level)
			])

		"sethp":
			if not _require_integer(args, 1, "Usage: sethp <amount>"):
				return
			PlayerProgression.ensure_hp_initialized()
			var hp_max: int = PlayerProgression.get_total_max_hp()
			PlayerProgression.current_hp = clampi(int(args[1]), 0, hp_max)
			PlayerProgression.hp_changed.emit()
			_write_line("HP set to %d / %d." % [PlayerProgression.current_hp, hp_max])

		"fullheal", "heal":
			PlayerProgression.current_hp = PlayerProgression.get_total_max_hp()
			PlayerProgression.hp_changed.emit()
			_write_line("HP restored to %d / %d." % [
				PlayerProgression.current_hp,
				PlayerProgression.get_total_max_hp()
			])

		"setlevel":
			if not _require_integer(args, 1, "Usage: setlevel <level>"):
				return
			PlayerProgression.level = clampi(int(args[1]), 1, 999)
			PlayerProgression.current_exp = clampi(
				PlayerProgression.current_exp,
				0,
				PlayerProgression.get_max_exp(PlayerProgression.level) - 1
			)
			PlayerProgression.current_hp = PlayerProgression.get_total_max_hp()
			PlayerProgression.hp_changed.emit()
			PlayerProgression.leveled_up.emit()
			PlayerProgression.stats_changed.emit()
			_write_line("Level set to %d. HP fully restored." % PlayerProgression.level)

		"startquest":
			if not _require_text(args, 1, "Usage: startquest <quest_id>"):
				return
			var start_id: String = args[1]
			if QuestManager.get_quest(start_id) == null:
				_write_line("Unknown quest ID: " + start_id)
				return
			QuestManager.start_quest(start_id)
			if QuestManager.is_quest_active(start_id):
				_write_line("Quest is active: " + start_id)
			elif QuestManager.is_quest_completed(start_id):
				_write_line("Quest is already completed: " + start_id)
			else:
				_write_line("Quest did not start. Check Output for QuestManager messages.")

		"completequest":
			if not _require_text(args, 1, "Usage: completequest <quest_id>"):
				return
			_cmd_complete_quest(args[1])

		"redo", "redoquest", "rewindquest":
			if not _require_text(args, 1, "Usage: redo <quest_id> [clearflags]"):
				return
			var clear_flags: bool = false
			if args.size() >= 3:
				if args[2].to_lower() == "clearflags":
					clear_flags = true
				else:
					_write_line("Optional second argument must be 'clearflags'.")
					return
			_cmd_redo_quest(args[1], clear_flags)

		"quests", "listquests":
			_cmd_list_quests(false)

		"activequests":
			_cmd_list_quests(true)

		"setflag":
			if not _require_text(args, 1, "Usage: setflag <flag_id> [true|false]"):
				return
			var flag_value: bool = true
			if args.size() >= 3:
				var bool_arg: String = args[2].to_lower()
				if bool_arg in ["false", "0", "off"]:
					flag_value = false
				elif bool_arg in ["true", "1", "on"]:
					flag_value = true
				else:
					_write_line("Flag value must be true or false.")
					return
			QuestManager.set_dialogue_flag(args[1], flag_value)
			_write_line("Flag '%s' = %s." % [args[1], str(flag_value).to_lower()])

		"clearflag":
			if not _require_text(args, 1, "Usage: clearflag <flag_id>"):
				return
			QuestManager.set_dialogue_flag(args[1], false)
			_write_line("Flag '%s' cleared." % args[1])

		"flags":
			_cmd_list_flags()

		_:
			_write_line("Unknown command '%s'. Type help." % command)


func _cmd_complete_quest(quest_id: String) -> void:
	if QuestManager.get_quest(quest_id) == null:
		_write_line("Unknown quest ID: " + quest_id)
		return

	if QuestManager.is_quest_completed(quest_id):
		_write_line("Quest is already completed: " + quest_id)
		return

	# Start first if needed, then invoke the same completion routine used by
	# normal quest progression so rewards and quest_completed signals still run.
	if not QuestManager.is_quest_active(quest_id):
		QuestManager.start_quest(quest_id)

	if not QuestManager.is_quest_active(quest_id):
		_write_line("Could not activate quest. Check Output for QuestManager messages.")
		return

	QuestManager.call("_complete_quest", quest_id)
	if QuestManager.is_quest_completed(quest_id):
		_write_line("Force-completed quest: " + quest_id)
		_write_line("Note: this skips objectives; it does not automatically set unrelated story flags.")
	else:
		_write_line("Quest completion failed. Check Output for errors.")


## Rewind quest completion from the requested quest onward using the order
## in QuestManager.completed_quests, which is appended in completion order.
## The selected quest is then started again so the UI receives normal signals.
func _cmd_redo_quest(quest_id: String, clear_flags: bool = false) -> void:
	var target_data: QuestData = QuestManager.get_quest(quest_id)
	if target_data == null:
		_write_line("Unknown quest ID: " + quest_id)
		return

	var rewound_completed: Array[String] = []
	var completed_index: int = QuestManager.completed_quests.find(quest_id)

	# Completed quests are stored in the order they were completed. Removing
	# this tail makes later completed quests available to test again.
	if completed_index >= 0:
		for index in range(completed_index, QuestManager.completed_quests.size()):
			rewound_completed.append(str(QuestManager.completed_quests[index]))
		QuestManager.completed_quests.resize(completed_index)

	var removed_active: Array[String] = []
	var active_ids: Array = QuestManager.active_quests.keys()

	# If rewinding a main quest, clear currently active main quests as well;
	# in a normal linear main-story run they are downstream of this point.
	# Keep unrelated active side quests intact.
	for raw_active_id in active_ids:
		var active_id: String = str(raw_active_id)
		var active_data: QuestData = QuestManager.get_quest(active_id)
		var should_remove: bool = active_id == quest_id
		if target_data.is_main_quest and active_data != null and active_data.is_main_quest:
			should_remove = true
		if should_remove:
			QuestManager.active_quests.erase(active_id)
			removed_active.append(active_id)

	# Story flags are not linked to QuestData in the current project, so a
	# precise downstream flag rewind cannot be inferred automatically. Provide
	# an explicit opt-in to clear every flag when a clean-slate test is needed.
	if clear_flags:
		var known_flags: Array = QuestManager.dialogue_flags.keys()
		for raw_flag_id in known_flags:
			QuestManager.set_dialogue_flag(str(raw_flag_id), false)

	# Starting the selected quest again emits QuestManager's normal signals,
	# refreshing the HUD, quest log, and NPC markers.
	QuestManager.start_quest(quest_id)

	_write_line("Rewind complete: %s" % quest_id)
	if rewound_completed.is_empty():
		_write_line("No completed quest history was rewound for this ID.")
	else:
		_write_line("Marked as not completed (completion order): " + ", ".join(PackedStringArray(rewound_completed)))
	if not removed_active.is_empty():
		_write_line("Cleared active quest state: " + ", ".join(PackedStringArray(removed_active)))
	if clear_flags:
		_write_line("Cleared all dialogue/story flags. Earlier cutscene prerequisites may need to be set again.")
	else:
		_write_line("Story flags were preserved. Clear stale flags manually with clearflag <flag_id> if required.")
	if QuestManager.is_quest_active(quest_id):
		_write_line("Quest is active and ready to test: " + quest_id)
	else:
		_write_line("Quest did not activate. Check Output for QuestManager messages.")


func _cmd_status() -> void:
	PlayerProgression.ensure_hp_initialized()
	_write_line("Level: %d | EXP: %d / %d" % [
		PlayerProgression.level,
		PlayerProgression.current_exp,
		PlayerProgression.get_max_exp(PlayerProgression.level)
	])
	_write_line("Gold: %d | HP: %d / %d" % [
		PlayerProgression.gold,
		PlayerProgression.current_hp,
		PlayerProgression.get_total_max_hp()
	])
	_write_line("Quests: %d active | %d completed" % [
		QuestManager.active_quests.size(),
		QuestManager.completed_quests.size()
	])


func _cmd_list_quests(active_only: bool) -> void:
	var quest_ids: Array = QuestManager.quest_database.keys()
	quest_ids.sort()

	if quest_ids.is_empty():
		_write_line("No quests are loaded.")
		return

	var shown: int = 0
	for raw_id in quest_ids:
		var quest_id: String = str(raw_id)
		var status: String = "NOT STARTED"
		if QuestManager.is_quest_active(quest_id):
			status = "ACTIVE"
		elif QuestManager.is_quest_completed(quest_id):
			status = "COMPLETED"

		if active_only and status != "ACTIVE":
			continue

		var data: QuestData = QuestManager.get_quest(quest_id)
		var title: String = data.title if data != null else quest_id
		_write_line("[%s] %s (%s)" % [status, title, quest_id])
		shown += 1

	if shown == 0:
		_write_line("No active quests.")


func _cmd_list_flags() -> void:
	var flag_ids: Array = QuestManager.dialogue_flags.keys()
	flag_ids.sort()

	if flag_ids.is_empty():
		_write_line("No dialogue/story flags have been set.")
		return

	for raw_id in flag_ids:
		var flag_id: String = str(raw_id)
		_write_line("%s = %s" % [flag_id, str(QuestManager.dialogue_flags[raw_id]).to_lower()])


func _require_integer(args: PackedStringArray, index: int, usage: String) -> bool:
	if args.size() <= index or not args[index].is_valid_int():
		_write_line(usage)
		return false
	return true


func _require_text(args: PackedStringArray, index: int, usage: String) -> bool:
	if args.size() <= index or args[index].strip_edges().is_empty():
		_write_line(usage)
		return false
	return true


func _print_help() -> void:
	_write_line("Available commands:")
	_write_line("  help                              Show this list")
	_write_line("  status                            Show level, EXP, gold, HP and quest counts")
	_write_line("  addgold <amount>                  Add gold (negative amount removes gold)")
	_write_line("  setgold <amount>                  Set exact gold amount")
	_write_line("  addexp <amount>                   Add EXP and process level-ups")
	_write_line("  sethp <amount>                    Set current HP, capped at maximum HP")
	_write_line("  fullheal                          Restore HP to maximum")
	_write_line("  setlevel <level>                  Set level and fully restore HP")
	_write_line("  quests                            List all quest IDs and their states")
	_write_line("  activequests                      List only active quests")
	_write_line("  startquest <quest_id>             Start a quest directly")
	_write_line("  completequest <quest_id>          Force-complete a quest and grant rewards")
	_write_line("  redo <quest_id>                   Rewind this and later completed quests, then restart it")
	_write_line("  redo <quest_id> clearflags        Same, but also clears ALL story/dialogue flags")
	_write_line("  setflag <flag_id> [true|false]    Set or unset a story/dialogue flag")
	_write_line("  clearflag <flag_id>               Set a flag to false")
	_write_line("  flags                             List all known story/dialogue flags")


func _write_line(message: String) -> void:
	if not is_instance_valid(_output):
		return

	_output.append_text(message + "\n")

	# Prevent unbounded output growth when a developer leaves the console open.
	while _output.get_line_count() > MAX_OUTPUT_LINES:
		_output.remove_paragraph(0)

	_output.scroll_to_line(maxi(_output.get_line_count() - 1, 0))
