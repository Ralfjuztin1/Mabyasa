extends CanvasLayer

## Shared transition manager.
##
## Normal fade_out()/fade_in() calls use a plain black fade.
## The loading artwork is shown only after update_progress() is called,
## which is currently done by Main.gd while a level is being loaded.
## This keeps quest/cutscene fades black while level loads can use the artwork.

@onready var background_texture: TextureRect = $BackgroundTexture
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var progress_bar: ProgressBar = $ProgressBar

var current_tween: Tween = null
var _loading_screen_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_texture.visible = false

	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	progress_bar.anchor_left = 0.35
	progress_bar.anchor_right = 0.65
	progress_bar.anchor_top = 0.80
	progress_bar.anchor_bottom = 0.83
	progress_bar.offset_left = 0.0
	progress_bar.offset_right = 0.0
	progress_bar.offset_top = 0.0
	progress_bar.offset_bottom = 0.0
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Progress must draw above the fade overlay during loading.
	move_child(progress_bar, get_child_count() - 1)


## Plain black fade. Used by quests, cutscenes, and other normal transitions.
func fade_out(duration: float = 0.5) -> void:
	if not is_instance_valid(fade_overlay):
		return

	_kill_current_tween()
	_loading_screen_active = false
	background_texture.visible = false
	progress_bar.visible = false
	fade_overlay.visible = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	current_tween = create_tween()
	current_tween.tween_property(
		fade_overlay,
		"color:a",
		1.0,
		maxf(duration, 0.01)
	)
	await current_tween.finished


## Plain black fade-in for quests/cutscenes. If a loading screen is active,
## cover its art with black first, then reveal the newly loaded scene.
func fade_in(duration: float = 0.5) -> void:
	if not is_instance_valid(fade_overlay):
		return

	_kill_current_tween()
	fade_overlay.visible = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	if _loading_screen_active:
		# Keep the loading artwork visible while fading to black.
		background_texture.visible = true
		progress_bar.visible = true
		var cover_duration := maxf(duration * 0.5, 0.01)
		current_tween = create_tween()
		current_tween.tween_property(
			fade_overlay,
			"color:a",
			1.0,
			cover_duration
		)
		await current_tween.finished

		background_texture.visible = false
		progress_bar.visible = false
		_loading_screen_active = false

		current_tween = create_tween()
		current_tween.tween_property(
			fade_overlay,
			"color:a",
			0.0,
			maxf(duration - cover_duration, 0.01)
		)
		await current_tween.finished
	else:
		# Normal fade-in: hide all loading visuals and reveal gameplay from black.
		background_texture.visible = false
		progress_bar.visible = false
		current_tween = create_tween()
		current_tween.tween_property(
			fade_overlay,
			"color:a",
			0.0,
			maxf(duration, 0.01)
		)
		await current_tween.finished

	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called by Main.gd only while polling an asynchronous level load.
## First call switches from the black screen to the illustrated loading screen.
func update_progress(percent: float) -> void:
	if not is_instance_valid(progress_bar):
		return

	progress_bar.value = clampf(percent, 0.0, 1.0)
	progress_bar.visible = true

	if not _loading_screen_active:
		_loading_screen_active = true
		background_texture.visible = true
		fade_overlay.visible = true
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

		# fade_out() has already covered gameplay with black before Main.gd
		# starts polling the threaded load. Reveal the loading artwork smoothly.
		_kill_current_tween()
		current_tween = create_tween()
		current_tween.tween_property(
			fade_overlay,
			"color:a",
			0.0,
			0.18
		)


func _kill_current_tween() -> void:
	if is_instance_valid(current_tween) and current_tween.is_valid():
		current_tween.kill()
