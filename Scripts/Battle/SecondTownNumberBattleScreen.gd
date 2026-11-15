extends "res://Scenes/Battle/BattleScreen.gd"

const NUMBER_BOSS_ID: String = "second_town_number_guardian"
const NUMBER_OVERLAY: PackedScene = preload("res://Scenes/Battle/SecondTownNumberAssessmentOverlay.tscn")

func _on_battle_ended(victory: bool) -> void:
	if BattleManager.current_enemy == null or BattleManager.current_enemy.enemy_id != NUMBER_BOSS_ID:
		super._on_battle_ended(victory)
		return
	bottom_bar.hide()
	attack_button.hide()
	food_button.hide()
	flee_button.hide()
	continue_button.hide()
	var assessment: Control = NUMBER_OVERLAY.instantiate() as Control
	if assessment == null:
		push_error("[NUMBERS BOSS] Could not open the number assessment.")
		return
	assessment.name = "SecondTownNumberAssessment"
	assessment.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(assessment)
	assessment.connect("finished", Callable(self, "_on_boss_assessment_finished"))
	assessment.call("present", victory, BattleManager.get_boss_assessment_report(), BattleManager.current_enemy.display_name)
