MABIYASA - CHECKPOINTMARKER NORMAL BATTLE DEFEAT FIX

This patch changes only Scenes/Battle/BattleScreen.gd.

It uses the checkpoint already registered by your CheckpointMarker.gd via
CheckpointManager.set_checkpoint(). When the player loses a normal battle,
the button becomes "Return to Checkpoint" and calls
CheckpointManager.restore_checkpoint(). It does NOT create a new checkpoint
at the current battle location. If no CheckpointMarker has registered a
checkpoint, CheckpointManager will report that no checkpoint is registered.

Normal battle victory remains unchanged. Boss battle flow, BattleManager.gd,
combat turns, and damage logic are not changed by this patch.

Install:
1. Back up Scenes/Battle/BattleScreen.gd.
2. Extract this ZIP in your project root (the folder containing project.godot).
3. From that root, run:
   git apply Mabyasa_CheckpointMarker_Battle_Fix.patch

If the ZIP's nested folder is still intact, the patch's path is:
   Mabyasa_CheckpointMarker_Battle_Fix/Mabyasa_CheckpointMarker_Battle_Fix.patch

The patch is based on the current main-branch BattleScreen.gd. If you have local
changes to that file, inspect the patch before applying it. The game was not
runtime-tested in Godot in this environment.
