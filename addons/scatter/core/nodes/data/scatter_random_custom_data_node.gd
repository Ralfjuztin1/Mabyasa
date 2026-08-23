@tool
class_name ScatterRandomCustomDataNode
extends ScatterPlacementNode

@export var from_color := Color(0, 0, 0, 0)
@export var to_color := Color(1, 1, 1, 1)


func get_type_id() -> StringName:
	return &"random_custom_data"


func get_caption() -> String:
	return "Random Custom Data"


func get_category() -> StringName:
	return &"Data"


func get_color() -> Color:
	return Color("8b929e")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	buffer.normalize()
	ScatterDataOps.randomize_colors(
		buffer.custom_data,
		buffer.transforms.size(),
		from_color,
		to_color,
		context.random_for(self),
	)
	return buffer
