extends CanvasLayer

signal food_selected(item_id: String)

## Supported modes: inventory, market, battle.
var mode: String = "inventory"

const PANEL_TEXTURE_PATH: String = "res://Assets/UI/PauseMenu/panel_base_9slice.png"
const BUTTON_NORMAL_PATH: String = "res://Assets/UI/PauseMenu/button_normal.png"
const BUTTON_SELECTED_PATH: String = "res://Assets/UI/PauseMenu/button_selected.png"
const PIXEL_FONT_PATH: String = "res://Assets/UI/Sprout Lands - UI Pack - Basic pack/fonts/pixelFont-7-8x14-sproutLands.ttf"

const COLOR_GOLD: Color = Color(0.94, 0.70, 0.25, 1.0)
const COLOR_TEXT: Color = Color(0.94, 0.92, 0.83, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.71, 0.63, 1.0)
const COLOR_PANEL: Color = Color(0.035, 0.055, 0.041, 0.96)
const COLOR_DETAIL: Color = Color(0.05, 0.07, 0.052, 0.98)
const COLOR_BORDER: Color = Color(0.72, 0.62, 0.36, 0.40)

var _theme: Theme
var _food_list: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _owned_label: Label
var _description_label: Label
var _effect_label: Label
var _price_label: Label
var _gold_label: Label
var _status_label: Label
var _primary_button: Button
var _selected_item_id: String = ""
var _visible_item_ids: Array[String] = []
var _refreshing: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_theme()
	_build_interface()

	if InventoryManager != null and not InventoryManager.inventory_changed.is_connected(_refresh):
		InventoryManager.inventory_changed.connect(_refresh)
	if PlayerProgression != null and PlayerProgression.has_signal("stats_changed"):
		if not PlayerProgression.stats_changed.is_connected(_refresh):
			PlayerProgression.stats_changed.connect(_refresh)

	_refresh()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _exit_tree() -> void:
	if InventoryManager != null and InventoryManager.inventory_changed.is_connected(_refresh):
		InventoryManager.inventory_changed.disconnect(_refresh)
	if PlayerProgression != null and PlayerProgression.has_signal("stats_changed"):
		if PlayerProgression.stats_changed.is_connected(_refresh):
			PlayerProgression.stats_changed.disconnect(_refresh)


func _build_theme() -> void:
	_theme = Theme.new()
	var font: Font = load(PIXEL_FONT_PATH) as Font
	if font != null:
		_theme.default_font = font
	_theme.default_font_size = 14


func _build_interface() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = _theme
	add_child(root)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.005, 0.012, 0.008, 0.84)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dimmer)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(1000, 620)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(frame)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 18)
	frame.add_child(margin)

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 50)
	header.add_theme_constant_override("separation", 14)
	main.add_child(header)

	var title_stack: VBoxContainer = VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)

	var title_label: Label = Label.new()
	title_label.name = "MenuTitle"
	title_label.text = _get_title()
	title_label.add_theme_color_override("font_color", COLOR_GOLD)
	title_label.add_theme_font_size_override("font_size", 30)
	title_stack.add_child(title_label)

	var subtitle: Label = Label.new()
	subtitle.text = _get_subtitle()
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	subtitle.add_theme_font_size_override("font_size", 13)
	title_stack.add_child(subtitle)

	var gold_row: HBoxContainer = HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 7)
	header.add_child(gold_row)

	var coin: TextureRect = TextureRect.new()
	coin.custom_minimum_size = Vector2(24, 24)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin_atlas: Texture2D = load("res://Assets/UI/PauseMenu/pause_icons_atlas.png") as Texture2D
	if coin_atlas != null:
		var coin_texture: AtlasTexture = AtlasTexture.new()
		coin_texture.atlas = coin_atlas
		coin_texture.region = Rect2(128, 128, 128, 128)
		coin.texture = coin_texture
	gold_row.add_child(coin)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", COLOR_TEXT)
	_gold_label.add_theme_font_size_override("font_size", 18)
	gold_row.add_child(_gold_label)

	var close_button: Button = _make_button("CLOSE  ✕", Vector2(112, 40))
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	main.add_child(_make_gold_separator())

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	var list_panel: PanelContainer = PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(410, 0)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_PANEL))
	body.add_child(list_panel)

	var list_margin: MarginContainer = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_panel.add_child(list_margin)

	var list_box: VBoxContainer = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_box)

	var list_heading: Label = Label.new()
	list_heading.text = "AVAILABLE FOOD"
	list_heading.add_theme_color_override("font_color", COLOR_GOLD)
	list_heading.add_theme_font_size_override("font_size", 16)
	list_box.add_child(list_heading)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(scroll)

	_food_list = VBoxContainer.new()
	_food_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_food_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_food_list)

	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_inner_panel_style(COLOR_DETAIL))
	body.add_child(detail_panel)

	var detail_margin: MarginContainer = MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 22)
	detail_margin.add_theme_constant_override("margin_top", 18)
	detail_margin.add_theme_constant_override("margin_right", 22)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	detail_panel.add_child(detail_margin)

	var detail_box: VBoxContainer = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 9)
	detail_margin.add_child(detail_box)

	var detail_header: Label = Label.new()
	detail_header.text = "FOOD DETAILS"
	detail_header.add_theme_color_override("font_color", COLOR_GOLD)
	detail_header.add_theme_font_size_override("font_size", 16)
	detail_box.add_child(detail_header)

	var detail_top: HBoxContainer = HBoxContainer.new()
	detail_top.add_theme_constant_override("separation", 16)
	detail_box.add_child(detail_top)

	var icon_frame: PanelContainer = PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(144, 144)
	icon_frame.add_theme_stylebox_override("panel", _make_inner_panel_style(Color(0.025, 0.04, 0.03, 1.0)))
	detail_top.add_child(icon_frame)

	var icon_margin: MarginContainer = MarginContainer.new()
	icon_margin.add_theme_constant_override("margin_left", 5)
	icon_margin.add_theme_constant_override("margin_top", 5)
	icon_margin.add_theme_constant_override("margin_right", 5)
	icon_margin.add_theme_constant_override("margin_bottom", 5)
	icon_frame.add_child(icon_margin)

	_detail_icon = TextureRect.new()
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.custom_minimum_size = Vector2(132, 132)
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(_detail_icon)

	var detail_identity: VBoxContainer = VBoxContainer.new()
	detail_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_identity.add_theme_constant_override("separation", 6)
	detail_top.add_child(detail_identity)

	_detail_name = Label.new()
	_detail_name.add_theme_color_override("font_color", COLOR_TEXT)
	_detail_name.add_theme_font_size_override("font_size", 23)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_identity.add_child(_detail_name)

	_owned_label = Label.new()
	_owned_label.add_theme_color_override("font_color", COLOR_GOLD)
	_owned_label.add_theme_font_size_override("font_size", 13)
	detail_identity.add_child(_owned_label)

	_description_label = Label.new()
	_description_label.add_theme_color_override("font_color", COLOR_MUTED)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_description_label)

	detail_box.add_child(_make_gold_separator())

	var effect_header: Label = Label.new()
	effect_header.text = "EFFECT"
	effect_header.add_theme_color_override("font_color", COLOR_GOLD)
	effect_header.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(effect_header)

	_effect_label = Label.new()
	_effect_label.add_theme_color_override("font_color", COLOR_TEXT)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_effect_label)

	_price_label = Label.new()
	_price_label.add_theme_color_override("font_color", COLOR_GOLD)
	_price_label.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(_price_label)

	main.add_child(_make_gold_separator())

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main.add_child(footer)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	footer.add_child(_status_label)

	_primary_button = _make_button(_get_primary_label(), Vector2(150, 42))
	_primary_button.pressed.connect(_on_primary_pressed)
	footer.add_child(_primary_button)


func _make_frame_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	var texture: Texture2D = load(PANEL_TEXTURE_PATH) as Texture2D
	style.texture = texture
	style.texture_margin_left = 26.0
	style.texture_margin_top = 24.0
	style.texture_margin_right = 26.0
	style.texture_margin_bottom = 24.0
	style.content_margin_left = 20.0
	style.content_margin_top = 18.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 16.0
	return style


func _make_button_style(selected: bool = false) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	var path: String = BUTTON_SELECTED_PATH if selected else BUTTON_NORMAL_PATH
	style.texture = load(path) as Texture2D
	style.texture_margin_left = 30.0
	style.texture_margin_top = 16.0
	style.texture_margin_right = 34.0
	style.texture_margin_bottom = 16.0
	style.content_margin_left = 14.0
	style.content_margin_top = 6.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 6.0
	return style


func _make_button(text_value: String, minimum_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style(false))
	button.add_theme_stylebox_override("hover", _make_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_button_style(true))
	button.add_theme_stylebox_override("focus", _make_button_style(true))
	return button


func _make_gold_separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color(0.72, 0.62, 0.36, 0.32)
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


func _make_inner_panel_style(background_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


func _get_title() -> String:
	match mode:
		"market":
			return "PALENGKE"
		"battle":
			return "CHOOSE FOOD"
		_:
			return "FOOD INVENTORY"


func _get_subtitle() -> String:
	match mode:
		"market":
			return "Local dishes for your next journey"
		"battle":
			return "Eating uses your action; the enemy still takes its turn"
		_:
			return "Your food bag and healing items"


func _get_primary_label() -> String:
	match mode:
		"market":
			return "BUY FOOD"
		"battle":
			return "EAT FOOD"
		_:
			return "USE FOOD"


func _refresh() -> void:
	if _refreshing or not is_instance_valid(_food_list):
		return
	_refreshing = true
	_gold_label.text = "%s G" % _format_number(PlayerProgression.gold if PlayerProgression != null else 0)

	for child: Node in _food_list.get_children():
		_food_list.remove_child(child)
		child.queue_free()

	_visible_item_ids.clear()
	var database: Dictionary = InventoryManager.get_food_database()
	for key: Variant in database.keys():
		var item_id: String = str(key)
		var food: Dictionary = database[item_id]
		var quantity: int = InventoryManager.get_quantity(item_id)
		if mode != "market" and quantity <= 0:
			continue
		_visible_item_ids.append(item_id)
		_add_food_row(item_id, food, quantity)

	if _visible_item_ids.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No food in your bag yet. Visit the Palengke to buy some."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size = Vector2(0, 80)
		empty_label.add_theme_color_override("font_color", COLOR_MUTED)
		_food_list.add_child(empty_label)

	if not _visible_item_ids.has(_selected_item_id):
		_selected_item_id = _visible_item_ids[0] if not _visible_item_ids.is_empty() else ""
	_refresh_detail()
	_refreshing = false


func _add_food_row(item_id: String, food: Dictionary, quantity: int) -> void:
	var food_name: String = str(food.get("name", item_id))
	var second_line: String
	if mode == "market":
		second_line = "%d Gold  ·  Owned: %d" % [int(food.get("price", 0)), quantity]
	else:
		second_line = _short_effect(food)

	var row: Button = _make_button("%s   ×%d\n%s" % [food_name, quantity, second_line], Vector2(0, 78))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	row.expand_icon = true
	row.add_theme_constant_override("icon_max_width", 56)
	row.clip_text = true
	row.add_theme_font_size_override("font_size", 14)
	row.add_theme_stylebox_override("normal", _make_button_style(item_id == _selected_item_id))
	row.add_theme_stylebox_override("hover", _make_button_style(true))
	row.add_theme_stylebox_override("pressed", _make_button_style(true))
	row.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_theme_color_override("font_hover_color", Color.WHITE)
	row.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	var icon_texture: Texture2D = food.get("icon") as Texture2D
	if icon_texture != null:
		row.icon = icon_texture
	row.pressed.connect(_on_item_pressed.bind(item_id))
	_food_list.add_child(row)


func _refresh_detail() -> void:
	var food: Dictionary = InventoryManager.get_food(_selected_item_id) if not _selected_item_id.is_empty() else {}
	if food.is_empty():
		_detail_icon.texture = null
		_detail_name.text = "No food selected"
		_owned_label.text = ""
		_description_label.text = "Buy food at the Palengke to stock your bag."
		_effect_label.text = ""
		_price_label.text = ""
		_primary_button.disabled = true
		_status_label.text = _empty_status()
		return

	var icon_texture: Texture2D = food.get("icon") as Texture2D
	_detail_icon.texture = icon_texture
	_detail_name.text = str(food.get("name", _selected_item_id))
	_owned_label.text = "OWNED: %d" % InventoryManager.get_quantity(_selected_item_id)
	_description_label.text = str(food.get("description", ""))
	_effect_label.text = _effect_description(food)
	_price_label.text = "Price: %d Gold" % int(food.get("price", 0))
	_primary_button.text = _get_primary_label()

	if mode == "market":
		_primary_button.disabled = not InventoryManager.can_buy_food(_selected_item_id)
		_primary_button.tooltip_text = "Buy one serving with Gold."
	else:
		var hp_full: bool = false
		if PlayerProgression != null:
			PlayerProgression.ensure_hp_initialized()
			hp_full = PlayerProgression.current_hp >= PlayerProgression.get_total_max_hp()
		_primary_button.disabled = (
			InventoryManager.get_quantity(_selected_item_id) <= 0
			or hp_full
		)
		_primary_button.tooltip_text = "Your HP is full." if hp_full else "Use one serving of this food."

	if _status_label.text.is_empty():
		_status_label.text = _empty_status()


func _on_item_pressed(item_id: String) -> void:
	_selected_item_id = item_id
	_status_label.text = _empty_status()
	_refresh()


func _on_primary_pressed() -> void:
	if _selected_item_id.is_empty():
		return
	var food: Dictionary = InventoryManager.get_food(_selected_item_id)
	if food.is_empty():
		return

	match mode:
		"market":
			if InventoryManager.buy_food(_selected_item_id):
				_status_label.text = "Bought %s." % str(food.get("name", _selected_item_id))
			else:
				_status_label.text = "Not enough Gold to buy this food."
			_refresh()
		"battle":
			if InventoryManager.get_quantity(_selected_item_id) <= 0:
				_status_label.text = "You do not have that food anymore."
				_refresh()
				return
			food_selected.emit(_selected_item_id)
			queue_free()
		_:
			if InventoryManager.use_food(_selected_item_id):
				_status_label.text = "Used %s. Healing was applied." % str(food.get("name", _selected_item_id))
			else:
				_status_label.text = "You cannot use this now, or your HP is already full."
			_refresh()


func _on_close_pressed() -> void:
	queue_free()


func _short_effect(food: Dictionary) -> String:
	var instant: int = int(food.get("heal_amount", 0))
	var per_turn: int = int(food.get("heal_per_turn", 0))
	var duration: int = int(food.get("duration", 0))
	if instant > 0 and per_turn > 0 and duration > 0:
		return "+%d HP + %d HP/turn" % [instant, per_turn]
	if instant > 0:
		return "+%d HP" % instant
	if per_turn > 0 and duration > 0:
		return "+%d HP/turn × %d turns" % [per_turn, duration]
	return "No healing effect"


func _effect_description(food: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var instant: int = int(food.get("heal_amount", 0))
	var per_turn: int = int(food.get("heal_per_turn", 0))
	var duration: int = int(food.get("duration", 0))
	if instant > 0:
		lines.append("Instantly restores up to %d HP." % instant)
	if per_turn > 0 and duration > 0:
		lines.append("In battle: restores %d HP after each enemy turn for %d turns." % [per_turn, duration])
		lines.append("Outside battle: restores %d HP immediately." % [per_turn * duration])
	return "\n".join(lines) if not lines.is_empty() else "No healing effect configured."


func _empty_status() -> String:
	match mode:
		"market":
			return "Select a dish, then buy it with Gold."
		"battle":
			return "Choose carefully. Eating uses your action."
		_:
			return "Select food to see its effect. Esc closes this menu."


func _format_number(number: int) -> String:
	var text_value: String = str(number)
	var output: String = ""
	var digits: int = 0
	for index: int in range(text_value.length() - 1, -1, -1):
		output = text_value.substr(index, 1) + output
		digits += 1
		if digits % 3 == 0 and index > 0:
			output = "," + output
	return output
