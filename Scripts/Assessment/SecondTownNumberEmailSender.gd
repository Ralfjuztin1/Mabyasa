extends "res://Scripts/Assessment/AssessmentEmailSender.gd"

## Reuse Boss 1's secure, redirect-aware HTTP transport, but keep a separate
## numbers_boss report. It MUST be routed separately on Google Apps Script.
const NUMBER_COMPARISON: GDScript = preload("res://Scripts/Assessment/NumbersAssessmentComparison.gd")


func send_numbers_assessment_report(report: Dictionary, victory: bool) -> void:
	if not is_instance_valid(SupabaseManager) or SupabaseManager.current_user_id.is_empty():
		completed.emit(false, "Sign in before sending the number-boss assessment.")
		return
	var user_id: String = str(SupabaseManager.current_user_id)
	if not await SupabaseManager._ensure_fresh_token():
		completed.emit(false, "Could not refresh sign-in session.")
		return
	if str(SupabaseManager.current_user_id) != user_id or SupabaseManager.session_token.is_empty():
		completed.emit(false, "Account session changed. Sign in again and retry.")
		return

	var comparison: Dictionary = NUMBER_COMPARISON.build(
		SaveManager.get_pre_assessment_report(), report
	)
	var payload: Dictionary = {
		"assessment_type": "numbers_boss",
		"boss_id": "second_town_number_guardian",
		"lesson": "numbers_1_to_10",
		"access_token": SupabaseManager.session_token,
		"report": report.duplicate(true),
		"comparison": comparison,
		"battle_outcome": "Victory" if victory else "Defeat",
		"attempt_number": 1
	}
	var response: Dictionary = await _post_to_google(JSON.stringify(payload))
	completed.emit(
		bool(response.get("success", false)),
		str(response.get("message", "Unknown server response."))
	)
