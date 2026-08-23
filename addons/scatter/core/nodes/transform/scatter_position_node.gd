@tool
class_name ScatterPositionNode
extends ScatterPlacementNode

@export_enum("Offset:0", "Multiply:1", "Override:2") var operation := 0
@export var position := Vector3.ZERO
@export_enum("Global:0", "Local:1", "Instance:2") var space := 1


func get_type_id() -> StringName:
	return &"position"


func get_caption() -> String:
	return "Edit Position"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_position(buffer, position, operation, space, context.target)
	return buffer
