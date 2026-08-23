@tool
class_name ScatterScaleNode
extends ScatterPlacementNode

@export_enum("Offset:0", "Multiply:1", "Override:2") var operation := 1
@export var scale := Vector3.ONE
@export_enum("Global:0", "Local:1", "Instance:2") var space := 2


func get_type_id() -> StringName:
	return &"scale"


func get_caption() -> String:
	return "Edit Scale"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_scale(buffer, scale, operation, space, context.target)
	return buffer
