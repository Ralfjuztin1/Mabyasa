extends CanvasLayer

## Spotlight-style tutorial overlay.
## Keeps the actual game UI visible through a cutout and dims everything else.

signal finished(tutorial_id: String)

const SHADE_COLOR := Color(0.015, 0.018, 0.024, 0.84)
const GOLD := Color(0.96, 0.76, 0.34, 1.0)
const CREAM := Color(0.97, 0.94, 0.84, 1.0)
const MUTED := Color(0.72, 0.72, 0.67, 1.0)
const HIGHLIGHT_PADDING := 9.0
const SCREEN_MARGIN := 18.0

var tutorial_id: String = ""
## Dialogic glossary entry key currently being hovered (hoverable tutorial only).
var hoverable_meta_key: String = ""
var tutorial_title: String = "FIELD GUIDE"
var page_data: Array = []

var _page_index: int = 0
var _root: Control
var _shade_top: ColorRect
var _shade_bottom: ColorRect
var _shade_left: ColorRect
var _shade_right: ColorRect
var _spotlight_border: Panel
var _card: PanelContainer
var _title_label: Label
var _description_label: Label
var _page_counter: Label
var _back_button: Button
var _next_button: Button

var _target_node: Node = null
var _target_rect: Rect2 = Rect2()
var _highlight_rect: Rect2 = Rect2()
var _was_tree_paused: bool = false
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _finished_emitted: bool = false
var _missing_target_warned: bool = false
var _hover_popup_pointer: Control = null
var _hover_popup_layer: Node = null
var _hover_popup_layer_was_processing: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_mouse_mode = Input.mouse_mode

	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func begin_tutorial() -> void:
	if page_data.is_empty():
		push_warning("[UI TUTORIAL] No spotlight pages configured for: " + tutorial_id)
		_finish_tutorial()
		return

	_was_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_overlay()
	_lock_hoverable_popup()
	_show_current_page()

	# Wait one frame for containers and CanvasLayers to finish their layout.
	await get_tree().process_frame
	_refresh_spotlight(true)


func _build_overlay() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var card_width: float = minf(520.0, maxf(viewport_size.x - 36.0, 280.0))

	_root = Control.new()
	_root.name = "SpotlightTutorialRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# During the glossary-hover tutorial, do not steal mouse hover from the
	# Dialogic word underneath the cursor. Otherwise the glossary popup hides
	# as soon as this overlay appears, leaving a meaningless fallback box.
	_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if tutorial_id == "hoverable"
		else Control.MOUSE_FILTER_STOP
	)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	# Four panels create a transparent hole around the selected control.
	_shade_top = _make_shade("ShadeTop")
	_shade_bottom = _make_shade("ShadeBottom")
	_shade_left = _make_shade("ShadeLeft")
	_shade_right = _make_shade("ShadeRight")
	_root.add_child(_shade_top)
	_root.add_child(_shade_bottom)
	_root.add_child(_shade_left)
	_root.add_child(_shade_right)

	_spotlight_border = Panel.new()
	_spotlight_border.name = "SpotlightBorder"
	_spotlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spotlight_border.process_mode = Node.PROCESS_MODE_ALWAYS
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_style.draw_center = false
	border_style.border_color = GOLD
	border_style.set_border_width_all(3)
	border_style.set_corner_radius_all(9)
	_spotlight_border.add_theme_stylebox_override("panel", border_style)
	_root.add_child(_spotlight_border)

	_card = PanelContainer.new()
	_card.name = "SpotlightInstructionCard"
	_card.custom_minimum_size = Vector2(card_width, 0.0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.process_mode = Node.PROCESS_MODE_ALWAYS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.055, 0.065, 0.06, 0.98)
	card_style.border_color = Color(0.58, 0.48, 0.28, 1.0)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(9)
	card_style.content_margin_left = 17.0
	card_style.content_margin_right = 17.0
	card_style.content_margin_top = 13.0
	card_style.content_margin_bottom = 12.0
	_card.add_theme_stylebox_override("panel", card_style)
	_root.add_child(_card)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 9)
	_card.add_child(contents)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	contents.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_font_size_override("font_size", 21)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title_label)

	_page_counter = Label.new()
	_page_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_counter.add_theme_color_override("font_color", MUTED)
	_page_counter.add_theme_font_size_override("font_size", 15)
	header.add_child(_page_counter)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_color_override("font_color", CREAM)
	_description_label.add_theme_font_size_override("font_size", 16)
	contents.add_child(_description_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	contents.add_child(footer)

	var skip_button := _make_button("Skip")
	skip_button.pressed.connect(_finish_tutorial)
	footer.add_child(skip_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_back_button = _make_button("Back")
	_back_button.pressed.connect(_go_back)
	footer.add_child(_back_button)

	_next_button = _make_button("Next")
	_next_button.pressed.connect(_go_next)
	footer.add_child(_next_button)


func _make_shade(node_name: String) -> ColorRect:
	var shade := ColorRect.new()
	shade.name = node_name
	shade.color = SHADE_COLOR
	shade.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if tutorial_id == "hoverable"
		else Control.MOUSE_FILTER_STOP
	)
	shade.process_mode = Node.PROCESS_MODE_ALWAYS
	return shade


func _make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(94.0, 37.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", GOLD)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.16, 0.145, 1.0)
	normal.border_color = Color(0.45, 0.41, 0.30, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.23, 0.17, 1.0)
	hover.border_color = GOLD
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.09, 0.105, 0.095, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.085, 0.08, 1.0)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _show_current_page() -> void:
	if page_data.is_empty():
		_finish_tutorial()
		return

	_page_index = clampi(_page_index, 0, page_data.size() - 1)
	var raw_page: Variant = page_data[_page_index]
	if not raw_page is Dictionary:
		push_warning("[UI TUTORIAL] Invalid spotlight page in: " + tutorial_id)
		return

	var page: Dictionary = raw_page
	_title_label.text = str(page.get("title", tutorial_title))
	_description_label.text = str(page.get("description", ""))
	_page_counter.text = "%02d / %02d" % [_page_index + 1, page_data.size()]
	_back_button.disabled = _page_index == 0
	_next_button.text = "Finish" if _page_index == page_data.size() - 1 else "Next  →"

	_target_node = null
	_target_rect = Rect2()
	_missing_target_warned = false
	_refresh_spotlight(true)


func _process(_delta: float) -> void:
	if _finished_emitted or not is_instance_valid(_root):
		return

	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Keep the glossary popup visible and stationary while the user moves the
	# cursor to the tutorial controls. Normally Dialogic hides the popup as soon
	# as the cursor leaves the word, which would make the spotlight disappear.
	_keep_hoverable_popup_visible()

	# Re-resolve if the target was added after the tutorial opened, hidden,
	# or removed due to a scene/UI change.
	if not _target_is_usable(_target_node):
		_target_node = _find_target_for_current_page()
		if tutorial_id == "hoverable" and _target_is_usable(_target_node):
			_lock_hoverable_popup()

	_refresh_spotlight(false)


func _refresh_spotlight(force: bool) -> void:
	if not is_instance_valid(_root):
		return

	if force or not _target_is_usable(_target_node):
		_target_node = _find_target_for_current_page()

	if (
		tutorial_id == "hoverable"
		and _target_is_usable(_target_node)
		and not is_instance_valid(_hover_popup_pointer)
	):
		_lock_hoverable_popup()

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var new_rect := (
		_get_hovered_glossary_word_screen_rect()
		if tutorial_id == "hoverable"
		else _get_target_screen_rect(_target_node)
	)

	if new_rect.size.x <= 0.0 or new_rect.size.y <= 0.0:
		# The hoverable tutorial must never draw a pretend highlight in the middle
		# of the screen. Keep the instructions visible over a dimmed scene and
		# keep searching until the actual linked word can be measured.
		if not _missing_target_warned:
			var page_title := tutorial_id
			if page_data.size() > _page_index and page_data[_page_index] is Dictionary:
				page_title = str(page_data[_page_index].get("title", tutorial_id))
			push_warning("[UI TUTORIAL] Spotlight target not found or not visible for '" + page_title + "'. The hoverable tutorial will wait for the linked word in Dialogic text.")
			_missing_target_warned = true

		if tutorial_id == "hoverable":
			_set_control_rect(_shade_top, Rect2(Vector2.ZERO, viewport_size))
			_set_control_rect(_shade_bottom, Rect2(Vector2.ZERO, Vector2.ZERO))
			_set_control_rect(_shade_left, Rect2(Vector2.ZERO, Vector2.ZERO))
			_set_control_rect(_shade_right, Rect2(Vector2.ZERO, Vector2.ZERO))
			_spotlight_border.hide()
			_position_card_centered(viewport_size)
			return

		var fallback_size := Vector2(minf(240.0, viewport_size.x * 0.45), 74.0)
		new_rect = Rect2(
			Vector2((viewport_size.x - fallback_size.x) * 0.5, viewport_size.y * 0.36),
			fallback_size
		)
		_target_node = null

	else:
		_spotlight_border.show()
		if force:
			print("[UI TUTORIAL] Spotlight target resolved: ", _target_node.get_path())

	_target_rect = new_rect
	_highlight_rect = _target_rect.grow(HIGHLIGHT_PADDING)
	_highlight_rect.size.x = minf(_highlight_rect.size.x, viewport_size.x - 2.0)
	_highlight_rect.size.y = minf(_highlight_rect.size.y, viewport_size.y - 2.0)
	_highlight_rect.position.x = clampf(_highlight_rect.position.x, 1.0, maxf(1.0, viewport_size.x - _highlight_rect.size.x - 1.0))
	_highlight_rect.position.y = clampf(_highlight_rect.position.y, 1.0, maxf(1.0, viewport_size.y - _highlight_rect.size.y - 1.0))

	# Areas outside the cutout are shaded. The target itself is left untouched.
	_set_control_rect(_shade_top, Rect2(Vector2.ZERO, Vector2(viewport_size.x, _highlight_rect.position.y)))
	_set_control_rect(_shade_bottom, Rect2(Vector2(0.0, _highlight_rect.end.y), Vector2(viewport_size.x, maxf(0.0, viewport_size.y - _highlight_rect.end.y))))
	_set_control_rect(_shade_left, Rect2(Vector2(0.0, _highlight_rect.position.y), Vector2(_highlight_rect.position.x, _highlight_rect.size.y)))
	_set_control_rect(_shade_right, Rect2(Vector2(_highlight_rect.end.x, _highlight_rect.position.y), Vector2(maxf(0.0, viewport_size.x - _highlight_rect.end.x), _highlight_rect.size.y)))
	_set_control_rect(_spotlight_border, _highlight_rect)
	_position_card(viewport_size)


func _set_control_rect(control: Control, rect: Rect2) -> void:
	if not is_instance_valid(control):
		return
	control.position = rect.position
	control.size = rect.size


func _position_card_centered(viewport_size: Vector2) -> void:
	if not is_instance_valid(_card):
		return
	var card_width := minf(520.0, maxf(viewport_size.x - 36.0, 280.0))
	_card.custom_minimum_size.x = card_width
	var minimum := _card.get_combined_minimum_size()
	var card_height := maxf(minimum.y, 128.0)
	_card.size = Vector2(card_width, card_height)
	_card.position = Vector2(
		(viewport_size.x - card_width) * 0.5,
		(viewport_size.y - card_height) * 0.5
	)


func _position_card(viewport_size: Vector2) -> void:
	if not is_instance_valid(_card):
		return

	var card_width := minf(520.0, maxf(viewport_size.x - 36.0, 280.0))
	_card.custom_minimum_size.x = card_width
	var minimum := _card.get_combined_minimum_size()
	var card_height := maxf(minimum.y, 128.0)
	_card.size = Vector2(card_width, card_height)

	# Keep the hover tutorial instructions at the top. Positioning the card
	# directly below the glossary popup can cover the word under the cursor,
	# dismissing the popup that this tutorial is supposed to highlight.
	if tutorial_id == "hoverable":
		_card.position = Vector2(
			(viewport_size.x - card_width) * 0.5,
			SCREEN_MARGIN
		)
		return

	var x := _highlight_rect.get_center().x - card_width * 0.5
	x = clampf(x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - card_width - SCREEN_MARGIN))

	var below_y := _highlight_rect.end.y + 16.0
	var above_y := _highlight_rect.position.y - card_height - 16.0
	var y := below_y
	if below_y + card_height > viewport_size.y - SCREEN_MARGIN:
		if above_y >= SCREEN_MARGIN:
			y = above_y
		else:
			y = viewport_size.y - card_height - SCREEN_MARGIN
	y = clampf(y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.y - card_height - SCREEN_MARGIN))

	_card.position = Vector2(x, y)


func _lock_hoverable_popup() -> void:
	if tutorial_id != "hoverable":
		return

	var panel := _find_glossary_popup_panel(get_tree().root)
	if not _target_is_usable(panel):
		return

	var pointer := panel.get_parent() as Control
	if not is_instance_valid(pointer):
		return

	_hover_popup_pointer = pointer
	_hover_popup_layer = pointer.get_parent()
	if is_instance_valid(_hover_popup_layer):
		_hover_popup_layer_was_processing = _hover_popup_layer.is_processing()
		_hover_popup_layer.set_process(false)

	_hover_popup_pointer.show()


func _keep_hoverable_popup_visible() -> void:
	if tutorial_id != "hoverable":
		return
	if is_instance_valid(_hover_popup_pointer):
		_hover_popup_pointer.show()


func _restore_hoverable_popup() -> void:
	if is_instance_valid(_hover_popup_pointer):
		# The cursor is now on the tutorial card, so the glossary popup should
		# close normally after the tutorial exits.
		_hover_popup_pointer.hide()

	if is_instance_valid(_hover_popup_layer):
		_hover_popup_layer.set_process(_hover_popup_layer_was_processing)

	_hover_popup_pointer = null
	_hover_popup_layer = null
	_hover_popup_layer_was_processing = false


func _find_target_for_current_page() -> Node:
	if page_data.is_empty() or _page_index >= page_data.size():
		return null

	# For hoverable tutorials, target the RichTextLabel containing the active
	# glossary link. Its word-specific rectangle is calculated separately.
	if tutorial_id == "hoverable":
		var word_label := _find_hoverable_text_node()
		if _target_is_usable(word_label):
			return word_label

	var page: Dictionary = page_data[_page_index]
	var raw_names: Variant = page.get("target_names", [])
	var names: Array = []

	if raw_names is String:
		names.append(raw_names)
	elif raw_names is Array or raw_names is PackedStringArray:
		for raw_name: Variant in raw_names:
			names.append(raw_name)

	for raw_name: Variant in names:
		var wanted_name := str(raw_name).strip_edges()
		if wanted_name.is_empty():
			continue
		var found := _find_named_node(get_tree().root, wanted_name)
		if is_instance_valid(found):
			return found

	return null


func _find_glossary_popup_panel(node: Node) -> Node:
	if not is_instance_valid(node) or node == self:
		return null

	if node is Control and str(node.name) == "Panel":
		var pointer := node.get_parent()
		if is_instance_valid(pointer) and str(pointer.name) == "Pointer":
			var title_node := node.find_child("Title", true, false)
			var text_node := node.find_child("Text", true, false)
			var extra_node := node.find_child("Extra", true, false)
			if (
				is_instance_valid(title_node)
				and is_instance_valid(text_node)
				and is_instance_valid(extra_node)
				and _target_is_usable(node)
			):
				return node

	# Keep searching even below hidden branches; only the candidate popup
	# itself must be visible. This allows the layer to become visible between
	# frames while the tutorial is waiting for it.
	for child: Node in node.get_children():
		var found := _find_glossary_popup_panel(child)
		if is_instance_valid(found):
			return found

	return null


func _find_named_node(node: Node, wanted_name: String) -> Node:
	if node == self:
		return null

	if not _node_is_visible(node):
		return null

	# A slash-delimited target is resolved as a node path relative to the
	# matching root node. This is needed for Dialogic's glossary popup panel,
	# whose generic child name "Panel" is used elsewhere in the project too.
	if wanted_name.contains("/"):
		var slash_index: int = wanted_name.find("/")
		var root_name: String = wanted_name.substr(0, slash_index)
		if str(node.name) == root_name:
			var relative_path: String = wanted_name.substr(slash_index + 1)
			var path_target: Node = node.get_node_or_null(NodePath(relative_path))
			if _target_is_usable(path_target):
				return path_target

	if str(node.name) == wanted_name:
		if node is Control:
			var control := node as Control
			if control.size.x > 1.0 and control.size.y > 1.0:
				return node
		elif node is Node3D or node is Node2D:
			return node

	for child: Node in node.get_children():
		var found := _find_named_node(child, wanted_name)
		if is_instance_valid(found):
			return found

	return null


func _node_is_visible(node: Node) -> bool:
	if node is CanvasItem:
		return (node as CanvasItem).is_visible_in_tree()
	if node is VisualInstance3D:
		return (node as VisualInstance3D).visible
	return true


func _target_is_usable(node: Node) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false
	if not _node_is_visible(node):
		return false
	if node is Control:
		var control := node as Control
		return control.size.x > 1.0 and control.size.y > 1.0
	return node is Node3D or node is Node2D


func _find_hoverable_text_node() -> RichTextLabel:
	if hoverable_meta_key.is_empty():
		return null

	var preferred_open_tag := '[url="' + hoverable_meta_key + '"]'
	var fallback_label: RichTextLabel = null
	for candidate: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		if not candidate is RichTextLabel:
			continue
		var label := candidate as RichTextLabel
		if not label.is_visible_in_tree():
			continue
		if label.text.contains(preferred_open_tag) or label.text.contains("[url=" + hoverable_meta_key + "]"):
			return label
		# Some Dialogic layouts normalize URL tags differently. If the exact
		# key does not match raw BBCode, keep the active text label as a safe
		# fallback instead of losing the hoverable tutorial altogether.
		if fallback_label == null and label.text.contains("[url="):
			fallback_label = label

	return fallback_label


func _extract_glossary_link_text(raw_bbcode: String) -> String:
	if hoverable_meta_key.is_empty():
		return ""

	var open_tags: Array[String] = [
		'[url="' + hoverable_meta_key + '"]',
		"[url=" + hoverable_meta_key + "]",
		"[url='" + hoverable_meta_key + "']"
	]

	for open_tag: String in open_tags:
		var tag_start := raw_bbcode.find(open_tag)
		if tag_start < 0:
			continue

		var content_start := tag_start + open_tag.length()
		var content_end := raw_bbcode.find("[/url]", content_start)
		if content_end < 0:
			continue

		var inner_bbcode := raw_bbcode.substr(content_start, content_end - content_start)
		var tag_regex := RegEx.new()
		if tag_regex.compile("\\[[^\\]]*\\]") != OK:
			return ""
		return tag_regex.sub(inner_bbcode, "", true).strip_edges()

	return ""


func _get_hovered_glossary_word_screen_rect() -> Rect2:
	# The actual target is the matched glossary word inside Dialogic's text,
	# not the popup panel and not an arbitrary rectangle in the 3D scene.
	var label := _find_hoverable_text_node()
	if not is_instance_valid(label):
		return Rect2()

	var linked_text := _extract_glossary_link_text(label.text)
	if linked_text.is_empty():
		# Still point to the actual dialogue text, never to an arbitrary spot
		# on the screen, if this Dialogic layout formats its URL tag differently.
		return _get_target_screen_rect(label)

	var parsed_text := label.get_parsed_text()
	var search_from := 0
	var best_rect := Rect2()
	var best_distance := INF
	var mouse_position := get_viewport().get_mouse_position()

	while search_from < parsed_text.length():
		var occurrence := parsed_text.find(linked_text, search_from)
		if occurrence < 0:
			break

		var candidate_rect := _measure_text_range_screen_rect(label, occurrence, linked_text)
		if candidate_rect.size.x > 0.0 and candidate_rect.size.y > 0.0:
			var distance := candidate_rect.grow(6.0).get_center().distance_squared_to(mouse_position)
			if candidate_rect.grow(6.0).has_point(mouse_position):
				distance = 0.0
			if distance < best_distance:
				best_distance = distance
				best_rect = candidate_rect

		search_from = occurrence + maxi(linked_text.length(), 1)

	if best_rect.size.x <= 0.0 or best_rect.size.y <= 0.0:
		return _get_target_screen_rect(label)

	return best_rect


func _measure_text_range_screen_rect(
	label: RichTextLabel,
	start_index: int,
	text_range: String
) -> Rect2:
	var parsed_text := label.get_parsed_text()
	if text_range.is_empty() or start_index < 0 or start_index + text_range.length() > parsed_text.length():
		return Rect2()

	var end_index := start_index + text_range.length() - 1
	var first_line := label.get_character_line(start_index)
	var last_line := label.get_character_line(end_index)
	if first_line < 0 or last_line < 0:
		return Rect2()

	# Dialogic glossary entries are normally kept on one line. If an unusually
	# long entry wraps, outline the relevant text-label region rather than
	# drawing a misleading highlight elsewhere on the screen.
	if first_line != last_line:
		return _get_target_screen_rect(label)

	var line_start := start_index
	while line_start > 0 and label.get_character_line(line_start - 1) == first_line:
		line_start -= 1

	var prefix := parsed_text.substr(line_start, start_index - line_start)
	var font: Font = label.get_theme_font("normal_font", "RichTextLabel")
	if font == null:
		return _get_target_screen_rect(label)

	var font_size := label.get_theme_font_size("normal_font_size", "RichTextLabel")
	if font_size <= 0:
		font_size = 16

	var prefix_width := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var word_width := font.get_string_size(text_range, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if word_width <= 0.0:
		return Rect2()

	var left_margin := 0.0
	var top_margin := 0.0
	var text_style := label.get_theme_stylebox("normal", "RichTextLabel")
	if text_style != null:
		left_margin = text_style.get_content_margin(SIDE_LEFT)
		top_margin = text_style.get_content_margin(SIDE_TOP)

	var line_width := float(label.get_line_width(first_line))
	var content_width := maxf(label.size.x - left_margin - (text_style.get_content_margin(SIDE_RIGHT) if text_style != null else 0.0), 0.0)
	var alignment_offset := 0.0
	# The custom Dialogic text node uses these alignment values: 0 left, 1
	# center, 2 right. Account for non-left text so the frame stays on the word.
	if "alignment" in label:
		match int(label.get("alignment")):
			1:
				alignment_offset = maxf((content_width - line_width) * 0.5, 0.0)
			2:
				alignment_offset = maxf(content_width - line_width, 0.0)

	var line_y := top_margin + label.get_line_offset(first_line)
	var line_height := maxf(float(label.get_line_height(first_line)), float(font_size))
	var local_rect := Rect2(
		Vector2(left_margin + alignment_offset + prefix_width, line_y),
		Vector2(word_width, line_height)
	)

	return label.get_global_transform_with_canvas() * local_rect


func _get_target_screen_rect(node: Node) -> Rect2:
	if not _target_is_usable(node):
		return Rect2()

	if node is Control:
		var control := node as Control
		var canvas_item := control as CanvasItem
		return canvas_item.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

	if node is Node3D:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return Rect2()
		var world_position := (node as Node3D).global_position
		if camera.is_position_behind(world_position):
			return Rect2()
		var screen_position := camera.unproject_position(world_position)
		var projected_size := Vector2(244.0, 56.0)
		return Rect2(screen_position - projected_size * 0.5, projected_size)

	if node is Node2D:
		var canvas_item := node as CanvasItem
		var local_rect := Rect2(Vector2.ZERO, Vector2(160.0, 52.0))
		return canvas_item.get_global_transform_with_canvas() * local_rect

	return Rect2()


func _go_back() -> void:
	if _page_index <= 0:
		return
	_page_index -= 1
	_show_current_page()


func _go_next() -> void:
	if _page_index >= page_data.size() - 1:
		_finish_tutorial()
		return
	_page_index += 1
	_show_current_page()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_finish_tutorial()
		get_viewport().set_input_as_handled()


func _finish_tutorial() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	_restore_hoverable_popup()
	Input.mouse_mode = _previous_mouse_mode
	finished.emit(tutorial_id)
	queue_free()


func _on_viewport_size_changed() -> void:
	if is_instance_valid(_root):
		_refresh_spotlight(true)
