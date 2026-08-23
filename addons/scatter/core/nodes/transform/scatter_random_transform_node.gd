@tool
class_name ScatterRandomTransformNode
extends ScatterPlacementNode

@export var position := Vector3.ZERO
@export var rotation := Vector3.ZERO
@export var scale := Vector3.ZERO
@export_enum("Global:0", "Local:1", "Instance:2") var space := 2


func get_type_id() -> StringName:
	return &"random_transform"


func get_caption() -> String:
	return "Randomize Transforms"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_random_transform(
		buffer,
		position,
		rotation,
		scale,
		space,
		context.random_for(self),
		context.target,
	)
	return buffer
