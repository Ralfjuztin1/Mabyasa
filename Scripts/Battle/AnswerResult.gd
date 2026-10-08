class_name AnswerResult
extends RefCounted

## Result of any language challenge.
## The combat layer only reads this result. It does not know how questions
## are built or judged.

var correct: bool = false
var score: float = 0.0

var vocab_id: String = ""
var tested_vocab_ids: Array[String] = []
## Per-entry result lets matching reward correct pairs instead of calling
## every phrase wrong just because one pair was missed.
var per_vocab_results: Dictionary = {}

var question_kind: String = ""
var answer_line: String = ""
var chosen_note: String = ""
var hint: String = ""
var pronunciation: String = ""

var elapsed: float = 0.0
var time_limit: float = 0.0
var timed_out: bool = false
var speed_bonus: float = 0.0
var damage_multiplier: float = 1.0
var mistake_count: int = 0
