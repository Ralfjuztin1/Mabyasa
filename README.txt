MABYASA — F10 QUEST CHECKPOINT DEBUG
Based on current GitHub quest IDs and the Litik Forest continuation.

COPY THIS NEW SCRIPT INTO YOUR PROJECT:
  res://Scripts/Debug/QuestCheckpointDebug.gd

ONE-TIME GODOT ACTIVATION:
  Project > Project Settings > Globals (Autoload)
  Select res://Scripts/Debug/QuestCheckpointDebug.gd
  Name: QuestCheckpointDebug
  Click Add. Keep it enabled.
  (No existing script or project.godot replacement needed.)

OPTIONAL QUEST FILE:
  Data/Quests/follow_litik_to_second_town.tres
  Copy it only if you did not already install the Litik continuation pack.
  The Litik portal/dialogue also require the rest of that previous pack.

HOW TO USE:
  Run game from Godot (debug build).
  In gameplay press F10. Pick a checkpoint. Click Jump, then Confirm.
  The system resets *main story* progress to the selected quest.
  Earlier main quests show completed in the Quest Log.
  Unrelated side quests and dialogue flags are kept where possible.
  The appropriate story flags and known learned language entries are applied.
  Game loads FirstTown or Forest and spawns near the objective.

EXAMPLES:
  - Get Mystic Ylang-Ylang: Guardian still alive.
  - Mystic Ylang-Ylang — Guardian already defeated: skip boss and collect flower.
  - Follow Litik to the Next Town: flower/Guardian already finished; route quest active.
  - Reach Forest: earlier Chief final battle finished and gate unlocked.
  - Ask Ale: Chief travel quest remains active, so Ale cutscene can fire.

IMPORTANT SAFETY:
  * DEBUG BUILDS ONLY. Menu does not work in release builds.
  * DEBUG JUMPS CHANGE GAME STATE AND CAN AUTOSAVE TO THE CURRENT ACCOUNT,
    INCLUDING SUPABASE. USE A THROWAWAY TEST ACCOUNT.
  * This fast-forward marks quests complete; it does not retroactively award
    skipped quest gold/EXP or undo previously learned words / equipment.
  * FirstTown and Forest spawning use verified project nodes and forest
    coordinates. If terrain has changed, adjust the three Forest positions
    at the bottom of QuestCheckpointDebug.gd.
  * The new Litik second-town quest cannot load the next map yet because
    SecondTown.tscn is not in the repository.
  * Existing map teleport shortcuts are unchanged.

VALIDATION: checked against currently pushed QuestManager, GameManager,
TimeManager, LanguageProgress, Main.gd and quest resources. Static checks only:
Godot runtime compiler not available here. Test F10 -> After Guardian ->
flower collection -> Litik, then F10 -> Follow Litik -> portal.
