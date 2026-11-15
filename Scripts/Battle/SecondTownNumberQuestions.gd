extends RefCounted

## Second Town only: Merchant 1-3, Farmer 4-6, Elder 7-10.
## The first ten prompts test every number exactly once, without visible counts.
## Later prompts are variations if the fight lasts longer.
const CORE_COVERAGE_COUNT: int = 10
const TRIALS: Array[Dictionary] = [
	{
		"id": "well_eight_stones", "lesson": "ELDER", "phase": "RECOGNITION",
		"target_number": 8, "vocab": "walo_or_walu",
		"prompt": "Count the stones:\n● ● ● ●\n● ● ● ●\nWhich Kapampangan word matches?",
		"answer": "Walo", "options": ["Walo", "Pitu", "Siyam"],
		"ids": ["walo_or_walu", "pito_or_pitu", "siyam"],
		"tip": "Eight is WALO. Count the stones once."
	},
	{
		"id": "merchant_one_basket", "lesson": "MERCHANT", "phase": "RECOGNITION",
		"target_number": 1, "vocab": "metung",
		"prompt": "Only 1 basket is on the table.\nWhich Kapampangan word means ONE?",
		"answer": "Metung", "options": ["Metung", "Adwa", "Atlu"],
		"ids": ["metung", "adwa", "atlo_or_atlu"],
		"tip": "METUNG means one."
	},
	{
		"id": "farmer_four_five", "lesson": "FARMER", "phase": "REASONING",
		"target_number": 9, "vocab": "siyam",
		"prompt": "4 crops + 5 crops = ?\nChoose the Kapampangan result.",
		"answer": "Siyam", "options": ["Walo", "Siyam", "Apulu"],
		"ids": ["walo_or_walu", "siyam", "apulo_or_apulu"],
		"tip": "4 + 5 = 9, or SIYAM."
	},
	{
		"id": "merchant_adwa", "lesson": "MERCHANT", "phase": "RECOGNITION",
		"target_number": 2, "vocab": "adwa",
		"prompt": "ADWA\nHow many baskets is that?",
		"answer": "2", "options": ["1", "2", "3"],
		"ids": ["metung", "adwa", "atlo_or_atlu"],
		"tip": "ADWA means two."
	},
	{
		"id": "farmer_ten_four", "lesson": "FARMER", "phase": "REASONING",
		"target_number": 6, "vocab": "anam",
		"prompt": "10 supplies - 4 supplies = ?\nChoose the Kapampangan result.",
		"answer": "Anam", "options": ["Lima", "Anam", "Pitu"],
		"ids": ["lima", "anam", "pito_or_pitu"],
		"tip": "10 - 4 = 6, or ANAM."
	},
	{
		"id": "well_pitu", "lesson": "ELDER", "phase": "RECOGNITION",
		"target_number": 7, "vocab": "pito_or_pitu",
		"prompt": "PITU\nHow many stones should be lit?",
		"answer": "7", "options": ["6", "7", "8"],
		"ids": ["anam", "pito_or_pitu", "walo_or_walu"],
		"tip": "PITU means seven."
	},
	{
		"id": "merchant_one_two", "lesson": "MERCHANT", "phase": "REASONING",
		"target_number": 3, "vocab": "atlo_or_atlu",
		"prompt": "METUNG + ADWA = ?\nChoose the Kapampangan result.",
		"answer": "Atlu", "options": ["Atlu", "Apat", "Adwa"],
		"ids": ["atlo_or_atlu", "apat", "adwa"],
		"tip": "METUNG (1) + ADWA (2) = ATLU (3)."
	},
	{
		"id": "farmer_four_crops", "lesson": "FARMER", "phase": "RECOGNITION",
		"target_number": 4, "vocab": "apat",
		"prompt": "There are 4 planted rows.\nWhich Kapampangan word means FOUR?",
		"answer": "Apat", "options": ["Atlu", "Apat", "Lima"],
		"ids": ["atlo_or_atlu", "apat", "lima"],
		"tip": "APAT means four."
	},
	{
		"id": "farmer_apat_metung", "lesson": "FARMER", "phase": "RECALL",
		"target_number": 5, "vocab": "lima",
		"prompt": "APAT + METUNG = ?\nChoose the Kapampangan result.",
		"answer": "Lima", "options": ["Apat", "Lima", "Anam"],
		"ids": ["apat", "lima", "anam"],
		"tip": "APAT (4) + METUNG (1) = LIMA (5)."
	},
	{
		"id": "well_seven_three", "lesson": "ELDER", "phase": "RECALL",
		"target_number": 10, "vocab": "apulo_or_apulu",
		"prompt": "PITU + ATLU = ?\nChoose the Kapampangan result.",
		"answer": "Apulu", "options": ["Siyam", "Apulu", "Walo"],
		"ids": ["siyam", "apulo_or_apulu", "walo_or_walu"],
		"tip": "PITU (7) + ATLU (3) = APULU (10)."
	},
	{
		"id": "mixed_three_five", "lesson": "MIXED", "phase": "RECALL",
		"target_number": 8, "vocab": "walo_or_walu",
		"prompt": "ATLU + LIMA = ?\nChoose the Kapampangan result.",
		"answer": "Walo", "options": ["Pitu", "Walo", "Siyam"],
		"ids": ["pito_or_pitu", "walo_or_walu", "siyam"],
		"tip": "ATLU (3) + LIMA (5) = WALO (8)."
	},
	{
		"id": "mixed_ten_one", "lesson": "MIXED", "phase": "RECALL",
		"target_number": 9, "vocab": "siyam",
		"prompt": "APULU - METUNG = ?\nChoose the Kapampangan result.",
		"answer": "Siyam", "options": ["Siyam", "Walo", "Anam"],
		"ids": ["siyam", "walo_or_walu", "anam"],
		"tip": "APULU (10) - METUNG (1) = SIYAM (9)."
	},
	{
		"id": "merchant_three_baskets", "lesson": "MERCHANT", "phase": "RECOGNITION",
		"target_number": 3, "vocab": "atlo_or_atlu",
		"prompt": "The merchant has 3 baskets.\nWhich Kapampangan word matches?",
		"answer": "Atlu", "options": ["Atlu", "Adwa", "Apat"],
		"ids": ["atlo_or_atlu", "adwa", "apat"],
		"tip": "ATLU means three."
	},
	{
		"id": "farmer_six_seeds", "lesson": "FARMER", "phase": "RECOGNITION",
		"target_number": 6, "vocab": "anam",
		"prompt": "Count the seeds:\n● ● ●\n● ● ●\nWhich Kapampangan word matches?",
		"answer": "Anam", "options": ["Lima", "Anam", "Pitu"],
		"ids": ["lima", "anam", "pito_or_pitu"],
		"tip": "ANAM means six."
	},
	{
		"id": "mixed_five_four", "lesson": "MIXED", "phase": "REASONING",
		"target_number": 1, "vocab": "metung",
		"prompt": "5 - 4 = ?\nChoose the Kapampangan result.",
		"answer": "Metung", "options": ["Metung", "Adwa", "Atlu"],
		"ids": ["metung", "adwa", "atlo_or_atlu"],
		"tip": "5 - 4 = 1, or METUNG."
	},
	{
		"id": "mixed_three_four", "lesson": "MIXED", "phase": "REASONING",
		"target_number": 7, "vocab": "pito_or_pitu",
		"prompt": "3 + 4 = ?\nChoose the Kapampangan result.",
		"answer": "Pitu", "options": ["Anam", "Pitu", "Walo"],
		"ids": ["anam", "pito_or_pitu", "walo_or_walu"],
		"tip": "3 + 4 = 7, or PITU."
	},
	{
		"id": "mixed_nine_seven", "lesson": "MIXED", "phase": "REASONING",
		"target_number": 2, "vocab": "adwa",
		"prompt": "9 - 7 = ?\nChoose the Kapampangan result.",
		"answer": "Adwa", "options": ["Metung", "Adwa", "Atlu"],
		"ids": ["metung", "adwa", "atlo_or_atlu"],
		"tip": "9 - 7 = 2, or ADWA."
	},
	{
		"id": "mixed_five_five", "lesson": "MIXED", "phase": "RECALL",
		"target_number": 10, "vocab": "apulo_or_apulu",
		"prompt": "LIMA + LIMA = ?\nChoose the Kapampangan result.",
		"answer": "Apulu", "options": ["Siyam", "Apulu", "Walo"],
		"ids": ["siyam", "apulo_or_apulu", "walo_or_walu"],
		"tip": "LIMA (5) + LIMA (5) = APULU (10)."
	},
	{
		"id": "mixed_two_two", "lesson": "MIXED", "phase": "REASONING",
		"target_number": 4, "vocab": "apat",
		"prompt": "2 + 2 = ?\nChoose the Kapampangan result.",
		"answer": "Apat", "options": ["Atlu", "Apat", "Lima"],
		"ids": ["atlo_or_atlu", "apat", "lima"],
		"tip": "2 + 2 = 4, or APAT."
	},
	{
		"id": "mixed_one_four", "lesson": "MIXED", "phase": "RECALL",
		"target_number": 5, "vocab": "lima",
		"prompt": "METUNG + APAT = ?\nChoose the Kapampangan result.",
		"answer": "Lima", "options": ["Apat", "Lima", "Anam"],
		"ids": ["apat", "lima", "anam"],
		"tip": "METUNG (1) + APAT (4) = LIMA (5)."
	}
]

static func get_trial(sequence_index: int) -> Dictionary:
	return TRIALS[posmod(sequence_index, TRIALS.size())].duplicate(true)

static func make_question(sequence_index: int) -> QuizQuestion:
	var trial: Dictionary = get_trial(sequence_index)
	var q := QuizQuestion.new()
	q.quiz_type = QuizQuestion.QuizType.MULTIPLE_CHOICE
	# No phase/question counter is shown on the combat screen.
	q.prompt = str(trial["prompt"])
	q.vocab_id = str(trial["vocab"])
	q.tested_vocab_ids = [q.vocab_id]
	q.answer_line = str(trial["tip"])
	q.time_limit = 35.0
	q.hint = ""

	var options: Array = trial["options"]
	var ids: Array = trial["ids"]
	var order: Array[int] = []
	for i: int in range(options.size()):
		order.append(i)
	order.shuffle()
	for idx: int in order:
		q.choices.append(str(options[idx]))
		q.choice_vocab_ids.append(str(ids[idx]))
		if str(options[idx]) == str(trial["answer"]):
			q.correct_index = q.choices.size() - 1
	return q
