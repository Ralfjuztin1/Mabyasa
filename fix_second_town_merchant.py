#!/usr/bin/env python3
"""One-time MABIYASA Second Town merchant quest repair.

Usage: from the Godot project root, run:
    python path/to/fix_second_town_merchant.py

The script checks EVERY expected source fragment before changing any file.
Review changes with `git diff` before committing. Tested against the
Ralfjuztin1/Mabyasa `main` branch as read on 2026-11-15.
"""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path.cwd() if len(sys.argv) == 1 else Path(sys.argv[1]).resolve()
if not (ROOT / "project.godot").exists():
    raise SystemExit("Run this script from your MABIYASA Godot project folder (containing project.godot).")

edits: dict[str, list[tuple[str, str]]] = {}

def replace(path: str, old: str, new: str):
    edits.setdefault(path, []).append((old, new))

quest = "Data/Quests/st_merchant_orders.tres"
steps = [
    ("Step1", "solve_puzzle", "merchant counting lesson", "second_town_merchant", "solve_puzzle", "merchant counting lesson", "Talk to Merchant"),
    ("Step2", "interact_object", "Berto", "st_berto", "interact_object", "Berto", "Deliver 1 basket to Berto"),
    ("Step3", "interact_object", "Mila", "st_mila", "interact_object", "Mila", "Deliver 2 baskets to Mila"),
    ("Step4", "interact_object", "Nena", "st_nena", "interact_object", "Nena", "Deliver 3 baskets to Nena"),
    ("Step5", "interact_object", "Merchant", "second_town_merchant", "solve_puzzle", "Merchant", "Return to Merchant"),
]
for name, original_type, original_target, npc_id, validation, validation_target, label in steps:
    original = (
        f'[sub_resource type="Resource" id="{name}"]\n'
        'script = ExtResource("3_step")\n'
        f'type = "{original_type}"\n'
        f'target = "{original_target}"\n'
        'required_count = 1\n'
    )
    new = (
        f'[sub_resource type="Resource" id="{name}"]\n'
        'script = ExtResource("3_step")\n'
        'type = "talk_npc"\n'
        f'target = "{npc_id}"\n'
        'required_count = 1\n'
        f'validation_type = "{validation}"\n'
        f'validation_target = "{validation_target}"\n'
        f'objective_text = "{label}"\n'
    )
    replace(quest, original, new)

replace("Scripts/Quest/QuestStep.gd",
    '@export var target: String = ""\n',
    '@export var target: String = ""\n'
    '@export var objective_text: String = "" # Player-facing label; target remains the event ID.\n')

# The active SecondTown scene never instantiated the merchant delivery controller.
scene = "Scenes/Main/SecondTown.tscn"
replace(scene,
    '[ext_resource type="Script" uid="uid://damoiwgbiulyk" path="res://Scripts/SecondTown/SecondTownWellInteraction.gd" id="40_qb2ep"]\n',
    '[ext_resource type="Script" uid="uid://damoiwgbiulyk" path="res://Scripts/SecondTown/SecondTownWellInteraction.gd" id="40_qb2ep"]\n'
    '[ext_resource type="Script" path="res://Scripts/SecondTown/MerchantDeliveryController.gd" id="41_merchant"]\n')
replace(scene,
    '[node name="SecondTownQuests" type="Node" parent="." unique_id=1504503506]\nscript = ExtResource("39_8gg83")\n',
    '[node name="MerchantDelivery" type="Node" parent="."]\nscript = ExtResource("41_merchant")\n\n'
    '[node name="SecondTownQuests" type="Node" parent="." unique_id=1504503506]\nscript = ExtResource("39_8gg83")\n')

# Only MerchantDeliveryController may assign merchant dialogue (formerly overwritten).
town = "Scripts/SecondTown/SecondTownQuestController.gd"
replace(town,
    '\t_set_npc_dialogue(npc_root, "merchant",\n'
    '\t\t"merchant_done" if QuestManager.is_quest_completed(QUEST_MERCHANT) else "merchant_quest")\n\n',
    '\t# Merchant dialogue belongs to MerchantDeliveryController, which tracks\n'
    '\t# its lesson, three deliveries, and turn-in state.\n\n')
replace(town,
    '\tif not QUESTS.has(chapter):\n\t\treturn\n\tvar quest_id: String = str(QUESTS[chapter])\n',
    '\tif chapter == "merchant" or not QUESTS.has(chapter):\n'
    '\t\treturn\n\tvar quest_id: String = str(QUESTS[chapter])\n')

merchant = "Scripts/SecondTown/MerchantDeliveryController.gd"
replace(merchant,
    'const UI: PackedScene = preload("res://Scenes/SecondTown/MerchantDeliveryUI.tscn")\n',
    'const UI: PackedScene = preload("res://Scenes/SecondTown/MerchantDeliveryUI.tscn")\n'
    'const BASE_NPC: PackedScene = preload("res://Scenes/Characters/NPC/BaseNPC.tscn")\n'
    'const NPC_ANIMATIONS: Array[String] = [\n'
    '\t"idle_front", "idle_back", "idle_left", "idle_right",\n'
    '\t"walk_front", "walk_back", "walk_left", "walk_right"\n'
    ']\n')
replace(merchant,
    '\t{"id": "berto", "name": "Berto", "count": 1, "event": "Berto"},\n'
    '\t{"id": "mila", "name": "Mila", "count": 2, "event": "Mila"},\n'
    '\t{"id": "nena", "name": "Nena", "count": 3, "event": "Nena"}\n',
    '\t{"id": "berto", "name": "Berto", "count": 1, "event": "Berto", "position": Vector3(-48.0, 0.60, 17.0)},\n'
    '\t{"id": "mila", "name": "Mila", "count": 2, "event": "Mila", "position": Vector3(-26.0, 0.60, 12.0)},\n'
    '\t{"id": "nena", "name": "Nena", "count": 3, "event": "Nena", "position": Vector3(6.0, 0.60, 12.0)}\n')
replace(merchant,
    'func _ready() -> void:\n\tDialogic.signal_event.connect(_on_dialogic_signal)\n',
    'func _ready() -> void:\n'
    '\t_ensure_delivery_npcs()\n'
    '\tDialogic.signal_event.connect(_on_dialogic_signal)\n')
replace(merchant,
    'func _initialize_delivery_quest() -> void:\n',
    '''# The shipping scene currently has only Merchant, Farmer and Elder. Create
# the delivery recipients at runtime so fresh and existing town saves work.
func _ensure_delivery_npcs() -> void:
	var npc_root: Node3D = get_parent().get_node_or_null("npc") as Node3D
	if not is_instance_valid(npc_root):
		push_error("[MERCHANT] SecondTown/npc is missing; deliveries cannot spawn.")
		return
	for entry: Dictionary in TARGETS:
		var npc_key: String = str(entry["id"])
		if npc_root.get_node_or_null(npc_key) != null:
			continue
		var npc: CharacterBody3D = BASE_NPC.instantiate() as CharacterBody3D
		if npc == null:
			push_error("[MERCHANT] BaseNPC scene could not be instantiated.")
			return
		npc.name = npc_key
		npc.position = entry["position"]
		npc.set("npc_name", str(entry["name"]))
		npc.set("npc_id", "st_" + npc_key)
		npc.set("dialogue_id", DIALOGUE_FOLDER + "st_delivery_" + npc_key + "_wait")
		npc.set("dialogue_entries", [])
		npc.set("can_wander", false)
		var sprite_path: String = "res://Assets/SecondTown/" + npc_key + "_placeholder.png"
		if ResourceLoader.exists(sprite_path):
			var art: Texture2D = load(sprite_path) as Texture2D
			if art != null:
				var frames: SpriteFrames = SpriteFrames.new()
				if frames.has_animation(&"default"):
					frames.remove_animation(&"default")
				for animation_name: String in NPC_ANIMATIONS:
					frames.add_animation(animation_name)
					frames.set_animation_loop(animation_name, true)
					frames.set_animation_speed(animation_name, 5.0)
					frames.add_frame(animation_name, art)
				npc.set("npc_frames", frames)
		else:
			push_warning("[MERCHANT] Missing NPC sprite: " + sprite_path)
		npc_root.add_child(npc)
		print("[MERCHANT] Spawned delivery recipient: ", npc_key)


func _initialize_delivery_quest() -> void:
''')
replace(merchant,
    '\tif QuestManager.is_quest_completed(QUEST_ID):\n\t\t_update_npc_dialogues()\n\t\treturn\n\n'
    '\t# A previous local version used this same ID for a 1-step sorting quiz.\n',
    '\tif QuestManager.is_quest_completed(QUEST_ID):\n\t\t_update_npc_dialogues()\n\t\treturn\n\n'
    '\t# Do not activate the merchant quest until Litik\'s arrival cutscene.\n'
    '\t# SecondTownQuestController starts the chain after that flag.\n'
    '\tif not QuestManager.has_dialogue_flag("st_litik_arrival_seen"):\n'
    '\t\t_update_npc_dialogues()\n\t\treturn\n\n'
    '\t# A previous local version used this same ID for a 1-step sorting quiz.\n')

ui = "Scripts/SecondTown/MerchantDeliveryUI.gd"
replace(ui,
    'func _redraw() -> void:\n',
    '''# A recipient can review all three words without losing their delivery.
func _review_numbers() -> void:
	_mode = "review"
	_page = 0
	_redraw()


func _resume_delivery() -> void:
	_mode = "delivery"
	_redraw()


func _restart_numbers() -> void:
	_page = 0
	_redraw()


func _redraw() -> void:
''')
replace(ui,
    '\tif _mode == "lesson":\n\t\t_redraw_lesson()\n',
    '\tif _mode == "lesson" or _mode == "review":\n\t\t_redraw_lesson()\n')
replace(ui,
    '\t_heading.text = "MERCHANT  /  LEARN THE NUMBERS"\n',
    '\t_heading.text = "NUMBER REVIEW" if _mode == "review" else "MERCHANT  /  LEARN THE NUMBERS"\n')
replace(ui,
    '''	if _page > 0:
		_add_button("‹ PREVIOUS", _previous)
	_add_button("NEXT ›" if _page < 2 else "TAKE THE DELIVERIES ›", _next, true)
	_add_button("LEAVE", _exit)
''',
    '''	if _page > 0:
		_add_button("‹ PREVIOUS", _previous)
	if _page < 2:
		_add_button("NEXT ›", _next, true)
	else:
		_add_button("REVIEW FROM METUNG", _restart_numbers)
		_add_button("BACK TO DELIVERY" if _mode == "review" else "START DELIVERIES ›", _next, true)
	if _mode == "review":
		if _page < 2:
			_add_button("BACK TO DELIVERY", _resume_delivery)
	else:
		_add_button("LEAVE", _exit)
''')
replace(ui,
    '''	if _page < 2:
		_page += 1
		_redraw()
		return
	if not _complete:
''',
    '''	if _page < 2:
		_page += 1
		_redraw()
		return
	if _mode == "review":
		_resume_delivery()
		return
	if not _complete:
''')
replace(ui,
    '\t_add_button("CONFIRM DELIVERY", _confirm, true)\n\t_add_button("CANCEL", _exit)\n',
    '\t_add_button("CONFIRM DELIVERY", _confirm, true)\n'
    '\t_add_button("REVIEW NUMBERS", _review_numbers)\n'
    '\t_add_button("CANCEL", _exit)\n')

# Prefer the quest resource's readable objective label over its internal ID.
for path in ["Scenes/UI/QuestUI.gd", "Scenes/UI/QuestLog.gd"]:
    replace(path,
        'func _get_objective_text(step: QuestStep) -> String:\n',
        'func _get_objective_text(step: QuestStep) -> String:\n'
        '\tif not step.objective_text.strip_edges().is_empty():\n'
        '\t\treturn step.objective_text\n')
replace("Scenes/UI/QuestMultiTrackHUD.gd",
    '\t\tvar step: QuestStep = quest.steps[index]\n'
    '\t\tif step == null:\n'
    '\t\t\tcontinue\n'
    '\t\tvar target: String =',
    '\t\tvar step: QuestStep = quest.steps[index]\n'
    '\t\tif step == null:\n'
    '\t\t\tcontinue\n'
    '\t\tif not step.objective_text.strip_edges().is_empty():\n'
    '\t\t\treturn step.objective_text\n'
    '\t\tvar target: String =')
replace("Scripts/Quest/QuestWaypointController.gd",
    'func _format_hud_objective(step: QuestStep) -> String:\n',
    'func _format_hud_objective(step: QuestStep) -> String:\n'
    '\tif not step.objective_text.strip_edges().is_empty():\n'
    '\t\treturn step.objective_text\n')

# Presentation strings, not quest IDs: make all three quest displays readable.
for path in ["Scenes/UI/QuestUI.gd", "Scenes/UI/QuestLog.gd"]:
    replace(path,
        '\treturn target.replace("_", " ").capitalize()\n',
        '\tvar readable: String = target.strip_edges().trim_prefix("second_town_").trim_prefix("st_")\n'
        '\treturn readable.replace("_", " ").capitalize()\n')
replace("Scenes/UI/QuestMultiTrackHUD.gd",
    '\t\tvar target: String = step.target.replace("_", " ").capitalize()\n',
    '\t\tvar target: String = step.target.trim_prefix("second_town_").trim_prefix("st_").replace("_", " ").capitalize()\n')
replace("Scripts/Quest/QuestWaypointController.gd",
    '\tvar target := (\n\t\tstep.target\n\t\t.strip_edges()\n\t\t.replace("_", " ")\n',
    '\tvar target_id: String = step.target.strip_edges().trim_prefix("second_town_").trim_prefix("st_")\n'
    '\tvar target := (\n\t\ttarget_id\n\t\t.replace("_", " ")\n')

# Validate every file, every replacement, and then commit all changes.
output: dict[Path, str] = {}
for rel, changes in edits.items():
    path = ROOT / rel
    if not path.is_file():
        raise SystemExit(f"ABORT (no files changed): missing {rel}")
    data = path.read_text(encoding="utf-8")
    for old, new in changes:
        hits = data.count(old)
        if hits != 1:
            raise SystemExit(
                f"ABORT (no files changed): {rel}: expected one copy of change anchor, found {hits}. "
                "Your local branch differs from the inspected version."
            )
        data = data.replace(old, new, 1)
    output[path] = data

for path, data in output.items():
    path.write_text(data, encoding="utf-8", newline="\n")
    print("FIXED:", path.relative_to(ROOT))
print("\nSecond Town merchant fix applied. Review `git diff` and test in Godot before pushing.")
