extends CanvasLayer

## Short, non-blocking toast shown when the player discovers new vocabulary.
## The notifier queues discoveries so several components of one phrase do not
## overlap or turn into a stack of simultaneous notifications.

signal display_finished

const DISPLAY_SECONDS: float = 2.6
const ENTER_SECONDS: float = 0.28
const EXIT_SECONDS: float = 0.24
const HIDDEN_TOP: float = -116.0
const HIDDEN_BOTTOM: float = -24.0
const VISIBLE_TOP: float = 20.0
const VISIBLE_BOTTOM: float = 112.0

@onready var toast_panel: PanelContainer = $ToastPanel
@onready var icon_texture: TextureRect = $ToastPanel/Margin/Content/BookIcon
@onready var eyebrow_label: Label = $ToastPanel/Margin/Content/TextStack/EyebrowLabel
@onready var message_label: Label = $ToastPanel/Margin/Content/TextStack/MessageLabel
@onready var entry_label: Label = $ToastPanel/Margin/Content/TextStack/EntryLabel

var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	toast_panel.modulate.a = 0.0
	toast_panel.offset_top = HIDDEN_TOP
	toast_panel.offset_bottom = HIDDEN_BOTTOM


func show_discovery(entry_text: String, is_phrase: bool) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	entry_label.text = entry_text.strip_edges()
	message_label.text = "New phrase discovered!" if is_phrase else "New word discovered!"
	eyebrow_label.text = "WORDBOOK UPDATED"
	toast_panel.modulate.a = 0.0
	toast_panel.offset_top = HIDDEN_TOP
	toast_panel.offset_bottom = HIDDEN_BOTTOM
	visible = true

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(toast_panel, "offset_top", VISIBLE_TOP, ENTER_SECONDS)
	_tween.parallel().tween_property(toast_panel, "offset_bottom", VISIBLE_BOTTOM, ENTER_SECONDS)
	_tween.parallel().tween_property(toast_panel, "modulate:a", 1.0, 0.22)
	_tween.tween_interval(DISPLAY_SECONDS)
	_tween.tween_property(toast_panel, "modulate:a", 0.0, EXIT_SECONDS)
	_tween.parallel().tween_property(toast_panel, "offset_top", HIDDEN_TOP, EXIT_SECONDS)
	_tween.parallel().tween_property(toast_panel, "offset_bottom", HIDDEN_BOTTOM, EXIT_SECONDS)
	_tween.finished.connect(_on_display_tween_finished)


func _on_display_tween_finished() -> void:
	visible = false
	display_finished.emit()
