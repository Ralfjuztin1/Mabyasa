class_name QuizQuestion
extends Resource

## Multiple choice only for this first pass — fill-in-the-blank and
## translate can come later. Content here is placeholder (not Kapampangan
## vocab) on purpose, so the battle loop itself can be tested and judged
## on its own before real content gets wired in.

enum QuizType { MULTIPLE_CHOICE, FILL_BLANK, TRANSLATE }

@export var quiz_type: QuizType = QuizType.MULTIPLE_CHOICE

## For FILL_BLANK, prompt should contain "____" as the blank marker,
## e.g. "Mayap a ____" — QuizUI fills it in visually once answered.
@export var prompt: String = ""
@export var choices: Array[String] = []
@export var correct_index: int = 0


func get_type_label() -> String:
	match quiz_type:
		QuizType.MULTIPLE_CHOICE:
			return "MULTIPLE CHOICE"
		QuizType.FILL_BLANK:
			return "FILL IN THE BLANK"
		QuizType.TRANSLATE:
			return "TRANSLATE"
		_:
			return ""

