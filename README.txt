MABIYASA SECOND TOWN — MERCHANT LESSON HANDOFF FIX
===================================================
DIRECT REPLACEMENT FILES. No Python command is required.

1. Make a backup/commit of your project.
2. Extract the ZIP contents into your project folder (where project.godot is).
3. Replace matching files, then restart Godot.
4. Play the merchant conversation until its dialogue box closes.

After the final conversation line, the visual counting lesson should open:
METUNG -> 1 basket; ADWA -> 2 baskets; ATLU -> 3 baskets.
Player can go back to review the numbers or proceed with deliveries.
Then Berto (1), Mila (2), Nena (3), and finally merchant turn-in.

WHAT WAS CHANGED
The merchant controller now listens to the GameEvents.npc_talked event
emitted by DialogueManager after an NPC conversation finishes. This gives
it a reliable fallback instead of depending only on a Dialogic [signal].
It retains a queued request until dialogue and exploration state are ready.
SecondTownQuestController also confirms the merchant controller is attached.

IF IT STILL DOESN'T DISPLAY
Open Godot > Debugger > Errors / Output and check for these lines:
[SECOND TOWN] Attached merchant-delivery controller
[MERCHANT] Delivery controller ready; listening for NPC conversations
[MERCHANT] Finished talking to Merchant; opening action: lesson
[MERCHANT] Launching visual panel: lesson
Send any related red errors or missing lines so we can pinpoint the block.

NOTE
These files were checked against the previous replacement package; Godot
runtime was not available, so the in-game result is not yet verified.
