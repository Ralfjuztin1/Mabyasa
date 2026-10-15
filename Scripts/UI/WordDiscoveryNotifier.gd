extends Node

## Connects LanguageProgress's gameplay-only discovery signal to the toast UI.
## Add this script as an AutoLoad named WordDiscoveryNotifier, after LanguageProgress.

const TOAST_SCENE: PackedScene = preload("res://Scenes/UI/WordDiscoveryToast.tscn")

var _toast: CanvasLayer = null
var _pending_ids: Array[String] = []
var _queued_or_showing: Dictionary = {}
var _is_showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(LanguageProgress):
		push_warning("[WORD DISCOVERY] LanguageProgress is unavailable.")
		return
	if not LanguageProgress.has_signal("vocabulary_discovered"):
		push_warning("[WORD DISCOVERY] Add vocabulary_discovered to LanguageProgress.gd before enabling this AutoLoad.")
		return
	var discovery_signal: Signal = Signal(LanguageProgress, "vocabulary_discovered")
	if not discovery_signal.is_connected(_on_vocabulary_discovered):
		discovery_signal.connect(_on_vocabulary_discovered)


func _exit_tree() -> void:
	if is_instance_valid(LanguageProgress) and LanguageProgress.has_signal("vocabulary_discovered"):
		var discovery_signal: Signal = Signal(LanguageProgress, "vocabulary_discovered")
		if discovery_signal.is_connected(_on_vocabulary_discovered):
			discovery_signal.disconnect(_on_vocabulary_discovered)
	if is_instance_valid(_toast):
		_toast.queue_free()


func _on_vocabulary_discovered(vocab_id: String) -> void:
	if vocab_id.is_empty() or _queued_or_showing.has(vocab_id):
		return
	var entry: VocabEntry = LanguageProgress.get_entry(vocab_id) as VocabEntry
	if entry == null:
		return
	_queued_or_showing[vocab_id] = true
	_pending_ids.append(vocab_id)
	if not _is_showing:
		_is_showing = true
		call_deferred("_show_next")


func _show_next() -> void:
	if _pending_ids.is_empty():
		_is_showing = false
		return

	var vocab_id: String = _pending_ids.pop_front()
	var entry: VocabEntry = LanguageProgress.get_entry(vocab_id) as VocabEntry
	if entry == null:
		_queued_or_showing.erase(vocab_id)
		call_deferred("_show_next")
		return

	if not is_instance_valid(_toast):
		_toast = TOAST_SCENE.instantiate() as CanvasLayer
		if _toast == null:
			push_error("[WORD DISCOVERY] Could not instantiate WordDiscoveryToast.tscn.")
			_queued_or_showing.erase(vocab_id)
			call_deferred("_show_next")
			return
		get_tree().root.add_child(_toast)

	var finish_callback := _on_toast_finished.bind(vocab_id)
	if not _toast.is_connected("display_finished", finish_callback):
		_toast.connect("display_finished", finish_callback, CONNECT_ONE_SHOT)

	var is_phrase: bool = entry.category.to_lower() == "phrase" or not entry.parts.is_empty()
	_toast.call("show_discovery", entry.kapampangan, is_phrase)


func _on_toast_finished(vocab_id: String) -> void:
	_queued_or_showing.erase(vocab_id)
	call_deferred("_show_next")
