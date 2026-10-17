extends "res://Scenes/Battle/BattleScreen.gd"

## Overrides only the normal-battle defeat exit.
## The parent script continues to handle all battle UI, animations, and boss flow.

var _normal_battle_lost: bool = false


func _on_battle_ended(victory: bool) -> void:
	var enemy_is_boss: bool = (
		BattleManager.current_enemy != null
		and BattleManager.current_enemy.is_boss
	)

	if not enemy_is_boss:
		_normal_battle_lost = not victory

	# Keep the existing battle ending behavior.
	super._on_battle_ended(victory)

	# Normal defeat should offer a checkpoint return; normal victory remains normal.
	if not enemy_is_boss:
		continue_button.text = "CONTINUE" if victory else "RETURN TO CHECKPOINT"


func _on_continue_pressed() -> void:
	# Do not change normal victory behavior.
	if not _normal_battle_lost:
		super._on_continue_pressed()
		return

	# Prevent repeated clicks while the checkpoint restoration is running.
	continue_button.disabled = true
	bottom_bar.visible = false

	# Restore the checkpoint already registered by CheckpointMarker.
	# This does not create a new checkpoint at the defeat location.
	var restored: bool = await CheckpointManager.restore_checkpoint()

	if not restored:
		push_warning(
			"[BATTLE] Could not restore a registered CheckpointMarker checkpoint. "
			+ "Make sure the player has touched a CheckpointMarker before defeat."
		)
		GameManager.set_game_state(GameManager.GameState.EXPLORATION)
		if GameManager.has_method("request_save"):
			GameManager.request_save()

	if is_instance_valid(self):
		closed.emit()
		queue_free()
