@tool
class_name ScatterRemoveRandomNode
extends ScatterPlacementNode

@export_range(0.0, 100.0, 1.0) var probability := 50.0


func get_type_id() -> StringName:
	return &"remove_random"


func get_caption() -> String:
	return "Remove Random"


func get_category() -> StringName:
	return &"Filter"


func get_color() -> Color:
	return Color("bd5b60")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterFilterOps.remove_random(buffer, probability, context.random_for(self))
	return buffer
