@tool
class_name ScatterRelaxNode
extends ScatterPlacementNode

@export_range(1, 100, 1) var iterations := 3
@export_range(0.0, 1000000.0, 0.01) var offset_step := 0.01
@export_range(0.0, 1000000.0, 0.05) var consecutive_step_multiplier := 0.5


func get_type_id() -> StringName:
	return &"relax"


func get_caption() -> String:
	return "Relax Position"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_relax(
		buffer,
		iterations,
		offset_step,
		consecutive_step_multiplier,
	)
	return buffer
