extends CanvasLayer

## Story-led Second Town number lesson.
## The NPC explains each word while matching bucket sprites appear.
## Players can revisit an earlier word, then practise the learned numbers.

signal lesson_completed(chapter: String)
signal lesson_closed()

const BUCKET: Texture2D = preload("res://Assets/SecondTown/bucket_pixel.png")
const DARK: Color = Color(0.035, 0.085, 0.060, 0.98)
const INNER: Color = Color(0.065, 0.145, 0.105, 0.98)
const GOLD: Color = Color(0.88, 0.72, 0.43)
const CREAM: Color = Color(0.97, 0.94, 0.84)
const MUTED: Color = Color(0.71, 0.80, 0.72)

const LESSONS: Dictionary = {
	"merchant": {
		"npc": "MERCHANT",
		"title": "The Merchant's Deliveries",
		"intro": "Let me show you how we count our buckets.",
		"numbers": [1, 2, 3],
		"words": ["metung", "adwa", "atlu / atlo"],
		"explanations": [
			"Metung. That's one bucket.",
			"Adwa. Now there are two buckets.",
			"Atlu, also said as atlo. Three buckets."
		],
		"questions": [
			{"prompt": "Look at the water delivery. Which Kapampangan word matches?", "visual_amount": 2, "options": ["metung", "adwa", "atlu"], "correct": 1, "hint": "Two buckets is adwa."},
			{"prompt": "Which word belongs on this workshop delivery?", "visual_amount": 1, "options": ["atlu", "metung", "adwa"], "correct": 1, "hint": "One bucket is metung."},
			{"prompt": "Label the farmer's delivery with the correct word.", "visual_amount": 3, "options": ["adwa", "metung", "atlu / atlo"], "correct": 2, "hint": "Three buckets is atlu (atlo)."}
		],
		"success": "All three deliveries are ready. The merchant can now direct you to the farmer."
	},
	"farmer": {
		"npc": "FARMER",
		"title": "Water for the Fields",
		"intro": "Let's count the water buckets before we share them with the fields.",
		"numbers": [4, 5, 6],
		"words": ["apat", "lima", "anam"],
		"explanations": [
			"Apat. Four buckets ready for the seedlings.",
			"Lima. That's five buckets for the young crops.",
			"Anam. Six buckets in all."
		],
		"questions": [
			{"prompt": "A field needs ANAM buckets, but has APAT. How many more?", "visual_amount": 6, "options": ["metung (1)", "adwa (2)", "atlu (3)"], "correct": 1, "hint": "Anam is six. Apat is four. Find the difference."},
			{"prompt": "We need LIMA buckets but have APAT. How many more?", "visual_amount": 5, "options": ["adwa (2)", "metung (1)", "atlu (3)"], "correct": 1, "hint": "Count from apat (four) to lima (five)."},
			{"prompt": "We filled ANAM buckets. ADWA spilled. How many remain?", "visual_amount": 6, "options": ["lima (5)", "apat (4)", "atlu (3)"], "correct": 1, "hint": "Six minus two leaves four."}
		],
		"success": "The field supplies are accounted for. The Elder is ready to speak about the well."
	},
	"elder": {
		"npc": "ELDER",
		"title": "The Ancient Well's Records",
		"intro": "These old records count the buckets collected from our well.",
		"numbers": [7, 8, 9, 10],
		"words": ["pito / pitu", "walo / walu", "siyam", "apulo / apulu"],
		"explanations": [
			"Pito, also pitu. Seven buckets.",
			"Walo, also walu. Eight buckets.",
			"Siyam. Nine buckets.",
			"Apulo, also apulu. Ten buckets."
		],
		"questions": [
			{"prompt": "The east has PITO buckets; the west has WALO. Which has more?", "visual_amount": 8, "options": ["East — pito", "West — walo", "Both the same"], "correct": 1, "hint": "Pito is seven and walo is eight."},
			{"prompt": "The well needs APULO stone seals, but SIYAM are ready. How many are missing?", "visual_amount": 9, "options": ["metung (1)", "adwa (2)", "atlu (3)"], "correct": 0, "hint": "Apulo is ten. Siyam is nine."},
			{"prompt": "The inscription reads WALO, ___, APULO. What's missing?", "visual_amount": 9, "options": ["anam", "siyam", "pito"], "correct": 1, "hint": "The missing number comes between eight and ten."},
			{"prompt": "You need PITO buckets but found APULO. Is that enough?", "visual_amount": 10, "options": ["No", "Exactly enough", "Yes, with extras"], "correct": 2, "hint": "Apulo is ten, which is more than pito (seven)."}
		],
		"success": "The old water records make sense. Inspect the well's carved stones for the next clue."
	}
}

var _chapter: String = "merchant"
var _stage: int = 0  # 0 = visual lesson, 1 = applied questions, 2 = complete
var _word_index: int = 0
var _question_index: int = 0
var _answer_correct: bool = false
var _feedback: String = ""
var _finished_once: bool = false
var _returning_from_review: bool = false

const WORD_IDS: Dictionary = {
	"merchant": ["metung", "adwa", "atlo_or_atlu"],
	"farmer": ["apat", "lima", "anam"],
	"elder": ["pito_or_pitu", "walo_or_walu", "siyam", "apulo_or_apulu"]
}

var _title: Label
var _step_label: Label
var _speech: Label
var _word: Label
var _caption: Label
var _bucket_holder: CenterContainer
var _controls: FlowContainer
var _body: VBoxContainer
var _frame: PanelContainer


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_scene()


func start_chapter(chapter: String) -> void:
	if not LESSONS.has(chapter):
		push_error("[SECOND TOWN] Unknown lesson: " + chapter)
		lesson_closed.emit()
		return
	_chapter = chapter
	_stage = 0
	_word_index = 0
	_question_index = 0
	_answer_correct = false
	_feedback = ""
	_finished_once = false
	_returning_from_review = false
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		lesson_closed.emit()


func _build_scene() -> void:
	var root: Control = Control.new()
	root.name = "BucketLessonCutscene"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.017, 0.87)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(700, 500)
	_frame.add_theme_stylebox_override("panel", _style(DARK, GOLD, 2, 12))
	center.add_child(_frame)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 23)
	margin.add_theme_constant_override("margin_bottom", 24)
	_frame.add_child(margin)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	margin.add_child(_body)

	_title = _label(22, GOLD)
	_body.add_child(_title)
	_step_label = _label(14, MUTED)
	_body.add_child(_step_label)
	_speech = _label(18, CREAM)
	_speech.custom_minimum_size.y = 47
	_body.add_child(_speech)

	var stage_panel: PanelContainer = PanelContainer.new()
	stage_panel.custom_minimum_size.y = 209
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_theme_stylebox_override("panel", _style(INNER, Color(0.30, 0.41, 0.28), 1, 9))
	_body.add_child(stage_panel)

	var stage_center: CenterContainer = CenterContainer.new()
	stage_panel.add_child(stage_center)
	var stage_stack: VBoxContainer = VBoxContainer.new()
	stage_stack.add_theme_constant_override("separation", 5)
	stage_center.add_child(stage_stack)

	_word = _label(29, GOLD)
	stage_stack.add_child(_word)
	_bucket_holder = CenterContainer.new()
	_bucket_holder.custom_minimum_size = Vector2(520, 135)
	stage_stack.add_child(_bucket_holder)

	_caption = _label(15, MUTED)
	_body.add_child(_caption)

	_controls = HFlowContainer.new()
	_controls.alignment = FlowContainer.ALIGNMENT_CENTER
	_controls.add_theme_constant_override("separation", 12)
	_body.add_child(_controls)


func _render() -> void:
	_clear_buttons()
	var data: Dictionary = LESSONS[_chapter]
	_title.text = str(data["title"]).to_upper()
	match _stage:
		0:
			_render_word(data)
		1:
			_render_question(data)
		2:
			_render_finished(data)


func _render_word(data: Dictionary) -> void:
	var numbers: Array = data["numbers"]
	var words: Array = data["words"]
	var explanations: Array = data["explanations"]
	var amount: int = int(numbers[_word_index])
	var ids: Array = WORD_IDS[_chapter]
	LanguageProgress.mark_encountered(str(ids[_word_index]))
	_step_label.text = "WATCH AND LEARN   %d / %d" % [_word_index + 1, numbers.size()]
	_speech.text = "%s: %s" % [str(data["npc"]).capitalize(), str(explanations[_word_index])]
	_word.text = "%s  —  %d" % [str(words[_word_index]).to_upper(), amount]
	_caption.text = "Look at the buckets. Use Previous and Next to review each word."
	_display_buckets(amount)

	if _word_index > 0:
		_add_button("‹ PREVIOUS WORD", _previous_word, false)
	_add_button("NEXT WORD ›" if _word_index < numbers.size() - 1 else "TRY THE TASK ›", _next_word, true)
	_add_button("LEAVE", _close, false)


func _previous_word() -> void:
	_word_index = maxi(_word_index - 1, 0)
	_render()


func _next_word() -> void:
	var data: Dictionary = LESSONS[_chapter]
	var words: Array = data["words"]
	if _word_index < words.size() - 1:
		_word_index += 1
	else:
		_stage = 1
		if not _returning_from_review:
			_question_index = 0
			_answer_correct = false
			_feedback = ""
		_returning_from_review = false
	_render()


func _render_question(data: Dictionary) -> void:
	var questions: Array = data["questions"]
	var q: Dictionary = questions[_question_index]
	_step_label.text = "HELP THE VILLAGER   %d / %d" % [_question_index + 1, questions.size()]
	_speech.text = "%s: %s" % [str(data["npc"]).capitalize(), str(q["prompt"])]
	_word.text = "YOUR TURN"
	_display_buckets(int(q.get("visual_amount", 0)))
	_caption.text = _feedback if not _feedback.is_empty() else "Use what you learned to choose the right answer."

	if _answer_correct:
		_add_button("CONTINUE ›" if _question_index < questions.size() - 1 else "FINISH TASK ›", _next_question, true)
	else:
		var options: Array = q["options"]
		for i: int in range(options.size()):
			_add_button(str(options[i]), _choose_answer.bind(i), false)
	_add_button("‹ REVIEW WORDS", _review_words, false)


func _choose_answer(index: int) -> void:
	if _answer_correct:
		return
	var data: Dictionary = LESSONS[_chapter]
	var questions: Array = data["questions"]
	var q: Dictionary = questions[_question_index]
	_answer_correct = index == int(q["correct"])
	_feedback = "Correct!" if _answer_correct else "Try again: " + str(q["hint"])
	_render()


func _review_words() -> void:
	_returning_from_review = true
	_stage = 0
	_word_index = 0
	_render()


func _next_question() -> void:
	var data: Dictionary = LESSONS[_chapter]
	var questions: Array = data["questions"]
	if _question_index < questions.size() - 1:
		_question_index += 1
		_answer_correct = false
		_feedback = ""
	else:
		_stage = 2
		if not _finished_once:
			_finished_once = true
			lesson_completed.emit(_chapter)
	_render()


func _render_finished(data: Dictionary) -> void:
	_step_label.text = "LESSON COMPLETE"
	_speech.text = "%s: %s" % [str(data["npc"]).capitalize(), str(data["success"])]
	_word.text = "WELL DONE!"
	var numbers: Array = data["numbers"]
	_display_buckets(int(numbers[numbers.size() - 1]))
	_caption.text = "Your new words have been added to your learning progress."
	_add_button("RETURN TO TOWN", _close, true)


func _display_buckets(amount: int) -> void:
	for child: Node in _bucket_holder.get_children():
		_bucket_holder.remove_child(child)
		child.queue_free()

	if amount <= 0:
		var hint: Label = _label(22, MUTED)
		hint.text = "Remember the word you learned from the buckets."
		_bucket_holder.add_child(hint)
		return

	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	_bucket_holder.add_child(grid)

	for i: int in range(amount):
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = BUCKET
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.custom_minimum_size = Vector2(58, 63)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.modulate.a = 0.0
		grid.add_child(sprite)
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.19).set_delay(float(i) * 0.045)


func _clear_buttons() -> void:
	for button: Node in _controls.get_children():
		_controls.remove_child(button)
		button.queue_free()


func _add_button(label_text: String, action: Callable, primary: bool) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(125 if not primary else 151, 42)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(Color(0.18, 0.29, 0.17) if primary else INNER, GOLD, 1, 7))
	button.add_theme_stylebox_override("hover", _style(Color(0.25, 0.38, 0.23), GOLD, 2, 7))
	button.add_theme_stylebox_override("pressed", _style(Color(0.14, 0.21, 0.12), GOLD, 2, 7))
	button.pressed.connect(action)
	_controls.add_child(button)


func _label(font_size: int, tint: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


func _style(fill: Color, edge: Color, thick: int, corner: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(thick)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _close() -> void:
	lesson_closed.emit()
