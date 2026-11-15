extends RefCounted

## Ten blind baseline questions, one for each number learned in Second Town.
## These run BEFORE any lesson; do not show correctness or solutions to the player.
## Canonical IDs match the Number Guardian's assessment rows.
const NUMBER_IDS: Array[String] = [
	"metung", "adwa", "atlo_or_atlu", "apat", "lima", "anam",
	"pito_or_pitu", "walo_or_walu", "siyam", "apulo_or_apulu"
]

const NUMBER_WORDS: Array[String] = [
	"Metung", "Adwa", "Atlu", "Apat", "Lima", "Anam",
	"Pitu", "Walo", "Siyam", "Apulu"
]

# Each prompt targets a unique number. Correct answer is always the first
# option before shuffling. A prompt never depends on vocabulary not assessed.
const SPECS: Array[Dictionary] = [
	{"n": 1, "prompt": "Which Kapampangan word means ONE?", "word": true,
	 "options": [1, 2, 3, 4]},
	{"n": 2, "prompt": "ADWA means which number?", "word": false,
	 "options": [2, 1, 3, 4]},
	{"n": 3, "prompt": "Which Kapampangan word means THREE?", "word": true,
	 "options": [3, 2, 4, 5]},
	{"n": 4, "prompt": "APAT means which number?", "word": false,
	 "options": [4, 3, 5, 6]},
	{"n": 5, "prompt": "There are 5 crops. Which Kapampangan word matches?", "word": true,
	 "options": [5, 4, 6, 7]},
	{"n": 6, "prompt": "ANAM means which number?", "word": false,
	 "options": [6, 5, 7, 8]},
	{"n": 7, "prompt": "Which Kapampangan word means SEVEN?", "word": true,
	 "options": [7, 6, 8, 9]},
	{"n": 8, "prompt": "WALO means which number?", "word": false,
	 "options": [8, 7, 9, 10]},
	{"n": 9, "prompt": "Which Kapampangan word means NINE?", "word": true,
	 "options": [9, 8, 10, 7]},
	{"n": 10, "prompt": "APULU means which number?", "word": false,
	 "options": [10, 9, 8, 7]}
]


static func build_questions() -> Array[Dictionary]:
	var questions: Array[Dictionary] = []
	for spec: Dictionary in SPECS:
		var target_number: int = int(spec["n"])
		var target_id: String = NUMBER_IDS[target_number - 1]
		if LanguageProgress.get_entry(target_id) == null:
			push_error("[PRE-ASSESSMENT] Missing number vocabulary: " + target_id)
			return []
		var q := QuizQuestion.new()
		q.quiz_type = QuizQuestion.QuizType.TRANSLATE if bool(spec["word"]) else QuizQuestion.QuizType.MULTIPLE_CHOICE
		q.prompt = str(spec["prompt"])
		q.vocab_id = target_id
		q.tested_vocab_ids = [target_id]
		q.time_limit = 35.0
		q.hint = ""
		q.pronunciation = ""
		q.answer_line = "" # The baseline MUST NOT reveal the answer key.
		var numbers: Array[int] = []
		for raw_number: Variant in spec["options"]:
			var option_number: int = int(raw_number)
			if option_number < 1 or option_number > 10:
				return []
			if not numbers.has(option_number):
				numbers.append(option_number)
		if numbers.size() != 4 or not numbers.has(target_number):
			push_error("[PRE-ASSESSMENT] Invalid choices for number %d." % target_number)
			return []
		numbers.shuffle()
		for option_number: int in numbers:
			q.choices.append(NUMBER_WORDS[option_number - 1] if bool(spec["word"]) else str(option_number))
			q.choice_vocab_ids.append(NUMBER_IDS[option_number - 1])
			if option_number == target_number:
				q.correct_index = q.choices.size() - 1
		questions.append({
			"question": q,
			"topic_key": "cardinal_numbers",
			"topic_name": "Cardinal Numbers"
		})
	return questions


static func blind_email_question_rows(responses: Array[Dictionary]) -> Array[Dictionary]:
	# Researcher can see actual prompts and player answers, but no answer key.
	var rows: Array[Dictionary] = []
	for response: Dictionary in responses:
		rows.append({
			"topic_name": str(response.get("topic_name", "")),
			"vocab_id": str(response.get("vocab_id", "")),
			"prompt": str(response.get("prompt", "")),
			"player_answer": str(response.get("player_answer", "")),
			"correct": bool(response.get("correct", false)),
			"timed_out": bool(response.get("timed_out", false)),
			"elapsed_seconds": float(response.get("elapsed_seconds", 0.0))
		})
	return rows


static func get_number_ids() -> Array[String]:
	var output: Array[String] = []
	output.append_array(NUMBER_IDS)
	return output
