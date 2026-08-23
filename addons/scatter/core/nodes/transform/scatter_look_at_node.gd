@tool
class_name ScatterLookAtNode
extends ScatterPlacementNode

@export var target := Vector3.ZERO
@export var up := Vector3.UP


func get_type_id() -> StringName:
	return &"look_at"


func get_caption() -> String:
	return "Look At"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_look_at(buffer, target, up)
	return buffer
