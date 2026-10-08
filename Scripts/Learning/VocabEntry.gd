class_name VocabEntry
extends Resource

## Data-only language entry.
## Adding new Kapampangan content should normally mean adding a .tres file,
## not changing battle code.

@export var id: String = ""
@export var kapampangan: String = ""
@export var english: String = ""

@export_enum("greeting", "word", "particle", "phrase") var category: String = "word"
@export_range(1, 5) var difficulty: int = 1
@export var source_npc: String = ""

## Optional progression metadata. The story can unlock a whole lesson group
## instead of learning hundreds of entries one by one.
@export var lesson_group: String = ""
@export var source_section: String = ""

## Supported values:
## multiple_choice, translate, fill_blank, match, sentence_build,
## sentence_part.
@export var allowed_types: PackedStringArray = PackedStringArray([
	"multiple_choice",
	"translate",
	"fill_blank",
	"match",
	"sentence_build"
])

@export_multiline var hint: String = ""
@export var pronunciation: String = ""

## For phrase entries: the exact word/component IDs in correct order.
@export var parts: PackedStringArray = PackedStringArray()

## Context-aware blanks. Each dictionary should contain:
## {"prompt": "It is morning. Complete the greeting:\nMayap a ____",
##  "answer_id": "abak"}
@export var fill_blank_variants: Array[Dictionary] = []

## Optional extra words for boss sentence building.
@export var sentence_distractors: PackedStringArray = PackedStringArray()
