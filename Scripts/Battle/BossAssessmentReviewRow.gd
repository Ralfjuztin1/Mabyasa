extends PanelContainer

## One editable sentence-review card. The container layout and style are in
## BossAssessmentReviewRow.tscn; this script inserts response-specific text.

const CORRECT_COLOR: Color = Color(0.49, 0.76, 0.50, 1.0)
const REVIEW_COLOR: Color = Color(0.86, 0.43, 0.35, 1.0)

@onready var number_label: Label = $Margin/Body/Header/NumberLabel
@onready var score_label: Label = $Margin/Body/Header/ScoreLabel
@onready var your_sentence_label: Label = $Margin/Body/YourSentenceBlock/ValueLabel
@onready var correct_sentence_label: Label = $Margin/Body/CorrectSentenceBlock/ValueLabel
@onready var meaning_label: Label = $Margin/Body/MeaningBlock/ValueLabel
@onready var mistakes_block: VBoxContainer = $Margin/Body/MistakesBlock
@onready var mistakes_label: Label = $Margin/Body/MistakesBlock/ValueLabel
@onready var feedback_label: Label = $Margin/Body/FeedbackLabel


func setup(index: int, row_data: Dictionary) -> void:
	var is_correct: bool = bool(row_data.get("correct", false))
	var timed_out: bool = bool(row_data.get("timed_out", false))
	var score_percent: int = int(row_data.get("score_percent", 0))

	number_label.text = "SENTENCE %02d" % index
	score_label.text = "%d%% · %s" % [score_percent, "CORRECT" if is_correct else "REVIEW"]
	score_label.add_theme_color_override("font_color", CORRECT_COLOR if is_correct else REVIEW_COLOR)

	your_sentence_label.text = str(row_data.get("submitted_sentence", "(no answer)"))
	correct_sentence_label.text = str(row_data.get("correct_sentence", "—"))
	meaning_label.text = str(row_data.get("english_meaning", "—"))

	var raw_mistakes: Variant = row_data.get("mistakes", [])
	var mistakes: Array = raw_mistakes if raw_mistakes is Array else []
	if not mistakes.is_empty():
		var lines: PackedStringArray = []
		for mistake: Variant in mistakes:
			lines.append("• " + str(mistake))
		mistakes_label.text = "\n".join(lines)
		mistakes_block.visible = true
		feedback_label.visible = false
	elif timed_out:
		mistakes_label.text = "Time ran out before the sentence was submitted."
		mistakes_block.visible = true
		feedback_label.visible = false
	else:
		mistakes_block.visible = false
		feedback_label.visible = true
		feedback_label.text = "All words were placed correctly." if is_correct else "Review the correct sentence and meaning above."
		feedback_label.add_theme_color_override("font_color", CORRECT_COLOR if is_correct else REVIEW_COLOR)
