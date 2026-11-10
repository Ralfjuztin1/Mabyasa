extends RefCounted
class_name AssessmentComparison

## Baseline choices test recognition/translation; Guardian tests construction.
## Treat only first official answer per vocabulary ID as evidence.
## Never subtract percentages from different question formats.


static func build(pre_report: Dictionary, boss_report: Dictionary) -> Dictionary:
	var before_value: Variant = pre_report.get("assessment_items", [])
	var after_value: Variant = boss_report.get("rows", [])
	var before: Array = before_value if before_value is Array else []
	var after: Array = after_value if after_value is Array else []
	return _compare(before, after, false)


static func compare_attempts(previous_report: Dictionary, current_report: Dictionary) -> Dictionary:
	var before_value: Variant = previous_report.get("rows", [])
	var after_value: Variant = current_report.get("rows", [])
	var before: Array = before_value if before_value is Array else []
	var after: Array = after_value if after_value is Array else []
	return _compare(before, after, true)


static func _compare(before: Array, after: Array, same_format: bool) -> Dictionary:
	var before_by_id: Dictionary = _first_by_id(before)
	var after_by_id: Dictionary = _first_by_id(after)
	var matched: Array[Dictionary] = []
	var categories := {
		"improved": 0,
		"retained": 0,
		"needs_practice": 0,
		"recognition_gap": 0
	}
	var topic_counts: Dictionary = {}
	var before_correct: int = 0
	var after_correct: int = 0

	for raw_id: Variant in before_by_id.keys():
		var vocab_id: String = str(raw_id)
		if not after_by_id.has(vocab_id):
			continue
		var old_item: Dictionary = before_by_id[vocab_id]
		var new_item: Dictionary = after_by_id[vocab_id]
		var was_correct: bool = _is_correct(old_item)
		var now_correct: bool = _is_correct(new_item)
		if was_correct:
			before_correct += 1
		if now_correct:
			after_correct += 1

		var category: String = "needs_practice"
		if not was_correct and now_correct:
			category = "improved"
		elif was_correct and now_correct:
			category = "retained"
		elif was_correct and not now_correct:
			category = "recognition_gap"
		categories[category] = int(categories[category]) + 1

		var topic_key: String = str(old_item.get("topic_key", new_item.get("topic_key", "uncategorized")))
		var topic_name: String = str(old_item.get("topic_name", new_item.get("topic_name", topic_key)))
		if not topic_counts.has(topic_key):
			topic_counts[topic_key] = {
				"topic_name": topic_name,
				"count": 0,
				"improved": 0,
				"needs_practice": 0
			}
		var topic: Dictionary = topic_counts[topic_key]
		topic["count"] = int(topic["count"]) + 1
		if category == "improved":
			topic["improved"] = int(topic["improved"]) + 1
		if category == "needs_practice" or category == "recognition_gap":
			topic["needs_practice"] = int(topic["needs_practice"]) + 1
		topic_counts[topic_key] = topic

		matched.append({
			"vocab_id": vocab_id,
			"meaning": str(old_item.get("meaning", new_item.get("english_meaning", ""))),
			"topic_name": topic_name,
			"before_correct": was_correct,
			"after_correct": now_correct,
			"classification": category,
			"submitted_sentence": str(new_item.get("submitted_sentence", "")),
			"correct_sentence": str(new_item.get("correct_sentence", "")),
			"mistakes": new_item.get("mistakes", []),
			"timed_out": bool(new_item.get("timed_out", false))
		})

	var topics: Array[Dictionary] = []
	for raw: Variant in topic_counts.values():
		if topics.size() >= 3:
			break
		var bucket: Dictionary = raw
		topics.append({
			"topic_name": str(bucket["topic_name"]),
			"matched_count": int(bucket["count"]),
			"improved_count": int(bucket["improved"]),
			"needs_practice_count": int(bucket["needs_practice"])
		})

	var recommendations: Array[String] = []
	for item: Dictionary in matched:
		if recommendations.size() >= 3:
			break
		var classification: String = str(item["classification"])
		if classification != "needs_practice" and classification != "recognition_gap":
			continue
		var feedback: String = "Review the correct word order and practise aloud."
		var raw_mistakes: Variant = item.get("mistakes", [])
		if raw_mistakes is Array and not (raw_mistakes as Array).is_empty():
			feedback = str((raw_mistakes as Array)[0])
		recommendations.append("%s: %s" % [str(item["meaning"]), feedback])

	if recommendations.is_empty():
		recommendations.append("Keep practising the ten phrases by saying and arranging them without hints.")

	var insights: Array[String] = []
	if matched.is_empty():
		insights.append("No matching vocabulary IDs were answered in both assessments.")
	elif same_format:
		insights.append("%d shared phrases: %d correct previously, %d correct now (same sentence-building format)." % [matched.size(), before_correct, after_correct])
	else:
		insights.append("Across %d shared phrases: %d recognized/translated before gameplay; %d constructed correctly during the Guardian fight." % [matched.size(), before_correct, after_correct])
		insights.append("Different question formats measure different skills; these scores are not a percentage-point learning gain.")
	insights.append("%d corrected · %d successfully applied · %d still weak · %d recognition/construction gaps." % [
		int(categories["improved"]),
		int(categories["retained"]),
		int(categories["needs_practice"]),
		int(categories["recognition_gap"])
	])

	return {
		"comparison_type": "retry_to_retry" if same_format else "recognition_to_construction",
		"matched_count": matched.size(),
		"pre_correct": before_correct,
		"post_correct": after_correct,
		"pre_accuracy": float(before_correct) * 100.0 / float(maxi(matched.size(), 1)),
		"post_accuracy": float(after_correct) * 100.0 / float(maxi(matched.size(), 1)),
		"newly_learned": 0, # Do not claim causation from these assessments.
		"improved": int(categories["improved"]),
		"retained": int(categories["retained"]),
		"needs_practice": int(categories["needs_practice"]),
		"recognition_gap": int(categories["recognition_gap"]),
		"inconsistent": int(categories["recognition_gap"]),
		"topics": topics,
		"insights": insights,
		"recommendations": recommendations,
		"matched_items": matched
	}


static func _first_by_id(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw: Variant in items:
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		var vocab_id: String = str(item.get("vocab_id", ""))
		if vocab_id.is_empty() or result.has(vocab_id):
			continue
		result[vocab_id] = item
	return result


static func _is_correct(item: Dictionary) -> bool:
	if item.has("correct"):
		return bool(item["correct"])
	if item.has("score"):
		return float(item["score"]) >= 0.999
	return float(item.get("score_percent", 0.0)) >= 99.9
