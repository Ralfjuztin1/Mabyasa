extends "res://Scripts/Assessment/PairedBossAssessmentOverlay.gd"

## Focused presentation fix for the Mystic Ylang-Ylang Guardian assessment.
## Reuses the existing battle-review scene and ALL existing reporting,
## grading, attempt history, comparison, checkpoint, and email functions.
## Only the comparison display and responsive layout are changed here.

const REVIEW_GOLD: Color = Color(0.89, 0.72, 0.38)
const REVIEW_CREAM: Color = Color(0.96, 0.94, 0.85)
const REVIEW_MUTED: Color = Color(0.69, 0.75, 0.68)
const REVIEW_GREEN: Color = Color(0.63, 0.86, 0.64)

var _comparison_card: PanelContainer = null


func _ready() -> void:
	super._ready()
	if not get_viewport().size_changed.is_connected(_on_review_viewport_resized):
		get_viewport().size_changed.connect(_on_review_viewport_resized)
	call_deferred("_fit_review_to_viewport")


func _on_review_viewport_resized() -> void:
	call_deferred("_fit_review_to_viewport")


func _set_email_status(message: String, ok: bool) -> void:
	# Keep error details available on hover without allowing a long server
	# response to expand the entire review panel off screen.
	super._set_email_status(message, ok)
	if is_instance_valid(_email_status_label):
		_email_status_label.tooltip_text = message
		if message.length() > 48:
			_email_status_label.text = "Assessment email sent." if ok else "Email failed — retry below."


func _show_result(index: int, animate: bool = true) -> void:
	# The base review owns the result text and correctness evaluation.
	super._show_result(index, animate)
	# Every result starts at the top, not at the previous question's scroll offset.
	var review_scroll: ScrollContainer = _find_control("ReviewScroll") as ScrollContainer
	if is_instance_valid(review_scroll):
		review_scroll.scroll_vertical = 0


func _show_comparison(
	attempt_number: int,
	victory: bool,
	comparison: Dictionary,
	retry_comparison: Dictionary
) -> void:
	var content: VBoxContainer = _find_control("Content") as VBoxContainer
	if not is_instance_valid(content):
		push_warning("[GUARDIAN REVIEW] Missing Content container; comparison not displayed.")
		return

	# Old revisions placed recommendations about OTHER sentences inside the
	# current question's review. Never mix global practice advice into a result.
	var review_body: VBoxContainer = _find_control("ReviewBody") as VBoxContainer
	if is_instance_valid(review_body):
		for child: Node in review_body.get_children():
			if child.name == "GuardianLearningRecommendations":
				review_body.remove_child(child)
				child.queue_free()

	for child: Node in content.get_children():
		if child.name == "LearningComparisonPanel":
			content.remove_child(child)
			child.queue_free()

	_comparison_card = PanelContainer.new()
	_comparison_card.name = "LearningComparisonPanel"
	_comparison_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comparison_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comparison_card.add_theme_stylebox_override("panel", _comparison_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_comparison_card.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var title: String = "LEARNING COMPARISON  /  "
	if attempt_number == 1:
		title += "OFFICIAL FIRST ATTEMPT"
	else:
		title += "PRACTICE ATTEMPT %d" % attempt_number
	title += "  /  VICTORY" if victory else "  /  DEFEAT"
	_add_summary_line(stack, title, 12, REVIEW_GOLD, true)

	var matched: int = int(comparison.get("matched_count", 0))
	if matched <= 0:
		_add_summary_line(stack, "No matching pre-assessment phrases available for comparison.", 13, REVIEW_CREAM)
	else:
		var pre_correct: int = int(comparison.get("pre_correct", 0))
		var post_correct: int = int(comparison.get("post_correct", 0))
		_add_summary_line(stack,
			"Before gameplay: %d/%d recognized  |  Guardian: %d/%d constructed" % [
				pre_correct, matched, post_correct, matched
			], 14, REVIEW_CREAM, true
		)

		var newly_correct: int = int(comparison.get("improved", 0))
		var applied: int = int(comparison.get("retained", 0))
		var still_weak: int = int(comparison.get("needs_practice", 0))
		var construction_gap: int = int(comparison.get("recognition_gap", 0))
		_add_summary_line(stack,
			"Newly demonstrated: %d   |   Applied: %d   |   Still developing: %d   |   Construction gap: %d" % [
				newly_correct, applied, still_weak, construction_gap
			], 11, REVIEW_MUTED
		)

	if not retry_comparison.is_empty() and int(retry_comparison.get("matched_count", 0)) > 0:
		_add_summary_line(stack,
			"Since your previous Guardian attempt: %d newly correct." % int(retry_comparison.get("improved", 0)),
			11, REVIEW_GOLD
		)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 12)
	stack.add_child(footer)

	var note: Label = _make_summary_label(
		"Recognition and construction test different skills; percentages are not directly comparable.",
		10, REVIEW_MUTED
	)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)

	_email_status_label = _make_summary_label("Preparing email status...", 11, REVIEW_GREEN)
	_email_status_label.name = "OfficialEmailStatus"
	_email_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_email_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_email_status_label)

	_email_retry_button = Button.new()
	_email_retry_button.name = "RetryOfficialAssessmentEmail"
	_email_retry_button.text = "RETRY EMAIL"
	_email_retry_button.custom_minimum_size = Vector2(110.0, 30.0)
	_email_retry_button.visible = false
	_email_retry_button.pressed.connect(_retry_official_email)
	stack.add_child(_email_retry_button)

	content.add_child(_comparison_card)
	var review_header: Node = _find_control("ReviewHeader")
	if is_instance_valid(review_header) and review_header.get_parent() == content:
		content.move_child(_comparison_card, review_header.get_index())

	# Fit after the comparison has contributed its minimum height.
	call_deferred("_fit_review_to_viewport")


func _comparison_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.105, 0.084, 0.98)
	style.border_color = REVIEW_GOLD
	style.border_width_left = 3
	style.set_corner_radius_all(7)
	return style


func _make_summary_label(value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_summary_line(stack: VBoxContainer, value: String, font_size: int, color: Color, emphasize: bool = false) -> void:
	var label: Label = _make_summary_label(value, font_size, color)
	if emphasize:
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.3))
	stack.add_child(label)


func _fit_review_to_viewport() -> void:
	if not is_inside_tree():
		return
	var assessment_panel: PanelContainer = _find_control("AssessmentPanel") as PanelContainer
	var content: VBoxContainer = _find_control("Content") as VBoxContainer
	var review_scroll: ScrollContainer = _find_control("ReviewScroll") as ScrollContainer
	var review_panel_node: PanelContainer = _find_control("ReviewPanel") as PanelContainer
	var stats: HBoxContainer = _find_control("StatsRow") as HBoxContainer
	var header: HBoxContainer = _find_control("Header") as HBoxContainer
	if not is_instance_valid(assessment_panel) or not is_instance_valid(content) or not is_instance_valid(review_scroll):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var target_width: float = minf(930.0, maxf(320.0, viewport_size.x - 32.0))
	var target_height: float = minf(630.0, maxf(320.0, viewport_size.y - 30.0))
	assessment_panel.custom_minimum_size = Vector2(target_width, target_height)

	# Make the long answer/lesson section scroll, not the entire review panel.
	# This keeps Previous, Next and Continue visible at the bottom.
	content.add_theme_constant_override("separation", 6)
	review_scroll.custom_minimum_size.y = clampf(viewport_size.y * 0.16, 95.0, 160.0)
	review_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(review_panel_node):
		review_panel_node.custom_minimum_size.y = 0.0
	if is_instance_valid(stats):
		stats.custom_minimum_size.y = 62.0
	if is_instance_valid(header):
		header.custom_minimum_size.y = 46.0

	# The original scene's top/bottom margins were designed without the
	# post-assessment comparison, and were wasting vertical space.
	# This is the Margin directly under AssessmentPanel, not ReviewPanel/Margin.
	var direct_margin: MarginContainer = assessment_panel.get_node_or_null("Margin") as MarginContainer
	if is_instance_valid(direct_margin):
		direct_margin.add_theme_constant_override("margin_top", 12)
		direct_margin.add_theme_constant_override("margin_bottom", 12)

	# Let the panel recalculate after changing its minimum size.
	assessment_panel.queue_sort()
