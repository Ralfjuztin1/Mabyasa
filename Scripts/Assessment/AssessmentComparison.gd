extends RefCounted
class_name AssessmentComparison

## Compares the same vocabulary IDs across the baseline and a boss attempt.
## Only the first response for each vocabulary ID in a given attempt is used.

static func build(pre_report: Dictionary, boss_report: Dictionary) -> Dictionary:
	var pre_items: Array = pre_report.get("assessment_items", [])
	var post_rows: Array = boss_report.get("rows", [])
	return _compare_item_sets(pre_items, post_rows, "baseline_to_post")


static func compare_attempts(previous_report: Dictionary, current_report: Dictionary) -> Dictionary:
	var previous_rows: Array = previous_report.get("rows", [])
	var current_rows: Array = current_report.get("rows", [])
	return _compare_item_sets(previous_rows, current_rows, "retry_to_retry")


static func _compare_item_sets(before_items: Array, after_items: Array, comparison_type: String) -> Dictionary:
	var before_by_id: Dictionary = _first_item_by_id(before_items, false)
	var after_by_id: Dictionary = _first_item_by_id(after_items, true)

	var matched: Array[Dictionary] = []
	var counts := {
		"newly_learned": 0,
		"improved": 0,
		"retained": 0,
		"needs_practice": 0,
		"inconsistent": 0
	}
	var topics: Dictionary = {}

	for raw_id: Variant in before_by_id.keys():
		var vocab_id := str(raw_id)
		if not after_by_id.has(vocab_id):
			continue

		var before: Dictionary = before_by_id[vocab_id]
		var after: Dictionary = after_by_id[vocab_id]
		var before_score := _score(before, false)
		var after_score := _score(after, true)
		var classification := _classify(before_score, after_score)

		counts[classification] = int(counts.get(classification, 0)) + 1

		var topic_key := str(before.get("topic_key", after.get("topic_key", "uncategorized")))
		var topic_name := str(before.get("topic_name", after.get("topic_name", topic_key)))
		if not topics.has(topic_key):
			topics[topic_key] = {
				"topic_key": topic_key,
				"topic_name": topic_name,
				"before_total": 0.0,
				"after_total": 0.0,
				"count": 0,
				"improved": 0,
				"needs_practice": 0
			}

		var topic: Dictionary = topics[topic_key]
		topic["before_total"] = float(topic["before_total"]) + before_score
		topic["after_total"] = float(topic["after_total"]) + after_score
		topic["count"] = int(topic["count"]) + 1
		if classification == "newly_learned" or classification == "improved":
			topic["improved"] = int(topic["improved"]) + 1
		if classification == "needs_practice" or classification == "inconsistent":
			topic["needs_practice"] = int(topic["needs_practice"]) + 1
		topics[topic_key] = topic

		matched.append({
			"vocab_id": vocab_id,
			"meaning": str(before.get("meaning", after.get("english_meaning", ""))),
			"topic_key": topic_key,
			"topic_name": topic_name,
			"before_score": before_score,
			"after_score": after_score,
			"classification": classification
		})

	var before_average := 0.0
	var after_average := 0.0
	if not matched.is_empty():
		for item: Dictionary in matched:
			before_average += float(item["before_score"])
			after_average += float(item["after_score"])
		before_average /= float(matched.size())
		after_average /= float(matched.size())

	var topic_summaries: Array[Dictionary] = []
	for raw_topic: Variant in topics.values():
		var topic: Dictionary = raw_topic
		var count := maxi(int(topic["count"]), 1)
		topic_summaries.append({
			"topic_key": topic["topic_key"],
			"topic_name": topic["topic_name"],
			"before_accuracy": float(topic["before_total"]) / float(count) * 100.0,
			"after_accuracy": float(topic["after_total"]) / float(count) * 100.0,
			"matched_count": int(topic["count"]),
			"improved_count": int(topic["improved"]),
			"needs_practice_count": int(topic["needs_practice"])
		})
	topic_summaries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["after_accuracy"]) - float(a["before_accuracy"]) < float(b["after_accuracy"]) - float(b["before_accuracy"])
	)

	var change := (after_average - before_average) * 100.0
	var insights := _make_insights(
		matched,
		counts,
		before_average * 100.0,
		after_average * 100.0,
		change
	)

	return {
		"comparison_type": comparison_type,
		"matched_count": matched.size(),
		"pre_accuracy": before_average * 100.0,
		"post_accuracy": after_average * 100.0,
		"change_points": change,
		"newly_learned": counts["newly_learned"],
		"improved": counts["improved"],
		"retained": counts["retained"],
		"needs_practice": counts["needs_practice"],
		"inconsistent": counts["inconsistent"],
		"topics": topic_summaries,
		"insights": insights,
		"matched_items": matched
	}


static func _first_item_by_id(items: Array, is_post: bool) -> Dictionary:
	var result: Dictionary = {}
	for raw_item: Variant in items:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item
		var vocab_id := str(item.get("vocab_id", ""))
		if vocab_id.is_empty() or result.has(vocab_id):
			continue
		result[vocab_id] = item
	return result


static func _score(item: Dictionary, is_post: bool) -> float:
	if is_post and item.has("score_percent"):
		return clampf(float(item.get("score_percent", 0.0)) / 100.0, 0.0, 1.0)
	return clampf(float(item.get("score", item.get("accuracy_percent", 0.0) / 100.0)), 0.0, 1.0)


static func _classify(before_score: float, after_score: float) -> String:
	if before_score < 0.75 and after_score >= 0.95:
		return "newly_learned"
	if after_score > before_score + 0.05:
		return "improved"
	if before_score >= 0.75 and after_score >= 0.75:
		return "retained"
	if after_score < before_score - 0.05 and before_score >= 0.75:
		return "inconsistent"
	return "needs_practice"


static func _make_insights(
	matched: Array[Dictionary],
	counts: Dictionary,
	before_accuracy: float,
	after_accuracy: float,
	change_points: float
) -> Array[String]:
	var insights: Array[String] = []

	if matched.is_empty():
		insights.append(
			"No matching phrase results were available in both tests. "
			+ "The comparison is therefore not sufficient to judge learning change."
		)
		return insights

	var direction := "increased" if change_points > 0.5 else "decreased" if change_points < -0.5 else "remained almost unchanged"

	insights.append(
		"Across %d matched phrases, accuracy %s from %.1f%% to %.1f%%."
		% [matched.size(), direction, before_accuracy, after_accuracy]
	)

	if int(counts["newly_learned"]) > 0:
		insights.append(
			"%d phrase(s) changed from an incorrect or incomplete baseline answer "
			+ "to a fully correct boss answer."
			% int(counts["newly_learned"])
		)
	if int(counts["improved"]) > 0:
		insights.append(
			"%d phrase(s) showed a higher score after gameplay, although some "
			+ "may still need practice."
			% int(counts["improved"])
		)
	if int(counts["retained"]) > 0:
		insights.append(
			"%d phrase(s) were answered correctly in both tests, showing that "
			+ "the initial knowledge was retained."
			% int(counts["retained"])
		)
	if int(counts["needs_practice"]) > 0:
		insights.append(
			"%d phrase(s) remained below the correct-answer threshold in the "
			+ "post-test and should be reviewed."
			% int(counts["needs_practice"])
		)
	if int(counts["inconsistent"]) > 0:
		insights.append(
			"%d phrase(s) were correct in the baseline but not in the boss test. "
			+ "This may indicate inconsistent recall under battle pressure."
			% int(counts["inconsistent"])
		)

	return insights
