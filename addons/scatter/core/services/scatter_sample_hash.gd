@tool
class_name ScatterSampleHash
extends RefCounted


static func dimension(value: float, index: int) -> float:
	# PCG RXS-M-XS: turn one normalized scalar into independent deterministic axes.
	var state := int(clampf(value, 0.0, 0.999999999) * 4294967295.0)
	for _step in index + 1:
		state = (state * 747796405 + 2891336453) & 0xffffffff
	var word := (((state >> ((state >> 28) + 4)) ^ state) * 277803737) & 0xffffffff
	word = ((word >> 22) ^ word) & 0xffffffff
	return float(word) / 4294967296.0
