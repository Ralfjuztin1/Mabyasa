extends Node

const TIME_STATES: Array = ["morning", "afternoon", "night"]
var current_index: int = 0

func get_current_time() -> String:
	return TIME_STATES[current_index]

func advance_time() -> void:
	current_index = (current_index + 1) % TIME_STATES.size()
	_notify_time_change()

func set_time(target_state: String) -> void:
	var target_idx = TIME_STATES.find(target_state)
	if target_idx != -1 and target_idx != current_index:
		current_index = target_idx
		_notify_time_change()

func _notify_time_change() -> void:
	var new_time = get_current_time()
	print("🌙 [TIME] Advanced to: ", new_time.capitalize())
	if GameEvents:
		GameEvents.time_updated.emit(new_time)

# --- JSON SAVE INTEGRATION ---
func get_save_data() -> Dictionary:
	return { "time_index": current_index }

func load_save_data(data: Dictionary) -> void:
	if not data.is_empty():
		current_index = data.get("time_index", 0)
		_notify_time_change()
