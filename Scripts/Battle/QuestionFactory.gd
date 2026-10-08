extends RefCounted


const NORMAL_TYPES: Array[String] = [
	"multiple_choice",
	"fill_blank",
	"translate",
	"match"
]

const MAX_CHOICES: int = 3
const MAX_MATCH_PAIRS: int = 3


const STAGE_PREFERENCE: Array[Array] = [

	[
		"multiple_choice",
		"fill_blank",
		"translate",
		"match"
	],

	[
		"multiple_choice",
		"fill_blank",
		"translate",
		"match"
	],

	[
		"fill_blank",
		"translate",
		"match",
		"multiple_choice"
	],

	[
		"translate",
		"match",
		"fill_blank",
		"multiple_choice"
	]
]


# ============================================================
# NORMAL QUESTION
# ============================================================

static func build_normal_question(
	recent_ids: Array,
	recent_kinds: Array,
	forced_id: String = ""
) -> QuizQuestion:

	var pool: Array[VocabEntry] = (
		_combat_entries()
	)

	if pool.is_empty():
		return null


	var entry: VocabEntry = (
		_pick_entry(
			pool,
			recent_ids,
			forced_id
		)
	)

	if entry == null:
		return null


	var entries_to_try: Array[VocabEntry] = [
		entry
	]

	var others: Array[VocabEntry] = []


	for other: VocabEntry in pool:

		if other != entry:

			others.append(
				other
			)


	others.shuffle()

	entries_to_try.append_array(
		others
	)


	for candidate: VocabEntry in entries_to_try:

		var type_order: Array[String] = (
			_get_type_order(
				candidate,
				recent_kinds
			)
		)


		for type_name: String in type_order:

			var question: QuizQuestion = (
				_build_type(
					candidate,
					type_name,
					pool
				)
			)


			if question != null:

				return question


	return null


# ============================================================
# BOSS SENTENCE QUESTION
# ============================================================

static func build_boss_sentence_question(
	recent_ids: Array
) -> QuizQuestion:

	var phrases: Array[VocabEntry] = []


	for entry: VocabEntry in (
		LanguageProgress.get_encountered_entries()
	):

		if not entry.allowed_types.has(
			"sentence_build"
		):
			continue


		if entry.parts.size() < 2:
			continue


		var all_parts_encountered: bool = true


		for part_id: String in entry.parts:

			if not LanguageProgress.is_encountered(
				part_id
			):

				all_parts_encountered = false
				break


		if not all_parts_encountered:
			continue


		phrases.append(
			entry
		)


	if phrases.is_empty():
		return null


	var entry: VocabEntry = (
		_pick_entry(
			phrases,
			recent_ids,
			""
		)
	)


	if entry == null:
		return null


	var q := QuizQuestion.new()


	q.quiz_type = (
		QuizQuestion.QuizType.SENTENCE_BUILD
	)

	q.prompt = (
		"Build the Kapampangan sentence for:\n%s"
		% entry.english
	)


	q.time_limit = (
		28.0
		+ float(
			maxi(
				entry.difficulty - 1,
				0
			)
		)
	)


	q.vocab_id = entry.id

	q.tested_vocab_ids = [
		entry.id
	]

	q.hint = entry.hint

	q.pronunciation = (
		entry.pronunciation
	)

	q.answer_line = (
		"%s = %s"
		% [
			entry.kapampangan,
			entry.english
		]
	)


	for part_id: String in entry.parts:

		var part: VocabEntry = (
			LanguageProgress.get_entry(
				part_id
			)
		)


		if part == null:
			return null


		if not LanguageProgress.is_encountered(
			part.id
		):
			return null


		q.sentence_token_ids.append(
			part.id
		)

		q.sentence_token_texts.append(
			part.kapampangan
		)


	# --------------------------------------------------------
	# KNOWN DISTRACTORS ONLY
	# --------------------------------------------------------

	var used_parts: Dictionary = {}


	for part_id: String in q.sentence_token_ids:

		used_parts[part_id] = true


	for distractor_id: String in (
		entry.sentence_distractors
	):

		if used_parts.has(
			distractor_id
		):
			continue


		if not LanguageProgress.is_encountered(
			distractor_id
		):
			continue


		var distractor: VocabEntry = (
			LanguageProgress.get_entry(
				distractor_id
			)
		)


		if distractor == null:
			continue


		q.sentence_distractor_ids.append(
			distractor.id
		)

		q.sentence_distractor_texts.append(
			distractor.kapampangan
		)

		used_parts[distractor.id] = true


		if (
			q.sentence_distractor_ids.size()
			>= 2
		):
			break


	return q


# ============================================================
# ENCOUNTERED COMBAT POOL
# ============================================================

static func _combat_entries() -> Array[VocabEntry]:

	return (
		LanguageProgress
		.get_encountered_combat_entries()
	)


# ============================================================
# PICK ENTRY
# ============================================================

static func _pick_entry(
	pool: Array[VocabEntry],
	recent_ids: Array,
	forced_id: String
) -> VocabEntry:

	if pool.is_empty():
		return null


	# --------------------------------------------------------
	# RETRY
	# --------------------------------------------------------

	if not forced_id.is_empty():

		for entry: VocabEntry in pool:

			if (
				entry.id == forced_id
				and LanguageProgress.is_encountered(
					entry.id
				)
			):

				return entry


	# --------------------------------------------------------
	# AVOID RECENT ENTRIES
	# --------------------------------------------------------

	var fresh: Array[VocabEntry] = []


	for entry: VocabEntry in pool:

		if not recent_ids.has(
			entry.id
		):

			fresh.append(
				entry
			)


	var source: Array[VocabEntry] = (
		fresh
		if not fresh.is_empty()
		else pool
	)


	# --------------------------------------------------------
	# WEIGHT BY MASTERY
	# --------------------------------------------------------

	var weights: Array[float] = []
	var total: float = 0.0


	for entry: VocabEntry in source:

		var mastery: Dictionary = (
			LanguageProgress.get_mastery(
				entry.id
			)
		)


		var weight: float = 1.0


		weight += (
			float(
				mastery.get(
					"wrong",
					0
				)
			)
			* 0.75
		)


		weight -= (
			float(
				mastery.get(
					"correct",
					0
				)
			)
			* 0.08
		)


		if int(
			mastery.get(
				"seen",
				0
			)
		) == 0:

			weight += 1.25


		weight = maxf(
			weight,
			0.25
		)


		weights.append(
			weight
		)

		total += weight


	var roll: float = (
		randf()
		* maxf(
			total,
			0.01
		)
	)


	for i: int in source.size():

		roll -= weights[i]


		if roll <= 0.0:

			return source[i]


	return source.back()


# ============================================================
# TYPE ORDER
# ============================================================

static func _get_type_order(
	entry: VocabEntry,
	recent_kinds: Array
) -> Array[String]:

	var allowed: Array[String] = []


	for type_name: String in NORMAL_TYPES:

		if entry.allowed_types.has(
			type_name
		):

			allowed.append(
				type_name
			)


	if allowed.is_empty():
		return []


	var stage: int = clampi(
		LanguageProgress.get_stage(
			entry.id
		),
		0,
		STAGE_PREFERENCE.size() - 1
	)


	var preferred: Array[String] = []


	for type_name: String in (
		STAGE_PREFERENCE[stage]
	):

		if allowed.has(
			type_name
		):

			preferred.append(
				type_name
			)


	var fresh: Array[String] = []
	var repeated: Array[String] = []


	for type_name: String in preferred:

		if recent_kinds.has(
			type_name
		):

			repeated.append(
				type_name
			)

		else:

			fresh.append(
				type_name
			)


	fresh.append_array(
		repeated
	)


	# Don't randomize the entire preference order.
	# Try fresh types first in the designed order.
	return fresh


# ============================================================
# BUILD TYPE
# ============================================================

static func _build_type(
	entry: VocabEntry,
	type_name: String,
	pool: Array[VocabEntry]
) -> QuizQuestion:

	match type_name:

		"multiple_choice":

			return _build_choice(
				entry,
				true,
				pool
			)


		"translate":

			return _build_choice(
				entry,
				false,
				pool
			)


		"fill_blank":

			return _build_fill_blank(
				entry,
				pool
			)


		"match":

			return _build_match(
				entry,
				pool
			)


	return null


# ============================================================
# MULTIPLE CHOICE / TRANSLATE
# ============================================================

static func _build_choice(
	entry: VocabEntry,
	kapampangan_to_english: bool,
	pool: Array[VocabEntry]
) -> QuizQuestion:

	var correct_text: String = (
		entry.english
		if kapampangan_to_english
		else entry.kapampangan
	)


	if correct_text.strip_edges().is_empty():
		return null


	var options: Array[Dictionary] = [
		{
			"id": entry.id,
			"text": correct_text
		}
	]


	var used: Dictionary = {
		correct_text.to_lower(): true
	}


	# --------------------------------------------------------
	# ENCOUNTERED DISTRACTORS ONLY
	# --------------------------------------------------------

	var distractors: Array[VocabEntry] = []


	for other: VocabEntry in pool:

		if other == entry:
			continue


		if other.category == "particle":
			continue


		distractors.append(
			other
		)


	distractors.shuffle()


	for other: VocabEntry in distractors:

		if options.size() >= MAX_CHOICES:
			break


		var text: String = (
			other.english
			if kapampangan_to_english
			else other.kapampangan
		)


		if text.strip_edges().is_empty():
			continue


		if used.has(
			text.to_lower()
		):
			continue


		used[text.to_lower()] = true


		options.append(
			{
				"id": other.id,
				"text": text
			}
		)


	options.shuffle()


	var q := QuizQuestion.new()


	q.quiz_type = (
		QuizQuestion.QuizType.MULTIPLE_CHOICE
		if kapampangan_to_english
		else QuizQuestion.QuizType.TRANSLATE
	)


	if kapampangan_to_english:

		if entry.category == "greeting":

			q.prompt = (
				"Someone says:\n\"%s\"\nWhat are they saying?"
				% entry.kapampangan
			)

		else:

			q.prompt = (
				"What does \"%s\" mean?"
				% entry.kapampangan
			)

	else:

		q.prompt = (
			"How do you say:\n\"%s\"\nin Kapampangan?"
			% entry.english
		)


	q.time_limit = (
		25.0
		+ float(
			maxi(
				entry.difficulty - 1,
				0
			)
		)
	)


	q.vocab_id = entry.id

	q.tested_vocab_ids = [
		entry.id
	]

	q.hint = entry.hint

	q.pronunciation = (
		entry.pronunciation
	)

	q.answer_line = (
		"%s = %s"
		% [
			entry.kapampangan,
			entry.english
		]
	)


	for i: int in options.size():

		q.choices.append(
			str(
				options[i]["text"]
			)
		)

		q.choice_vocab_ids.append(
			str(
				options[i]["id"]
			)
		)


		if (
			str(
				options[i]["id"]
			)
			== entry.id
		):

			q.correct_index = i


	return q


# ============================================================
# FILL BLANK
# ============================================================

static func _build_fill_blank(
	entry: VocabEntry,
	pool: Array[VocabEntry]
) -> QuizQuestion:

	if (
		entry.fill_blank_variants.is_empty()
		or entry.parts.is_empty()
	):

		return null


	var variants: Array[Dictionary] = (
		entry.fill_blank_variants.duplicate()
	)

	variants.shuffle()


	for selected: Dictionary in variants:

		var prompt: String = str(
			selected.get(
				"prompt",
				""
			)
		)


		var answer_id: String = str(
			selected.get(
				"answer_id",
				""
			)
		)


		if (
			prompt.is_empty()
			or answer_id.is_empty()
		):

			continue


		if not entry.parts.has(
			answer_id
		):

			continue


		var answer_entry: VocabEntry = (
			LanguageProgress.get_entry(
				answer_id
			)
		)


		if answer_entry == null:
			continue


		# Answer part must also have been encountered.
		if not LanguageProgress.is_encountered(
			answer_id
		):

			continue


		var q := QuizQuestion.new()


		q.quiz_type = (
			QuizQuestion.QuizType.FILL_BLANK
		)

		q.prompt = prompt

		q.time_limit = (
			25.0
			+ float(
				maxi(
					entry.difficulty - 1,
					0
				)
			)
		)

		q.vocab_id = entry.id

		q.tested_vocab_ids = [
			entry.id
		]

		q.secondary_vocab_ids = [
			answer_id
		]

		q.hint = entry.hint


		q.pronunciation = (
			answer_entry.pronunciation
			if not answer_entry.pronunciation.is_empty()
			else entry.pronunciation
		)


		q.answer_line = (
			"%s = %s"
			% [
				entry.kapampangan,
				entry.english
			]
		)


		var options: Array[Dictionary] = [
			{
				"id": answer_entry.id,
				"text": answer_entry.kapampangan
			}
		]


		var used: Dictionary = {
			answer_entry.kapampangan.to_lower(): true
		}


		# Only encountered vocabulary.
		var distractors: Array[VocabEntry] = []


		for other: VocabEntry in pool:

			if other == entry:
				continue


			if other.category == "particle":
				continue


			distractors.append(
				other
			)


		distractors.shuffle()


		for other: VocabEntry in distractors:

			if options.size() >= MAX_CHOICES:
				break


			var text: String = (
				other.kapampangan
			)


			if text.is_empty():
				continue


			if used.has(
				text.to_lower()
			):

				continue


			used[text.to_lower()] = true


			options.append(
				{
					"id": other.id,
					"text": text
				}
			)


		options.shuffle()


		for i: int in options.size():

			q.choices.append(
				str(
					options[i]["text"]
				)
			)

			q.choice_vocab_ids.append(
				str(
					options[i]["id"]
				)
			)


			if (
				str(
					options[i]["id"]
				)
				== answer_id
			):

				q.correct_index = i


		return q


	return null


# ============================================================
# MATCH
# ============================================================

static func _build_match(
	focus: VocabEntry,
	pool: Array[VocabEntry]
) -> QuizQuestion:

	var candidates: Array[VocabEntry] = []


	# Focus MUST be included.
	candidates.append(
		focus
	)


	# Add only other encountered entries.
	var others: Array[VocabEntry] = []


	for entry: VocabEntry in pool:

		if entry == focus:
			continue


		if entry.category == "particle":
			continue


		if (
			entry.english.is_empty()
			or entry.kapampangan.is_empty()
		):

			continue


		others.append(
			entry
		)


	others.shuffle()


	while (
		candidates.size() < MAX_MATCH_PAIRS
		and not others.is_empty()
	):

		candidates.append(
			others.pop_back()
		)


	# --------------------------------------------------------
	# BUILD QUESTION
	# --------------------------------------------------------

	var q := QuizQuestion.new()


	q.quiz_type = (
		QuizQuestion.QuizType.MATCH
	)


	q.prompt = (
		"Connect each Kapampangan phrase "
		+ "to its English meaning."
	)


	q.time_limit = 30.0


	q.vocab_id = focus.id


	q.hint = (
		"Match each phrase to its correct meaning."
	)


	var right_entries: Array[VocabEntry] = (
		candidates.duplicate()
	)

	right_entries.shuffle()


	for entry: VocabEntry in candidates:

		q.match_left_ids.append(
			entry.id
		)

		q.match_left_texts.append(
			entry.kapampangan
		)

		q.tested_vocab_ids.append(
			entry.id
		)

		q.answer_line += (
			"\n"
			if not q.answer_line.is_empty()
			else ""
		)

		q.answer_line += (
			"%s = %s"
			% [
				entry.kapampangan,
				entry.english
			]
		)


	for entry: VocabEntry in right_entries:

		q.match_right_ids.append(
			entry.id
		)

		q.match_right_texts.append(
			entry.english
		)


	return q
