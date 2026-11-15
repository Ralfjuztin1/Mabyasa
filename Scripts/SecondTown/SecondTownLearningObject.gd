extends Control

## Small vector stand-ins for counting items; no third-party art required.
## NPC character sprites remain user-editable independently.

var kind: String = "basket"


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	match kind:
		"basket":
			var brown: Color = Color(0.65, 0.38, 0.18)
			var rim: Color = Color(0.87, 0.69, 0.35)
			draw_arc(Vector2(w * 0.5, h * 0.34), w * 0.30, PI, TAU, 16, rim, 4.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(w * 0.12, h * 0.40), Vector2(w * 0.88, h * 0.40),
				Vector2(w * 0.74, h * 0.88), Vector2(w * 0.26, h * 0.88)
			]), brown)
			draw_line(Vector2(w * 0.10, h * 0.42), Vector2(w * 0.90, h * 0.42), rim, 5.0)
			draw_line(Vector2(w * 0.22, h * 0.62), Vector2(w * 0.78, h * 0.62), rim, 2.0)
		"seed packet":
			var soil: Color = Color(0.66, 0.52, 0.26)
			var green: Color = Color(0.40, 0.64, 0.30)
			draw_rect(Rect2(w * 0.19, h * 0.22, w * 0.62, h * 0.66), soil)
			draw_circle(Vector2(w * 0.5, h * 0.48), w * 0.12, green)
			draw_line(Vector2(w * 0.5, h * 0.48), Vector2(w * 0.5, h * 0.70), green, 3.0)
		"water container":
			var base: Color = Color(0.30, 0.55, 0.66)
			var rim: Color = Color(0.70, 0.83, 0.80)
			draw_colored_polygon(PackedVector2Array([
				Vector2(w * 0.20, h * 0.25), Vector2(w * 0.80, h * 0.25),
				Vector2(w * 0.72, h * 0.88), Vector2(w * 0.28, h * 0.88)
			]), base)
			draw_line(Vector2(w * 0.20, h * 0.25), Vector2(w * 0.80, h * 0.25), rim, 5.0)
			draw_arc(Vector2(w * 0.5, h * 0.30), w * 0.28, PI, TAU, 14, rim, 2.0)
