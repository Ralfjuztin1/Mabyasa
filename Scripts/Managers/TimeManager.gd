
extends Node

const TIME_STATES: Array = ["morning", "afternoon", "night"]
var current_index: int = 0


func _ready() -> void:
	_sync_time_dialogue_flags()


func get_current_time() -> String:
	return TIME_STATES[current_index]


func advance_time() -> void:
	current_index = (current_index + 1) % TIME_STATES.size()
	_notify_time_change()


func set_time(target_state: String) -> void:
	var target_idx: int = TIME_STATES.find(target_state)

	if target_idx != -1 and target_idx != current_index:
		current_index = target_idx
		_notify_time_change()


func _sync_time_dialogue_flags() -> void:
	if not is_instance_valid(QuestManager):
		return

	var current_time: String = get_current_time()

	QuestManager.set_dialogue_flag(
		"time_morning", current_time == "morning"
	)
	QuestManager.set_dialogue_flag(
		"time_afternoon", current_time == "afternoon"
	)
	QuestManager.set_dialogue_flag(
		"time_night", current_time == "night"
	)


func _notify_time_change() -> void:
	var new_time: String = get_current_time()

	_sync_time_dialogue_flags()

	print("[TIME] Advanced to: ", new_time.capitalize())

	if GameEvents:
		GameEvents.time_updated.emit(new_time)


# --- JSON SAVE INTEGRATION ---

func get_save_data() -> Dictionary:
	return {"time_index": current_index}


func load_save_data(data: Dictionary) -> void:
	if not data.is_empty():
		current_index = clampi(
			int(data.get("time_index", 0)),
			0,
			TIME_STATES.size() - 1
		)
		_notify_time_change()
