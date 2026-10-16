extends Node

## Owns first-time spotlight tutorials and their per-account flags.
## Register this script as an Autoload named UITutorialManager.

const SPOTLIGHT_TUTORIAL_SCRIPT = preload("res://Scenes/UI/ScreenshotTutorial.gd")

const TUTORIALS: Dictionary = {
	"exploration_hud": {
		"title": "EXPLORATION HUD",
		"pages": [
			{
				"title": "Current Quest",
				"description": "Your active quest and next objective appear here. Check this panel when you are unsure what to do next.",
				"target_names": ["QuestPanel"]
			},
			{
				"title": "Character Status",
				"description": "This panel shows your level, gold, HP, and EXP. Keep an eye on your HP before heading into a fight.",
				"target_names": ["StatusPanel"]
			},
			{
				"title": "Quick Access",
				"description": "Use these shortcuts to open the Wordbook and Quest Log. The keys shown on each button are alternate shortcuts.",
				"target_names": ["ShortcutBar"]
			},
			{
				"title": "Your Location",
				"description": "This label tells you which area you are currently exploring.",
				"target_names": ["LocationPanel"]
			}
		]
	},
	"dialogue": {
		"title": "DIALOGUE",
		"pages": [
			{
				"title": "Read the Dialogue",
				"description": "The NPC's words appear here. Click or press the dialogue advance input to continue reading.",
				"target_names": ["DialogTextPanel", "DialogicNode_DialogText"]
			},
			{
				"title": "Who Is Speaking?",
				"description": "The name above the dialogue tells you who is speaking. Some important Kapampangan words may be highlighted for learning.",
				"target_names": ["DialogicNode_NameLabel", "NameLabelPanel"]
			},
			{
				"title": "Choose a Response",
				"description": "When response choices appear, select the answer that best matches what you want to say. Some choices can affect what the NPC tells you.",
				"target_names": ["NextIndicator", "DialogTextPanel"]
			}
		]
	},
	"hoverable": {
		"title": "HOVER OVER WORDS",
		"pages": [
			{
				"title": "Discover Word Meanings",
				"description": "Move your cursor over a highlighted Kapampangan word during dialogue to open its glossary popup and read its meaning.",
				"target_names": ["DialogicNode_DialogText"]
			}
		]
	},
	"normal_battle": {
		"title": "NORMAL BATTLE",
		"pages": [
			{
				"title": "Attack",
				"description": "Press Attack to begin your turn. Your attack may start a Kapampangan quiz, and correct answers can improve your damage.",
				"target_names": ["AttackButton"]
			},
			{
				"title": "Enemy Status",
				"description": "Watch the enemy's HP and barrier. Reduce its HP to zero to win the battle.",
				"target_names": ["EnemyInfoBox"]
			},
			{
				"title": "Your Status",
				"description": "Your HP and EXP are displayed here. If your HP reaches zero, you lose the battle.",
				"target_names": ["PlayerInfoBox"]
			},
			{
				"title": "Food Bag",
				"description": "Use available food items to recover health or gain their effects. The button also shows the available food count.",
				"target_names": ["PotionButton"]
			},
			{
				"title": "Flee",
				"description": "Use Flee to attempt to leave a normal battle. Fleeing is not available in every encounter.",
				"target_names": ["FleeButton"]
			}
		]
	},
	"quiz": {
		"title": "BATTLE QUIZ",
		"pages": [
			{
				"title": "Read the Question",
				"description": "Read the question and the instructions carefully before answering. The quiz timer may limit how long you have.",
				"target_names": ["PromptLabel"]
			},
			{
				"title": "Answer Area",
				"description": "Choose the best answer, complete the missing word, translate the phrase, or match pairs. The layout changes depending on the quiz type.",
				"target_names": ["AnswerGrid", "MatchRoot", "SentenceRoot"]
			},
			{
				"title": "Time Limit",
				"description": "Keep an eye on the timer and submit your answer before time runs out.",
				"target_names": ["TimerBar", "TimerLabel"]
			}
		]
	},
	"boss_battle": {
		"title": "BOSS BATTLE",
		"pages": [
			{
				"title": "Begin Your Attack",
				"description": "Boss battles use sentence-building challenges. Press Attack to open the word-building challenge, then arrange the words to form a sentence.",
				"target_names": ["AttackButton"]
			},
			{
				"title": "Boss Status",
				"description": "Bosses can have more health or a barrier. Check the boss's HP and barrier before choosing your next move.",
				"target_names": ["EnemyInfoBox"]
			},
			{
				"title": "Protect Your HP",
				"description": "Keep your own HP in view. Use food when needed and focus on building a correct sentence to make your attack count.",
				"target_names": ["PlayerInfoBox", "PotionButton"]
			}
		]
	},
	"quest_log": {
		"title": "QUEST LOG",
		"pages": [
			{
				"title": "Quest Filters",
				"description": "Use these filters to view all discovered quests, active quests, or completed quests.",
				"target_names": ["AllButton"]
			},
			{
				"title": "Quest List",
				"description": "Select a quest from this list to read its details. If the list is empty, you have not discovered any quests in this category yet.",
				"target_names": ["QuestListScroll"]
			},
			{
				"title": "Quest Details",
				"description": "The selected quest's title and description appear here. Read them to understand the task and its goal.",
				"target_names": ["DetailPanel"]
			},
			{
				"title": "Objectives and Rewards",
				"description": "Check the objectives to see what remains to be done. Rewards are shown near the bottom when the quest offers them.",
				"target_names": ["ObjectivesScroll", "RewardsRow"]
			},
			{
				"title": "Close the Quest Log",
				"description": "Use Close or press Escape to return to exploration.",
				"target_names": ["CloseButton"]
			}
		]
	},
	"wordbook": {
		"title": "WORDBOOK",
		"pages": [
			{
				"title": "Search Words",
				"description": "Search for a Kapampangan word or an English meaning using this field.",
				"target_names": ["SearchEdit"]
			},
			{
				"title": "Filter Your Words",
				"description": "Use the status filters and category chips to narrow down the words in your collection.",
				"target_names": ["StatusPanel", "CategoryFlow"]
			},
			{
				"title": "Your Word List",
				"description": "Select a word from the list to see its meaning and details. Words are collected as you encounter them in the game.",
				"target_names": ["VocabularyListFrame"]
			},
			{
				"title": "Word Details and Progress",
				"description": "The detail panel can show meaning, pronunciation, how a phrase is built, usage notes, and learning progress.",
				"target_names": ["EntryDetailFrame"]
			}
		]
	}
}


## Each account starts with every UI tutorial unseen.
var _seen_flags: Dictionary = {
	"exploration_hud": false,
	"dialogue": false,
	"hoverable": false,
	"normal_battle": false,
	"quiz": false,
	"boss_battle": false,
	"quest_log": false,
	"wordbook": false
}

var _queue: Array[String] = []
var _active_overlay: CanvasLayer = null
var _active_tutorial_id: String = ""
var _sequence_active: bool = false
var _tree_was_paused: bool = false
var _hoverable_request_pending: bool = false
var _hoverable_meta_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(GameEvents) and not GameEvents.npc_talked.is_connected(_on_npc_talked):
		GameEvents.npc_talked.connect(_on_npc_talked)

	if is_instance_valid(BattleManager):
		if not BattleManager.battle_started.is_connected(_on_battle_started):
			BattleManager.battle_started.connect(_on_battle_started)
		if not BattleManager.quiz_requested.is_connected(_on_quiz_requested):
			BattleManager.quiz_requested.connect(_on_quiz_requested)

	# The dialogue tutorial is requested when Dialogic starts a real timeline,
	# so its textbox is actually on-screen to spotlight.
	if is_instance_valid(Dialogic) and Dialogic.has_signal("timeline_started"):
		if not Dialogic.timeline_started.is_connected(_on_dialogue_started):
			Dialogic.timeline_started.connect(_on_dialogue_started)

	# Dialogic emits this when the player first hovers a glossary-tagged word.
	# The glossary popup itself is shown by the active Dialogic layout.
	if is_instance_valid(Dialogic.Text):
		if not Dialogic.Text.meta_hover_started.is_connected(_on_glossary_meta_hover_started):
			Dialogic.Text.meta_hover_started.connect(_on_glossary_meta_hover_started)

	print("[UI TUTORIAL] Spotlight manager ready; all unseen flags default to false.")


# ------------------------------------------------------------------
# FEATURE EVENT HOOKS
# ------------------------------------------------------------------

func _on_npc_talked(npc_id: String) -> void:
	if npc_id.strip_edges().to_lower() != "ima":
		return

	# Ima's first interaction opens the exploration HUD guide.
	# Dialogue is triggered separately at timeline_started so the tutorial
	# can spotlight the actual dialogue UI while it is visible.
	request_tutorial("exploration_hud")


func _on_dialogue_started() -> void:
	# The dialogue/cutscene tutorial must be eligible on the FIRST Dialogic
	# timeline. Do not gate this on exploration_hud: the opening cutscene can
	# start Dialogic directly and does not necessarily emit npc_talked.
	request_tutorial("dialogue")


func _on_glossary_meta_hover_started(meta: String) -> void:
	# Only teach hovering when an actual glossary entry is hovered, not for
	# arbitrary Dialogic metadata. The active glossary layer also listens to
	# this signal and needs a frame to display its popup before we spotlight it.
	if not is_instance_valid(Dialogic) or not is_instance_valid(Dialogic.Glossary):
		return

	var entry_info: Dictionary = Dialogic.Glossary.get_entry(meta)
	if entry_info.is_empty():
		return

	if (
		is_tutorial_seen("hoverable")
		or _active_tutorial_id == "hoverable"
		or _queue.has("hoverable")
		or _hoverable_request_pending
	):
		return

	# Remember the exact glossary entry being hovered. The overlay uses this
	# key to frame the linked word in the Dialogic RichTextLabel, not the NPC
	# or the glossary popup panel.
	_hoverable_meta_key = meta
	_hoverable_request_pending = true
	call_deferred("_request_hoverable_after_popup_layout")


func _request_hoverable_after_popup_layout() -> void:
	# Allow Dialogic's own meta_hover_started handler to show and lay out the
	# glossary popup before ScreenshotTutorial searches for it.
	await get_tree().process_frame
	await get_tree().process_frame
	_hoverable_request_pending = false
	if not is_tutorial_seen("hoverable"):
		request_tutorial("hoverable")


func _on_battle_started(enemy_data: Variant) -> void:
	if enemy_data == null:
		return

	var tutorial_id := "normal_battle"
	if enemy_data is Object and bool(enemy_data.get("is_boss")):
		tutorial_id = "boss_battle"

	request_tutorial(tutorial_id)


func _on_quiz_requested(_question: Variant) -> void:
	request_tutorial("quiz")


# ------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------

func request_tutorial(tutorial_id: String) -> bool:
	if not TUTORIALS.has(tutorial_id):
		push_warning("[UI TUTORIAL] Unknown tutorial ID: " + tutorial_id)
		return false

	if is_tutorial_seen(tutorial_id):
		return false

	if tutorial_id == _active_tutorial_id or _queue.has(tutorial_id):
		return true

	if not _sequence_active:
		_sequence_active = true
		_tree_was_paused = get_tree().paused

	_queue.append(tutorial_id)
	print("[UI TUTORIAL] Queued spotlight: ", tutorial_id)

	if not is_instance_valid(_active_overlay):
		call_deferred("_start_next_tutorial")

	return true


func request_tutorial_sequence(tutorial_ids: Array) -> void:
	for raw_id: Variant in tutorial_ids:
		request_tutorial(str(raw_id))


func is_tutorial_seen(tutorial_id: String) -> bool:
	return bool(_seen_flags.get(tutorial_id, false))


func get_save_data() -> Dictionary:
	return _seen_flags.duplicate(true)


func load_save_data(data: Dictionary) -> void:
	# Reset flags first so account switching cannot carry another user's state.
	for tutorial_id: String in _seen_flags.keys():
		_seen_flags[tutorial_id] = bool(data.get(tutorial_id, false))
	print("[UI TUTORIAL] Account flags loaded: ", _seen_flags)


func reset_tutorial_flags_for_testing() -> void:
	for tutorial_id: String in _seen_flags.keys():
		_seen_flags[tutorial_id] = false
	_queue.clear()
	_save_flags_now()
	print("[UI TUTORIAL] Reset all spotlight flags for testing.")


# ------------------------------------------------------------------
# OVERLAY SEQUENCE
# ------------------------------------------------------------------

func _start_next_tutorial() -> void:
	if is_instance_valid(_active_overlay):
		return

	while not _queue.is_empty():
		var tutorial_id: String = _queue.pop_front()
		if is_tutorial_seen(tutorial_id):
			continue

		var definition: Dictionary = TUTORIALS[tutorial_id]
		var pages: Array = definition.get("pages", [])
		if pages.is_empty():
			push_warning("[UI TUTORIAL] No spotlight pages configured for: " + tutorial_id)
			continue

		var overlay := SPOTLIGHT_TUTORIAL_SCRIPT.new() as CanvasLayer
		if overlay == null:
			push_error("[UI TUTORIAL] Could not create spotlight overlay.")
			continue

		overlay.name = "SpotlightTutorial_" + tutorial_id
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		overlay.set("tutorial_id", tutorial_id)
		overlay.set("tutorial_title", str(definition.get("title", tutorial_id)))
		overlay.set("page_data", pages.duplicate(true))
		if tutorial_id == "hoverable":
			overlay.set("hoverable_meta_key", _hoverable_meta_key)
		overlay.finished.connect(_on_overlay_finished)

		_active_overlay = overlay
		_active_tutorial_id = tutorial_id

		get_tree().root.add_child(overlay)
		get_tree().paused = true
		overlay.call_deferred("begin_tutorial")

		print("[UI TUTORIAL] Showing spotlight tutorial: ", tutorial_id)
		return

	_finish_sequence()


func _on_overlay_finished(tutorial_id: String) -> void:
	if tutorial_id.is_empty():
		tutorial_id = _active_tutorial_id

	if _seen_flags.has(tutorial_id):
		_seen_flags[tutorial_id] = true
		_save_flags_now()
		print("[UI TUTORIAL] Marked seen and saved: ", tutorial_id)

	_active_overlay = null
	_active_tutorial_id = ""

	# Maintain a paused state between any tutorials that were queued together.
	if not _queue.is_empty():
		call_deferred("_start_next_tutorial")
		return

	_finish_sequence()


func _finish_sequence() -> void:
	_sequence_active = false
	if is_inside_tree():
		get_tree().paused = _tree_was_paused
	_tree_was_paused = false


func _save_flags_now() -> void:
	if not is_instance_valid(SaveManager) or not SaveManager.has_method("save_game"):
		push_warning("[UI TUTORIAL] SaveManager is unavailable; flags were not persisted.")
		return

	var player_node := get_tree().get_first_node_in_group("player")
	if not (player_node is CharacterBody3D):
		push_warning("[UI TUTORIAL] Player was not found; flags remain in memory until the next save.")
		return

	var scene_path := ""
	if is_instance_valid(GameManager):
		scene_path = str(GameManager.current_level_path)
	if scene_path.is_empty() and is_instance_valid(get_tree().current_scene):
		scene_path = get_tree().current_scene.scene_file_path
	if scene_path.is_empty():
		scene_path = "res://Scenes/Main/FirstTown.tscn"

	# SaveManager must write/read the "ui_tutorials" section, as described
	# in the package README. This save happens immediately when a hint closes.
	SaveManager.save_game(player_node as CharacterBody3D, scene_path, false)
