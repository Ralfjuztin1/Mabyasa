extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	# Ensure the screen is clear when the game starts
	color_rect.modulate.a = 0.0
	progress_bar.visible = false

# Fades the screen to black and shows the loading bar
func fade_out(duration: float = 0.5) -> void:
	progress_bar.value = 0
	progress_bar.visible = true
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	await tween.finished

# Fades the screen back to transparent and hides the loading bar
func fade_in(duration: float = 0.5) -> void:
	progress_bar.visible = false
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	await tween.finished

# Updates the visual loading bar
func update_progress(percent: float) -> void:
	progress_bar.value = percent * 100
