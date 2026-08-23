@tool
class_name ScatterDataOps
extends RefCounted

static func set_colors(
		values: Array[Color],
		amount: int,
		color: Color,
) -> void:
	if values.size() > amount:
		values.resize(amount)
	while values.size() < amount:
		values.append(color)
	for index in values.size():
		values[index] = color

static func randomize_colors(
		values: Array[Color],
		amount: int,
		from_color: Color,
		to_color: Color,
		rng: RandomNumberGenerator,
) -> void:
	if values.size() > amount:
		values.resize(amount)
	while values.size() < amount:
		values.append(Color.WHITE)
	for index in values.size():
		values[index] = Color(
			rng.randf_range(from_color.r, to_color.r),
			rng.randf_range(from_color.g, to_color.g),
			rng.randf_range(from_color.b, to_color.b),
			rng.randf_range(from_color.a, to_color.a),
		)
