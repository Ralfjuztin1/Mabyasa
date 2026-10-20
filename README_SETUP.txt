MABYASA - FOREST MILESTONE SETUP
================================

This package adds a playable Forest objective using the current project's
existing QuestManager, GameEvents, Dialogic, Enemy.gd, and Main scene loader.
It does NOT overwrite Forest.tscn or the existing terrain.

BEFORE YOU START
----------------
1. Make a backup or commit your current project in Git.
2. Extract this zip into the Mabyasa project root, beside project.godot.
   Allow folders to merge. Do not extract it into a new nested Mabyasa folder.
3. Copy the included forest.gd over:
   Scenes/Main/forest.gd
4. Open DialogueManager_add_method.txt and append that function to the bottom
   of Scripts/Managers/DialogueManager.gd. It must be outside other functions.
5. Let Godot import/re-scan the new files before running.

ADD THESE SCENES TO THE EXISTING FOREST
---------------------------------------
Open Scenes/Main/Forest.tscn. Keep all existing terrain and nodes. Instance the
following scenes as children of the Forest root node. Position each one using
the 3D editor so the triggers sit just above the ground.

A) RETURN TO FIRSTTOWN
   Scene: Scenes/World/ForestReturnPortal.tscn
   Put it near the Forest entrance, but not directly on the DefaultSpawn marker.
   It loads Scenes/Main/FirstTown.tscn at the existing FirstTown marker named
   ForestGateReturnPoint.

B) ROUTE TO TOWN 2 (TEMPORARILY LOCKED)
   Scene: Scenes/World/ForestSecondTownPortal.tscn
   Place it at the far end of the Forest, away from the entrance.
   Before the flower is obtained, Litik explains that the party must find it
   first. After obtaining it, the portal checks for Scenes/Main/SecondTown.tscn.
   Since that scene does not exist yet, it plays a temporary dialogue instead
   of trying to load a missing scene. Once you create SecondTown.tscn, the
   portal will use its DefaultSpawn marker automatically.

C) NORMAL ENEMIES
   Instance Scenes/Characters/NPC/Enemy/ForestWildBoar.tscn 4-6 times.
   Scatter them along paths and in clearings. Keep the first one a short walk
   from the entrance, and leave the space around DefaultSpawn safe. Spread them
   out so their detection areas do not overlap too heavily.

D) YLANG-YLANG GUARDIAN
   Instance Scenes/Characters/NPC/Enemy/ForestYlangGuardian.tscn near the
   clearing where you want the Mystic Ylang-Ylang to be found. The guardian
   remembers its defeat through a QuestManager dialogue flag, so it will not
   respawn after the player leaves and re-enters the Forest.

E) MYSTIC YLANG-YLANG
   Instance Scenes/World/MysticYlangYlang.tscn in the clearing behind/near the
   guardian. The collectible uses a simple glowing yellow-flower placeholder
   built from 3D meshes, so you can replace its visuals with your preferred
   model later. It cannot be collected until the guardian is defeated.

F) PLACEMENT TIPS
   - Put all five types of instances directly under the Forest root for easy
     navigation in the Scene tree.
   - Leave enough room between the entrance, normal enemies, guardian, flower,
     and Town 2 portal.
   - The forest has a DefaultSpawn marker near the entrance. Use it as your
     spatial reference, but place the return portal a little away from it so
     the player does not immediately trigger the portal on arrival.

WHAT THE SYSTEM DOES
--------------------
- When Forest loads, forest.gd starts the "Find the Mystic Ylang-Ylang" quest.
- The old "Enter the Forest" quest event is preserved and still emits the
  location_reached("forest") event after terrain initialization.
- Normal boars trigger the project's existing touch-activated battle system.
- Winning the Forest guardian battle sets forest_ylang_guardian_defeated.
- Touching the Mystic Ylang-Ylang before defeating the guardian plays a Litik
  warning. After victory, touching the flower sets mystic_ylang_ylang_obtained,
  emits item_collected("mystic_ylang_ylang"), and completes the new quest.
- Touching the Town 2 portal before getting the flower plays Litik's warning.
- After getting the flower, the portal won't try to load Town 2 until the scene
  exists, so no invalid-scene transition occurs.
- The return portal loads FirstTown at ForestGateReturnPoint.

TEST ORDER
----------
1. Run the game and enter Forest. Confirm "Find the Mystic Ylang-Ylang" starts.
2. Touch a normal boar. Confirm the battle starts and victory removes the boar.
3. Touch the Town 2 portal before getting the flower. Confirm Litik stops you.
4. Try to collect the flower before the boss. Confirm the guardian warning plays
   and the flower stays in place.
5. Defeat the guardian and collect the flower. Confirm the quest completes.
6. Use the Town 2 portal. Confirm it explains SecondTown.tscn is not made yet.
7. Use the return portal. Confirm FirstTown loads near ForestGateReturnPoint.
8. Return to Forest and confirm the guardian and collected flower stay gone.

NOTES
-----
- The new files were prepared against the remote repository's current main-branch
  structure, but have not been run inside Godot. Test on a project backup first.
- New portals are Area3D triggers; their torus rings provide a visible placeholder.
- If your player uses a collision layer other than 1, update collision_mask on
  the two portal scenes and MysticYlangYlang.tscn to include the player layer.
- The Town 2 portal is already wired for res://Scenes/Main/SecondTown.tscn and
  DefaultSpawn, but that target scene must be created before real travel is possible.
