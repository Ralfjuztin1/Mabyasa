extends RefCounted

## Compare the SAME cardinal-number targets across the initial (blind)
## multiple-choice assessment and the Number Guardian's first attempts.
## Question formats differ, so do not describe score changes as proven learning.
const NUMBER_IDS: Array[String] = [
	"metung", "adwa", "atlo_or_atlu", "apat", "lima", "anam",
	"pito_or_pitu", "walo_or_walu", "siyam", "apulo_or_apulu"
]


static func build(pre_report: Dictionary, boss_report: Dictionary) -> Dictionary:
	var pre_items_raw: Variant = pre_report.get("assessment_items", [])
	var post_items_raw: Variant = boss_report.get("question_results", boss_report.get("rows", []))
	var pre_items: Array = pre_items_raw if pre_items_raw is Array else []
	var post_items: Array = post_items_raw if post_items_raw is Array else []
	var before: Dictionary = {}
	var after: Dictionary = {}
	for value: Variant in pre_items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var id: String = str(item.get("vocab_id", ""))
		if NUMBER_IDS.has(id) and not before.has(id):
			before[id] = bool(item.get("correct", false))
	for value: Variant in post_items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var id: String = str(item.get("vocab_id", ""))
		if NUMBER_IDS.has(id) and not after.has(id):
			after[id] = bool(item.get("correct", false))

	var matched: int = 0
	var pre_correct: int = 0
	var boss_correct: int = 0
	var improved: int = 0
	var needs_practice: int = 0
	var matched_rows: Array[Dictionary] = []
	for id: String in NUMBER_IDS:
		if not before.has(id) or not after.has(id):
			continue
		matched += 1
		var was_correct: bool = bool(before[id])
		var now_correct: bool = bool(after[id])
		pre_correct += 1 if was_correct else 0
		boss_correct += 1 if now_correct else 0
		if not was_correct and now_correct:
			improved += 1
		if not now_correct:
			needs_practice += 1
		matched_rows.append({
			"vocab_id": id,
			"pre_correct": was_correct,
			"boss_correct": now_correct
		})
	var insights: Array[String] = []
	if matched == 0:
		insights.append("No matched number responses are available from the initial assessment.")
	else:
		insights.append("%d shared number words: %d correct at baseline, %d correct in the boss fight." % [matched, pre_correct, boss_correct])
		insights.append("Baseline recognition and boss reasoning use different question formats; this is a descriptive comparison, not a measured percentage-point learning gain.")
	return {
		"assessment_group": "cardinal_numbers",
		"matched_count": matched,
		"pre_correct": pre_correct,
		"post_correct": boss_correct,
		"improved": improved,
		"needs_practice": needs_practice,
		"pre_accuracy": float(pre_correct) / float(maxi(matched, 1)) * 100.0,
		"post_accuracy": float(boss_correct) / float(maxi(matched, 1)) * 100.0,
		"matched_results": matched_rows,
		"insights": insights,
		"comparison_is_descriptive_only": true
	}
