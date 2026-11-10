extends "res://Scenes/Battle/BattleScreen.gd"

const PAIRED_BOSS_ASSESSMENT_SCENE: PackedScene = preload(
	"res://Scenes/Battle/PairedBossAssessmentOverlay.tscn"
)


func _on_battle_ended(victory: bool) -> void:
	if (
		BattleManager.current_enemy != null
		and BattleManager.current_enemy.is_boss
	):
		bottom_bar.visible = false
		attack_button.visible = false
		food_button.visible = false
		flee_button.visible = false
		continue_button.visible = false

		var assessment := PAIRED_BOSS_ASSESSMENT_SCENE.instantiate() as Control
		if assessment == null:
			push_error("[PAIRED BOSS] Could not instantiate paired assessment overlay.")
			return

		assessment.name = "BossAssessmentOverlay"
		assessment.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(assessment)

		assessment.connect(
			"finished",
			Callable(self, "_on_boss_assessment_finished")
		)

		var boss_name := BattleManager.current_enemy.display_name
		var report := BattleManager.get_boss_assessment_report()
		assessment.call("present", victory, report, boss_name)
		return

	super._on_battle_ended(victory)
