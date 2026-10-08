class_name QuestionFactory
extends RefCounted

## Stateless generator for language challenges.
## Only learned entries are eligible.

const NORMAL_TYPES := ["multiple_choice", "fill_blank", "translate", "match"]
const MAX_CHOICES := 3
const MIN_CHOICES := 2

## Difficulty progression:
## 0 = recognition
## 1 = recognition + guided recall
## 2 = recall + matching
## 3 = stronger recall/matching
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
	var pool := _combat_entries()
	if pool.is_empty():
		return null

	var entry := _pick_entry(pool, recent_ids, forced_id)
	if entry == null:
		return null

	## Prefer the selected word, but allow a fallback if that word cannot
	## support the preferred challenge yet.
	var candidates: Array[VocabEntry] = [entry]
	var others: Array[VocabEntry] = []
	for other in pool:
		if other != entry:
			others.append(other)
	others.shuffle()
	candidates.append_array(others)

	for candidate in candidates:
		var type_name := _choose_type(candidate, recent_kinds)
		var question := _build_type(candidate, type_name, pool)
		if question != null:
			return question

	return null


static func build_boss_sentence_question(recent_ids: Array) -> QuizQuestion:
	var phrases: Array[VocabEntry] = []
	for entry in LanguageProgress.get_learned_entries():
		if not entry.allowed_types.has("sentence_build"):
			continue
		if entry.parts.size() < 2:
			continue
		phrases.append(entry)

	if phrases.is_empty():
		return null

	var entry := _pick_entry(phrases, recent_ids, "")
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

	for part_id in entry.parts:
		var part := LanguageProgress.get_entry(part_id)
		if part == null:
			return null
		q.sentence_token_ids.append(part.id)
		q.sentence_token_texts.append(part.kapampangan)

	for distractor_id in entry.sentence_distractors:
		var distractor := LanguageProgress.get_entry(distractor_id)
		if distractor != null and not q.sentence_token_ids.has(distractor.id):
			q.sentence_distractor_ids.append(distractor.id)
			q.sentence_distractor_texts.append(distractor.kapampangan)

	## Learnable phrase parts from other learned phrases make boss fights
	## harder without inventing vocabulary.
	var seen_ids := {}
	for token_id in q.sentence_token_ids:
		seen_ids[token_id] = true
	for token_id in q.sentence_distractor_ids:
		seen_ids[token_id] = true

	for other in phrases:
		if other == entry:
			continue
		for part_id in other.parts:
			if seen_ids.has(part_id):
				continue
			var part := LanguageProgress.get_entry(part_id)
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
	var pool: Array[VocabEntry] = []
	for entry in LanguageProgress.get_learned_combat_entries():
		if entry.category == "particle":
			continue
		pool.append(entry)
	return pool


static func _pick_entry(
	pool: Array[VocabEntry],
	recent_ids: Array,
	forced_id: String
) -> VocabEntry:
	if pool.is_empty():
		return null

	if not forced_id.is_empty():
		for entry in pool:
			if entry.id == forced_id:
				return entry

	var fresh: Array[VocabEntry] = []
	for entry in pool:
		if not recent_ids.has(entry.id):
			fresh.append(entry)
	var source := fresh if not fresh.is_empty() else pool

	## Struggling words are more likely to return. Unseen words also get a
	## small boost, so battles gradually introduce the learned pool.
	var weights: Array[float] = []
	var total := 0.0
	for entry in source:
		var mastery := LanguageProgress.get_mastery(entry.id)
		var weight := 1.0
		weight += float(mastery.get("wrong", 0)) * 0.75
		weight -= float(mastery.get("correct", 0)) * 0.08
		if int(mastery.get("seen", 0)) == 0:
			weight += 1.25
		weights.append(maxf(weight, 0.25))
		total += weights.back()

	var roll := randf() * maxf(total, 0.01)
	for i in source.size():
		roll -= weights[i]
		if roll <= 0.0:
			return source[i]
	return source.back()


static func _choose_type(entry: VocabEntry, recent_kinds: Array) -> String:
	var allowed: Array[String] = []
	for type_name in NORMAL_TYPES:
		if entry.allowed_types.has(type_name):
			allowed.append(type_name)
	if allowed.is_empty():
		return ""

	var stage := clampi(LanguageProgress.get_stage(entry.id), 0, STAGE_PREFERENCE.size() - 1)
	var preference: Array = STAGE_PREFERENCE[stage].duplicate()
	preference.shuffle()

	for type_name in preference:
		if allowed.has(type_name) and not recent_kinds.has(type_name):
			return type_name
	for type_name in preference:
		if allowed.has(type_name):
			return type_name
	return allowed[0]


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
	var correct_text := entry.english if kapampangan_to_english else entry.kapampangan
	if correct_text.strip_edges().is_empty():
		return null

	var options := [{"id": entry.id, "text": correct_text}]
	var used := {correct_text.to_lower(): true}

	## Prefer distractors from the same category. That makes the answer less
	## obvious and checks actual memory rather than visual pattern recognition.
	var distractors: Array[VocabEntry] = []
	for other in pool:
		if other == entry or other.category == "particle":
			continue
		if other.category == entry.category:
			distractors.push_front(other)
		else:
			distractors.append(other)
	distractors.shuffle()

	for other in distractors:
		if options.size() >= MAX_CHOICES:
			break
		var text := other.english if kapampangan_to_english else other.kapampangan
		if text.strip_edges().is_empty() or used.has(text.to_lower()):
			continue
		used[text.to_lower()] = true
		options.append({"id": other.id, "text": text})

	if options.size() < MIN_CHOICES:
		return null

	options.shuffle()
	var q := QuizQuestion.new()
	q.quiz_type = QuizQuestion.QuizType.MULTIPLE_CHOICE if kapampangan_to_english else QuizQuestion.QuizType.TRANSLATE

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

	for i in options.size():
		q.choices.append(str(options[i]["text"]))
		q.choice_vocab_ids.append(str(options[i]["id"]))
		if str(options[i]["id"]) == entry.id:
			q.correct_index = i
	return q


static func _build_fill_blank(entry: VocabEntry, pool: Array[VocabEntry]) -> QuizQuestion:
	if entry.fill_blank_variants.is_empty() or entry.parts.is_empty():
		return null

	var variants := entry.fill_blank_variants.duplicate()
	variants.shuffle()
	var selected: Dictionary = variants[0]
	var prompt := str(selected.get("prompt", ""))
	var answer_id := str(selected.get("answer_id", ""))
	if prompt.is_empty() or answer_id.is_empty() or not entry.parts.has(answer_id):
		return null

	var answer_entry := LanguageProgress.get_entry(answer_id)
	if answer_entry == null or not LanguageProgress.is_learned(answer_id):
		return null

	var q := QuizQuestion.new()
	q.quiz_type = QuizQuestion.QuizType.FILL_BLANK
	q.prompt = prompt
	q.time_limit = _time_for(entry)
	q.vocab_id = entry.id
	q.tested_vocab_ids = [entry.id]
	q.secondary_vocab_ids = [answer_id]
	q.hint = entry.hint
	q.pronunciation = answer_entry.pronunciation if not answer_entry.pronunciation.is_empty() else entry.pronunciation
	q.answer_line = "%s = %s" % [entry.kapampangan, entry.english]

	var options := [{"id": answer_entry.id, "text": answer_entry.kapampangan}]
	var used := {answer_entry.kapampangan.to_lower(): true}

	## Best distractors are other learned words from similar phrase positions.
	## When those don't exist yet, use components of the same learned phrase.
	var other_learned: Array[VocabEntry] = []
	for other in pool:
		if other == entry or other.category == "particle":
			continue
		other_learned.append(other)
	other_learned.shuffle()

	for other in other_learned:
		if options.size() >= MAX_CHOICES:
			break
		var text := other.kapampangan
		if text.is_empty() or used.has(text.to_lower()):
			continue
		used[text.to_lower()] = true
		options.append({"id": other.id, "text": text})

	if options.size() < MAX_CHOICES:
		for part_id in entry.parts:
			if options.size() >= MAX_CHOICES:
				break
			if part_id == answer_id:
				continue
			var part := LanguageProgress.get_entry(part_id)
			if part == null or used.has(part.kapampangan.to_lower()):
				continue
			used[part.kapampangan.to_lower()] = true
			options.append({"id": part.id, "text": part.kapampangan})

	if options.size() < MIN_CHOICES:
		return null

	options.shuffle()
	for i in options.size():
		q.choices.append(str(options[i]["text"]))
		q.choice_vocab_ids.append(str(options[i]["id"]))
		if str(options[i]["id"]) == answer_id:
			q.correct_index = i
	return q


static func _build_match(focus: VocabEntry, pool: Array[VocabEntry]) -> QuizQuestion:
	var candidates: Array[VocabEntry] = []
	for entry in pool:
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
	if candidates.size() < 2:
		return null

	candidates = candidates.slice(0, mini(3, candidates.size()))
	var q := QuizQuestion.new()
	q.quiz_type = QuizQuestion.QuizType.MATCH
	q.prompt = "Connect each Kapampangan phrase to its English meaning."
	q.time_limit = 30.0
	q.vocab_id = focus.id
	q.hint = "Read each phrase first. Match by meaning, not by position."

	var right_entries := candidates.duplicate()
	right_entries.shuffle()

	for entry in candidates:
		q.match_left_ids.append(entry.id)
		q.match_left_texts.append(entry.kapampangan)
		q.tested_vocab_ids.append(entry.id)
		q.answer_line += ("\n" if not q.answer_line.is_empty() else "") + "%s = %s" % [entry.kapampangan, entry.english]
	for entry in right_entries:
		q.match_right_ids.append(entry.id)
		q.match_right_texts.append(entry.english)
	return q


static func _time_for(entry: VocabEntry) -> float:
	return 25.0 + float(maxi(entry.difficulty - 1, 0))
