@tool
class_name ScatterTransformNode
extends ScatterPlacementNode

@export var position := Vector3.ZERO
@export var rotation := Vector3.ZERO
@export var scale := Vector3.ONE
@export_enum("Global:0", "Local:1", "Instance:2") var space := 2


func get_type_id() -> StringName:
	return &"transform"


func get_caption() -> String:
	return "Edit Transform"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_transform(buffer, position, rotation, scale, space, context.target)
	return buffer
