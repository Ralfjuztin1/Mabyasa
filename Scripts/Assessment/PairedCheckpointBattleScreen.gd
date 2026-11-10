extends "res://Scenes/Battle/BattleScreenCheckpointFix.gd"

## Keeps normal-battle checkpoint restoration and every other boss unchanged.
## Only the Forest Ylang-Ylang Guardian gets the paired comparison overlay.

const PAIRED_GUARDIAN_OVERLAY: PackedScene = preload(
	"res://Scenes/Battle/PairedBossAssessmentOverlay.tscn"
)


func _ready() -> void:
	# The checkpoint script reconnects this signal in its _ready(). Bind explicitly
	# once more here so the live battle scene always calls this override.
	super._ready()
	for connection: Dictionary in BattleManager.battle_ended.get_connections():
		var callback: Callable = connection["callable"]
		if callback.get_object() == self and callback.get_method() == "_on_battle_ended":
			BattleManager.battle_ended.disconnect(callback)
	BattleManager.battle_ended.connect(_on_battle_ended)
	print("[GUARDIAN FIX] Paired checkpoint battle screen active.")


func _on_battle_ended(victory: bool) -> void:
	print("[GUARDIAN FIX] Battle ended. Guardian: ",
		BattleManager.current_enemy != null and
		BattleManager.current_enemy.enemy_id == "forest_ylang_guardian")
	if (
		BattleManager.current_enemy == null
		or BattleManager.current_enemy.enemy_id != "forest_ylang_guardian"
	):
		super._on_battle_ended(victory)
		return

	bottom_bar.visible = false
	attack_button.visible = false
	food_button.visible = false
	flee_button.visible = false
	continue_button.visible = false

	var assessment: Control = PAIRED_GUARDIAN_OVERLAY.instantiate() as Control
	if assessment == null:
		push_error("[PAIRED BOSS] Could not instantiate the result overlay.")
		return

	print("[GUARDIAN FIX] Showing final learning comparison; no follow-up quiz.")
	assessment.name = "BossAssessmentOverlay"
	assessment.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(assessment)
	assessment.connect("finished", Callable(self, "_on_boss_assessment_finished"))
	assessment.call(
		"present",
		victory,
		BattleManager.get_boss_assessment_report(),
		BattleManager.current_enemy.display_name
	)
