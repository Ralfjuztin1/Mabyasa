extends Control

## Scene-based post-boss assessment. Edit layout, controls, colours, spacing,
## and panel styles in BossAssessmentOverlay.tscn. This script only fills data
## and manages the close/continue action.

signal finished(victory: bool)

const REVIEW_ROW_SCENE: PackedScene = preload(
	"res://Scenes/Battle/BossAssessmentReviewRow.tscn"
)
const OVERLAY_SCENE_PATH: String = "res://Scenes/Battle/BossAssessmentOverlay.tscn"

const GOLD: Color = Color(0.82, 0.67, 0.36, 1.0)
const CREAM: Color = Color(0.94, 0.89, 0.76, 1.0)
const MUTED: Color = Color(0.68, 0.70, 0.61, 1.0)
const GREEN: Color = Color(0.49, 0.76, 0.50, 1.0)
const RED: Color = Color(0.86, 0.43, 0.35, 1.0)

# Resolve controls by their names instead of fixed full paths. This keeps the UI
# script working when the editable scene's containers are rearranged.
var title_label: Label
var subtitle_label: Label
var outcome_label: Label
var accuracy_value: Label
var perfect_value: Label
var words_value: Label
var mistakes_value: Label
var review_list: VBoxContainer
var empty_state_panel: PanelContainer
var review_scroll: ScrollContainer
var finish_button: Button

var _controls_ready: bool = false
var _scene_repair_scheduled: bool = false
var _presentation_requested: bool = false
var _pending_presentation: bool = false
var _pending_victory: bool = false
var _pending_report: Dictionary = {}
var _pending_boss_name: String = ""

var _victory: bool = false
var _finish_clicked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Assessment overlays must never appear merely because a scene or stray
	# script-only instance entered the tree. BattleScreen.show/present() opens it.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The layout lives in the editable .tscn; only bind to the existing controls.
	title_label = _find_control("TitleLabel") as Label
	subtitle_label = _find_control("SubtitleLabel") as Label
	outcome_label = _find_control("OutcomeLabel") as Label
	accuracy_value = _find_card_value("AccuracyCard")
	perfect_value = _find_card_value("PerfectCard")
	words_value = _find_card_value("WordsCard")
	mistakes_value = _find_card_value("MistakesCard")
	review_list = _find_control("ReviewList") as VBoxContainer
	empty_state_panel = _find_control("EmptyStatePanel") as PanelContainer
	review_scroll = _find_control("ReviewScroll") as ScrollContainer
	finish_button = _find_control("FinishButton") as Button

	var missing: Array[String] = []
	for required: Array in [
		["TitleLabel", title_label],
		["SubtitleLabel", subtitle_label],
		["OutcomeLabel", outcome_label],
		["AccuracyCard/ValueLabel", accuracy_value],
		["PerfectCard/ValueLabel", perfect_value],
		["WordsCard/ValueLabel", words_value],
		["MistakesCard/ValueLabel", mistakes_value],
		["ReviewList", review_list],
		["EmptyStatePanel", empty_state_panel],
		["ReviewScroll", review_scroll],
		["FinishButton", finish_button],
	]:
		if required[1] == null:
			missing.append(str(required[0]))

	if not missing.is_empty():
		# Recover from older code that created this script with .new() instead
		# of instantiating the .tscn. Such a node has no scene path or children.
		# The deferred repair runs after the caller's present() call, so that
		# request can be forwarded into the real scene instance.
		if scene_file_path.is_empty() and get_child_count() == 0:
			_scene_repair_scheduled = true
			call_deferred("_repair_script_only_instance")
			return

		push_error(
			"[BOSS ASSESSMENT] Controls not found in scene '%s' at node '%s': %s. " % [
				str(scene_file_path), str(get_path()), ", ".join(PackedStringArray(missing))
			] + "Open res://Scenes/Battle/BossAssessmentOverlay.tscn and check its node names."
		)
		return

	_controls_ready = true
	finish_button.pressed.connect(_on_finish_pressed)


func _repair_script_only_instance() -> void:
	if not is_instance_valid(self) or _controls_ready:
		return

	if not scene_file_path.is_empty() or get_child_count() > 0:
		push_error(
			"[BOSS ASSESSMENT] Auto-recovery stopped: this node is not a bare script-only instance. "
			+ "Scene path='%s', child count=%d. Check the matching .tscn file."
			% [str(scene_file_path), get_child_count()]
		)
		return

	var parent_node: Node = get_parent()
	if parent_node == null:
		push_error(
			"[BOSS ASSESSMENT] Created with GDScript.new() but has no parent; "
			+ "instantiate res://Scenes/Battle/BossAssessmentOverlay.tscn instead."
		)
		return

	var packed_scene: PackedScene = load(OVERLAY_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("[BOSS ASSESSMENT] Cannot load " + OVERLAY_SCENE_PATH)
		return

	var replacement: Control = packed_scene.instantiate() as Control
	if replacement == null:
		push_error("[BOSS ASSESSMENT] The assessment scene root is not a Control.")
		return

	replacement.name = "BossAssessmentOverlaySceneInstance"
	replacement.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_node.add_child(replacement)
	parent_node.move_child(replacement, get_index())
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Keep this node alive as a signal relay because BattleScreen may already
	# have connected to its finished signal before recovery ran.
	replacement.connect("finished", Callable(self, "_forward_replacement_finished"))

	if _pending_presentation:
		replacement.call_deferred(
			"present",
			_pending_victory,
			_pending_report.duplicate(true),
			_pending_boss_name
		)


func _forward_replacement_finished(victory: bool) -> void:
	finished.emit(victory)
	queue_free()


func _find_control(control_name: String) -> Node:
	return find_child(control_name, true, false)


func _find_card_value(card_name: String) -> Label:
	var card: Node = _find_control(card_name)
	if card == null:
		return null
	return card.find_child("ValueLabel", true, false) as Label


func present(victory: bool, report: Dictionary, boss_name: String) -> void:
	_presentation_requested = true
	if not _controls_ready:
		if _scene_repair_scheduled:
			_pending_presentation = true
			_pending_victory = victory
			_pending_report = report.duplicate(true)
			_pending_boss_name = boss_name
			return
		push_error(
			"[BOSS ASSESSMENT] Cannot present: controls are missing. "
			+ "Check the loaded BossAssessmentOverlay.tscn and the node this script is attached to."
		)
		return

	_victory = victory
	_finish_clicked = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_label.text = "BOSS ASSESSMENT"
	subtitle_label.text = "TRIAL COMPLETE  •  %s" % boss_name.to_upper()
	outcome_label.text = "VICTORY" if victory else "DEFEAT · REVIEW YOUR MISTAKES"
	outcome_label.add_theme_color_override(
		"font_color",
		GREEN if victory else RED
	)
	finish_button.text = "CONTINUE" if victory else "RETURN TO CHECKPOINT"

	var accuracy: int = int(report.get("accuracy_percent", 0))
	var correct_sentences: int = int(report.get("correct_sentences", 0))
	var total_sentences: int = int(report.get("total_sentences", 0))
	var words_correct: int = int(report.get("words_correct", 0))
	var words_total: int = int(report.get("words_total", 0))
	var mistake_count: int = int(report.get("mistake_count", 0))

	accuracy_value.text = "%d%%" % accuracy
	perfect_value.text = "%d / %d" % [correct_sentences, total_sentences]
	words_value.text = "%d / %d" % [words_correct, words_total]
	mistakes_value.text = str(mistake_count)
	mistakes_value.add_theme_color_override(
		"font_color",
		RED if mistake_count > 0 else GREEN
	)

	_clear_review_rows()
	var raw_rows: Variant = report.get("rows", [])
	var rows: Array = raw_rows if raw_rows is Array else []
	if rows.is_empty():
		empty_state_panel.visible = true
	else:
		empty_state_panel.visible = false
		for index in range(rows.size()):
			if not (rows[index] is Dictionary):
				continue
			var review_row: Control = REVIEW_ROW_SCENE.instantiate() as Control
			if review_row == null:
				push_error("[BOSS ASSESSMENT] Could not instantiate review row scene.")
				continue
			review_list.add_child(review_row)
			review_row.call("setup", index + 1, rows[index] as Dictionary)

		# Make sure the list starts at the top for every battle report.
		review_scroll.scroll_vertical = 0

	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	finish_button.grab_focus()


func _clear_review_rows() -> void:
	for child: Node in review_list.get_children():
		if child == empty_state_panel:
			continue
		child.queue_free()


func _on_finish_pressed() -> void:
	if _finish_clicked:
		return
	_finish_clicked = true
	finish_button.disabled = true
	var has_listener: bool = not get_signal_connection_list("finished").is_empty()
	finished.emit(_victory)
	# If this scene was accidentally instanced outside BattleScreen, no owner
	# will handle the signal. Let the user dismiss the stray overlay anyway.
	if not has_listener:
		queue_free()
