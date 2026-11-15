extends CanvasLayer

## One reusable in-game visual for learning and delivering merchant goods.
## Each selected Kapampangan word displays the corresponding number of basket sprites.

signal lesson_finished()
signal delivery_finished(recipient_id: String)
signal closed()

const BASKET: Texture2D = preload("res://Assets/SecondTown/merchant_goods_basket.png")
const WORDS = ["metung", "adwa", "atlu / atlo"]
const DARK: Color = Color(0.035, 0.085, 0.064, 0.98)
const GREEN: Color = Color(0.09, 0.20, 0.145, 1.0)
const GOLD: Color = Color(0.86, 0.70, 0.39, 1.0)
const CREAM: Color = Color(0.96, 0.93, 0.84, 1.0)
const MUTED: Color = Color(0.70, 0.79, 0.71, 1.0)

var _mode: String = "lesson"
var _page: int = 0
var _selected: int = 0
var _quantity_needed: int = 1
var _recipient: String = ""
var _recipient_name: String = ""
var _complete: bool = false
var _feedback: String = ""

var _heading: Label
var _speaker: Label
var _counter: Label
var _word: Label
var _illustration: HBoxContainer
var _feedback_label: Label
var _actions: HFlowContainer


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func show_lesson() -> void:
	_mode = "lesson"
	_page = 0
	_complete = false
	_feedback = ""
	_redraw()


func show_delivery(recipient_id: String, recipient_name: String, amount: int) -> void:
	_mode = "delivery"
	_recipient = recipient_id
	_recipient_name = recipient_name
	_quantity_needed = amount
	_selected = 0
	_complete = false
	_feedback = ""
	_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _build() -> void:
	var screen: Control = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.022, 0.016, 0.77)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dimmer)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 450)
	panel.add_theme_stylebox_override("panel", _style(DARK, GOLD, 2))
	center.add_child(panel)

	var padding: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(padding)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	padding.add_child(stack)

	_heading = _text(23, GOLD)
	stack.add_child(_heading)
	_counter = _text(14, MUTED)
	stack.add_child(_counter)
	_speaker = _text(19, CREAM)
	_speaker.custom_minimum_size.y = 56
	stack.add_child(_speaker)

	var display: PanelContainer = PanelContainer.new()
	display.custom_minimum_size.y = 185
	display.add_theme_stylebox_override("panel", _style(GREEN, Color(0.30, 0.43, 0.30), 1))
	stack.add_child(display)

	var inside: VBoxContainer = VBoxContainer.new()
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override("separation", 7)
	display.add_child(inside)
	_word = _text(27, GOLD)
	inside.add_child(_word)
	var row_center: CenterContainer = CenterContainer.new()
	inside.add_child(row_center)
	_illustration = HBoxContainer.new()
	_illustration.alignment = BoxContainer.ALIGNMENT_CENTER
	_illustration.add_theme_constant_override("separation", 13)
	row_center.add_child(_illustration)

	_feedback_label = _text(15, MUTED)
	_feedback_label.custom_minimum_size.y = 24
	stack.add_child(_feedback_label)

	_actions = HFlowContainer.new()
	_actions.alignment = FlowContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 9)
	stack.add_child(_actions)


func _redraw() -> void:
	for node: Node in _actions.get_children():
		_actions.remove_child(node)
		node.queue_free()

	if _mode == "lesson":
		_redraw_lesson()
	else:
		_redraw_delivery()


func _redraw_lesson() -> void:
	_heading.text = "MERCHANT  /  LEARN THE NUMBERS"
	_counter.text = "LESSON  %d / 3" % (_page + 1)
	_speaker.text = "Merchant: %s means %d. Count the baskets with me." % [WORDS[_page].capitalize(), _page + 1]
	_word.text = "%s   —   %d" % [WORDS[_page].to_upper(), _page + 1]
	_update_baskets(_page + 1)
	_feedback_label.text = "Go back at any time to review a word."
	if _page > 0:
		_add_button("‹ PREVIOUS", _previous)
	_add_button("NEXT ›" if _page < 2 else "TAKE THE DELIVERIES ›", _next, true)
	_add_button("LEAVE", _exit)


func _previous() -> void:
	_page = maxi(0, _page - 1)
	_redraw()


func _next() -> void:
	if _page < 2:
		_page += 1
		_redraw()
		return
	if not _complete:
		_complete = true
		lesson_finished.emit()
	_heading.text = "DELIVERY BASKETS RECEIVED"
	_counter.text = "6 BASKETS  /  3 ADDRESSES"
	_speaker.text = "Merchant: Take metung to Berto, adwa to Mila, then atlu to Nena. Come back when you're done!"
	_word.text = "READY FOR DELIVERY"
	_update_baskets(3)
	_feedback_label.text = "The quest log will guide you to the first recipient."
	for node: Node in _actions.get_children():
		_actions.remove_child(node)
		node.queue_free()
	_add_button("RETURN TO TOWN", _exit, true)


func _redraw_delivery() -> void:
	_heading.text = "SUPPLY DELIVERY  /  %s" % _recipient_name.to_upper()
	_counter.text = "CHOOSE THE KAPAMPANGAN WORD FOR THE BASKETS"
	if _complete:
		var clues: Dictionary = {
			"berto": "Berto: Thank you! The fields are drying. The old well isn't giving enough water.",
			"mila": "Mila: Perfect! I saw strange markings carved beside the old well.",
			"nena": "Nena: Thank you! Some nights we hear odd sounds from the old well. Ask the Elder about them."
		}
		_speaker.text = str(clues.get(_recipient, "The delivery is complete."))
	else:
		_speaker.text = "%s: I have an order from the merchant. Can you give me the correct number of baskets?" % _recipient_name
	_word.text = "%s   —   %d" % [WORDS[_selected].to_upper(), _selected + 1]
	_update_baskets(_selected + 1)
	_feedback_label.text = _feedback if not _feedback.is_empty() else "Choosing a word changes how many baskets you are about to deliver."
	if _complete:
		_add_button("RETURN TO TOWN", _exit, true)
		return
	for i: int in range(WORDS.size()):
		_add_button(WORDS[i].to_upper(), _select_amount.bind(i), i == _selected)
	_add_button("CONFIRM DELIVERY", _confirm, true)
	_add_button("CANCEL", _exit)


func _select_amount(index: int) -> void:
	_selected = index
	_feedback = ""
	_redraw()


func _confirm() -> void:
	if _complete:
		return
	if _selected + 1 != _quantity_needed:
		_feedback = "Not quite. Ask the villager to repeat the order, or review the numbers from the merchant."
		_redraw()
		return
	_complete = true
	_feedback = "Correct! %s receives %d basket%s." % [_recipient_name, _quantity_needed, "" if _quantity_needed == 1 else "s"]
	delivery_finished.emit(_recipient)
	_redraw()


func _update_baskets(count: int) -> void:
	for child: Node in _illustration.get_children():
		_illustration.remove_child(child)
		child.queue_free()
	for _i: int in range(count):
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = BASKET
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(100, 100)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_illustration.add_child(sprite)


func _text(size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_button(caption: String, callback: Callable, primary: bool = false) -> void:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(130, 43)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(Color(0.18, 0.31, 0.21) if primary else GREEN, GOLD, 1))
	button.add_theme_stylebox_override("hover", _style(Color(0.23, 0.41, 0.28), GOLD, 2))
	button.add_theme_stylebox_override("pressed", _style(DARK, GOLD, 2))
	button.pressed.connect(callback)
	_actions.add_child(button)


func _style(fill: Color, rim: Color, thickness: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = rim
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	return style


func _exit() -> void:
	closed.emit()
