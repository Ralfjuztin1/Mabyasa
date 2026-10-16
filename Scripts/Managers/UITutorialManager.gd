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
var _text_tutorial_request_pending: bool = false
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

	# Wait for a line to finish revealing before opening a dialogue tutorial.
	# timeline_started fires too early: Dialogic has not necessarily drawn the
	# first line at that point. text_finished guarantees the RichTextLabel has
	# revealed the complete line before the game is paused for the overlay.
	if is_instance_valid(Dialogic) and is_instance_valid(Dialogic.Text):
		if Dialogic.Text.has_signal("text_finished"):
			if not Dialogic.Text.text_finished.is_connected(_on_dialogic_text_finished):
				Dialogic.Text.text_finished.connect(_on_dialogic_text_finished)

	print("[UI TUTORIAL] Spotlight manager ready; all unseen flags default to false.")


# ------------------------------------------------------------------
# FEATURE EVENT HOOKS
# ------------------------------------------------------------------

func _on_npc_talked(npc_id: String) -> void:
	if npc_id.strip_edges().to_lower() != "ima":
		return

	# Ima's first interaction opens the exploration HUD guide.
	# Dialogue guidance is triggered only after Dialogic finishes revealing
	# a line, so the actual text is visible before the overlay pauses gameplay.
	request_tutorial("exploration_hud")


func _on_dialogic_text_finished(info: Dictionary) -> void:
	# Do not pause at timeline_started or while text is being typed. This
	# callback runs only after the current dialogue line is fully revealed.
	if _text_tutorial_request_pending:
		return

	var should_show_dialogue := (
		not is_tutorial_seen("dialogue")
		and _active_tutorial_id != "dialogue"
		and not _queue.has("dialogue")
	)

	var glossary_key := ""
	var should_show_hoverable := false
	if is_instance_valid(Dialogic) and is_instance_valid(Dialogic.Glossary):
		glossary_key = _find_first_glossary_key(str(info.get("text", "")))
		should_show_hoverable = (
			not glossary_key.is_empty()
			and not is_tutorial_seen("hoverable")
			and _active_tutorial_id != "hoverable"
			and not _queue.has("hoverable")
		)

	if not should_show_dialogue and not should_show_hoverable:
		return

	if should_show_hoverable:
		_hoverable_meta_key = glossary_key

	_text_tutorial_request_pending = true
	call_deferred(
		"_request_text_tutorials_after_line_is_visible",
		should_show_dialogue,
		should_show_hoverable
	)


func _find_first_glossary_key(displayed_text: String) -> String:
	# Dialogic Glossary.parse_glossary() wraps valid terms as:
	# [url="entry_key"][color=...]visible word[/color][/url]
	# Check that the key exists in the glossary instead of triggering on any URL.
	var search_from := 0
	var open_tag := '[url="'

	while search_from < displayed_text.length():
		var tag_start := displayed_text.find(open_tag, search_from)
		if tag_start < 0:
			return ""

		var key_start := tag_start + open_tag.length()
		var key_end := displayed_text.find('"]', key_start)
		if key_end < 0:
			return ""

		var glossary_key := displayed_text.substr(key_start, key_end - key_start).strip_edges()
		if not glossary_key.is_empty():
			var entry_info: Dictionary = Dialogic.Glossary.get_entry(glossary_key)
			if not entry_info.is_empty():
				return glossary_key

		search_from = key_end + 2

	return ""


func _request_text_tutorials_after_line_is_visible(
	should_show_dialogue: bool,
	should_show_hoverable: bool
) -> void:
	# Let at least one render frame pass after the final character appears,
	# then leave the line visible briefly before the spotlight pauses gameplay.
	await get_tree().process_frame
	await get_tree().create_timer(0.45, true, false, true).timeout
	_text_tutorial_request_pending = false

	if not is_inside_tree():
		return

	if should_show_dialogue and not is_tutorial_seen("dialogue"):
		request_tutorial("dialogue")

	# Preserve the order: explain the dialogue box first, then explain the
	# glossary hover interaction if this same visible line contains a term.
	if should_show_hoverable and not is_tutorial_seen("hoverable"):
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
