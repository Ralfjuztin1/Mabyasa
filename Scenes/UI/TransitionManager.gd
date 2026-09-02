extends CanvasLayer

var color_rect: ColorRect
var progress_bar: ProgressBar
var current_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128 # Render on top of all UI elements and menus
	
	# 1. Full-screen black fade overlay
	color_rect = ColorRect.new()
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.color = Color(0, 0, 0, 1.0) # Start fully black on boot
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(color_rect)
	
	# 2. Dynamic Loading Progress Bar (Centered near the bottom of the screen)
	progress_bar = ProgressBar.new()
	progress_bar.anchor_left = 0.35
	progress_bar.anchor_right = 0.65
	progress_bar.anchor_top = 0.8
	progress_bar.anchor_bottom = 0.83
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.visible = false # Hidden initially until an async load starts
	add_child(progress_bar)
	
	# Wait one frame for the viewport to stabilize, then fade in from black
	await get_tree().process_frame
	fade_in(0.6)

func fade_out(duration: float = 0.5) -> void:
	if not color_rect:
		return
		
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP 
	print("🎬 [TRANSITION] Fading OUT to black over ", duration, "s")
	
	current_tween = create_tween()
	current_tween.tween_property(color_rect, "color:a", 1.0, duration)
	await current_tween.finished

func fade_in(duration: float = 0.5) -> void:
	if not color_rect:
		return
		
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		
	# Hide the progress bar once the fade-in starts completing
	if progress_bar:
		progress_bar.visible = false
		
	print("🎬 [TRANSITION] Fading IN from black over ", duration, "s")
	
	current_tween = create_tween()
	current_tween.tween_property(color_rect, "color:a", 0.0, duration)
	await current_tween.finished
	
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Re-enable mouse clicks

func update_progress(percent: float) -> void:
	if progress_bar:
		if not progress_bar.visible:
			progress_bar.visible = true # Show bar as soon as loading progress is fed
		progress_bar.value = percent
