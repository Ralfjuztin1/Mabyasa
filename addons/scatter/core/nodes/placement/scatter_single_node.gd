@tool
class_name ScatterSingleNode
extends ScatterPlacementSourceNode

@export var offset := Vector3.ZERO
@export var rotation := Vector3.ZERO
@export var scale := Vector3.ONE


func get_type_id() -> StringName:
	return &"single"


func get_caption() -> String:
	return "Add Single Item"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_single(buffer, offset, rotation, scale, context.maximum_instances)
	return buffer
