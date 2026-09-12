extends Node

var active_quests: Dictionary = {}
var completed_quests: Array = []

# The static rules for every quest in the game
var quest_database: Dictionary = {
	
	"the_lost_artifact": {
		"title": "The Lost Artifact",
		"rewards": {"exp": 500, "gold": 250},
		"steps": [
			{ "type": "talk_npc", "target": "scholar_fane" },
			{ "type": "wait_time", "target": "night" },
			{ "type": "reach_location", "target": "ruins_entrance" }
		]
	},
	
	"talk_to_bebang": {
		"title": "Talk to Bebang",
		"rewards": {"exp": 100, "gold": 50},
		"steps": [
			{ "type": "talk_npc", "target": "bebang" }
		]
	}
}


func _ready() -> void:
	# Listen to all game events
	GameEvents.location_reached.connect(_on_event.bind("reach_location"))
	GameEvents.npc_talked.connect(_on_event.bind("talk_npc"))
	GameEvents.time_updated.connect(_on_event.bind("wait_time"))
	GameEvents.puzzle_solved.connect(_on_event.bind("solve_puzzle"))


func start_quest(quest_id: String) -> void:
	if not quest_database.has(quest_id):
		print("❌ [QUEST] Quest does not exist: ", quest_id)
		return

	if completed_quests.has(quest_id):
		print("⚠️ [QUEST] Quest already completed: ", quest_id)
		return

	if active_quests.has(quest_id):
		print("⚠️ [QUEST] Quest already active: ", quest_id)
		return

	active_quests[quest_id] = {
		"current_step": 0
	}

	print("📜 [QUEST STARTED] ", quest_database[quest_id]["title"])
	print("   Quest ID: ", quest_id)


func _on_event(target_id: String, event_type: String) -> void:
	for q_id in active_quests.keys():
		var q_data = quest_database[q_id]
		var step_idx = active_quests[q_id]["current_step"]

		if step_idx < q_data["steps"].size():
			var current_objective = q_data["steps"][step_idx]

			if current_objective["type"] == event_type \
			and current_objective["target"] == target_id:
				print(
					"✅ [QUEST OBJECTIVE COMPLETE] ",
					q_data["title"],
					" → ",
					event_type,
					": ",
					target_id
				)

				_advance_quest(q_id)


func _advance_quest(quest_id: String) -> void:
	active_quests[quest_id]["current_step"] += 1

	var q_data = quest_database[quest_id]
	var new_step = active_quests[quest_id]["current_step"]

	if new_step >= q_data["steps"].size():
		_complete_quest(quest_id)
	else:
		print(
			"📜 [QUEST ADVANCED] ",
			q_data["title"],
			" → Step ",
			new_step + 1,
			" of ",
			q_data["steps"].size()
		)


func _complete_quest(quest_id: String) -> void:
	var q_data = quest_database[quest_id]

	print("")
	print("========================================")
	print("✨ [QUEST COMPLETED] ", q_data["title"])
	print("========================================")

	# Grant EXP
	if q_data["rewards"].has("exp"):
		var exp_reward: int = q_data["rewards"]["exp"]
		PlayerProgression.add_exp(exp_reward)

		print("   ⭐ EXP REWARD: +", exp_reward)

	# Grant Gold
	if q_data["rewards"].has("gold"):
		var gold_reward: int = q_data["rewards"]["gold"]
		PlayerProgression.gold += gold_reward

		print("   🪙 GOLD REWARD: +", gold_reward)

	print("========================================")
	print("✨ [QUEST] Rewards granted successfully.")
	print("")


	completed_quests.append(quest_id)
	active_quests.erase(quest_id)


# --- JSON SAVE INTEGRATION ---

func get_save_data() -> Dictionary:
	return {
		"active_quests": active_quests,
		"completed_quests": completed_quests
	}


func load_save_data(data: Dictionary) -> void:
	if not data.is_empty():
		active_quests = data.get("active_quests", {})
		completed_quests = data.get("completed_quests", [])

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)
