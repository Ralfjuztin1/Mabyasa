MABIYASA - Merchant sprite visibility fix
Latest code inspected: b488d0a (merchant sprite not appearing)

Replacement file:
Scripts/SecondTown/NPCSpritePlaceholder.gd

Extract this ZIP to your MABYASA project root (contains project.godot),
and overwrite the matching file. Restart Godot and play the second town.

Diagnosis:
The merchant has working idle atlas frames, but its original mesh is
hidden as soon as a sprite is added. The inherited AnimatedSprite3D
was almost at the ground (local Y 0.013). This fix lifts and slightly
scales only the merchant's sprite, makes it unshaded and visible.

No scene layout, NPC identity, dialogue, quest, or delivery code changes.
If still invisible, inspect the running Remote scene's merchant/
AnimatedSprite3D and Godot Debugger > Errors.
