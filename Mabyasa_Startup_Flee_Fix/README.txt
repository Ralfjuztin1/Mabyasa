MABYASA: CHIEF FLEE + OPENING WAIT FIX (REVISION 2)

This revision omits the fallback FirstTownIntro.gd hunk because it did not match your local copy. Your active opening sequence uses the Scene1Cutscene director, so its start delay and camera hold are changed in Scene1Cutscene.tscn instead.

Changes in the included patch:
1. Hides the Flee button during Chief's scripted training battle (enemy ID: chief_training).
2. Blocks fleeing inside BattleManager for that same training battle.
3. Removes the extra one-second wait after the final controls-tutorial step.
4. Removes the 0.15-second start delay and 0.5-second hold from the first-town opening cutscene.

HOW TO APPLY
1. Back up the project.
2. Extract this ZIP into the MABYASA repository root, preserving the Mabyasa_Startup_Flee_Fix folder.
3. In Command Prompt at the repository root, run:

   git apply --check Mabyasa_Startup_Flee_Fix/mabyasa_startup_flee_fix.patch

4. If the check succeeds, apply it:

   git apply Mabyasa_Startup_Flee_Fix/mabyasa_startup_flee_fix.patch

5. Check the changes with:

   git diff

6. Open Godot and test the tutorial-to-opening transition and both Chief and normal battles.

The earlier patch check failed only on Scripts/Cutscene/FirstTownIntro.gd because the local lines differed. This revised patch skips that optional fallback-script edit rather than forcing it. It does not alter that file.

This is a local patch; no files were committed to GitHub and the game has not been run in Godot here.
