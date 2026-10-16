extends Control

## Small self-drawn pixel forge. Uses simple rectangles so it needs no extra textures.
## BlacksmithMenu drives strike_index and animation_progress during each hammer hit.

var strike_index: int = 0
var animation_progress: float = 0.0
var result_mode: int = 0 # 0 = forging/idle, 1 = success, -1 = failure

const BG := Color(0.025, 0.045, 0.032, 1.0)
const BG_GLOW := Color(0.19, 0.12, 0.035, 0.34)
const GOLD := Color(0.96, 0.70, 0.23, 1.0)
const HOT := Color(1.0, 0.83, 0.38, 1.0)
const ORANGE := Color(1.0, 0.39, 0.12, 1.0)
const IRON := Color(0.43, 0.49, 0.43, 1.0)
const IRON_LIGHT := Color(0.72, 0.75, 0.62, 1.0)
const IRON_DARK := Color(0.16, 0.22, 0.17, 1.0)
const WOOD := Color(0.43, 0.24, 0.11, 1.0)
const SUCCESS := Color(0.47, 0.80, 0.39, 1.0)
const FAILURE := Color(0.85, 0.31, 0.25, 1.0)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 108)
	clip_contents = true
	queue_redraw()


func set_forge_state(new_strike_index: int, new_progress: float, new_result_mode: int = 0) -> void:
	strike_index = new_strike_index
	animation_progress = clampf(new_progress, 0.0, 1.0)
	result_mode = new_result_mode
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_rect(Rect2(Vector2(0, h - 8), Vector2(w, 8)), Color(0.01, 0.02, 0.015, 1.0))

	var cx: float = w * 0.52
	var impact: Vector2 = Vector2(cx + 5.0, h * 0.58)
	var glow_color: Color = BG_GLOW
	if result_mode == 1:
		glow_color = Color(0.24, 0.35, 0.10, 0.52)
	elif result_mode == -1:
		glow_color = Color(0.36, 0.06, 0.045, 0.42)
	elif strike_index > 0:
		glow_color = Color(0.32, 0.16, 0.035, 0.40)

	# Pixel glow behind the work surface.
	draw_rect(Rect2(cx - 72, 22, 144, 57), glow_color)
	draw_rect(Rect2(cx - 56, 30, 112, 42), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.72))

	# Two small flame tongues under the anvil.
	var flame_phase: float = sin(animation_progress * PI * 2.0) * 3.0 if strike_index > 0 else 0.0
	draw_rect(Rect2(cx - 13, h - 29 + flame_phase, 8, 12), ORANGE)
	draw_rect(Rect2(cx - 9, h - 33 + flame_phase, 6, 12), HOT)
	draw_rect(Rect2(cx + 6, h - 27 - flame_phase, 7, 10), ORANGE)
	draw_rect(Rect2(cx + 8, h - 30 - flame_phase, 4, 8), GOLD)

	# Anvil: chunky silhouettes designed to read at the game's pixel scale.
	draw_rect(Rect2(cx - 21, h - 29, 42, 9), IRON_DARK)
	draw_rect(Rect2(cx - 17, h - 27, 34, 7), IRON)
	draw_rect(Rect2(cx - 30, h - 36, 60, 9), IRON_DARK)
	draw_rect(Rect2(cx - 28, h - 37, 56, 7), IRON_LIGHT)
	draw_rect(Rect2(cx - 35, h - 40, 70, 6), IRON)
	draw_rect(Rect2(cx - 27, h - 41, 54, 2), HOT if strike_index > 0 and animation_progress > 0.6 else GOLD)

	# Hammer swings down to the anvil and returns during every strike.
	var swing: float = 0.0
	if strike_index > 0:
		var p: float = animation_progress
		if p < 0.42:
			swing = lerpf(-0.92, 0.42, p / 0.42)
		else:
			swing = lerpf(0.42, -0.92, (p - 0.42) / 0.58)
	else:
		swing = -0.70
	var hammer_pivot: Vector2 = Vector2(cx + 30, 20)
	draw_set_transform(hammer_pivot, swing, Vector2.ONE)
	draw_rect(Rect2(-3, -1, 6, 38), WOOD)
	draw_rect(Rect2(-4, 3, 8, 5), Color(0.58, 0.34, 0.16, 1.0))
	draw_rect(Rect2(-15, -9, 30, 12), IRON_DARK)
	draw_rect(Rect2(-15, -11, 30, 9), IRON_LIGHT)
	draw_rect(Rect2(-12, -12, 24, 3), Color(0.84, 0.84, 0.69, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Small pixel glints around the impact. Positions are deterministic and animate with the strike.
	if strike_index > 0:
		var p2: float = animation_progress
		var alpha: float = 1.0 - p2 * 0.55
		for i: int in range(12):
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var row: float = float(i / 2)
			var travel: float = 5.0 + p2 * (13.0 + row * 2.0)
			var sx: float = impact.x + side * (7.0 + row * 4.0 + travel * 0.25)
			var sy: float = impact.y - travel + float((i * 7) % 9) - 4.0
			var spark_color: Color = HOT if i % 3 == 0 else (ORANGE if i % 2 == 0 else GOLD)
			spark_color.a = alpha
			draw_rect(Rect2(Vector2(round(sx), round(sy)), Vector2(3 if i % 3 == 0 else 2, 3 if i % 3 == 0 else 2)), spark_color)

	# Sparse decorative pixel flecks keep the area from looking empty while idle.
	for i: int in range(8):
		var px: float = float((i * 61 + 19) % int(maxf(w, 1.0)))
		var py: float = float(12 + ((i * 17) % 36))
		var dot_color: Color = Color(0.68, 0.54, 0.26, 0.35)
		draw_rect(Rect2(Vector2(px, py), Vector2(2, 2)), dot_color)

	var caption: String = "THE FORGE IS READY"
	var caption_color: Color = GOLD
	if strike_index > 0:
		caption = "STRIKE %d / 3" % mini(strike_index, 3)
	if result_mode == 1:
		caption = "THE METAL HOLDS!"
		caption_color = SUCCESS
	elif result_mode == -1:
		caption = "THE STRIKE SLIPPED"
		caption_color = FAILURE
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, caption_color)
