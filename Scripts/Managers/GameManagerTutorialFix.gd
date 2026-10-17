extends "res://Scripts/Managers/GameManager.gd"

## Resets spotlight state at the beginning of each account session.
## SaveManagerTutorialFix then loads that account's saved UI tutorial flags.


func initialize_session(email: String) -> void:
	if is_instance_valid(UITutorialManager) and UITutorialManager.has_method("load_save_data"):
		UITutorialManager.load_save_data({})
	await super.initialize_session(email)
