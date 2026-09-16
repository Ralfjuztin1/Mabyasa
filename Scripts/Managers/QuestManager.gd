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

	var directory := DirAccess.open(QUESTS_PATH)

	if directory == null:
		push_error(
			"[QUEST] Could not open quest folder: "
			+ QUESTS_PATH
		)
		return

	var files := directory.get_files()

	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue

		var file_path := QUESTS_PATH + file_name
		var quest_resource = ResourceLoader.load(file_path)

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

		var quest_data: QuestData = quest_resource

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

	active_quests[quest_id] = {
		"current_step": 0,
		"current_count": 0,
		"validation_state": "none"
	}

	print("")
	print("📜 [QUEST STARTED] ", quest_data.title)
	print("   Quest ID: ", quest_id)

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

		var step_index: int = (
			active_quests[quest_id]["current_step"]
		)

		if step_index < 0 or step_index >= quest_data.steps.size():
			continue

		var current_step: QuestStep = quest_data.steps[step_index]

		# Only validation events for the current step matter here.
		if current_step.validation_type != "talk_npc":
			continue

		if current_step.validation_target != npc_id:
			continue

		print(
			"🔍 [QUEST PRE-DIALOGUE VALIDATION] ",
			quest_data.title,
			" → talk_npc: ",
			npc_id
		)

		_validate_counted_objective(
			quest_id,
			quest_data,
			current_step
		)


# ============================================================
# GAME EVENT HANDLER
# ============================================================

func _on_event(target_id: String, event_type: String) -> void:
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

		var step_index: int = (
			active_quests[quest_id]["current_step"]
		)

		if step_index < 0 or step_index >= quest_data.steps.size():
			continue

		var current_step: QuestStep = quest_data.steps[step_index]

		print(
			"   📌 [QUEST CHECK] ",
			quest_id,
			" | step=",
			current_step.type,
			" | target=",
			current_step.target,
			" | count=",
			active_quests[quest_id].get("current_count", 0)
		)

		# ----------------------------------------------------
		# NORMAL / COUNTED OBJECTIVE
		# ----------------------------------------------------

		var objective_matches: bool = (
			current_step.type == event_type
			and current_step.target == target_id
		)

		if objective_matches:
			_handle_objective_event(
				quest_id,
				quest_data,
				current_step
			)

		# ----------------------------------------------------
		# VALIDATION EVENTS
		# ----------------------------------------------------

		if not active_quests.has(quest_id):
			continue

		if (
			current_step.validation_type != "none"
			and not current_step.validation_type.is_empty()
		):
			# IMPORTANT:
			# NPC validation is handled before Dialogue starts.
			# Do not validate it again when Dialogic ends.
			if (
				event_type == "talk_npc"
				and current_step.validation_type == "talk_npc"
			):
				continue

			var validation_matches: bool = (
				current_step.validation_type == event_type
				and current_step.validation_target == target_id
			)

			if validation_matches:
				_validate_counted_objective(
					quest_id,
					quest_data,
					current_step
				)


# ============================================================
# HANDLE OBJECTIVE
# ============================================================

func _handle_objective_event(
	quest_id: String,
	quest_data: QuestData,
	current_step: QuestStep
) -> void:

	if not active_quests.has(quest_id):
		return

	# Counted objective.
	if current_step.required_count > 1:
		active_quests[quest_id]["current_count"] += 1

		# New interaction means the player is attempting again.
		active_quests[quest_id]["validation_state"] = "none"

		var current_count: int = (
			active_quests[quest_id]["current_count"]
		)

		print(
			"🔢 [QUEST COUNT] ",
			quest_data.title,
			" → ",
			current_count,
			"/",
			current_step.required_count
		)

		_emit_current_objective(quest_id)

		return

	# Normal one-time objective.
	print(
		"✅ [QUEST OBJECTIVE COMPLETE] ",
		quest_data.title,
		" → ",
		current_step.type,
		": ",
		current_step.target
	)

	_advance_quest(quest_id)


# ============================================================
# VALIDATE COUNTED OBJECTIVE
# ============================================================

func _validate_counted_objective(
	quest_id: String,
	quest_data: QuestData,
	current_step: QuestStep
) -> void:

	if not active_quests.has(quest_id):
		return

	var current_count: int = (
		active_quests[quest_id]["current_count"]
	)

	var required_count: int = (
		current_step.required_count
	)

	print(
		"🔍 [QUEST VALIDATION] ",
		quest_data.title,
		" → ",
		current_count,
		"/",
		required_count
	)

	# --------------------------------------------------------
	# ZERO
	# --------------------------------------------------------

	if current_count == 0:
		active_quests[quest_id]["validation_state"] = "zero"

		print(
			"⚠️ [QUEST VALIDATION] No interactions yet."
		)

		return

	# --------------------------------------------------------
	# EXACT
	# --------------------------------------------------------

	if current_count == required_count:
		active_quests[quest_id]["validation_state"] = "correct"

		print(
			"✅ [QUEST VALIDATION PASSED] ",
			quest_data.title
		)

		_advance_quest(quest_id)
		return

	# --------------------------------------------------------
	# TOO FEW
	# --------------------------------------------------------

	if current_count < required_count:
		active_quests[quest_id]["validation_state"] = "under"

		print(
			"❌ [QUEST VALIDATION FAILED] TOO FEW → ",
			current_count,
			"/",
			required_count
		)

		_reset_failed_attempt(
			quest_id,
			quest_data,
			current_step
		)

		return

	# --------------------------------------------------------
	# TOO MANY
	# --------------------------------------------------------

	if current_count > required_count:
		active_quests[quest_id]["validation_state"] = "over"

		print(
			"❌ [QUEST VALIDATION FAILED] TOO MANY → ",
			current_count,
			"/",
			required_count
		)

		_reset_failed_attempt(
			quest_id,
			quest_data,
			current_step
		)


# ============================================================
# RESET FAILED ATTEMPT
# ============================================================

func _reset_failed_attempt(
	quest_id: String,
	quest_data: QuestData,
	current_step: QuestStep
) -> void:

	# Keep the validation state so Dialogic can see
	# why the attempt failed.
	active_quests[quest_id]["current_count"] = 0

	quest_validation_failed.emit(
		quest_id,
		quest_data,
		current_step
	)

	_emit_current_objective(quest_id)


# ============================================================
# ADVANCE QUEST
# ============================================================

func _advance_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	active_quests[quest_id]["current_step"] += 1
	active_quests[quest_id]["current_count"] = 0
	active_quests[quest_id]["validation_state"] = "none"

	var new_step_index: int = (
		active_quests[quest_id]["current_step"]
	)

	if new_step_index >= quest_data.steps.size():
		_complete_quest(quest_id)
		return

	print(
		"📜 [QUEST ADVANCED] ",
		quest_data.title,
		" → Step ",
		new_step_index + 1,
		" of ",
		quest_data.steps.size()
	)

	_emit_current_objective(quest_id)


# ============================================================
# CURRENT OBJECTIVE
# ============================================================

func _emit_current_objective(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	var step_index: int = (
		active_quests[quest_id]["current_step"]
	)

	if step_index < 0 or step_index >= quest_data.steps.size():
		return

	var current_step: QuestStep = quest_data.steps[step_index]

	quest_objective_updated.emit(
		quest_id,
		step_index,
		current_step
	)


# ============================================================
# COMPLETE QUEST
# ============================================================

func _complete_quest(quest_id: String) -> void:
	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return

	print("")
	print("========================================")
	print("✨ [QUEST COMPLETED] ", quest_data.title)
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

func _grant_rewards(quest_data: QuestData) -> void:
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

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)


func get_current_step(quest_id: String) -> int:
	if not active_quests.has(quest_id):
		return -1

	return active_quests[quest_id]["current_step"]


func get_current_count(quest_id: String) -> int:
	if not active_quests.has(quest_id):
		return 0

	return active_quests[quest_id].get(
		"current_count",
		0
	)


func get_required_count(quest_id: String) -> int:
	if not active_quests.has(quest_id):
		return 0

	var quest_data := get_quest(quest_id)

	if quest_data == null:
		return 0

	var step_index: int = (
		active_quests[quest_id]["current_step"]
	)

	if step_index < 0 or step_index >= quest_data.steps.size():
		return 0

	return quest_data.steps[step_index].required_count


# ============================================================
# VALIDATION STATE
# ============================================================

func get_validation_state(quest_id: String) -> String:
	if not active_quests.has(quest_id):
		return "none"

	return active_quests[quest_id].get(
		"validation_state",
		"none"
	)


func is_validation_failed(quest_id: String) -> bool:
	var state := get_validation_state(quest_id)

	return state == "under" or state == "over"


func is_count_zero(quest_id: String) -> bool:
	return get_validation_state(quest_id) == "zero"


func is_count_under(quest_id: String) -> bool:
	return get_validation_state(quest_id) == "under"


func is_count_over(quest_id: String) -> bool:
	return get_validation_state(quest_id) == "over"


func is_count_correct(quest_id: String) -> bool:
	return get_validation_state(quest_id) == "correct"


# ============================================================
# DIALOGUE FLAGS
# ============================================================

func has_dialogue_flag(flag_id: String) -> bool:
	return dialogue_flags.get(
		flag_id,
		false
	)


func set_dialogue_flag(
	flag_id: String,
	value: bool = true
) -> void:

	dialogue_flags[flag_id] = value

	dialogue_flag_changed.emit(flag_id)

	print(
		"💬 [DIALOGUE FLAG] ",
		flag_id,
		" = ",
		value
	)


# ============================================================
# SAVE / LOAD
# ============================================================

func get_save_data() -> Dictionary:
	return {
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"dialogue_flags": dialogue_flags
	}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Active quests
	var saved_active_quests = data.get(
		"active_quests",
		{}
	)

	active_quests.clear()

	if saved_active_quests is Dictionary:
		for quest_id in saved_active_quests.keys():
			var saved_state = saved_active_quests[quest_id]

			if not saved_state is Dictionary:
				continue

			active_quests[quest_id] = {
				"current_step": int(
					saved_state.get(
						"current_step",
						0
					)
				),

				"current_count": int(
					saved_state.get(
						"current_count",
						0
					)
				),

				"validation_state": str(
					saved_state.get(
						"validation_state",
						"none"
					)
				)
			}

	# Completed quests
	var saved_completed_quests = data.get(
		"completed_quests",
		[]
	)

	completed_quests.clear()

	if saved_completed_quests is Array:
		for quest_id in saved_completed_quests:
			if quest_id is String:
				completed_quests.append(
					quest_id
				)

	# Dialogue flags
	var saved_dialogue_flags = data.get(
		"dialogue_flags",
		{}
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
