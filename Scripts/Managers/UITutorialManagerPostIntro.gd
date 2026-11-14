extends "res://Scripts/Managers/UITutorialManager.gd"

## Minimal override of the existing spotlight manager.
## The first-town intro director raises this flag AFTER end_cutscene(),
## which restores the camera and releases player control.
const FIRST_TOWN_INTRO_FINISHED := "cene_1_ima_good_morning_complete"


func _ready() -> void:
	super._ready()
	if not QuestManager.dialogue_flag_changed.is_connected(_on_intro_flag_changed):
		QuestManager.dialogue_flag_changed.connect(_on_intro_flag_changed)


# Override the old trigger: talking to Ima should NOT bring up the HUD guide.
func _on_npc_talked(_npc_id: String) -> void:
	pass


func _on_intro_flag_changed(flag_id: String) -> void:
	if flag_id != FIRST_TOWN_INTRO_FINISHED:
		return
	if not QuestManager.has_dialogue_flag(FIRST_TOWN_INTRO_FINISHED):
		return
	call_deferred("_show_hud_guide_after_intro")


func _show_hud_guide_after_intro() -> void:
	# Allow the scene UI to settle after the cutscene releases control.
	await get_tree().process_frame
	if not is_inside_tree() or is_tutorial_seen("exploration_hud"):
		return
	request_tutorial("exploration_hud")
