extends Node


# ============================================================
# SIGNALS
# ============================================================

signal quest_started(quest_id: String, quest_data: QuestData)

signal quest_objective_updated(
	quest_id: String,
	step_index: int,
	step: QuestStep
)

signal quest_completed(
	quest_id: String,
	quest_data: QuestData
)

signal quest_validation_failed(
	quest_id: String,
	quest_data: QuestData,
	step: QuestStep
)

signal dialogue_flag_changed(flag_id: String)


# ============================================================
# CONSTANTS
# ============================================================

const QUESTS_PATH: String = "res://Data/Quests/"


# ============================================================
# RUNTIME QUEST STATE
# ============================================================

# Each active quest uses:
#
# {
#     "current_step": 0,
#     "current_count": 0,
#     "validation_state": "none",
#     "objectives": [
#         {
#             "count": 0,
#             "completed": false,
#             "validation_state": "none"
#         }
#     ]
# }
#
# current_step/current_count/validation_state remain for
# compatibility with existing dialogue code.

var active_quests: Dictionary = {}
var completed_quests: Array[String] = []
var dialogue_flags: Dictionary = {}


# ============================================================
# QUEST DATABASE
# ============================================================

var quest_database: Dictionary = {}


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_load_quest_database()

	GameEvents.location_reached.connect(
		_on_event.bind("reach_location")
	)

	GameEvents.npc_talked.connect(
		_on_event.bind("talk_npc")
	)

	GameEvents.time_updated.connect(
		_on_event.bind("wait_time")
	)

	GameEvents.puzzle_solved.connect(
		_on_event.bind("solve_puzzle")
	)

	GameEvents.enemy_killed.connect(
		_on_event.bind("enemy_killed")
	)

	GameEvents.item_collected.connect(
		_on_event.bind("item_collected")
	)

	GameEvents.object_interacted.connect(
		_on_event.bind("interact_object")
	)

	print(
		"📚 [QUEST] Loaded ",
		quest_database.size(),
		" quest(s)."
	)


# ============================================================
# LOAD QUEST DATA
# ============================================================

func _load_quest_database() -> void:
	quest_database.clear()

	var files: PackedStringArray = ResourceLoader.list_directory(
		QUESTS_PATH
	)

	print("🔎 [QUEST] Scanning: ", QUESTS_PATH)
	print("🔎 [QUEST] Found entries: ", files.size())

	for file_name in files:
		# ResourceLoader.list_directory() can also return directories.
		if file_name.ends_with("/"):
			continue

		if not file_name.to_lower().ends_with(".tres"):
			continue

		var file_path: String = QUESTS_PATH + file_name

		print("🔄 [QUEST] Loading: ", file_path)

		var quest_resource: Resource = ResourceLoader.load(
			file_path
		)

		if quest_resource == null:
			push_warning(
				"[QUEST] Failed to load quest: "
				+ file_path
			)
			continue

		if not quest_resource is QuestData:
			push_warning(
				"[QUEST] File is not a QuestData resource: "
				+ file_path
			)
			continue

		var quest_data: QuestData = quest_resource as QuestData

		if quest_data.quest_id.is_empty():
			push_warning(
				"[QUEST] Quest has no quest_id: "
				+ file_path
			)
			continue

		if quest_database.has(quest_data.quest_id):
			push_warning(
				"[QUEST] Duplicate quest ID: "
				+ quest_data.quest_id
			)
			continue

		quest_database[quest_data.quest_id] = quest_data

		print(
			"   📜 [QUEST LOADED] ",
			quest_data.quest_id,
			" → ",
			quest_data.title
		)

	print(
		"📚 [QUEST] Loaded ",
		quest_database.size(),
		" quest(s)."
	)


# ============================================================
# GET QUEST
# ============================================================

func get_quest(quest_id: String) -> QuestData:
	var quest_data = quest_database.get(quest_id)

	if quest_data is QuestData:
		return quest_data

	return null


# ============================================================
# START QUEST
# ============================================================

func start_quest(quest_id: String) -> void:
	var quest_data := get_quest(quest_id)

	if quest_data == null:
		print(
			"❌ [QUEST] Quest does not exist: ",
			quest_id
		)
		return

	if completed_quests.has(quest_id):
		print(
			"⚠️ [QUEST] Quest already completed: ",
			quest_id
		)
		return

	if active_quests.has(quest_id):
		print(
			"⚠️ [QUEST] Quest already active: ",
			quest_id
		)
		return

	if quest_data.steps.is_empty():
		push_warning(
			"[QUEST] Cannot start quest with no objectives: "
			+ quest_id
		)
		return

	var objective_states: Array = []

	for _step in quest_data.steps:
		objective_states.append({
			"count": 0,
			"completed": false,
			"validation_state": "none"
		})

	active_quests[quest_id] = {
		"current_step": 0,
		"current_count": 0,
		"validation_state": "none",
		"objectives": objective_states
	}

	print("")
	print("📜 [QUEST STARTED] ", quest_data.title)
	print("   Quest ID: ", quest_id)
	print("   Objectives: ", quest_data.steps.size())

	quest_started.emit(
		quest_id,
		quest_data
	)

	_emit_current_objective(quest_id)


# ============================================================
# NPC INTERACTION BEFORE DIALOGUE
# ============================================================

func handle_npc_interaction(npc_id: String) -> void:
	var active_ids: Array = active_quests.keys()

	for quest_id in active_ids:
		if not active_quests.has(quest_id):
			continue

		var quest_data := get_quest(quest_id)

		if quest_data == null:
			continue

		var objective_count: int = quest_data.steps.size()

		var objective_states: Array = active_quests[quest_id].get(
			"objectives",
			[]
		)

		for step_index in range(objective_count):
			if not active_quests.has(quest_id):
				break

			if step_index >= objective_states.size():
				break

			if bool(
				objective_states[step_index].get(
					"completed",
					false
				)
			):
				continue

			var current_step: QuestStep = quest_data.steps[step_index]

			if current_step.validation_type != "talk_npc":
				continue

			if current_step.validation_target != npc_id:
				continue

			print(
				"🔍 [QUEST PRE-DIALOGUE VALIDATION] ",
				quest_data.title,
				" → objective ",
				step_index,
				" → talk_npc: ",
				npc_id
			)

			_validate_counted_objective(
				quest_id,
				quest_data,
				step_index
			)

			objective_states = active_quests.get(
				quest_id,
				{}
			).get(
				"objectives",
				[]
			)


# ============================================================
# GAME EVENT HANDLER
# ============================================================

func _on_event(
	target_id: String,
	event_type: String
) -> void:
	print(
		"🔔 [QUEST EVENT] type=",
		event_type,
		" target=",
		target_id
	)

	var active_ids: Array = active_quests.keys()

	for quest_id in active_ids:
		if not active_quests.has(quest_id):
			continue

		var quest_data := get_quest(quest_id)

		if quest_data == null:
			continue

		var objective_states: Array = active_quests[quest_id].get(
			"objectives",
			[]
		)

		for step_index in range(
			quest_data.steps.size()
		):
			if not active_quests.has(quest_id):
				break

			objective_states = active_quests[quest_id].get(
				"objectives",
				[]
			)

			if step_index >= objective_states.size():
				continue

			var objective_state: Dictionary = (
				objective_states[step_index]
			)

			if bool(
				objective_state.get(
					"completed",
					false
				)
			):
				continue

			var current_step: QuestStep = (
				quest_data.steps[step_index]
			)

			print(
				"   📌 [QUEST CHECK] ",
				quest_id,
				" | objective=",
				step_index,
				" | step=",
				current_step.type,
				" | target=",
				current_step.target,
				" | count=",
				objective_state.get(
					"count",
					0
				)
			)

			# ----------------------------------------------------
			# NORMAL OBJECTIVE
			# ----------------------------------------------------

			var objective_matches: bool = (
				current_step.type == event_type
				and current_step.target == target_id
			)

			if objective_matches:
				_handle_objective_event(
					quest_id,
					quest_data,
					step_index
				)

			if not active_quests.has(quest_id):
				break

			# ----------------------------------------------------
			# VALIDATION
			# ----------------------------------------------------

			objective_states = active_quests[quest_id].get(
				"objectives",
				[]
			)

			if step_index >= objective_states.size():
				continue

			if bool(
				objective_states[step_index].get(
					"completed",
					false
				)
			):
				continue

			# NPC validation happens before Dialogic.
			if (
				event_type == "talk_npc"
				and current_step.validation_type == "talk_npc"
			):
				continue

			if (
				current_step.validation_type != "none"
				and not current_step.validation_type.is_empty()
			):
				var validation_matches: bool = (
					current_step.validation_type == event_type
					and current_step.validation_target == target_id
				)

				if validation_matches:
					_validate_counted_objective(
						quest_id,
						quest_data,
						step_index
					)


# ============================================================
# HANDLE OBJECTIVE EVENT
# ============================================================

func _handle_objective_event(
	quest_id: String,
	quest_data: QuestData,
	step_index: int
) -> void:

	if not active_quests.has(quest_id):
		return

	if step_index < 0:
		return

	if step_index >= quest_data.steps.size():
		return

	var current_step: QuestStep = (
		quest_data.steps[step_index]
	)

	var objective_state: Dictionary = (
		active_quests[quest_id]["objectives"][step_index]
	)

	# Counted objective.
	if current_step.required_count > 1:
		objective_state["count"] = int(
			objective_state.get(
				"count",
				0
			)
		) + 1

		objective_state["validation_state"] = "none"

		var current_count: int = int(
			objective_state.get(
				"count",
				0
			)
		)

		print(
			"🔢 [QUEST COUNT] ",
			quest_data.title,
			" → objective ",
			step_index,
			" → ",
			current_count,
			"/",
			current_step.required_count
		)

		# No validator = complete automatically.
		if (
			current_step.validation_type == "none"
			and current_count >= current_step.required_count
		):
			_complete_objective(
				quest_id,
				quest_data,
				step_index
			)
		else:
			_sync_legacy_state(quest_id)
			_emit_objective_updated(
				quest_id,
				step_index
			)

		return

	# One-time objective.
	objective_state["count"] = 1
	objective_state["validation_state"] = "none"

	if current_step.validation_type == "none":
		print(
			"✅ [QUEST OBJECTIVE COMPLETE] ",
			quest_data.title,
			" → ",
			current_step.type,
			": ",
			current_step.target
		)

		_complete_objective(
			quest_id,
			quest_data,
			step_index
		)

		return

	# Still needs external validation.
	_sync_legacy_state(quest_id)

	_emit_objective_updated(
		quest_id,
		step_index
	)


# ============================================================
# VALIDATE COUNTED OBJECTIVE
# ============================================================

func _validate_counted_objective(
	quest_id: String,
	quest_data: QuestData,
	step_index: int
) -> void:

	if not active_quests.has(quest_id):
		return

	if step_index < 0:
		return

	if step_index >= quest_data.steps.size():
		return

	var current_step: QuestStep = (
		quest_data.steps[step_index]
	)

	var objective_state: Dictionary = (
		active_quests[quest_id]["objectives"][step_index]
	)

	var current_count: int = int(
		objective_state.get(
			"count",
			0
		)
	)

	var required_count: int = (
		current_step.required_count
	)

	print(
		"🔍 [QUEST VALIDATION] ",
		quest_data.title,
		" → objective ",
		step_index,
		" → ",
		current_count,
		"/",
		required_count
	)

	# --------------------------------------------------------
	# ZERO
	# --------------------------------------------------------

	if current_count == 0:
		objective_state["validation_state"] = "zero"

		_sync_legacy_state(quest_id)
		_emit_objective_updated(
			quest_id,
			step_index
		)

		print(
			"⚠️ [QUEST VALIDATION] No interactions yet."
		)

		return

	# --------------------------------------------------------
	# EXACT
	# --------------------------------------------------------

	if current_count == required_count:
		objective_state["validation_state"] = "correct"

		print(
			"✅ [QUEST VALIDATION PASSED] ",
			quest_data.title,
			" → objective ",
			step_index
		)

		_complete_objective(
			quest_id,
			quest_data,
			step_index
		)

		return

	# --------------------------------------------------------
	# TOO FEW
	# --------------------------------------------------------

	if current_count < required_count:
		objective_state["validation_state"] = "under"

		print(
			"❌ [QUEST VALIDATION FAILED] TOO FEW → ",
			current_count,
			"/",
			required_count
		)

		_reset_failed_attempt(
			quest_id,
			quest_data,
			step_index
		)

		return

	# --------------------------------------------------------
	# TOO MANY
	# --------------------------------------------------------

	if current_count > required_count:
		objective_state["validation_state"] = "over"

		print(
			"❌ [QUEST VALIDATION FAILED] TOO MANY → ",
			current_count,
			"/",
			required_count
		)

		_reset_failed_attempt(
			quest_id,
			quest_data,
			step_index
		)


# ============================================================
# RESET FAILED ATTEMPT
# ============================================================

func _reset_failed_attempt(
	quest_id: String,
	quest_data: QuestData,
	step_index: int
) -> void:

	var objective_state: Dictionary = (
		active_quests[quest_id]["objectives"][step_index]
	)

	objective_state["count"] = 0

	quest_validation_failed.emit(
		quest_id,
		quest_data,
		quest_data.steps[step_index]
	)

	_sync_legacy_state(quest_id)

	_emit_objective_updated(
		quest_id,
		step_index
	)


# ============================================================
# COMPLETE ONE OBJECTIVE
# ============================================================

func _complete_objective(
	quest_id: String,
	quest_data: QuestData,
	step_index: int
) -> void:

	if not active_quests.has(quest_id):
		return

	if step_index < 0:
		return

	if step_index >= quest_data.steps.size():
		return

	var objective_state: Dictionary = (
		active_quests[quest_id]["objectives"][step_index]
	)

	var required_count: int = (
		quest_data.steps[step_index].required_count
	)

	objective_state["completed"] = true

	objective_state["count"] = max(
		int(
			objective_state.get(
				"count",
				0
			)
		),
		required_count
	)

	objective_state["validation_state"] = "correct"

	print(
		"✅ [QUEST OBJECTIVE COMPLETED] ",
		quest_data.title,
		" → objective ",
		step_index + 1,
		"/",
		quest_data.steps.size()
	)

	_sync_legacy_state(quest_id)

	_emit_objective_updated(
		quest_id,
		step_index
	)

	if _all_objectives_completed(
		quest_id,
		quest_data
	):
		_complete_quest(quest_id)


# ============================================================
# ALL OBJECTIVES COMPLETED
# ============================================================

func _all_objectives_completed(
	quest_id: String,
	quest_data: QuestData
) -> bool:

	if not active_quests.has(quest_id):
		return false

	var objective_states: Array = (
		active_quests[quest_id].get(
			"objectives",
			[]
		)
	)

	if objective_states.size() < quest_data.steps.size():
		return false

	for step_index in range(
		quest_data.steps.size()
	):
		if not bool(
			objective_states[step_index].get(
				"completed",
				false
			)
		):
			return false

	return true


# ============================================================
# LEGACY / CURRENT OBJECTIVE STATE
# ============================================================

func _sync_legacy_state(
	quest_id: String
) -> void:

	if not active_quests.has(quest_id):
		return

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	var objective_states: Array = (
		active_quests[quest_id].get(
			"objectives",
			[]
		)
	)

	var next_index: int = (
		quest_data.steps.size()
	)

	for step_index in range(
		quest_data.steps.size()
	):
		if step_index >= objective_states.size():
			break

		if not bool(
			objective_states[step_index].get(
				"completed",
				false
			)
		):
			next_index = step_index
			break

	active_quests[quest_id]["current_step"] = (
		next_index
	)

	if next_index >= quest_data.steps.size():
		active_quests[quest_id]["current_count"] = 0
		active_quests[quest_id]["validation_state"] = "none"
		return

	active_quests[quest_id]["current_count"] = int(
		objective_states[next_index].get(
			"count",
			0
		)
	)

	active_quests[quest_id]["validation_state"] = str(
		objective_states[next_index].get(
			"validation_state",
			"none"
		)
	)


func _emit_current_objective(
	quest_id: String
) -> void:

	if not active_quests.has(quest_id):
		return

	_sync_legacy_state(quest_id)

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	var step_index: int = int(
		active_quests[quest_id].get(
			"current_step",
			-1
		)
	)

	if step_index < 0:
		return

	if step_index >= quest_data.steps.size():
		return

	_emit_objective_updated(
		quest_id,
		step_index
	)


func _emit_objective_updated(
	quest_id: String,
	step_index: int
) -> void:

	if not active_quests.has(quest_id):
		return

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	if step_index < 0:
		return

	if step_index >= quest_data.steps.size():
		return

	quest_objective_updated.emit(
		quest_id,
		step_index,
		quest_data.steps[step_index]
	)


# ============================================================
# COMPLETE QUEST
# ============================================================

func _complete_quest(
	quest_id: String
) -> void:

	if not active_quests.has(quest_id):
		return

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	print("")
	print("========================================")
	print(
		"✨ [QUEST COMPLETED] ",
		quest_data.title
	)
	print("========================================")

	_grant_rewards(quest_data)

	active_quests.erase(quest_id)

	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)

	quest_completed.emit(
		quest_id,
		quest_data
	)

	print("========================================")
	print("✨ [QUEST] Rewards granted successfully.")
	print("")


# ============================================================
# REWARDS
# ============================================================

func _grant_rewards(
	quest_data: QuestData
) -> void:

	if quest_data.rewards == null:
		return

	if quest_data.rewards.exp > 0:
		PlayerProgression.add_exp(
			quest_data.rewards.exp
		)

		print(
			"   ⭐ EXP REWARD: +",
			quest_data.rewards.exp
		)

	if quest_data.rewards.gold > 0:
		PlayerProgression.gold += (
			quest_data.rewards.gold
		)

		print(
			"   🪙 GOLD REWARD: +",
			quest_data.rewards.gold
		)


# ============================================================
# QUEST STATE
# ============================================================

func is_quest_active(
	quest_id: String
) -> bool:
	return active_quests.has(quest_id)


func is_quest_completed(
	quest_id: String
) -> bool:
	return completed_quests.has(quest_id)


func get_current_step(
	quest_id: String
) -> int:

	if not active_quests.has(quest_id):
		return -1

	_sync_legacy_state(quest_id)

	return int(
		active_quests[quest_id].get(
			"current_step",
			-1
		)
	)


func get_current_count(
	quest_id: String
) -> int:

	if not active_quests.has(quest_id):
		return 0

	_sync_legacy_state(quest_id)

	return int(
		active_quests[quest_id].get(
			"current_count",
			0
		)
	)


func get_required_count(
	quest_id: String
) -> int:

	if not active_quests.has(quest_id):
		return 0

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return 0

	var step_index: int = get_current_step(
		quest_id
	)

	if step_index < 0:
		return 0

	if step_index >= quest_data.steps.size():
		return 0

	return quest_data.steps[step_index].required_count


# ============================================================
# MULTI-OBJECTIVE STATE
# ============================================================

func get_objective_count(
	quest_id: String,
	step_index: int
) -> int:

	if not active_quests.has(quest_id):
		return 0

	var objective_states: Array = (
		active_quests[quest_id].get(
			"objectives",
			[]
		)
	)

	if step_index < 0:
		return 0

	if step_index >= objective_states.size():
		return 0

	return int(
		objective_states[step_index].get(
			"count",
			0
		)
	)


func get_objective_required_count(
	quest_id: String,
	step_index: int
) -> int:

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return 0

	if step_index < 0:
		return 0

	if step_index >= quest_data.steps.size():
		return 0

	return quest_data.steps[step_index].required_count


func is_objective_completed(
	quest_id: String,
	step_index: int
) -> bool:

	if not active_quests.has(quest_id):
		return false

	var objective_states: Array = (
		active_quests[quest_id].get(
			"objectives",
			[]
		)
	)

	if step_index < 0:
		return false

	if step_index >= objective_states.size():
		return false

	return bool(
		objective_states[step_index].get(
			"completed",
			false
		)
	)


func get_objective_validation_state(
	quest_id: String,
	step_index: int
) -> String:

	if not active_quests.has(quest_id):
		return "none"

	var objective_states: Array = (
		active_quests[quest_id].get(
			"objectives",
			[]
		)
	)

	if step_index < 0:
		return "none"

	if step_index >= objective_states.size():
		return "none"

	return str(
		objective_states[step_index].get(
			"validation_state",
			"none"
		)
	)


# ============================================================
# VALIDATION STATE
# ============================================================

func get_validation_state(
	quest_id: String
) -> String:

	if not active_quests.has(quest_id):
		return "none"

	_sync_legacy_state(quest_id)

	return str(
		active_quests[quest_id].get(
			"validation_state",
			"none"
		)
	)


func is_validation_failed(
	quest_id: String
) -> bool:

	var state := get_validation_state(
		quest_id
	)

	return (
		state == "under"
		or state == "over"
	)


func is_count_zero(
	quest_id: String
) -> bool:

	return (
		get_validation_state(quest_id)
		== "zero"
	)


func is_count_under(
	quest_id: String
) -> bool:

	return (
		get_validation_state(quest_id)
		== "under"
	)


func is_count_over(
	quest_id: String
) -> bool:

	return (
		get_validation_state(quest_id)
		== "over"
	)


func is_count_correct(
	quest_id: String
) -> bool:

	return (
		get_validation_state(quest_id)
		== "correct"
	)


# ============================================================
# NPC QUEST MARKER
# ============================================================

# Returns:
#
# "available" = !
# "turn_in"   = ?
# "none"      = hidden
#
# The NPC itself does not need to know which quest belongs
# to it. QuestData contains quest_giver_id and quest_turn_in_id.

func get_npc_quest_marker(
	npc_id: String
) -> String:

	if npc_id.is_empty():
		return "none"

	# --------------------------------------------------------
	# TURN-IN QUESTS
	# --------------------------------------------------------

	for quest_id in active_quests.keys():
		var active_id: String = str(
			quest_id
		)

		var quest_data: QuestData = get_quest(
			active_id
		)

		if quest_data == null:
			continue

		if quest_data.quest_turn_in_id != npc_id:
			continue

		if _all_objectives_completed(
			active_id,
			quest_data
		):
			return "turn_in"

	# --------------------------------------------------------
	# AVAILABLE QUESTS
	# --------------------------------------------------------

	var available_side_quest: bool = false
	var available_main_quest: bool = false

	for quest_id in quest_database.keys():
		var quest_data: QuestData = (
			quest_database[str(quest_id)]
		)

		if quest_data == null:
			continue

		if quest_data.quest_giver_id != npc_id:
			continue

		if completed_quests.has(
			str(quest_id)
		):
			continue

		if active_quests.has(
			str(quest_id)
		):
			continue

		if quest_data.is_main_quest:
			available_main_quest = true
		else:
			available_side_quest = true

	# Main quest gets priority over side quest.
	if available_main_quest:
		return "available"

	if available_side_quest:
		return "available"

	return "none"


# Returns true when the highest-priority available or turn-in
# quest for this NPC is a main quest.
#
# Useful later if BaseNPC wants to make the marker yellow for
# main quests and another color for side quests.

func is_npc_main_quest_marker(
	npc_id: String
) -> bool:

	if npc_id.is_empty():
		return false

	# Turn-in has priority.
	for quest_id in active_quests.keys():
		var active_id: String = str(
			quest_id
		)

		var quest_data: QuestData = get_quest(
			active_id
		)

		if quest_data == null:
			continue

		if quest_data.quest_turn_in_id != npc_id:
			continue

		if _all_objectives_completed(
			active_id,
			quest_data
		):
			return quest_data.is_main_quest

	# Available quest.
	for quest_id in quest_database.keys():
		var quest_data: QuestData = (
			quest_database[str(quest_id)]
		)

		if quest_data == null:
			continue

		if quest_data.quest_giver_id != npc_id:
			continue

		if completed_quests.has(
			str(quest_id)
		):
			continue

		if active_quests.has(
			str(quest_id)
		):
			continue

		if quest_data.is_main_quest:
			return true

	return false


# ============================================================
# DIALOGUE FLAGS
# ============================================================

func has_dialogue_flag(
	flag_id: String
) -> bool:

	return bool(
		dialogue_flags.get(
			flag_id,
			false
		)
	)


func set_dialogue_flag(
	flag_id: String,
	value: bool = true
) -> void:

	dialogue_flags[flag_id] = value

	dialogue_flag_changed.emit(
		flag_id
	)

	print(
		"💬 [DIALOGUE FLAG] ",
		flag_id,
		" = ",
		value
	)


# ============================================================
# SAVE
# ============================================================

func get_save_data() -> Dictionary:
	return {
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"dialogue_flags": dialogue_flags
	}


# ============================================================
# LOAD
# ============================================================

func load_save_data(
	data: Dictionary
) -> void:

	if data.is_empty():
		return

	# --------------------------------------------------------
	# ACTIVE QUESTS
	# --------------------------------------------------------

	var saved_active_quests = data.get(
		"active_quests",
		{}
	)

	active_quests.clear()

	if saved_active_quests is Dictionary:
		for quest_id in saved_active_quests.keys():
			var saved_state = (
				saved_active_quests[quest_id]
			)

			if not saved_state is Dictionary:
				continue

			var id: String = str(quest_id)

			var quest_data: QuestData = get_quest(
				id
			)

			if quest_data == null:
				continue

			var objective_states: Array = []

			var saved_objectives = (
				saved_state.get(
					"objectives",
					null
				)
			)

			# New multi-objective format.
			if saved_objectives is Array:

				for step_index in range(
					quest_data.steps.size()
				):
					var state: Dictionary = {
						"count": 0,
						"completed": false,
						"validation_state": "none"
					}

					if step_index < saved_objectives.size():

						var saved_objective = (
							saved_objectives[step_index]
						)

						if saved_objective is Dictionary:

							state["count"] = int(
								saved_objective.get(
									"count",
									0
								)
							)

							state["completed"] = bool(
								saved_objective.get(
									"completed",
									false
								)
							)

							state["validation_state"] = str(
								saved_objective.get(
									"validation_state",
									"none"
								)
							)

					objective_states.append(
						state
					)

			# Old sequential format.
			else:

				var old_current_step: int = int(
					saved_state.get(
						"current_step",
						0
					)
				)

				var old_current_count: int = int(
					saved_state.get(
						"current_count",
						0
					)
				)

				var old_validation_state: String = str(
					saved_state.get(
						"validation_state",
						"none"
					)
				)

				for step_index in range(
					quest_data.steps.size()
				):
					var migrated_state: Dictionary = {
						"count": 0,
						"completed": (
							step_index < old_current_step
						),
						"validation_state": "none"
					}

					if step_index == old_current_step:
						migrated_state["count"] = (
							old_current_count
						)

						migrated_state[
							"validation_state"
						] = old_validation_state

					objective_states.append(
						migrated_state
					)

			active_quests[id] = {
				"current_step": 0,
				"current_count": 0,
				"validation_state": "none",
				"objectives": objective_states
			}

			_sync_legacy_state(id)

	# --------------------------------------------------------
	# COMPLETED QUESTS
	# --------------------------------------------------------

	var saved_completed_quests = (
		data.get(
			"completed_quests",
			[]
		)
	)

	completed_quests.clear()

	if saved_completed_quests is Array:
		for quest_id in saved_completed_quests:
			if quest_id is String:
				completed_quests.append(
					quest_id
				)

	# --------------------------------------------------------
	# DIALOGUE FLAGS
	# --------------------------------------------------------

	var saved_dialogue_flags = (
		data.get(
			"dialogue_flags",
			{}
		)
	)

	dialogue_flags.clear()

	if saved_dialogue_flags is Dictionary:
		for flag_id in saved_dialogue_flags.keys():
			dialogue_flags[str(flag_id)] = bool(
				saved_dialogue_flags[flag_id]
			)

	print(
		"💾 [QUEST] Loaded ",
		active_quests.size(),
		" active quest(s), ",
		completed_quests.size(),
		" completed quest(s), and ",
		dialogue_flags.size(),
		" dialogue flag(s)."
	)
