class_name QuestionFactory
extends RefCounted

## Stateless generator for language challenges.
## ONLY ENCOUNTERED entries are eligible for normal battle questions.
## The vocabulary data itself comes from LanguageProgress/VocabEntry.

const NORMAL_TYPES := ["multiple_choice", "fill_blank", "translate", "match"]
const MAX_CHOICES := 3
const MAX_MATCH_PAIRS := 3

const STAGE_PREFERENCE := [
	["multiple_choice", "fill_blank", "translate", "match"],
	["multiple_choice", "fill_blank", "translate", "match"],
	["fill_blank", "translate", "match", "multiple_choice"],
	["translate", "match", "fill_blank", "multiple_choice"]
]


static func build_normal_question(
	recent_ids: Array,
	recent_kinds: Array,
	forced_id: String = ""
) -> QuizQuestion:
	var pool: Array[VocabEntry] = _combat_entries()
	if pool.is_empty():
		return null

	var entry: VocabEntry = _pick_entry(pool, recent_ids, forced_id)
	if entry == null:
		return null

	## Try the selected entry first. If its preferred format is impossible
	## with the current amount of encountered data, try another valid format
	## before giving up. This is important with a brand-new account.
	var entries_to_try: Array[VocabEntry] = [entry]
	var others: Array[VocabEntry] = []

	for other: VocabEntry in pool:
		if other != entry:
			others.append(other)

	others.shuffle()
	entries_to_try.append_array(others)

	for candidate: VocabEntry in entries_to_try:
		var type_order: Array[String] = _get_type_order(candidate, recent_kinds)

		for type_name: String in type_order:
			var question: QuizQuestion = _build_type(
				candidate,
				type_name,
				pool
			)

			if question != null:
				return question

	return null


static func build_boss_sentence_question(recent_ids: Array) -> QuizQuestion:
	var phrases: Array[VocabEntry] = []

	for entry: VocabEntry in LanguageProgress.get_encountered_entries():
		if not entry.allowed_types.has("sentence_build"):
			continue

		if entry.parts.size() < 2:
			continue

		## Every component shown in the boss quiz must also have been
		## encountered. No surprise vocabulary sneaks in through the parts.
		var all_parts_encountered: bool = true
		for part_id: String in entry.parts:
			if not LanguageProgress.is_encountered(part_id):
				all_parts_encountered = false
				break

		if not all_parts_encountered:
			continue

		phrases.append(entry)

	if phrases.is_empty():
		return null

	var entry: VocabEntry = _pick_entry(phrases, recent_ids, "")
	if entry == null:
		return null

	var q := QuizQuestion.new()
	q.quiz_type = QuizQuestion.QuizType.SENTENCE_BUILD
	q.prompt = "Build the Kapampangan sentence for:\n%s" % entry.english
	q.time_limit = 28.0 + float(maxi(entry.difficulty - 1, 0))
	q.vocab_id = entry.id
	q.tested_vocab_ids = [entry.id]
	q.hint = entry.hint
	q.pronunciation = entry.pronunciation
	q.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

	for part_id: String in entry.parts:
		var part: VocabEntry = LanguageProgress.get_entry(part_id)
		if part == null or not LanguageProgress.is_encountered(part.id):
			return null

		q.sentence_token_ids.append(part.id)
		q.sentence_token_texts.append(part.kapampangan)

	for distractor_id: String in entry.sentence_distractors:
		var distractor: VocabEntry = LanguageProgress.get_entry(distractor_id)
		if distractor == null:
			continue
		if not LanguageProgress.is_encountered(distractor.id):
			continue
		if q.sentence_token_ids.has(distractor.id):
			continue

		q.sentence_distractor_ids.append(distractor.id)
		q.sentence_distractor_texts.append(distractor.kapampangan)

	## Only use components from other encountered sentence entries as
	## optional boss distractors.
	var seen_ids: Dictionary = {}
	for token_id: String in q.sentence_token_ids:
		seen_ids[token_id] = true
	for token_id: String in q.sentence_distractor_ids:
		seen_ids[token_id] = true

	for other: VocabEntry in phrases:
		if other == entry:
			continue

		for part_id: String in other.parts:
			if seen_ids.has(part_id):
				continue
			if not LanguageProgress.is_encountered(part_id):
				continue

			var part: VocabEntry = LanguageProgress.get_entry(part_id)
			if part == null:
				continue

			seen_ids[part.id] = true
			q.sentence_distractor_ids.append(part.id)
			q.sentence_distractor_texts.append(part.kapampangan)

			if q.sentence_distractor_ids.size() >= 2:
				break

		if q.sentence_distractor_ids.size() >= 2:
			break

	return q


static func _combat_entries() -> Array[VocabEntry]:
	## Critical rule: encountered, not the whole vocabulary database.
	return LanguageProgress.get_encountered_combat_entries()


static func _pick_entry(
	pool: Array[VocabEntry],
	recent_ids: Array,
	forced_id: String
) -> VocabEntry:
	if pool.is_empty():
		return null

	if not forced_id.is_empty():
		for entry: VocabEntry in pool:
			if entry.id == forced_id:
				return entry

	var fresh: Array[VocabEntry] = []
	for entry: VocabEntry in pool:
		if not recent_ids.has(entry.id):
			fresh.append(entry)

	var source: Array[VocabEntry] = fresh if not fresh.is_empty() else pool

	var weights: Array[float] = []
	var total: float = 0.0

	for entry: VocabEntry in source:
		var mastery: Dictionary = LanguageProgress.get_mastery(entry.id)
		var weight: float = 1.0
		weight += float(mastery.get("wrong", 0)) * 0.75
		weight -= float(mastery.get("correct", 0)) * 0.08

		if int(mastery.get("seen", 0)) == 0:
			weight += 1.25

		weights.append(maxf(weight, 0.25))
		total += weights.back()

	var roll: float = randf() * maxf(total, 0.01)
	for i: int in source.size():
		roll -= weights[i]
		if roll <= 0.0:
			return source[i]

	return source.back()


static func _get_type_order(
	entry: VocabEntry,
	recent_kinds: Array
) -> Array[String]:
	var allowed: Array[String] = []

	for type_name: String in NORMAL_TYPES:
		if entry.allowed_types.has(type_name):
			allowed.append(type_name)

	if allowed.is_empty():
		return []

	var stage: int = clampi(
		LanguageProgress.get_stage(entry.id),
		0,
		STAGE_PREFERENCE.size() - 1
	)

	var preferred: Array[String] = []
	for type_name: String in STAGE_PREFERENCE[stage]:
		if allowed.has(type_name):
			preferred.append(type_name)

	preferred.shuffle()

	var fresh: Array[String] = []
	var repeated: Array[String] = []

	for type_name: String in preferred:
		if recent_kinds.has(type_name):
			repeated.append(type_name)
		else:
			fresh.append(type_name)

	fresh.append_array(repeated)
	return fresh


static func _build_type(
	entry: VocabEntry,
	type_name: String,
	pool: Array[VocabEntry]
) -> QuizQuestion:
	match type_name:
		"multiple_choice":
			return _build_choice(entry, true, pool)
		"translate":
			return _build_choice(entry, false, pool)
		"fill_blank":
			return _build_fill_blank(entry, pool)
		"match":
			return _build_match(entry, pool)

	return null


static func _build_choice(
	entry: VocabEntry,
	kapampangan_to_english: bool,
	pool: Array[VocabEntry]
) -> QuizQuestion:
	var correct_text: String = (
		entry.english if kapampangan_to_english else entry.kapampangan
	)

	if correct_text.strip_edges().is_empty():
		return null

	var options: Array[Dictionary] = [
		{"id": entry.id, "text": correct_text}
	]
	var used: Dictionary = {correct_text.to_lower(): true}

	var distractors: Array[VocabEntry] = []
	for other: VocabEntry in pool:
		if other == entry or other.category == "particle":
			continue

		if other.category == entry.category:
			distractors.push_front(other)
		else:
			distractors.append(other)

	distractors.shuffle()

	for other: VocabEntry in distractors:
		if options.size() >= MAX_CHOICES:
			break

		var text: String = (
			other.english if kapampangan_to_english else other.kapampangan
		)

		if text.strip_edges().is_empty():
			continue
		if used.has(text.to_lower()):
			continue

		used[text.to_lower()] = true
		options.append({"id": other.id, "text": text})

	## One encountered entry is still a valid question. The player simply
	## gets one valid answer card instead of being forced to see unknown words.
	if options.is_empty():
		return null

	options.shuffle()

	var q := QuizQuestion.new()
	q.quiz_type = (
		QuizQuestion.QuizType.MULTIPLE_CHOICE
		if kapampangan_to_english
		else QuizQuestion.QuizType.TRANSLATE
	)

	if kapampangan_to_english:
		if entry.category == "greeting":
			q.prompt = "Someone says:\n\"%s\"\nWhat are they saying?" % entry.kapampangan
		else:
			q.prompt = "What does \"%s\" mean?" % entry.kapampangan
	else:
		q.prompt = "How do you say:\n\"%s\"\nin Kapampangan?" % entry.english

	q.time_limit = _time_for(entry)
	q.vocab_id = entry.id
	q.tested_vocab_ids = [entry.id]
	q.hint = entry.hint
	q.pronunciation = entry.pronunciation
	q.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

	for i: int in options.size():
		q.choices.append(str(options[i]["text"]))
		q.choice_vocab_ids.append(str(options[i]["id"]))

		if str(options[i]["id"]) == entry.id:
			q.correct_index = i

	return q


static func _build_fill_blank(
	entry: VocabEntry,
	pool: Array[VocabEntry]
) -> QuizQuestion:
	if entry.fill_blank_variants.is_empty() or entry.parts.is_empty():
		return null

	var variants: Array[Dictionary] = entry.fill_blank_variants.duplicate()
	variants.shuffle()

	for selected: Dictionary in variants:
		var prompt: String = str(selected.get("prompt", ""))
		var answer_id: String = str(selected.get("answer_id", ""))

		if prompt.is_empty() or answer_id.is_empty():
			continue
		if not entry.parts.has(answer_id):
			continue

		var answer_entry: VocabEntry = LanguageProgress.get_entry(answer_id)
		if answer_entry == null:
			continue

		## Only encountered vocabulary can be shown or used as an answer.
		if not LanguageProgress.is_encountered(answer_id):
			continue

		var q := QuizQuestion.new()
		q.quiz_type = QuizQuestion.QuizType.FILL_BLANK
		q.prompt = prompt
		q.time_limit = _time_for(entry)
		q.vocab_id = entry.id
		q.tested_vocab_ids = [entry.id]
		q.secondary_vocab_ids = [answer_id]
		q.hint = entry.hint
		q.pronunciation = (
			answer_entry.pronunciation
			if not answer_entry.pronunciation.is_empty()
			else entry.pronunciation
		)
		q.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

		var options: Array[Dictionary] = [
			{"id": answer_entry.id, "text": answer_entry.kapampangan}
		]
		var used: Dictionary = {
			answer_entry.kapampangan.to_lower(): true
		}

		## Distractors come ONLY from the encountered pool. We do not fall back
		## to unencountered phrase parts just to reach three cards.
		var distractors: Array[VocabEntry] = []
		for other: VocabEntry in pool:
			if other == entry or other.category == "particle":
				continue
			distractors.append(other)

		distractors.shuffle()

		for other: VocabEntry in distractors:
			if options.size() >= MAX_CHOICES:
				break

			var text: String = other.kapampangan
			if text.is_empty() or used.has(text.to_lower()):
				continue

			used[text.to_lower()] = true
			options.append({"id": other.id, "text": text})

		options.shuffle()
		for i: int in options.size():
			q.choices.append(str(options[i]["text"]))
			q.choice_vocab_ids.append(str(options[i]["id"]))

			if str(options[i]["id"]) == answer_id:
				q.correct_index = i

		return q

	return null


static func _build_match(
	focus: VocabEntry,
	pool: Array[VocabEntry]
) -> QuizQuestion:
	var candidates: Array[VocabEntry] = []

	for entry: VocabEntry in pool:
		if entry.english.is_empty() or entry.kapampangan.is_empty():
			continue
		if entry.category == "particle":
			continue

		if entry.category == focus.category:
			candidates.push_front(entry)
		else:
			candidates.append(entry)

	candidates.shuffle()

	if not candidates.has(focus):
		candidates.push_front(focus)

	if candidates.is_empty():
		return null

	## With one encountered entry, matching is one pair. As more entries are
	## encountered, it grows up to three pairs. Never add unknown vocabulary.
	var pair_count: int = mini(MAX_MATCH_PAIRS, candidates.size())
	candidates = candidates.slice(0, pair_count)

	var q := QuizQuestion.new()
	q.quiz_type = QuizQuestion.QuizType.MATCH
	q.prompt = "Connect each Kapampangan phrase to its English meaning."
	q.time_limit = 30.0
	q.vocab_id = focus.id
	q.hint = "Read each phrase first. Match by meaning, not by position."

	var right_entries: Array[VocabEntry] = candidates.duplicate()
	right_entries.shuffle()

	for entry: VocabEntry in candidates:
		q.match_left_ids.append(entry.id)
		q.match_left_texts.append(entry.kapampangan)
		q.tested_vocab_ids.append(entry.id)
		q.answer_line += (
			"\n" if not q.answer_line.is_empty() else ""
		) + "%s = %s" % [entry.kapampangan, entry.english]

	for entry: VocabEntry in right_entries:
		q.match_right_ids.append(entry.id)
		q.match_right_texts.append(entry.english)

	return q


static func _time_for(entry: VocabEntry) -> float:
	return 25.0 + float(maxi(entry.difficulty - 1, 0))
