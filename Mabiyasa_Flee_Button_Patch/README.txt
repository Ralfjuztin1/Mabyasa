MABIYASA FLEE BUTTON PATCH

This patch adds a Flee button for NORMAL battles. Boss battles intentionally do
not allow fleeing, so they cannot skip the existing boss assessment/checkpoint
flow. Fleeing grants no EXP or gold and does not damage the player.

FILES CHANGED:
- Scripts/Battle/BattleManager.gd
- Scenes/Battle/BattleScreen.gd
- Scenes/Battle/BattleScreen.tscn

INSTALL (Git Bash / terminal):
1. Back up or commit your current project changes.
2. Extract this ZIP into the project root, so add_flee_button.patch is beside
   project.godot.
3. Open Git Bash in the project root.
4. Run:
     git apply --check add_flee_button.patch
   If this reports conflicts, STOP and do not apply it; the local files differ
   from the GitHub versions this patch was made against.
5. If the check succeeds, run:
     git apply add_flee_button.patch
6. Open Godot, let it reload scripts, and run a normal enemy battle.

BEHAVIOR:
- Flee appears for normal battles and is hidden for boss battles.
- Flee is blocked while a quiz/feedback is active or while the enemy turn is
  resolving. This prevents dodging the opponent's counterattack.
- Flee exits the battle immediately, returns GameManager to EXPLORATION, and
  requests a save. No win reward is given.
- No enemy/world instance is deleted by fleeing; the existing enemy remains
  where it was. If you want fleeing to reset an enemy's position or remove the
  encounter, that should be handled by the enemy scene/encounter script.

This patch has a static diff validation only. It has not been run in Godot.
