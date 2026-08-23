@tool
class_name ScatterSnapNode
extends ScatterPlacementNode

@export var position_step := Vector3.ZERO
@export var rotation_step := Vector3.ZERO
@export var scale_step := Vector3.ZERO


func get_type_id() -> StringName:
	return &"snap"


func get_caption() -> String:
	return "Snap Transforms"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_snap(buffer, position_step, rotation_step, scale_step)
	return buffer
