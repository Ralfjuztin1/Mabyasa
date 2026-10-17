# Mabyasa First Town Dialogic Draft

These `.dtl` timelines were written to match the line, label, choice, wait, signal, jump, and `[end_timeline]` conventions found in the current Mabyasa repository.

## Files

- `meeting_apu.dtl` — replacement for the current Apu meeting scene. Starts the basket-delivery quest.
- `bebang_basket_return.dtl` — basket return and gratitude lesson.
- `chief_afternoon_intro.dtl` — Chief's afternoon greeting and gear objective.
- `blacksmith_gear_and_quiz.dtl` — collect gear, then answer the gratitude mini-quiz.
- `chief_training_start.dtl` — dialogue immediately before the first training battle.
- `chief_after_training.dtl` — post-battle dialogue and evening-transition request.
- `ima_evening_greeting.dtl` — evening greeting lesson and sleep-transition request.
- `ima_morning_greeting.dtl` — next morning greeting and final-training unlock.
- `narrow_path.dtl` — replacement for the existing narrow-path timeline; Litik teaches `Makilabas ku pu` and Ale moves aside.
- `chief_final_training.dtl` — dialogue before the final training battle near the forest entrance.

## Suggested placement

Copy the files into:
`Scenes/Characters/NPC/Dialogic/FirstTownSceneDialogues/`

`meeting_apu.dtl` and `narrow_path.dtl` are intended to replace files with those names. Add the other files as new timelines. Then assign the appropriate `.dtl` paths to the matching NPC dialogue entries, with conditions/priority so the NPC advances through the sequence at the right point.

## Important integration notes

This is dialogue content, not a complete quest/time/battle implementation. The current `DialogueManager` recognizes `start_`, `set_flag_`, `encounter_`, and `learn_` signals. The files use those conventions.

- `start_deliver_bebang_basket` and `start_get_training_gear` require matching `QuestData` resources in `Data/Quests/`. These quest resources do not come in this dialogue-only draft.
- The flags `training_gear_ready`, `training_gear_received`, `training_battle_requested`, `request_time_evening`, `sleep_transition_requested`, `final_training_unlocked`, `ale_path_cleared`, and `final_training_battle_requested` are set by dialogue. Game logic still needs to watch those flags and grant gear, launch battles, or change time/fade screens as appropriate.
- Trigger `chief_after_training.dtl` only after the first training battle is won. Trigger `ima_evening_greeting.dtl` after returning home in evening. After the sleep transition, trigger `ima_morning_greeting.dtl` in the morning. Trigger `chief_final_training.dtl` after the Ale path scene, then start the final battle after that timeline ends.
- The blacksmith dialogue sets a gear-ready flag; it does not itself add equipment to inventory.
- The phrase signals mark words/phrases encountered or learned using the project's existing vocabulary IDs.

## DTL syntax note

The repo's current timelines encode signal events using nested signal text, for example `[signal arg="[signal arg="encounter_mayap_a_abak"]"]`. These files intentionally follow that existing pattern. If your installed Dialogic version or editor rewrites these events differently, compare the serialized signal event in a working timeline before bulk-editing them.

Review the narrative and event wiring before replacing the working project files. This archive does not change the GitHub repository.
