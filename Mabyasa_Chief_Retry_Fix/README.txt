MABYASA - CHIEF TRAINING RETRY FIX (PATCH CORRECTED)

The previous archive had a malformed patch hunk count. This archive corrects that formatting error.

Install from your MABYASA project root (the folder containing project.godot):

1. Extract this updated ZIP. If Windows asks whether to replace the existing Mabyasa_Chief_Retry_Fix folder, choose Replace.
2. Copy Mabyasa_Chief_Retry_Fix/Scripts/World/HealingTreeQuestBridge.gd to Scripts/World/HealingTreeQuestBridge.gd, replacing the existing bridge script. Keep FirstTown.tscn's Bigtree/Area3D using res://Scripts/World/HealingTreeQuestBridge.gd.
3. Check the patch:

   git apply --check Mabyasa_Chief_Retry_Fix/Scripts/Managers/chief_retry_fix.patch

4. Only if the check succeeds, apply it:

   git apply Mabyasa_Chief_Retry_Fix/Scripts/Managers/chief_retry_fix.patch

5. Verify:

   git diff -- Scripts/Managers/DialogueManager.gd Scripts/World/HealingTreeQuestBridge.gd

What it does:
- Big Tree healing clears the Chief loss state and sets chief_training_healed = true.
- When Chief's retry dialogue (chief_training_start) ends after healing, DialogueManager re-arms training_battle_requested and resets the battle-start state so the battle can begin again.
- It does not change the normal post-victory flow.

If git apply --check still says the patch does not apply, do not force it. That means your local DialogueManager.gd differs from the context in this patch. Open Scripts/Managers/DialogueManager.gd, find `var finished_npc: Node = current_npc` inside `_on_dialogue_ended()`, and insert the added block from the patch immediately below that line, before `var should_start_chief_training: bool = (`.

Not tested in Godot. Test: lose to Chief -> heal at Big Tree -> talk to Chief -> finish dialogue -> battle should restart.
